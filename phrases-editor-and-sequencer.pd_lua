
local Phrases = pd.Class:new():register("phrases-editor-and-sequencer")



-- Load the code's data tables in a tidy manner
local tabs = require("phrases-main-tables")
local kbnames = tabs.kbnames
local kbhash = tabs.kbhash(kbnames)
local notenames = tabs.notenames
local cmdtable = tabs.cmdtable
local cmdnames = tabs.cmdnames
local trnames = tabs.trnames
local catchtypes = tabs.catchtypes
local modenames = tabs.modenames



-- Check whether a value falls within a particular range; return true or false
local function rangeCheck(val, low, high)

	if high < low then
		low, high = high, low
	end

	if (val >= low)
	and (val <= high)
	then
		return true
	end
	
	return false

end



-- Recursively copy all sub-tables, when copying from one table to another. Form of: newtable = deepCopy(oldtable, {})
local function deepCopy(t, t2)

	for k, v in pairs(t) do
	
		if type(v) ~= "table" then
			t2[k] = v
		else
			local temp = {}
			deepCopy(v, temp)
			t2[k] = temp
		end
		
	end
	
	return t2
	
end



-- Convert a numerical MIDI note value to a more human-readable note (e.g. C-3, D-4 etc). Note: The input is 0-indexed
local function readableNote(f)

	local nkey = (f % 12) + 1
	local nval = math.floor(f / 12)
	
	local mout = notenames[nkey]
	
	if string.len(mout) == 1 then
		mout = mout .. "-"
	end
	
	mout = mout .. nval
	
	return mout
	
end



-- Calculate a random transference direction, from a hash of weighted directions (1-9; 10 is ignored)
local function calcTransference(trhash)

	local total, count, num = 0, 0, 0
	
	for k, v in pairs(trhash) do
		if k <= 9 then
			total = total + v
		end
	end
	
	local sel = math.random(total)
	
	while (count < sel)
	and (num < 9)
	do
		num = num + 1
		if trhash[num] ~= nil then
			count = count + trhash[num]
		end
	end
	
	return num
	
end



-- Convert x,y coordinates into a key, within a matrix of width,height
local function coordsToKey(x, y, width, height, inoffset, outoffset)

	x = x - inoffset
	y = y - inoffset
	
	local key = (((width * y) + x) % (height * width)) + outoffset
	
	return key
	
end

-- Convert a key into coords x,y, within a martix of width,height
local function keyToCoords(key, width, height, inoffset, outoffset)

	local x = ((key - inoffset) % width) + outoffset
	local y = ((((key - inoffset) - x) / width) % height) + outoffset
	
	return x, y
	
end

-- Move from key by offset of xmod,ymod, as plotted within a matrix of width,height, and return the proper key
local function trMod(key, xmod, ymod, width, height)

	local x, y = keyToCoords(key, width, height, 1, 0)
	
	x = (x + xmod) % width
	y = (y + ymod) % height
	
	return coordsToKey(x, y, width, height, 0, 1)
	
end

-- Make a matrix, linking each key to its surrounding keys, and connecting all edges
local function makeTrMatrix(width, height)
	
	local matrix = {}
	
	for x = 1, width do
		
		for y = 1, height do
		
			local key = coordsToKey(x, y, width, height, 1, 1)
			
			matrix[key] = {}
			matrix[key][1] = trMod(key, -1, -1, width, height)
			matrix[key][2] = trMod(key, 0, -1, width, height)
			matrix[key][3] = trMod(key, 1, -1, width, height)
			matrix[key][4] = trMod(key, -1, 0, width, height)
			matrix[key][5] = key
			matrix[key][6] = trMod(key, 1, 0, width, height)
			matrix[key][7] = trMod(key, -1, 1, width, height)
			matrix[key][8] = trMod(key, 0, 1, width, height)
			matrix[key][9] = trMod(key, 1, 1, width, height)
			
		end
		
	end
	
	return matrix
	
end



-- Pre-generate a hash for displaying tick numbers in the editor GUI. Implemented this way to avoid the lag that would otherwise occur from a huge number of for-loop iterations if this were done live in updateNoteButton().
local function makeDisplayValHash(t)

	local hash = {}
	local halts = 1

	for k, v in ipairs(t) do
		hash[k] = halts
		if v[1] == -1 then
			halts = halts + 1
		end
	end
	
	return hash

end



-- Get a table of RGB values (0-255), and return a table of RGB-normal, RGB-dark, RGB-light
local function modColor(color)

	local colout = {}
	
	colout[1] = color
	colout[2], colout[3] = {}, {}
	for i = 1, 3 do
		colout[2][i] = math.max(0, color[i] - 30)
		colout[3][i] = math.min(255, color[i] + 30)
	end
	
	return colout

end

-- Arrange a send-name, a color table, and a message-color table into a flat list
local function rgbOutList(name, ctab, mtab)

	return { name, ctab[1], ctab[2], ctab[3], mtab[1], mtab[2], mtab[3], }

end



-- Send a note that has been parsed by noteParse()
function Phrases:noteSend(k, note)

	if note[1] == -5 then
	
		self.bpm = note[2]
		pd.send("phrases-bpm", "float", {self.bpm})
		
	elseif note[1] == -6 then
	
		self.tpb = note[2]
		pd.send("phrases-tpb", "float", {self.tpb})
		
	elseif note[1] == -7 then
	
		self.gate = note[2]
		pd.send("phrases-gate", "float", {self.gate})
		
	else
		self:outlet(2, "list", note)
	end
	
	if rangeCheck(note[1], 144, 159) then -- All note-ons
	
		local x = (k - 1) % self.gridx
		local y = ((k - 1) - x) / self.gridy
		
		local active = 1
		if self.phrase[k].active == false then
			active = 0
		end
	
		self:outlet(4, "list", {x, y, active}) -- Send a blink command for the phrase's Monome button
		
	end

end

-- Pass a note command through the local and global sustain-tables
function Phrases:noteParse(k, note)

	local chan = note[1] % 16
	local command = note[1] - chan
	local pitch = note[2]
	local velo = note[3]
	
	if (command == 144)
	or (command == 128)
	then
	
		-- Set pitch and velocity to their ADC-shifted values, if applicable
		if self.noteshift[chan][note[2]] ~= nil then
			pitch = self.noteshift[chan][note[2]]
		end
		
		if self.veloshift[chan][note[2]] ~= nil then
			velo = self.veloshift[chan][note[2]]
		end
		
		-- Create the parent tables if they don't exist
		if self.midi[chan][pitch] == nil then
			self.midi[chan][pitch] = 0
		end
		
		if self.phrase[k].midi[chan][pitch] == nil then
			self.phrase[k].midi[chan][pitch] = 0
		end

		-- Modify sustain values, based on incoming note-on/note-offs
		if command == 128 then
		
			self.midi[chan][pitch] = self.midi[chan][pitch] - self.phrase[k].midi[chan][pitch]
			self.phrase[k].midi[chan][pitch] = 0
			
			-- Only send the noteoff command if the note's global sustain value is 0
			if self.midi[chan][pitch] == 0 then
				self.noteshift[chan][pitch] = nil
				self.veloshift[chan][pitch] = nil
				self:noteSend(k, {note[1], pitch, velo})
			end
			
		elseif command == 144 then
		
			local oldpitch = pitch
			local oldvelo = velo
			
			-- Only shift note values before a noteon, so that they aren't changed inbetween a noteon and its corresponding noteoff
			for k, v in ipairs(self.adc) do
			
				if v.channel == chan then
				
					local modval = v.magnitude * v.val
					
					if v.target == 2 then
					
						if v.style == "relative" then
							pitch = math.min(127, math.max(0, math.floor(pitch + modval - (v.magnitude / 2))))
						elseif v.style == "absolute" then
							pitch = math.min(127, math.max(0, modval))
						end
						
						self.noteshift[chan][note[2]] = pitch
						
					elseif v.target == 3 then
					
						if v.style == "relative" then
							velo = math.min(127, math.max(1, math.floor(velo + modval - (v.magnitude / 2))))
						elseif v.style == "absolute" then
							velo = math.min(127, math.max(1, modval))
						end
						
						self.veloshift[chan][note[2]] = velo
						
					end
					
				end
				
			end
			
			if oldpitch ~= pitch then
				self.noteshift[chan][oldpitch] = nil
			end
			
			if oldvelo ~= velo then
				self.veloshift[chan][oldpitch] = nil
			end
			
			if self.midi[chan][pitch] >= 1 then
			
				-- If the note is already playing, send a quick noteoff and noteon, leaving the internal values the same
				-- Old note is terminated correctly, using values from before the most recent ADC value-shift
				self:noteSend(k, {128 + chan, oldpitch, oldvelo})
				self:noteSend(k, {note[1], pitch, velo})
				
				if self.phrase[k].midi[chan][pitch] == 0 then -- If the note is newly active in the phrase, track that locally and globally
					self.phrase[k].midi[chan][pitch] = 1
					self.midi[chan][pitch] = self.midi[chan][pitch] + 1
				end
				
			else -- If the note isn't already playing, track it locally and globally, and send a noteon
				self.midi[chan][pitch] = 1
				self.phrase[k].midi[chan][pitch] = 1
				self:noteSend(k, {note[1], pitch, velo})
			end
			
		end
		
	else -- Send all commands that aren't NOTEON/NOTEOFFs
		self:noteSend(k, note)
	end
	
end

-- Halt all MIDI sustains in a phrase, and apply them to the global MIDI-sustain array, and MIDI note-offs.
function Phrases:haltPhraseMidi(p)

	-- For every currently active note in the phrase, send a MIDI-OFF through noteParse()
	for chan, v in pairs(self.phrase[p].midi) do
		for pitch, num in pairs(v) do
			if num == 1 then
				self:noteParse(p, {128 + chan, pitch, 127})
			end
		end
	end
	
end

-- Called to iterate through the notes in various phrases
function Phrases:iterate(k)
	
	local p = self.phrase[k].pointer
	local tick = self.phrase[k].tick
	
	tick = tick + 1
	
	repeat -- Iterate through notes until hitting a silent beat, or looping through a self-terminating phrase
	
		local oldp = p
		local note = self.phrase[k].notes[p]
		local chan = note[1] % 16
		
		-- If the current note isn't a blank-tick, parse the note value
		if self.phrase[k].notes[p][1] ~= -1 then
			self:noteParse(k, self.phrase[k].notes[p])
		end
	
		p = p + 1
		
		-- If the pointer has passed the end of the phrase, add a transference command to the tick's trqueue
		if p > #self.phrase[k].notes then
		
			p = 1
			tick = 1
			
			if self.phrase[k].tdir ~= 5 then -- Insert a transference command into the tick's transference table
				self.trqueue[k] = self.phrase[k].tdir
			else -- Recalculate the transference direction of every stationary phrase, as it wouldn't otherwise by done by the trqueue iterations
				self.phrase[k].tdir = calcTransference(self.phrase[k].transfer)
			end
			
			-- Slate all self-terminating phrases for termination
			if self.phrase[k].transfer[10] == 0 then
				table.insert(self.trhalts, k)
			end
			
		end
		
	until self.phrase[k].notes[oldp][1] == -1
	
	self.phrase[k].pointer = p
	self.phrase[k].tick = tick
	
end



-- Shift the volume value, transference strength, or ADC magnitude by a certain amount, depending on the input mode
function Phrases:shiftVolumeVal(val)

	if self.inputmode == "note" then
	
		self.velocity = (self.velocity + val) % 128
		self:updateVelocityButton()
		pd.post("MIDI Velocity set to " .. self.velocity)
		
	elseif self.inputmode == "tr" then
	
		if rangeCheck(self.trpoint, 1, 9) then
			self.phrase[self.key].transfer[self.trpoint] = math.min(255, math.max(0, self.phrase[self.key].transfer[self.trpoint] + val))
			pd.post("Phrase " .. self.key .. ": Set transference direction " .. self.channel .. " to strength " .. self.phrase[self.key].transfer[self.trpoint])
		elseif self.trpoint == 10 then
			self.phrase[self.key].transfer[10] = (self.phrase[self.key].transfer[10] + 1) % 2
			pd.post("Phrase " .. self.key .. ": Persistence set to " .. self.phrase[self.key].transfer[10])
		end

		-- Update the relevant transference sub-button in the grid GUI
		local xtr, ytr = keyToCoords(self.key, self.gridx, self.gridy, 1, 0)
		local trbut = ytr .. "-" .. xtr .. "-grid-"
		if rangeCheck(self.trpoint, 1, 9) then
			if self.phrase[self.key].transfer[self.trpoint] > 0 then
				self:outlet(5, "list", rgbOutList(trbut .. "sub-" .. self.trpoint, self.color[8][3], self.color[8][3]))
			else
				self:outlet(5, "list", rgbOutList(trbut .. "sub-" .. self.trpoint, self.color[8][2], self.color[8][2]))
			end
		end
		
		self:addStateToHistory()

		self:updateEditorGUI()
		
	elseif (self.inputmode == "adc")
	and (self.adc[self.adcpoint] ~= nil)
	then
	
		self.adc[self.adcpoint].magnitude = (self.adc[self.adcpoint].magnitude + val) % 128
		pd.post("ADC " .. self.adcpoint .. ": magnitude set to " .. self.adc[self.adcpoint].magnitude)
		
		self:addStateToHistory()

		self:updateEditorGUI()
		
	end
	
end



-- Update the color and contents of a cell in the editor panel
function Phrases:updateNoteButton(cellx, celly, k, p) -- editor x pointer, editor y pointer, phrase key, note pointer

	local cvals = -1 -- Color-out value
	local mcvals = -1 -- Message-color-out value
	local col = {} -- Note-cell color holder
	local message = ""
	local bname = ""
	
	local gsize = self.gridx * self.gridy
	local offsetx = math.ceil(self.editorx / 2)
	local offsety = math.floor(self.editory / 2)
	
	local notex = (cellx + k) - offsetx
	if (notex < 1)
	or (notex > gsize)
	then
		notex = ((notex - 1) % gsize) + 1
	end
	
	local notenum = #self.phrase[notex].notes
	
	-- Wrap short, non-active phrases against the active phrase's pointer
	if p > notenum then
		p = ((p - 1) % notenum) + 1
	end
	
	local notey = (celly - offsety) + 1 -- All inactive notes are stationary
	if cellx == offsetx then -- All notes in the active phrase follow the pointer
		notey = (celly + p) - offsety
	end
	
	-- Wrap the notes, to display the phrase repeating
	if (notey < 1)
	or (notey > notenum)
	then
		notey = ((notey - 1) % notenum) + 1
	end
	
	local haltticks = self.phrase[notex].dhash
	local htick = haltticks[notey]
	local hlen = string.len(tostring(htick))
	local hmaxlen = string.len(tostring(haltticks[#haltticks]))
	
	local note = self.phrase[notex].notes[notey]
	
	-- Insert a number of periods that properly aligns the note with its column's max tick value
	message = htick .. string.rep(".", hmaxlen - (hlen - 1))
	
	-- Make the relevant data bytes more human-readable, if the pitchview flag is true. Else return their internal values
	if self.pitchview == true then
	
		if rangeCheck(note[1], 128, 143) then -- All NOTE-OFFs
			message = message .. " " .. (note[1] % 16) .. "off " .. readableNote(note[2]) .. " " .. note[3]
		elseif rangeCheck(note[1], 144, 159) then -- All NOTE-ONs
			message = message .. " " .. (note[1] % 16) .. "on " .. readableNote(note[2]) .. " " .. note[3]
		elseif rangeCheck(note[1], 192, 223) then -- All two-byte notes
			message = message .. " " .. note[1] .. " " .. note[2]
		elseif note[1] == -1 then -- Empty notes
			message = message .. " --------"
		elseif note[1] == -5 then -- Local BPM
			message = message .. " BPM " .. note[2]
		elseif note[1] == -6 then -- Local TPB
			message = message .. " TPB " .. note[2]
		elseif note[1] == -7 then -- Local GATE
			message = message .. " GATE " .. note[2]
		else -- All other three-byte MIDI messages
			message = message .. " " .. table.concat(note, " ")
		end
	
	else
		message = message .. " " .. table.concat(note, " ")
	end
	
	if self.inputmode == "tr" then -- Show the transference panel when transference mode is active
	
		local tr = self.phrase[notex].transfer
		
		if rangeCheck(celly, 1, 10) then
		
			if (tr[celly] >= 1)
			or (self.pitchview == false)
			then
				message = celly .. ". " .. tr[celly]
			else
				message = celly .. ". --"
			end
			
			mcvals = self.color[4][1]
			
			if cellx == offsetx then -- Set active phrase's transference values to the main user-defined color
				if celly == self.trpoint then
					cvals = self.color[1][1]
				else
					cvals = self.color[1][2]
				end
			else -- Set other transference values to the secondary user-defined color
				cvals = self.color[2][1]
			end
			
		else
			cvals = self.color[3][2]
			mcvals = self.color[3][1]
		end
		
		bname = (celly - 1) .. "-" .. (cellx - 1) .. "-editor-button"
		self:outlet(5, "list", {bname, cvals[1], cvals[2], cvals[3], mcvals[1], mcvals[2], mcvals[3]})
		pd.send(bname, "label", {message})
	
	elseif self.inputmode == "adc" then
	
		cvals = self.color[3][2]
		mcvals = self.color[3][1]
		
		if cellx == offsetx then
		
			mcvals = self.color[4][1]
		
			local curadc = math.floor((celly - 1) / 4) + 1
			
			if self.adc[curadc] ~= nil then
			
				if ((celly - 1) % 4) == 0 then
					message = curadc .. ". Chan: " .. self.adc[curadc].channel
				elseif ((celly - 1) % 4) == 1 then
					message = curadc .. ". Target: " .. self.adc[curadc].target
				elseif ((celly - 1) % 4) == 2 then
					message = curadc .. ". Style: " .. self.adc[curadc].style
				elseif ((celly - 1) % 4) == 3 then
					message = curadc .. ". Magnitude: " .. self.adc[curadc].magnitude
				end
			
				if curadc == self.adcpoint then
					cvals = self.color[1][1]
				else
					cvals = self.color[2][2]
				end
			
			end
			
		end
		
		bname = (celly - 1) .. "-" .. (cellx - 1) .. "-editor-button"
		self:outlet(5, "list", {bname, cvals[1], cvals[2], cvals[3], mcvals[1], mcvals[2], mcvals[3]})
		pd.send(bname, "label", {message})
	
	else -- Display colors normally when in other view modes
	
		if note[1] == -1 then -- Blank note color
			col = self.color[3]
		elseif rangeCheck(note[1], 128, 159) then -- Note-on / note-off color
			col = self.color[1]
		else -- Other commands color
			col = self.color[2]
		end
		
		if cellx == offsetx then -- For the active phrase, use regular colors
			cvals = col[1]
			mcvals = self.color[4][1]
		else -- For all inactive notes, use dark colors
			cvals = col[2]
			mcvals = self.color[4][2]
		end
			
		if ((htick - 1) % self.gate) == 0 then -- For all notes that fall on the global gate value, use bright colors
			cvals = col[3]
			mcvals = self.color[4][3]
		end
		
		if cellx == offsetx then -- On the active phrase, replace some regular colors with copypaste colors, if the copypaste variables are active
		
			if (
				(self.copystart ~= nil)
				and (notey == self.copystart)
			) or (
				(self.copyend ~= nil)
				and (notey == self.copyend)
			)
			then -- Assign gaudy color values to the upper and lower bounds of the copypaste selection area
			
				cvals = self.color[2][1]
				mcvals = self.color[1][1]
				
			elseif (self.copystart ~= nil)
			and (self.copyend ~= nil)
			and (notey > self.copystart)
			and (notey < self.copyend)
			then -- Reverse color values for all notes within the copypaste selection area
			
				cvals, mcvals = mcvals, cvals
				
			end
			
		end
		
		if celly == offsety then -- Reverse color values on the active row
			cvals, mcvals = mcvals, cvals
		end
		
		bname = (celly - 1) .. "-" .. (cellx - 1) .. "-editor-button"
		self:outlet(5, "list", {bname, cvals[1], cvals[2], cvals[3], mcvals[1], mcvals[2], mcvals[3]})
		pd.send(bname, "label", {message})
	
	end

end

-- Update the toggle-tracking button
function Phrases:updateToggleButton()

	if self.recording == true then
		self:outlet(5, "list", rgbOutList("phrases-editor-toggle-button", self.color[1][1], self.color[4][1]))
		pd.send("phrases-editor-toggle-button", "label", {"REC"})
	else
		self:outlet(5, "list", rgbOutList("phrases-editor-toggle-button", self.color[2][1], self.color[4][1]))
		pd.send("phrases-editor-toggle-button", "label", {"PLAY"})
	end

end

-- Update the phrase-key button
function Phrases:updateKeyButton()

	self:outlet(5, "list", rgbOutList("phrases-editor-key-button", self.color[2][2], self.color[4][2]))
	pd.send("phrases-editor-key-button", "label", {"Phrase " .. self.key})
	
end

-- Update the note-item button
function Phrases:updateItemButton()

	self:outlet(5, "list", rgbOutList("phrases-editor-item-button", self.color[2][2], self.color[4][2]))
	pd.send("phrases-editor-item-button", "label", {"Item " .. self.pointer})
	
end

-- Update the tick-counter button
function Phrases:updateTickButton()

	local tcount = 0
	local nbyte = 0
	
	for i = 1, #self.phrase[self.key].notes do -- Count which tick the pointer is on, as opposed to which MIDI command
		nbyte = self.phrase[self.key].notes[i][1]
		if nbyte == -1 then
			tcount = tcount + 1
			if i >= self.pointer then
				do break end -- Break the for loop, after encountering the first halting tick at or past the pointer
			end
		end
	end
	
		self:outlet(5, "list", rgbOutList("phrases-editor-tick-button", self.color[2][2], self.color[4][2]))
	pd.send("phrases-editor-tick-button", "label", {"Tick " .. tcount})

end

-- Update the data-entry-mode button
function Phrases:updateModeButton()

	self:outlet(5, "list", rgbOutList("phrases-editor-mode-button", self.color[2][1], self.color[4][1]))
	if self.inputmode == "note" then
		pd.send("phrases-editor-mode-button", "label", {"Mode: Note"})
	elseif self.inputmode == "tr" then
		pd.send("phrases-editor-mode-button", "label", {"Mode: Tr"})
	elseif self.inputmode == "adc" then
		pd.send("phrases-editor-mode-button", "label", {"Mode: ADC"})
	end

end

-- Update the MIDI-catch-style button
function Phrases:updateMIDICatchButton()

	if self.midicatch == "all" then
		self:outlet(5, "list", rgbOutList("phrases-editor-midicatch-button", self.color[2][2], self.color[4][2]))
		pd.send("phrases-editor-midicatch-button", "label", {"Catch: All"})
	elseif self.midicatch == "no-offs" then
		self:outlet(5, "list", rgbOutList("phrases-editor-midicatch-button", self.color[2][1], self.color[4][1]))
		pd.send("phrases-editor-midicatch-button", "label", {"Catch: No Offs"})
	elseif self.midicatch == "auto-offs" then
		self:outlet(5, "list", rgbOutList("phrases-editor-midicatch-button", self.color[1][1], self.color[4][1]))
		pd.send("phrases-editor-midicatch-button", "label", {"Catch: Auto Offs"})
	elseif self.midicatch == "notes" then
		self:outlet(5, "list", rgbOutList("phrases-editor-midicatch-button", self.color[2][1], self.color[4][1]))
		pd.send("phrases-editor-midicatch-button", "label", {"Catch: Notes"})
	elseif self.midicatch == "ignore" then
		self:outlet(5, "list", rgbOutList("phrases-editor-midicatch-button", self.color[2][3], self.color[4][3]))
		pd.send("phrases-editor-midicatch-button", "label", {"Catch: None"})
	end

end

-- Update the MIDI-channel button
function Phrases:updateChannelButton()

	local chbcolor = -1
	local chbmessage = ""

	if self.inputmode == "note" then
		chbcolor = self.color[2][1]
		chbmessage = "Chan " .. self.channel
	elseif self.inputmode == "tr" then
		chbcolor = self.color[1][1]
		chbmessage = "Tr: " .. trnames[self.trpoint]
	elseif self.inputmode == "adc" then
		chbcolor = self.color[1][1]
		chbmessage = "ADC: "
		if self.adc[self.adcpoint] ~= nil then
			chbmessage = chbmessage .. self.adcpoint
		else
			chbmessage = chbmessage .. "N/A"
		end
	end
	
	self:outlet(5, "list", rgbOutList("phrases-editor-channel-button", chbcolor, self.color[4][1]))
	pd.send("phrases-editor-channel-button", "label", {chbmessage})

end

-- Update the MIDI-command button
function Phrases:updateCommandButton()

	local cmdkey = 1
	for k, v in pairs(cmdtable) do
		if v == self.command then
			cmdkey = k
		end
	end

	local cmdbcol = self.color[2][1]
	if rangeCheck(self.command, -2, -4)
	or rangeCheck(self.command, 128, 144)
	then
		cmdbcol = self.color[1][1]
	end

	self:outlet(5, "list", rgbOutList("phrases-editor-command-button", cmdbcol, self.color[4][1]))
	pd.send("phrases-editor-command-button", "label", {"Cmd: " .. cmdnames[cmdkey]})

end

-- Update the MIDI-velocity button
function Phrases:updateVelocityButton()

	self:outlet(5, "list", rgbOutList("phrases-editor-velocity-button", self.color[2][1], self.color[4][1]))
	pd.send("phrases-editor-velocity-button", "label", {"Velo " .. self.velocity})

end

-- Update the input octave button
function Phrases:updateOctaveButton()

	self:outlet(5, "list", rgbOutList("phrases-editor-octave-button", self.color[2][1], self.color[4][1]))
	pd.send("phrases-editor-octave-button", "label", {"Octave " .. self.octave})

end

-- Update the input spacing button
function Phrases:updateSpacingButton()

	self:outlet(5, "list", rgbOutList("phrases-editor-spacing-button", self.color[2][1], self.color[4][1]))
	pd.send("phrases-editor-spacing-button", "label", {"Spacing " .. self.spacing})

end

-- Update the global BPM button
function Phrases:updateGlobalBPMButton()

	self:outlet(5, "list", rgbOutList("phrases-editor-global-bpm-button", self.color[2][1], self.color[4][1]))
	pd.send("phrases-editor-global-bpm-button", "label", {"BPM " .. self.bpm})

end

-- Update the global TPB button
function Phrases:updateGlobalTPBButton()

	self:outlet(5, "list", rgbOutList("phrases-editor-global-tpb-button", self.color[2][1], self.color[4][1]))
	pd.send("phrases-editor-global-tpb-button", "label", {"TPB " .. self.tpb})

end

-- Update the global GATE button
function Phrases:updateGlobalGateButton()

	self:outlet(5, "list", rgbOutList("phrases-editor-global-gate-button", self.color[2][1], self.color[4][1]))
	pd.send("phrases-editor-global-gate-button", "label", {"Gate " .. self.gate})

end

-- Update the savefile hotseat buttons
function Phrases:updateHotseatButtons()

	local outcolor = nil
	for k, v in pairs(self.hotseats) do
		if k == self.hotseatnum then
			outcolor = self.color[1][1]
		elseif v == self.loadname then
			outcolor = self.color[2][2]
		else
			outcolor = self.color[2][1]
		end
		self:outlet(5, "list", rgbOutList("phrases-editor-hotseat-button-" .. k, outcolor, self.color[4][1]))
		pd.send("phrases-editor-hotseat-button-" .. k, "label", {k .. string.rep(".", 3 - string.len(k)) .. " " .. v})
	end

end

-- Update the editor's background color
function Phrases:updateBackground()

	self:outlet(5, "list", rgbOutList("phrases-editor-bg", self.color[3][1], self.color[3][1]))

end

-- Update all cells and buttons in the editor GUI
function Phrases:updateEditorGUI()

	self:updateToggleButton()
	self:updateKeyButton()
	self:updateItemButton()
	self:updateTickButton()
	self:updateModeButton()
	self:updateMIDICatchButton()
	self:updateChannelButton()
	self:updateCommandButton()
	self:updateVelocityButton()
	self:updateOctaveButton()
	self:updateSpacingButton()
	
	self:updateGlobalBPMButton()
	self:updateGlobalTPBButton()
	self:updateGlobalGateButton()
	
	self:updateHotseatButtons()
	
	for ey = 1, self.editory do
		for ex = 1, self.editorx do
			self:updateNoteButton(ex, ey, self.key, self.pointer)
		end
	end
	
	self:updateBackground()

end

-- Setup the color values in the grid GUI that would otherwise not be set by other code
function Phrases:setupGridGUI()

	for x = 0, self.gridx - 1 do
		for y = 0, self.gridy - 1 do
		
			self:outlet(5, "list", rgbOutList(y .. "-" .. x .. "-grid-button", self.color[8][2], self.color[8][2]))
			
			for i = 1, 9 do
				self:outlet(5, "list", rgbOutList(y .. "-" .. x .. "-grid-sub-" .. i, self.color[8][1], self.color[8][1]))
			end
			
		end
	end
	
	self:outlet(5, "list", rgbOutList("phrases-grid-bg", self.color[8][1], self.color[8][1]))
	
	for i = 1, self.adcnum do
		self:outlet(5, "list", rgbOutList(i .. "-adc-button", self.color[5][1], self.color[5][1]))
	end

end

-- Refresh the transference sub-buttons in the grid GUI
function Phrases:refreshSubButtons()

	for x = 0, self.gridx - 1 do
		for y = 0, self.gridy - 1 do
			local subkey = coordsToKey(x, y, self.gridx, self.gridy, 0, 1)
			for i = 1, 9 do
				if self.phrase[subkey].transfer[i] > 0 then
					self:outlet(5, "list", rgbOutList(y .. "-" .. x .. "-grid-sub-" .. i, self.color[8][3], self.color[8][3]))
				else
					self:outlet(5, "list", rgbOutList(y .. "-" .. x .. "-grid-sub-" .. i, self.color[8][2], self.color[8][2]))
				end
			end
		end
	end
	
end



-- Inserts an OFF-note at the location of the pointer, if there is at least one other ON-note on the same MIDI channel at any point in the phrase.
function Phrases:insertAutoOff()

	local offchan = nil
	local offnote = nil
	local iterc = (self.pointer % #self.phrase[self.key].notes) + 1
	
	while iterc ~= self.pointer do
	
		if (self.phrase[self.key].notes[iterc][1] % 16) == self.channel then
			offchan = self.phrase[self.key].notes[iterc][1] % 16
			offnote = self.phrase[self.key].notes[iterc][2]
		end
		
		iterc = (iterc % #self.phrase[self.key].notes) + 1
		
	end
	
	if offchan ~= nil then
	
		offchan = offchan + 128
		local offbytes = {offchan, offnote, 127}
		
		table.insert(self.phrase[self.key].notes, self.pointer, offbytes)
		
		self.pointer = self.pointer + 1
		
		pd.post("Inserted note " .. table.concat(offbytes, " ") .. " at point " .. (self.pointer - 1))
	
	end
	
end



-- Add the current phrase table to the history table
function Phrases:addStateToHistory()

	if self.undopoint < #self.history then
		for i = #self.history, self.undopoint + 1, -1 do
			table.remove(self.history, i)
		end
	end

	if #self.history == 50 then
		table.remove(self.history, 1)
	else
		self.undopoint = self.undopoint + 1
	end

	self.history[#self.history + 1] = {deepCopy(self.phrase, {}), deepCopy(self.adc, {}), self.key, self.pointer}
	
end

-- Erase all history and replace it with the current state
function Phrases:replaceOldHistory()

	self.history = {{deepCopy(self.phrase, {}), deepCopy(self.adc, {}), self.key, self.pointer}}
	self.undopoint = 1

end

-- Undo: move backwards by one step through the history stack
function Phrases:undo()

	if self.undopoint > 1 then
	
		self.undopoint = self.undopoint - 1
		
		self.phrase = deepCopy(self.history[self.undopoint][1], {})
		self.adc = deepCopy(self.history[self.undopoint][2], {})
		self.key = self.history[self.undopoint][3]
		self.pointer = self.history[self.undopoint][4]
		
	end
	
	pd.post("Undo depth: " .. self.undopoint .. "/" .. #self.history)
	
end

-- Redo: move forwards by one step through the history stack
function Phrases:redo()

	if self.undopoint < #self.history then
	
		self.undopoint = self.undopoint + 1
		
		self.phrase = deepCopy(self.history[self.undopoint][1], {})
		self.adc = deepCopy(self.history[self.undopoint][2], {})
		self.key = self.history[self.undopoint][3]
		self.pointer = self.history[self.undopoint][4]
		
	end

	pd.post("Undo depth: " .. self.undopoint .. "/" .. #self.history)

end



-- Adjust the copypaste variables to fall within the boundaries of the currently active phrase's notes
function Phrases:adjustCopyRange()

	if (self.copystart ~= nil)
	and (#self.phrase[self.key].notes < self.copystart)
	then
		self.copystart = #self.phrase[self.key].notes
		pd.post("Copy Range: Start Moved: " .. self.copystart)
	end
	
	if (self.copyend ~= nil)
	and (#self.phrase[self.key].notes < self.copyend)
	then
		self.copyend = #self.phrase[self.key].notes
		pd.post("Copy Range: End Moved: " .. self.copystart)
	end
	
end



function Phrases:setDefaultNotes(p)

	if self.phrase[p] == nil then
		self.phrase[p] = {}
	end
	
	self.phrase[p].transfer = { 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, } -- Default transference vals
	self.phrase[p].notes = { {-1}, {-1}, {-1}, {-1}, } -- Default note vals
	self.phrase[p].dhash = { 1, 2, 3, 4, } -- Hash of display-values for each note's prefix in the editor GUI
	
end

-- Set the default values for a given phrase
function Phrases:setDefaultVars(p)

	if self.phrase[p] == nil then
		self.phrase[p] = {}
	end
	
	self.phrase[p].tdir = 5 -- Transference direction
	self.phrase[p].pointer = 1 -- Phrase note pointer (not to be confused with the global pointer)
	self.phrase[p].tick = 1 -- Tracks how many tempo ticks have elapsed, as opposed to how many notes have been processed
	self.phrase[p].active = false -- Phrase activity status
	self.phrase[p].midi = {} -- Local MIDI sustain table (not to be confused with the global MIDI sustain table)
	
	-- Fill MIDI sustain table with MIDI channel tables
	for chan = 0, 15 do
		self.phrase[p].midi[chan] = {}
		for pitch = 1, 128 do
			self.phrase[p].midi[chan][pitch] = 0
		end
	end
	
end



function Phrases:initialize(sel, atoms)

	-- 1. Key commands
	-- 2. MIDI-IN
	-- 3. Monome button
	-- 4. Monome ADC
	-- 5. Tempo ticks
	-- 6. Gate bangs
	-- 7. Loadfile name
	-- 8. Savefile name
	-- 9. Global BPM
	-- 10. Global TPB
	-- 11. Global GATE
	-- 12. Preferences list
	-- 13. GUI color lists
	self.inlets = 13
	
	-- 1. Editor note-send out (to delayed note-off as well)
	-- 2. Sequencer note-send out
	-- 3. Monome LED-command out
	-- 4. Blink out
	-- 5. Destination / color list / message color list
	self.outlets = 5
	
	-- Default grid height and width
	self.gridx = 8
	self.gridy = 8
	
	-- Number of ADCs on the Monome
	self.adcnum = 0
	
	-- Default editor height and width
	self.editorx = 6
	self.editory = 32
	
	-- Load user-defined default hotseats
	self.hotseats = self:dofile("phrases-hotseats.lua")
	for k, v in pairs(self.hotseats) do
		pd.post("Default hotseat " .. k .. ": " .. v)
	end
	
	-- Default file names and paths
	self.loadname = self.hotseats[1]
	self.savename = "default.lua"
	self.filepath = ""
	
	self.hotseatnum = 1 -- Currently active hotseat number
	
	-- Default BPM, TPB, GATE values
	self.bpm = 120
	self.tpb = 4
	self.gate = 16
	
	self.tick = 1 -- Track which tempo tick is currently active
	
	self.color = { -- Default GUI colors: {regular, highlight, dark}
		{-1, -1, -1}, {-1, -1, -1}, {-1, -1, -1}, {-1, -1, -1},
		{-1, -1, -1}, {-1, -1, -1}, {-1, -1, -1}, {-1, -1, -1},
	}
	
	self.phrase = {}
	
	self.adc = {} -- Table for a song's ADC values
	self.adcpoint = 1 -- Currently active ADC value in the editor
	
	self.midi = {} -- Table for tracking global MIDI sustain values
	for chan = 0, 15 do
		self.midi[chan] = {}
		for pitch = 1, 128 do
			self.midi[chan][pitch] = 0
		end
	end
	
	self.trpoint = 1 -- Currently active transference value in the editor
	
	-- Tables to track which sustain values have been shifted by ADC activity
	self.noteshift = {}
	self.veloshift = {}
	for i = 0, 15 do
		self.noteshift[i] = {}
		self.veloshift[i] = {}
	end
	
	self.matrix = makeTrMatrix(self.gridx, self.gridy) -- Matrix to link keys to other keys, for transference purposes
	
	self.queue = {} -- Holds all incoming button presses; it is emptied out on every gate-tick
	self.trqueue = {} -- Holds all ongoing transference; it is filled and flushed during every tick
	self.trhalts = {} -- Holds keys of all active phrases with self-terminating transference, so that their MIDI sustains are turned off at the proper tick
	
	self.key = 1 -- Currently active phrase
	
	self.pointer = 1 -- Pointer for note manipulation
	
	self.spacing = 0 -- Spacing of gaps between notes. 0 is no pause; 1 is a tick's worth of pause; and so on
	self.command = 144 -- Command-type for computer-keystrokes
	self.octave = 1 -- Octave
	self.channel = 0 -- MIDI channel
	self.velocity = 127 -- MIDI velocity
	
	self.recording = false -- Toggle whether to record data from incoming keystrokes
	
	self.inputmode = "note" -- Set to 'note', 'tr', or 'adc', depending on which input mode is active
	self.pitchview = true -- Flag that controls whether editor data values are shown as pitches or numbers
	
	self.midicatch = "all" -- Changes which sort of MIDI input is accepted
	
	self.history = {{self.phrase, self.key, self.pointer}} -- Table for holding previous states of the editor, for undo/redo purposes
	self.undopoint = 1 -- Tracks the current undo location in the history table
	
	self.copystart = nil -- Start of the cut/copy selection area. Nil when not in use.
	self.copyend = nil -- End of the cut/copy selection area. Nil when not in use.
	self.copytab = {} -- Table to hold an arbitrary series of notes that has been cut or copied.
	
	return true
	
end



-- Control-commands in
function Phrases:in_1_list(list)

	local cmd = list[1]
	
	if kbhash[cmd] ~= nil then -- Interpret all possible computer-keyboard-note keys
	
		local putnote = kbhash[cmd] + (self.octave * 12)
		while putnote > 127 do -- Cull back out-of-bounds note values to a valid octave
			putnote = putnote - 12
		end
		
		if self.recording == true then
		
			if self.inputmode == "note" then -- Use incoming keycommands to insert notes in the active phrase
		
				if self.spacing > 0 then
					for i = 1, self.spacing do
						table.insert(self.phrase[self.key].notes, self.pointer, {-1})
					end
				end
				
				if rangeCheck(self.command, 144, 159) then -- If incoming note-on...
					-- If in auto-offs mode, insert a note-off if applicable
					if self.midicatch == "auto-offs" then
						self:insertAutoOff()
					end
				end
				
				if self.command >= 128 then -- All MIDI commands
					table.insert(self.phrase[self.key].notes, self.pointer, {self.command + self.channel, putnote, self.velocity})
					pd.post("Inserted command " .. (self.command + self.channel) .. " " .. putnote .. " " .. self.velocity)
				elseif self.command == -2 then -- Global BPM
					self.bpm = putnote + self.velocity
					pd.send("phrases-bpm", "float", {putnote + self.velocity})
				elseif self.command == -3 then -- Global TPB
					self.tpb = putnote + self.velocity
					pd.send("phrases-tpb", "float", {putnote + self.velocity})
				elseif self.command == -4 then -- Global GATE
					self.gate = putnote + self.velocity
					pd.send("phrases-gate", "float", {putnote + self.velocity})
				elseif rangeCheck(self.command, -5, -7) then -- Local BPM, local TPB, local GATE
					table.insert(self.phrase[self.key].notes, self.pointer, {self.command, putnote + self.velocity, 0})
				end
				
				-- Update the active phrase's display-value hash
				self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
				
			end
			
			-- If a new command was inserted, increase note pointer, and prevent overshooting the limit of the note array
			if (self.inputmode == "note")
			and (
				rangeCheck(self.command, 128, 255)
				or rangeCheck(self.command, -5, -7)
			)
			then
				self.pointer = (self.pointer + self.spacing) + 1
				if self.pointer > #self.phrase[self.key].notes then
					self.pointer = 1
				end
			end
			
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
		
		-- Send MIDI note to outlet, regardless of whether the editor is recording, so long as the editor is in note mode
		if self.inputmode == "note" then
			self:outlet(1, "list", {144 + self.channel, putnote, self.velocity})
		end
		
	elseif cmd == "RECORD" then -- Toggle recording mode ON or OFF
	
		self.recording = not(self.recording)
		pd.post("Recording toggled to " .. tostring(self.recording))
		
		self.tick = 1 -- Reset global tick-tracking value, to prevent gate errors
	
		self:updateEditorGUI()
		
	elseif cmd:sub(1, 12) == "LOAD_HOTSEAT" then -- Savefile hotseat commands
	
		self.hotseatnum = tonumber(cmd:sub(14))
		self.loadname = self.hotseats[self.hotseatnum]
		pd.post("Current loadfile name is now: " .. self.loadname)
		
		self:updateHotseatButtons()
	
	elseif cmd == "LOAD" then -- Load a Lua savename into local variables
	
		-- Check all current phrases for activity, and change the flag appropriately
		local activecheck = false
		for _, v in pairs(self.phrase) do
			if v.active == true then
				activecheck = true
			end
		end

		-- Does not require recording-mode to be on; but no phrases must currently be active, in order to prevent errors
		if activecheck == false then

			-- self:dofile() is currently the only serviceable dofile method in pdlua, and apparently it will be changed in a later version of pdlua, so this load function will probably have to be changed later as well.
			local ltab = self:dofile(self.loadname)

			self.phrase = {} -- Unset all phrase data
			self.adc = {} -- Unset all ADC data

			for k, v in pairs(ltab) do -- Load all data tables

				pd.post("loading: " .. k .. " - " .. tostring(v))

				if k == "phrase" then

					for pnum, pcontents in pairs(v) do
					
						if pnum <= (self.gridx * self.gridy) then -- Only load the phrase if it fits within the Monome that is being used

							self:setDefaultVars(pnum) -- Set default sequencer variables, which aren't saved by the editor

							for kk, vv in pairs(pcontents) do -- Set the phrase values that were saved (transference, notes)
								self.phrase[pnum][kk] = vv
							end

							self.phrase[pnum].dhash = makeDisplayValHash(self.phrase[pnum].notes) -- Update the phrase's display-value hash
							
						end

					end
					
					-- If the Monome has more buttons than the savefile has phrases, fill the remaining unset phrases with dummy values
					if #v < (self.gridx * self.gridy) then
					
						for i = #v + 1, self.gridx * self.gridy do
							self:setDefaultVars(i) -- Set default variables for the empty phrase
							self:setDefaultNotes(i) -- Default notes too
							pd.post("Inserted default sequence, at phrase " .. i)
							self.phrase[i].dhash = makeDisplayValHash(self.phrase[i].notes) -- Update the phrase's display-value hash
						end
					
					end

					-- Display the correct transference sub-buttons for a freshly loaded phrase
					self:refreshSubButtons()

				else
					self[k] = v -- Set global non-phrase variables
				end

			end
			
			if #self.adc < self.adcnum then -- If fewer ADCs are in the loadfile than on the Monome, fill the extras with dummy values
			
				for i = #self.adc + 1, self.adcnum do
					self.adc[i] = {
						["channel"] = 0,
						["target"] = 3,
						["style"] = "relative",
						["magnitude"] = 2,
						["val"] = 0,
					}
					pd.post("Inserted default ADC values, at ADC " .. i)
				end
				
			elseif self.adcnum < #self.adc then -- If more ADCs are in the loadfile than on the Monome, remove the superfluous ones from the ADC table data
			
				for i = #self.adc, self.adcnum, -1 do
					table.remove(self.adc, i)
				end
			
			end

			-- Reset the editor's phrase key and pointer, and ADC pointer, to prevent various fatal and nonfatal out-of-bounds errors
			self.key = 1
			self.pointer = 1
			self.adcpoint = 1
			
			-- Reset the copypaste positions, but NOT the copypaste table
			self.copystart = nil
			self.copyend = nil

			-- Remove the previous file's information from the old history table, and replace it with the new file's initial state
			self:replaceOldHistory()

			-- Send updated global BPM/TPB/GATE information to the program's Pd side
			pd.send("phrases-bpm", "float", {self.bpm})
			pd.send("phrases-tpb", "float", {self.tpb})
			pd.send("phrases-gate", "float", {self.gate})

			self:updateEditorGUI()

			pd.post("Loaded the contents of " .. self.loadname .. "!")

		else

			pd.post("Couldn't load file: Some phrases are still active!")

		end
		
		elseif cmd == "SAVE" then -- Save data as a Lua table in the savename
	
		local o = "return\n\n" -- Make the table executable, for the load function

		o = o .. "{\n\n" -- Open bracket for entire savedata table
	
		o = o .. "\t[\"bpm\"] = " .. self.bpm .. ", -- Global beats-per-minute\n" -- Save BPM
		o = o .. "\t[\"tpb\"] = " .. self.tpb .. ", -- Global ticks-per-beat\n" -- Save TPB
		o = o .. "\t[\"gate\"] = " .. self.gate .. ", -- Global gate size\n" -- Save gating
		
		o = o .. "\n\n\t[\"adc\"] = {\n\n"
		
		for k, v in ipairs(self.adc) do
		
			o = o .. "\t\t{ -- ADC " .. k .. "\n"
			
			o = o .. "\t\t\t[\"channel\"] = " .. v.channel .. ",\n"
			o = o .. "\t\t\t[\"target\"] = " .. v.target .. ",\n"
			o = o .. "\t\t\t[\"style\"] = \"" .. v.style .. "\",\n"
			o = o .. "\t\t\t[\"magnitude\"] = " .. v.magnitude .. ",\n"
			o = o .. "\t\t\t[\"val\"] = 0,\n"
			
			o = o .. "\t\t},\n\n"
			
		end
		
		o = o .. "\t},\n\n"
		
		o = o .. "\t[\"phrase\"] = {\n\n" -- Parent phrase table
	
		-- Add all phrase data to the long string
		for k, v in ipairs(self.phrase) do
			
			o = o .. "\t\t[" .. k .. "] = {\n" -- Phrase number
			
			o = o .. "\t\t\t[\"transfer\"] = {" -- Phrase transference
			for k2, v2 in ipairs(v.transfer) do
				if k2 > 1 then
					o = o .. ", "
				end
				o = o .. v2
			end
			o = o .. "},\n" -- Close transference table
			
			o = o .. "\t\t\t[\"notes\"] = {\n" -- Phrase notes
			
			local snum = 0 -- Track the number of ticks
			for k2, v2 in ipairs(v.notes) do
			
				o = o .. "\t\t\t\t"
				
				o = o .. "{" -- Open note-value table
				-- Individual MIDI byte values
				for k3, v3 in ipairs(v2) do
					if k3 > 1 then
						o = o .. ", "
					end
					o = o .. v3
				end
				o = o .. "}," -- Close note-value table
				
				if v2[1] == -1 then -- Add a tick comment, if applicable
					snum = snum + 1
					o = o .. " -- Tick " .. snum
				end
				
				o = o .. "\n"
				
			end
			
			o = o .. "\t\t\t}\n" -- Close notes table
			
			o = o .. "\t\t},\n" -- Close phrase table
			
		end
		
		o = o .. "\n\t}\n" -- Close parent phrase table
		
		o = o .. "\n}\n" -- Close entire savedata table
		
		-- Use complex Lua file manipulation, to prevent weird file errors while Pd is running
		local f = assert(io.open(self.filepath .. self.savename, "w"))
		f:write(o)
		f:close()
		
		pd.post("Data saved to " .. self.filepath .. self.savename)
		
	elseif cmd == "UNDO" then -- Undo most recent phrase-changing command, by moving back one space in the history table
	
		if self.recording == true then
		
			-- Convert the pointer from the active note to its corresponding tick
			local oldp = self.phrase[self.key].dhash[self.pointer]
		
			self:undo()
			
			-- Set the pointer to 1, in case there is no match
			self.pointer = 1
			
			-- Check the pointer against the new sequence's key-hash, to preserve numbering
			for k, v in ipairs(self.phrase[self.key].dhash) do
				if v == oldp then
					self.pointer = k
					do break end
				end
			end
			
			self:adjustCopyRange()
	
			self:refreshSubButtons()
	
			self:updateEditorGUI()
		
		end
	
	elseif cmd == "REDO" then -- Redo next-most-recent phrase-changing command, by moving forward one space in the history table
	
		if self.recording == true then
		
			-- Convert the pointer from the active note to its corresponding tick
			local oldp = self.phrase[self.key].dhash[self.pointer]
		
			self:redo()
			
			-- Set the pointer to 1, in case there is no match
			self.pointer = 1
			
			-- Check the pointer against the new sequence's key-hash, to preserve numbering
			for k, v in ipairs(self.phrase[self.key].dhash) do
				if v == oldp then
					self.pointer = k
					do break end
				end
			end
			
			self:adjustCopyRange()
			
			self:refreshSubButtons()
			
			self:updateEditorGUI()
		
		end
	
	elseif (cmd == "NOTE_NEXT") -- Advance the note pointer
	or (cmd == "NOTE_PREV") -- Retreat the note pointer
	then
	
		if self.inputmode == "note" then
		
			if cmd == "NOTE_NEXT" then
				self.pointer = self.pointer + 1
				if self.pointer > #self.phrase[self.key].notes then
					self.pointer = 1
				end
			else
				self.pointer = self.pointer - 1
				if self.pointer <= 0 then
					self.pointer = #self.phrase[self.key].notes
				end
			end
			
		elseif self.inputmode == "tr" then -- Advance/retreat the transference pointer
		
			if cmd == "NOTE_NEXT" then
				self.trpoint = (self.trpoint % 10) + 1
			else
				self.trpoint = self.trpoint - 1
				if self.trpoint <= 0 then
					self.trpoint = 10
				end
			end
		
		elseif (self.inputmode == "adc") -- Advance/retreat the active-ADC pointer, if there are any ADCs in the current setup
		and (self.adcnum > 0)
		then
		
			if cmd == "NOTE_NEXT" then
				self.adcpoint = (self.adcpoint % self.adcnum) + 1
			else
				self.adcpoint = self.adcpoint - 1
				if self.adcpoint <= 0 then
					self.adcpoint = self.adcnum
				end
			end
		
		end
		
		self:updateEditorGUI()
	
	elseif cmd == "NOTE_PREVPAGE" then -- Retreat the note pointer by the editor-window's page-height
	
		self.pointer = (((self.pointer - math.floor(self.editory / 2)) - 1) % #self.phrase[self.key].notes) + 1
		
		self:updateEditorGUI()
		
	elseif cmd == "NOTE_NEXTPAGE" then -- Advance the pointer by the editor-window's page-height
	
		self.pointer = (((self.pointer + math.floor(self.editory / 2)) - 1) % #self.phrase[self.key].notes) + 1
		
		self:updateEditorGUI()
	
	elseif cmd == "NOTE_HOME" then -- Set pointer to beginning of phrase
	
		self.pointer = 1
		
		self:updateEditorGUI()
	
	elseif cmd == "NOTE_INVERSE" then -- Set pointer to the opposite side of the phrase
	
		self.pointer = (((math.ceil(#self.phrase[self.key].notes / 2) + self.pointer) - 1) % #self.phrase[self.key].notes) + 1
	
		self:updateEditorGUI()
	
	elseif (cmd == "KEY_PREV") -- Toggle to previous phrase
	or (cmd == "KEY_NEXT") -- Or next phrase
	then
	
		-- Convert the pointer from the active note to its corresponding tick in the old phrase
		local oldp = self.phrase[self.key].dhash[self.pointer]
	
		if cmd == "KEY_PREV" then
			self.key = self.key - 1
		else
			self.key = self.key + 1
		end
		
		if self.key < 1 then
			self.key = self.gridy * self.gridx
		elseif self.key > (self.gridy * self.gridx) then
			self.key = 1
		end
		
		-- Set the pointer to 1, in case there is no match
		self.pointer = 1
		
		-- Check the pointer against the new phrase's key-hash, to preserve numbering
		for k, v in ipairs(self.phrase[self.key].dhash) do
			if v == oldp then
				self.pointer = k
				do break end
			end
		end
		
		self:adjustCopyRange()
		
		self:updateEditorGUI()
		pd.post("Active phrase: " .. self.key)
	
	elseif cmd == "SPACING_DEC" then -- Decrease spacing
	
		self.spacing = math.max(0, self.spacing - 1)
		
		self:updateSpacingButton()
		pd.post("Spacing set to " .. self.spacing)
	
	elseif cmd == "SPACING_INC" then -- Increase spacing
	
		self.spacing = self.spacing + 1

		self:updateSpacingButton()
		pd.post("Spacing set to " .. self.spacing)
	
	elseif cmd == "CHANNEL_DEC" then -- Decrease channel
	
		if (self.inputmode == "note")
		or (self.inputmode == "tr")
		then
		
			self.channel = (self.channel - 1) % 16
			pd.post("MIDI Channel set to " .. self.channel)
			
		elseif (self.inputmode == "adc")
		and (self.adc[self.adcpoint] ~= nil)
		then
		
			self.adc[self.adcpoint].channel = (self.adc[self.adcpoint].channel - 1) % 16
			pd.post("ADC " .. self.adcpoint .. ": target channel set to " .. self.adc[self.adcpoint].channel)
			
			self:addStateToHistory()
		
		end
		
		self:updateEditorGUI()
	
	elseif cmd == "CHANNEL_INC" then -- Increase channel
	
		if (self.inputmode == "note")
		or (self.inputmode == "tr")
		then
		
			self.channel = (self.channel + 1) % 16
			pd.post("MIDI Channel set to " .. self.channel)
		
		elseif (self.inputmode == "adc")
		and (self.adc[self.adcpoint] ~= nil)
		then
		
			self.adc[self.adcpoint].channel = (self.adc[self.adcpoint].channel + 1) % 16
			pd.post("ADC " .. self.adcpoint .. ": target channel set to " .. self.adc[self.adcpoint].channel)
			
			self:addStateToHistory()
		
		end
		
		self:updateEditorGUI()
		
	elseif cmd == "VELOCITY_DEC1" then -- Decrease velocity
	
		self:shiftVolumeVal(-1)
	
	elseif cmd == "VELOCITY_INC1" then -- Increase velocity
	
		self:shiftVolumeVal(1)
	
	elseif cmd == "VELOCITY_DEC10" then -- Decrease velocity by 10
	
		self:shiftVolumeVal(-10)
	
	elseif cmd == "VELOCITY_INC10" then -- Increase velocity by 10
	
		self:shiftVolumeVal(10)
	
	elseif cmd == "OCTAVE_DEC" then -- Lower octave
	
		self.octave = (self.octave - 1) % 12
		
		self:updateOctaveButton()
		pd.post("Octave set to " .. self.octave)
		
	elseif cmd == "OCTAVE_INC" then -- Raise octave
	
		self.octave = (self.octave + 1) % 12
		
		self:updateOctaveButton()
		pd.post("Octave set to " .. self.octave)
		
	elseif (cmd == "COMMAND_INC") -- Toggle forwards between computer-keyboard-command types
	or (cmd == "COMMAND_DEC") -- Or toggle backwards
	then
	
		if (self.inputmode == "note")
		or (self.inputmode == "tr")
		then
	
			local cmdkey = 1
			local cmdmod = 1
			if cmd == "COMMAND_DEC" then
				cmdmod = -1
			end
			
			for k, v in ipairs(cmdtable) do
			
				if v == self.command then
				
					cmdkey = k + cmdmod
					if cmdkey < 1 then
						cmdkey = #cmdtable
					elseif cmdkey > #cmdtable then
						cmdkey = 1
					end
					
					do break end
					
				end
				
			end
			
			self.command = cmdtable[cmdkey]
			
			pd.post("Command type: " .. cmdnames[cmdkey] .. " (" .. self.command .. ")")
			
			self:updateCommandButton()
			
		elseif (self.inputmode == "adc")
		and (self.adc[self.adcpoint] ~= nil)
		then -- Toggle ADC target between note-byte (2) and velocity-byte (3)
		
			if cmd == "COMMAND_DEC" then
			
				self.adc[self.adcpoint].target = ((self.adc[self.adcpoint].target - 1) % 2) + 2
				
			else
			
				if self.adc[self.adcpoint].style == "relative" then
					self.adc[self.adcpoint].style = "absolute"
				else
					self.adc[self.adcpoint].style = "relative"
				end
				
			end
			
			self:addStateToHistory()
		
			self:updateEditorGUI()
			
		end
	
	elseif cmd == "NOTE_DELETE" then -- Delete current note
	
		if self.recording == true then
	
			if #self.phrase[self.key].notes > 1 then
			
				table.remove(self.phrase[self.key].notes, self.pointer)
				pd.post("Deleted note " .. self.pointer .. " in phrase " .. self.key)
				
				if self.phrase[self.key].notes[self.pointer] == nil then
					self.pointer = self.pointer - 1
					pd.post("Moved pointer to " .. self.pointer .. " after note deletion")
				end
				
				-- Update the active phrase's display-value hash
				self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
				
				self:adjustCopyRange()
		
				self:addStateToHistory()

				self:updateEditorGUI()
				
			else
			
				pd.post("Could not delete the last remaining note in phrase " .. self.key)
			
			end
		
		end
	
	elseif cmd == "NOTE_INSERT_BLANK" then -- Add a blank note at current pointer position
	
		if self.recording == true then
		
			table.insert(self.phrase[self.key].notes, self.pointer, {-1})
			self.phrase[self.key].notes[self.pointer], self.phrase[self.key].notes[self.pointer + 1] = self.phrase[self.key].notes[self.pointer + 1], self.phrase[self.key].notes[self.pointer]
			self.pointer = self.pointer + 1
			
			pd.post("Inserted note -1 at point " .. self.pointer .. " in phrase " .. self.key)
			
			-- Update the active phrase's display-value hash
			self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
				
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
	
	elseif cmd == "MOVE_ALL_NOTES_BACK" then -- Shift all notes in a phrase backwards
	
		if self.recording == true then
		
			local shiftamt = math.max(1, self.velocity)
		
			for i = 1, shiftamt do
				local tempnote = table.remove(self.phrase[self.key].notes, 1)
				table.insert(self.phrase[self.key].notes, tempnote)
			end
			
			self.pointer = (((self.pointer - shiftamt) - 1) % #self.phrase[self.key].notes) + 1
			
			-- Update the active phrase's display-value hash
			self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
			
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
	
	elseif cmd == "MOVE_ALL_NOTES_FORWARD" then -- Shift all notes in a phrase forwards
	
		if self.recording == true then
		
			local shiftamt = math.max(1, self.velocity)
		
			for i = 1, shiftamt do
				local tempnote = table.remove(self.phrase[self.key].notes, #self.phrase[self.key].notes)
				table.insert(self.phrase[self.key].notes, 1, tempnote)
			end
			
			self.pointer = (((self.pointer + shiftamt) - 1) % #self.phrase[self.key].notes) + 1
			
			-- Update the active phrase's display-value hash
			self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
			
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
	
	elseif cmd:sub(1, 9) == "MOVE_NOTE" then -- Move a note backwards or forwards
	
		if self.recording == true then
		
			local shiftval = 0
			local iterval = 0
			if cmd == "MOVE_NOTE_BACK" then
				shiftval = self.velocity * -1
				iterval = -1
			elseif cmd == "MOVE_NOTE_FORWARD" then
				shiftval = self.velocity
				iterval = 1
			end
			
			-- Wrap the velocity value within the phrase's size
			local insertpoint = (((self.pointer + shiftval) - 1) % #self.phrase[self.key].notes) + 1
			
			-- Move the note one space at a time, in the prescribed direction, until it reaches the destination point.
			-- self.pointer is moved along with the note, which conveniently allows the user to keep track of positioning.
			while self.pointer ~= insertpoint do
			
				-- Wrap the adjacent location within the phrase's size
				local adjpoint = (((self.pointer + iterval) - 1) % #self.phrase[self.key].notes) + 1
			
				-- Switch current note with adjacent note
				self.phrase[self.key].notes[self.pointer], self.phrase[self.key].notes[adjpoint] = self.phrase[self.key].notes[adjpoint], self.phrase[self.key].notes[self.pointer]
				
				self.pointer = adjpoint -- Set pointer to the adjacent location
				
			end
			
			-- Update the active phrase's display-value hash
			self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
			
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
		
	elseif cmd:sub(1, 18) == "SHIFT_ALL_CHANNELS" then -- Shift the phrase's channels up or down by 1
	
		if self.recording == true then
		
			local shiftval = 0
			if cmd == "SHIFT_ALL_CHANNELS_DOWN" then
				shiftval = -1
			elseif cmd == "SHIFT_ALL_CHANNELS_UP" then
				shiftval = 1
			end
			
			for i = 1, #self.phrase[self.key].notes do
				local shiftbyte = self.phrase[self.key].notes[i][1]
				if rangeCheck(shiftbyte, 128, 255) then
					local command = shiftbyte - (shiftbyte % 16)
					shiftbyte = (shiftbyte + shiftval) % 16
					self.phrase[self.key].notes[i][1] = command + shiftbyte
				end
			end
		
			pd.post("Shifted all channels in phrase " .. self.key .. " by " .. shiftval .. " steps")
			
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
	
	elseif cmd:sub(1, 17) == "SHIFT_ALL_PITCHES" then -- Shift the phrase's notes up or down by the velocity value
	
		if self.recording == true then
		
			local shiftval = 0
			if cmd == "SHIFT_ALL_PITCHES_DOWN" then
				shiftval = self.velocity * -1
			elseif cmd == "SHIFT_ALL_PITCHES_UP" then
				shiftval = self.velocity
			end
		
			for i = 1, #self.phrase[self.key].notes do
				if rangeCheck(self.phrase[self.key].notes[i][1], 128, 159) then
					if self.phrase[self.key].notes[i][2] ~= nil then
						self.phrase[self.key].notes[i][2] = (self.phrase[self.key].notes[i][2] + shiftval) % 128
					end
				end
			end
		
			pd.post("Shifted all note bytes in phrase " .. self.key .. " by " .. shiftval .. " steps")
			
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
	
	elseif cmd:sub(1, 18) == "SHIFT_ALL_VELOCITY" then -- Shift the phrase's notes up or down by the velocity value
	
		if self.recording == true then
		
			local shiftval = 0
			if cmd == "SHIFT_ALL_VELOCITY_DOWN" then
				shiftval = self.velocity * -1
			elseif cmd == "SHIFT_ALL_VELOCITY_UP" then
				shiftval = self.velocity
			end
		
			for i = 1, #self.phrase[self.key].notes do
				if rangeCheck(self.phrase[self.key].notes[i][1], 128, 159) then
					if self.phrase[self.key].notes[i][3] ~= nil then
						self.phrase[self.key].notes[i][3] = (self.phrase[self.key].notes[i][3] + shiftval) % 128
					end
				end
			end
		
			pd.post("Shifted all velocity bytes in phrase " .. self.key .. " by " .. shiftval .. " steps")
			
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
		
	elseif cmd:sub(1, 13) == "SHIFT_CHANNEL" then -- Shift the channel byte at the pointer up or down by the velocity value
		
		if self.recording == true then
		
			local shiftval = 0
			if cmd == "SHIFT_CHANNEL_DOWN" then
				shiftval = self.velocity * -1
			elseif cmd == "SHIFT_CHANNEL_UP" then
				shiftval = self.velocity
			end
			
			local shiftbyte = self.phrase[self.key].notes[self.pointer][1]
			if rangeCheck(shiftbyte, 128, 255) then
				local command = shiftbyte - (shiftbyte % 16)
				shiftbyte = ((shiftbyte + shiftval) % 16)
				self.phrase[self.key].notes[self.pointer][1] = command + shiftbyte
				pd.post("Shifted channel of item " .. self.pointer .. " in phrase " .. self.key .. " to value " .. self.phrase[self.key].notes[self.pointer][2])
			end
			
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
		
	elseif cmd:sub(1, 11) == "SHIFT_PITCH" then -- Shift the note byte at the pointer up or down by the velocity value
	
		if self.recording == true then
		
			local shiftval = 0
			if cmd == "SHIFT_PITCH_DOWN" then
				shiftval = self.velocity * -1
			elseif cmd == "SHIFT_PITCH_UP" then
				shiftval = self.velocity
			end
		
			if self.phrase[self.key].notes[self.pointer][2] ~= nil then
				self.phrase[self.key].notes[self.pointer][2] = (self.phrase[self.key].notes[self.pointer][2] + shiftval) % 128
				pd.post("Shifted byte 2 of item " .. self.pointer .. " in phrase " .. self.key .. " to value " .. self.phrase[self.key].notes[self.pointer][2])
			end
		
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
	
	elseif cmd:sub(1, 14) == "SHIFT_VELOCITY" then -- Shift the velocity byte at the pointer up or down by the velocity value
	
		if self.recording == true then
		
			local shiftval = 0
			if cmd == "SHIFT_VELOCITY_DOWN" then
				shiftval = self.velocity * -1
			elseif cmd == "SHIFT_VELOCITY_UP" then
				shiftval = self.velocity
			end
		
			if self.phrase[self.key].notes[self.pointer][3] ~= nil then
				self.phrase[self.key].notes[self.pointer][3] = (self.phrase[self.key].notes[self.pointer][3] + shiftval) % 128
				pd.post("Shifted byte 3 of item " .. self.pointer .. " in phrase " .. self.key .. " to value " .. self.phrase[self.key].notes[self.pointer][3])
			end
			
			self:addStateToHistory()

			self:updateEditorGUI()
			
		end
		
	elseif cmd:sub(1, 12) == "SHIFT_PHRASE" then -- Move the active phrase to a new position, switching it with the phrase that currently exists there
	
		if self.recording == true then
		
			local oldkey = self.key
			local newkey = oldkey
		
			if cmd == "SHIFT_PHRASE_UP" then
				newkey = self.matrix[oldkey][2]
			elseif cmd == "SHIFT_PHRASE_LEFT" then
				newkey = self.matrix[oldkey][4]
			elseif cmd == "SHIFT_PHRASE_RIGHT" then
				newkey = self.matrix[oldkey][6]
			elseif cmd == "SHIFT_PHRASE_DOWN" then
				newkey = self.matrix[oldkey][8]
			end
			
			local phrasetemp = deepCopy(self.phrase[oldkey], {})
			self.phrase[oldkey] = deepCopy(self.phrase[newkey], {})
			self.phrase[newkey] = deepCopy(phrasetemp, {})
			
			self.key = newkey
			
			pd.post("Switched the positions of phrases " .. oldkey .. " and " .. newkey)
			pd.post("Active phrase: " .. self.key)
		
			self:addStateToHistory()

			self:refreshSubButtons()
			
			self:updateEditorGUI()
			
		end
	
	elseif cmd == "INPUT_MODE_TOGGLE" then -- Toggle between input modes
	
		for k, v in ipairs(modenames) do
			if self.inputmode == v then
				self.inputmode = modenames[(k % #modenames) + 1]
				pd.post("Input mode: " .. self.inputmode)
				do break end
			end
		end
	
		self:updateEditorGUI()
		
	elseif (cmd == "MIDI_CATCHTYPE_BACK") -- Toggle between MIDI-catching modes
	or (cmd == "MIDI_CATCHTYPE_FWD")
	then
	
		for k, v in pairs(catchtypes) do
		
			if self.midicatch == v then
			
				if cmd == "MIDI_CATCHTYPE_BACK" then
					self.midicatch = catchtypes[((k - 2) % #catchtypes) + 1]
				else
					self.midicatch = catchtypes[(k % #catchtypes) + 1]
				end
				
				self:updateMIDICatchButton()
				
				pd.post("MIDI catch-type: " .. self.midicatch)
				do break end
				
			end
			
		end
	
	elseif cmd == "VIEW_MODE_TOGGLE" then -- Toggle between number-view and pitch-view
	
		if self.pitchview == true then
			self.pitchview = false
			pd.post("Pitch view: MIDI byte numbers")
		else
			self.pitchview = true
			pd.post("Pitch view: Note pitches")
		end
		
		self:updateEditorGUI()
	
	elseif cmd == "ADD_NOTE_OFFS_AUTO" then -- Place correctly formatted note-offs before each note in the phrase
		
		-- Note: This command will only insert noteoffs properly for monophonic phrases.
		
		if self.recording == true then
		
			-- Convert the pointer from the active note to its corresponding tick
			local oldp = self.phrase[self.key].dhash[self.pointer]
			
			local tempnotes = self.phrase[self.key].notes
			
			local i = 1
			while i <= #tempnotes do -- Use a while loop instead of a for loop, because for doesn't track changes that happen to the limiting value of #tempnotes
			
				local note = tempnotes[i]
			
				if rangeCheck(note[1], 144, 159) then
				
					local space = 0
					local cycle = 0
					local inpoint = i
					
					while
					(
						(not(rangeCheck(tempnotes[inpoint][1], 144, 159)))
						or (space == 0)
					)
					and (cycle <= #tempnotes)
					do
					
						if tempnotes[inpoint][1] == -1 then
							space = space + 1
						end
						
						if inpoint >= #tempnotes then
							inpoint = 0
							i = i + 1
						end
						
						inpoint = inpoint + 1
						cycle = cycle + 1
						
					end
				
					table.insert(tempnotes, inpoint, {note[1] - 16, note[2], note[3]})
					
					pd.post("Added noteoff: position " .. inpoint .. ", note " .. (note[1] - 16) .. " " .. note[2] .. " " .. note[3])

				end
				
				i = i + 1
				
			end
			
			self.phrase[self.key].notes = tempnotes
			
			-- Update the active phrase's display-value hash
			self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
			
			-- Check the pointer against the new sequence's key-hash, to preserve numbering
			for k, v in ipairs(self.phrase[self.key].dhash) do
				if v == oldp then
					self.pointer = k
					do break end
				end
			end

			self:addStateToHistory()
			
			self:updateEditorGUI()
			
		end
		
	elseif cmd == "ADD_NOTE_OFFS_SPACING" then -- Place correctly formatted note-offs at a distance specified by the current spacing value
		
		if self.recording == true then
		
			if (self.spacing > 0)
			and (self.spacing <= self.phrase[self.key].dhash[#self.phrase[self.key].notes]) -- Refuse the command if spacing is greater than the number of notes
			then
		
				-- Convert the pointer from the active note to its corresponding tick
				local oldp = self.phrase[self.key].dhash[self.pointer]
				
				local tempnotes = deepCopy(self.phrase[self.key].notes, {})
				
				local i = 1
				while i <= #tempnotes do -- Use a while loop instead of a for loop, because for doesn't track changes that happen to the limiting value of #tempnotes
				
					local note = tempnotes[i]
					
					if rangeCheck(note[1], 144, 159) then
					
						local spaces = 0
						local cycle = 0
						local inpoint = ((i - 1) % #tempnotes) + 1
						local oldpoint = inpoint
						
						-- Increase the insert-point until it passes the number of halting notes specified by self.spacing
						while (spaces < self.spacing)
						and (cycle <= #tempnotes) -- Break the loop if there are no halting notes due to user error
						do
						
							if tempnotes[inpoint][1] == -1 then
								spaces = spaces + 1
							end
							
							inpoint = (inpoint % #tempnotes) + 1
							cycle = cycle + 1
							
						end
						
						table.insert(tempnotes, inpoint, {note[1] - 16, note[2], note[3]})
						
						-- If the insert point wrapped around, increase the iterator by an additional point, to prevent infinite loops of inserts from the same note-on
						if inpoint <= oldpoint then
							i = i + 1
						end
						
						pd.post("Added noteoff: item " .. inpoint .. ", note " .. (note[1] - 16) .. " " .. note[2] .. " " .. note[3])
					
					end
				
					i = i + 1
				
				end
				
				self.phrase[self.key].notes = deepCopy(tempnotes, {})
				
				-- Update the active phrase's display-value hash
				self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
				
				-- Check the pointer against the new sequence's key-hash, to preserve numbering
				for k, v in ipairs(self.phrase[self.key].dhash) do
					if v == oldp then
						self.pointer = k
						do break end
					end
				end

				self:addStateToHistory()

				self:updateEditorGUI()
				
			else
			
				pd.post("Spacing must be greater than 0, and less than the number of ticks in the phrase, for this command to work!")
			
			end
			
		end
		
	elseif cmd == "SET_COPY_POINT_1" then -- Set the top copy point
	
		if self.recording == true then
	
			-- If the bottom copy point is above the pointer, set it to the current pointer position
			if (self.copyend ~= nil)
			and (self.copyend < self.pointer)
			then
				self.copyend = self.pointer
				pd.post("Copy Range: Reset End: " .. self.copyend)
			end
			
			if (self.copystart ~= nil)
			and (self.copystart == self.pointer)
			then -- If this is invoked on the top copy point's current position, then unset it
				self.copystart = nil
			else -- Else set the top copy point to the current pointer location
				self.copystart = self.pointer
			end
			
			pd.post("Copy Range: Set Start: " .. self.copystart)
			
			self:updateEditorGUI()
			
		end
		
	elseif cmd == "SET_COPY_POINT_2" then -- Set the bottom copy point
	
		if self.recording == true then
	
			-- If the top copy point is below the pointer, set it to the current pointer position
			if (self.copystart ~= nil)
			and (self.copystart > self.pointer)
			then
				self.copystart = self.pointer
				pd.post("Copy Range: Reset Start: " .. self.copystart)
			end
		
			if (self.copyend ~= nil)
			and (self.copyend == self.pointer)
			then -- If this is invoked on the bottom copy point's current position, then unset it
				self.copyend = nil
			else -- Else set thebottom opy point to the current pointer location
				self.copyend = self.pointer
			end
			
			pd.post("Copy Range: Set End: " .. self.copyend)
			
			self:updateEditorGUI()
			
		end
		
	elseif cmd == "UNSET_COPY_POINTS" then -- Unset the copy points, if either of them is set
	
		if self.recording == true then
			
			if (self.copystart ~= nil)
			or (self.copyend ~= nil)
			then
			
				self.copystart = nil
				self.copyend = nil
				
				pd.post("Unset Copy Range")
				
				self:updateEditorGUI()
				
			end
			
		end
	
	elseif cmd == "CUT" then -- Remove the notes from within the copy-range on the active phrase, and transfer them into the copy table
	
		if self.recording == true then
	
			if (self.copystart ~= nil)
			and (self.copyend ~= nil)
			then
			
				self.copytab = {} -- Clear old copy data, if there was any
				
				-- Check whether the entirety of the phrase's contents will be cut
				local replaceflag = false
				if (self.copystart == 1)
				and (self.copyend == #self.phrase[self.key].notes)
				then
					replaceflag = true
				end
				
				-- Move notes from the active phrase to the copy table, deleting them from the phrase along the way
				for i = self.copystart, self.copyend do
					table.insert(self.copytab, table.remove(self.phrase[self.key].notes, self.copystart))
				end
				
				-- If the phrase's contents were completely cut, then insert a halting tick, to prevent errors
				if replaceflag == true then
					self.phrase[self.key].notes = {{-1}}
				end
				
				-- Reset the pointer's position if it is now greater than the size of the phrase
				if self.pointer > #self.phrase[self.key].notes then
					self.pointer = #self.phrase[self.key].notes
				end
				
				pd.post("Cut selection: items " .. self.copystart .. " to " .. self.copyend)
				
				-- Unset the copy positions, as they will have either been removed by the cut, or shifted on top of irrelevant notes
				self.copystart = nil
				self.copyend = nil
				
				-- Update the active phrase's display-value hash
				self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
				
				self:adjustCopyRange()
		
				self:addStateToHistory()

				self:updateEditorGUI()
				
			else
				pd.post("Could not cut: copy range is undefined!")
			end
			
		end
	
	elseif cmd == "COPY" then -- Copy the notes within the copy-range into the copy table
	
		if self.recording == true then
		
			if (self.copystart ~= nil)
			and (self.copyend ~= nil)
			then
			
				local temptab = {}
				
				-- Copy the notes from the active selection to temptab, non-destructively
				for i = self.copystart, self.copyend do
					table.insert(temptab, self.phrase[self.key].notes[i])
				end
				
				self.copytab = deepCopy(temptab, {}) -- Transfer data from temptab to self.copytab with deepCopy, to ensure an actual table is copied, rather than a reference
		
				pd.post("Copied selection: items " .. self.copystart .. " to " .. self.copyend)
		
			else
				pd.post("Could not copy: copy range is undefined!")
			end
			
		end
	
	elseif cmd == "PASTE" then -- Paste the notes within the copy table into the active phrase, at the current pointer position
	
		if self.recording == true then
		
			if #self.copytab > 0 then
		
				-- Duplicate the copytable's contents into the active phrase, at the current pointer location
				for k, v in ipairs(self.copytab) do
					table.insert(self.phrase[self.key].notes, self.pointer + (k - 1), v)
				end
				
				pd.post("Pasted " .. #self.copytab .. " items at point " .. self.pointer)
				
				-- Update the active phrase's display-value hash
				self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
				
				self:adjustCopyRange()
		
				self:addStateToHistory()

				self:updateEditorGUI()
				
			else
				pd.post("Could not paste: copy table is empty!")
			end
			
		end
	
	elseif cmd == "UPDATE_EDITOR_GUI" then -- Trigger an update in the editor GUI window
	
		self:updateEditorGUI()
	
	elseif cmd == "SETUP_GRID_GUI" then -- Setup colors in the grid GUI window that would otherwise go unset
	
		self:setupGridGUI()
		
	end

end



-- Receive MIDI notes from a MIDI device
function Phrases:in_2_list(note)

	-- Interpret the message's channel value, and save it internally
	-- Unsure whether this feature would be annoying or not
	--if self.channel ~= (note[1] % 16) then
	--	self.channel = note[1] % 16
	--end
	
	-- Interpret the message's command value, and save it internally
	if note[1] >= 128 then
		self.command = note[1] - (note[1] % 16)
		note[1] = self.command + self.channel -- Convert the incoming note's channel to the user-defined channel
	end
	
	-- Map the incoming note to the current octave setting, then bound its value to the 0-127 range
	note[2] = (note[2] + (self.octave * 12)) % 128
	
	if self.recording == true then -- If recording-mode is toggled on...
	
		if (self.midicatch == "all") -- If all incoming MIDI is captured...
		or (
			(self.midicatch == "notes") -- Or incoming MIDI notes are captured,
			and rangeCheck(note[1], 128, 159) -- And the incoming MIDI byte is a MIDI note...
		) or (
			(self.midicatch == "no-offs") -- Or incoming MIDI bytes are captured except for note-offs,
			and not(rangeCheck(note[1], 128, 143)) -- And the incoming MIDI byte is not a note-off...
		) or (
			(self.midicatch == "auto-offs") -- Or incoming MIDI bytes are captured, with note-offs automatically generated...
			and not(rangeCheck(note[1], 128, 143)) -- And the incoming MIDI byte is not a note-off...
		)
		then
			
			-- Insert a dummy byte at byte 3, if the MIDI message has two bytes
			if #note < 3 then
				note[3] = 0
			end

			-- Insert empty notes, if spacing is greater than 0
			if self.spacing > 0 then
				for i = 1, self.spacing do
					table.insert(self.phrase[self.key].notes, self.pointer, {-1})
				end
			end
			
			-- If in auto-offs mode, insert a note-off if applicable
			if self.midicatch == "auto-offs" then
				self:insertAutoOff()
			end
			
			-- Insert MIDI note
			table.insert(self.phrase[self.key].notes, self.pointer, note)
			
			-- Increase note pointer, and prevent overshooting the limit of the phrase's note array
			self.pointer = (self.pointer + self.spacing) + 1
			if self.pointer > #self.phrase[self.key].notes then
				self.pointer = 1
			end
			
			pd.post("Inserted note " .. table.concat(note, " ") .. " at point " .. self.pointer .. " in phrase " .. self.key)

			-- Update the active phrase's display-value hash
			self.phrase[self.key].dhash = makeDisplayValHash(self.phrase[self.key].notes)
			
			self:updateEditorGUI()
			
		else
		
			pd.post("Rejected incoming MIDI: " .. table.concat(note, " "))
		
		end
		
	end
	
	-- Send MIDI note to outlet, regardless of whether the editor is recording, so long as the editor is in note mode
	if self.inputmode == "note" then
		self:outlet(1, "list", note)
	end
	
end

-- Interpret an incoming Monome button command
function Phrases:in_3_list(k)

	local button = k[1] + (self.gridx * k[2]) + 1
	
	if self.recording == true then -- Recording mode

		-- Set active phrase to button value
		if (k[3] == 1) -- Do this on down-keystrokes only
		and (button <= #self.phrase) -- Only if the button maps to a currently-existant phrase
		then
		
			self.key = button
			self.pointer = 1 -- Prevent null-pointer errors by resetting the global pointer
			pd.post("Active phrase: " .. button)
	
			self:outlet(4, "list", {k[1], k[2], 0}) -- Send a blink command for the phrase's Monome button

			self:adjustCopyRange()
	
			self:updateEditorGUI()

		end
		
	else -- Playing mode
	
		if (k[3] == 1) -- Do this on down-keystrokes only
		and (button <= #self.phrase) -- Only if the button maps to a currently-existant phrase
		then
		
			-- Check whether the phrase has split transference
			-- TODO: Refactor this so that its variable is pre-emptively generated upon changes to any phrase's transference
			local splitcheck = 0
			for i = 1, 9 do
				if self.phrase[button].transfer[i] >= 1 then
					splitcheck = splitcheck + 1
				end
			end
			
			-- Count the remaining ticks before the end of the phrase
			local ticksleft = 0
			for i = self.phrase[button].pointer, #self.phrase[button].notes do
				if self.phrase[button].notes[i][1] == -1 then
					ticksleft = ticksleft + 1
				end
			end
			
			if (ticksleft < self.gate) -- If the phrase has fewer remaining ticks than the gate value...
			and (self.phrase[button].active == true) -- And is already active...
			and (
				( -- And has stationary-but-split transference...
					(self.phrase[button].tdir == 5)
					and (splitcheck >= 2)
				)
				or (self.phrase[button].tdir ~= 5) -- Or non-stationary transference of any kind...
			)
			then -- Then immediately turn it off, to prevent trainwrecks of short phrases
				-- Reset the phrase's internal variables, MIDI sustains, GUI cell, and Monome button
				local clearname = k[2] .. "-" .. k[1] .. "-grid-"
				table.insert(self.trhalts, button)
				self.phrase[button].active = false
				self.phrase[button].pointer = 1
				self.phrase[button].tick = 1
				self:outlet(3, "list", {k[1], k[2], 0})
				self:outlet(4, "list", {k[1], k[2], 0}) -- Override any blink commands that might lay a half-tick out in Pd
				self:outlet(5, "list", rgbOutList(clearname .. "button", self.color[8][2], self.color[8][2]))
				for i = 1, 9 do -- Clear transference sub-buttons
					if self.phrase[button].transfer[i] > 0 then
						self:outlet(5, "list", rgbOutList(clearname .. "sub-" .. i, self.color[8][3], self.color[8][3]))
					end
				end
			else -- Record a keystroke to the global keystroke-queue, which is emptied and parsed on each gate tick
				table.insert(self.queue, button)
				pd.post("Phrase " .. button .. ": QUEUED")
			end
			
		end
	
	end
	
end

-- Interpret an incoming Monome ADC command
function Phrases:in_4_list(n)

	n[1] = n[1] + 1 -- Convert from 0-indexed to 1-indexed

	-- Store the new ADC value locally
	if self.adc[n[1]] ~= nil then
		self.adc[n[1]].val = n[2]
	end
	
	-- Update the ADC-tile's color, based on the current ADC value
	local rgbadc = {}
	for i = 1, 3 do
		rgbadc[i] = math.max(1, math.min(255, math.floor(math.abs(
			self.color[5][1][i] + ((self.color[6][1][i] - self.color[5][1][i]) * n[2])
		))))
	end
	self:outlet(5, "list", rgbOutList(n[1] .. "-adc-button", rgbadc, self.color[8][1]))
	
end

-- React to incoming tempo ticks
function Phrases:in_5_bang()

	-- Update the gate-button's color, based on the current tick
	local rgbgate = {}
	for i = 1, 3 do
		rgbgate[i] = math.max(1, math.min(255, math.floor(math.abs(
			self.color[5][1][i] + ((self.color[6][1][i] - self.color[5][1][i]) * (self.tick / self.gate))
		))))
	end
	self:outlet(5, "list", rgbOutList("phrases-grid-gate-button", rgbgate, self.color[8][1]))
	
	-- Clear the MIDI sustains and internal variables from any phrases whose transference was self-terminating on the previous tick
	for _, v in pairs(self.trhalts) do
	
		self:haltPhraseMidi(v)
		
		self.phrase[v].active = false
		self.phrase[v].pointer = 1
		self.phrase[v].tick = 1
		
		-- Blank out the halting phrase's GUI presence
		local txold, tyold = keyToCoords(v, self.gridx, self.gridy, 1, 0)
		local oldbutton = tyold .. "-" .. txold .. "-grid-"
		self:outlet(3, "list", {txold, tyold, 0})
		self:outlet(4, "list", {txold, tyold, 0}) -- Override any blink commands that might lay a half-tick out in Pd
		self:outlet(5, "list", rgbOutList(oldbutton .. "button", self.color[8][2], self.color[8][2]))
		for i = 1, 9 do -- Clear transference sub-buttons
			if self.phrase[v].transfer[i] > 0 then
				self:outlet(5, "list", rgbOutList(oldbutton .. "sub-" .. i, self.color[8][3], self.color[8][3]))
			end
		end
		
		pd.post("Phrase " .. v .. ": OFF")
		
	end
	
	self.trhalts = {}
	
	-- Apply the transference matrix to every key-direction pair in the transference queue, and then activate those phrases
	for k, v in pairs(self.trqueue) do
		
		local trnew = self.matrix[k][v]
		
		self.phrase[trnew].active = true
		self.phrase[trnew].pointer = 1
		self.phrase[trnew].tick = 1
		self.phrase[trnew].tdir = calcTransference(self.phrase[trnew].transfer)
		
		-- Recalculate the original phrase's transference direction, if it is still active
		if self.phrase[k].transfer[10] == 1 then
			self.phrase[k].tdir = calcTransference(self.phrase[k].transfer)
		end
		
		local trax, tray = keyToCoords(trnew, self.gridx, self.gridy, 1, 0)
		self:outlet(3, "list", {trax, tray, 1})
		self:outlet(5, "list", rgbOutList(tray .. "-" .. trax .. "-grid-button", self.color[5][1], self.color[5][1]))
		
		if k ~= trnew then
			pd.post("Phrase " .. k .. ": TRANSFER")
			pd.post("Phrase " .. trnew .. ": ON")
		end
		
	end
	
	self.trqueue = {}

	-- On every tick, do things to every active phrase
	for k, v in ipairs(self.phrase) do
	
		if v.active == true then
		
			self:iterate(k) -- Run the iterate function once per active phrase per tick
		
			local guix, guiy = keyToCoords(k, self.gridx, self.gridy, 1, 0)
			
			-- Update all active cells' GUI colors
			local rgbout = {}
			for i = 1, 3 do
				rgbout[i] = math.max(1, math.min(255, math.floor(math.abs(
					self.color[5][1][i] + ((self.color[6][1][i] - self.color[5][1][i]) * (v.pointer / #v.dhash))
				))))
			end
			
			local bname = guiy .. "-" .. guix .. "-grid-"
			self:outlet(5, "list", rgbOutList(bname .. "button", rgbout, rgbout))
			
			-- Send the transference direction information to the relevant sub-cells
			for i = 1, 9 do
				if v.transfer[i] > 0 then
					self:outlet(5, "list", rgbOutList(bname .. "sub-" .. i, self.color[8][3], self.color[8][3]))
				end
			end
			self:outlet(5, "list", rgbOutList(bname .. "sub-" .. v.tdir, self.color[7][1], self.color[7][1]))
		
		end
		
	end
	
	self.tick = self.tick + 1
	
end

-- React to bangs that signify the gate has been reached
function Phrases:in_6_bang()

	self.tick = 1
	
	for _, v in pairs(self.queue) do
		
		local outx, outy = keyToCoords(v, self.gridx, self.gridy, 1, 0)
		local outbutton = outy .. "-" .. outx .. "-grid-"

		if self.phrase[v].active == false then -- On-toggle
		
			self.phrase[v].active = true
		
			-- Since the phrase was just activated, calculate a new transference direction, and send its info to the GUI
			self.phrase[v].tdir = calcTransference(self.phrase[v].transfer)
		
			-- Send a message to the Monome button updater
			self:outlet(3, "list", {outx, outy, 1})
			
			pd.post("Phrase " .. v .. ": ON")
			
		else -- Off-toggle
		
			self.phrase[v].active = false
		
			-- Turn off all active MIDI sustains in the phrase
			self:haltPhraseMidi(v)
		
			-- Reset the phrase's pointer and tick
			self.phrase[v].pointer = 1
			self.phrase[v].tick = 1
			
			-- Send a message to the Monome button updater
			self:outlet(3, "list", {outx, outy, 0})
			self:outlet(4, "list", {outx, outy, 0}) -- Override any blink commands that might lay a half-tick out in Pd
			
			-- Send a color message to the Pd grid GUI, then clear the cell's transference colors
			self:outlet(5, "list", rgbOutList(outbutton .. "button", self.color[8][2], self.color[8][2]))
			for i = 1, 9 do
				if self.phrase[v].transfer[i] > 0 then
					self:outlet(5, "list", rgbOutList(outbutton .. "sub-" .. i, self.color[8][3], self.color[8][3]))
				end
			end
			
			pd.post("Phrase " .. v .. ": OFF")
			
		end
		
	end
	
	-- Empty the queue after acting upon it
	self.queue = {}

end

-- Get loadfile name
function Phrases:in_7_list(s)
	-- table.concat() is necessary, because Pd will interpret paths that contain spaces as lists
	self.loadname = table.concat(s, " ")
	pd.post("Current loadfile name is now: " .. self.loadname)
	pd.post("Note: Data has NOT been loaded! To load this loadfile, press: Shift-Tab-Enter")
end

-- Get savefile name
function Phrases:in_8_list(s)
	-- table.concat() is necessary, because Pd will interpret paths that contain spaces as lists
	self.savename = table.concat(s, " ")
	pd.post("Current savefile name (including path) is now: " .. self.filepath .. self.savename)
	pd.post("NOTE: Data has NOT been saved! To save to this savefile, press: Shift-?-|")
end

-- Get global BPM value
function Phrases:in_9_float(f)
	self.bpm = f
end

-- Get global TPB value
function Phrases:in_10_float(f)
	self.tpb = f
end

-- Get global GATE value
function Phrases:in_11_float(f)
	self.gate = f
end

-- Get preferences list, and act upon some of its contents
function Phrases:in_12_list(n)

	self.gridx = n[1]
	self.gridy = n[2]
	self.adcnum = n[3]
	
	pd.send("phrases-osc-serial-type", "float", {n[4]})
	pd.send("phrases-osc-in-port", "float", {n[5]})
	pd.send("phrases-osc-out-port", "float", {n[6]})
	
	self.editorx = n[15]
	self.editory = n[16]
	
	self.matrix = makeTrMatrix(self.gridx, self.gridy)
	
	-- Gather the savefile directory from the end of the flat list, and shape it properly
	local tabremain = {}
	for i = 21, #n do
		table.insert(tabremain, n[i])
	end
	self.filepath = table.concat(tabremain, " ") -- table.concat() is necessary, because Pd will have interpreted paths that contain spaces as lists
	pd.post("Current savefile path is now: " .. self.filepath)
	
end

-- Get GUI color-values
function Phrases:in_13_list(c)
	
	local ckey = table.remove(c, 1)
	self.color[ckey] = modColor(c)
	
end


local Phrases = pd.Class:new():register("phrases-editor-and-sequencer")



-- Load the code's data tables in a tidy manner
local tabs = require("phrases-editor-tables")
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
	
	if (command == 144)
	or (command == 128)
	then

		-- Change the offset to apply to sustains, based on incoming note-on/note-offs
		local offset = 0
		if comand == 128 then
			offset = -1
		elseif command == 144 then
			offset = 1
		end
		
		-- Create the parent tables if they don't exist
		if self.midi[chan][pitch] == nil then
			self.midi[chan][pitch] = 0
		end
		if self.phrase[k].midi[chan][pitch] == nil then
			self.phrase[k].midi[chan][pitch] = 0
		end

		-- Add the offset to both local and global sustain-tracking tables
		self.phrase[k].midi[chan][pitch] = self.phrase[k].midi[chan][pitch] + offset
		self.midi[chan][pitch] = self.midi[chan][pitch] + offset

		if offset == 1 then
			self:noteSend(k, note)
		elseif self.phrase[k].midi[chan][pitch] <= 0 then
			self.phrase[k].midi[chan][pitch] = nil
		end

		if self.midi[chan][pitch] <= 0 then
			self.midi[chan][pitch] = nil
			self:noteSend(k, note)
		end
		
	else
		self:noteSend(k, note)
	end
	
end

-- Halt all MIDI sustains in a phrase, and apply them to the global MIDI-sustain array, and MIDI note-offs.
function Phrases:haltPhraseMidi(p)

	-- For every currently active note in the phrase, send a MIDI-OFF through noteParse()
	for chan, v in pairs(self.phrase[p].midi) do
		for pitch, num in pairs(v) do
			self:noteParse(p, {128 + chan, pitch, 127})
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
			
			-- Insert a transference command into the tick's transference table
			self.trqueue[k] = self.phrase[k].tdir
			
			-- Calculate a new transference value
			self.phrase[k].tdir = calcTransference(self.phrase[k].transfer)
			
		end
		
	until (self.phrase[k].notes[oldp][1] == -1)
	or (
		(self.phrase[k].transfer[10] == 0)
		and (oldp == #self.phrase[k].notes)
	)
	
	self.phrase[k].pointer = p
	self.phrase[k].tick = tick
	
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
	local offsety = math.floor(self.editory / 4)
	
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
	
	local notey = celly - offsety + 1 -- All inactive notes are stationary
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
		local nakedy = (celly - offsety) + 1
		
		if rangeCheck(nakedy, 1, 10) then
		
			if (tr[nakedy] >= 1)
			or (self.pitchview == false)
			then
				message = nakedy .. ". " .. tr[nakedy]
			else
				message = nakedy .. ". --"
			end
			
			mcvals = self.color[4][1]
			
			if cellx == offsetx then -- Set active phrase's transference values to the main user-defined color
				if (nakedy == self.channel)
				or (
					(nakedy == 10)
					and (self.channel >= 10)
				)
				then
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

	if self.inputmode == "tr" then
		chbcolor = self.color[1][1]
		chbmessage = "Tr: " .. trnames[math.min(math.max(self.channel, 1), 10)]
	else
		chbcolor = self.color[2][1]
		chbmessage = "Chan " .. self.channel
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
	
	for ey = 1, self.editory do
		for ex = 1, self.editorx do
			self:updateNoteButton(ex, ey, self.key, self.pointer)
		end
	end
	
	self:updateBackground()

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
	for i = 0, 15 do
		self.phrase[p].midi[i] = {}
	end
	
end



function Phrases:initialize(sel, atoms)

	-- 1. Key commands
	-- 2. MIDI-IN
	-- 3. Monome button
	-- 4. Tempo ticks
	-- 5. Gate bangs
	-- 6. Loadfile name
	-- 7. Savefile name
	-- 8. Savepath name
	-- 9. Global BPM
	-- 10. Global TPB
	-- 11. Global GATE
	-- 12. Grid X cells
	-- 13. Grid Y cells
	-- 14. Editor X cells
	-- 15. Editor Y cells
	-- 16. Editor GUI color 1
	-- 17. Editor GUI color 2
	-- 18. Editor GUI color 3
	-- 19. Editor GUI color 4
	-- 20. Grid GUI color 1
	-- 21. Grid GUI color 2
	-- 22. Grid GUI color 3
	-- 23. Grid GUI color 4
	self.inlets = 23
	
	-- 1. Editor note-send out (to delayed note-off as well)
	-- 2. Sequencer note-send out
	-- 3. Monome LED-command out
	-- 4. Blink out
	-- 5. Destination / color list / message color list
	self.outlets = 5
	
	-- Default grid height and width
	self.gridx = 8
	self.gridy = 8
	
	-- Default editor height and width
	self.editorx = 6
	self.editory = 32
	
	-- Default file names and paths
	self.loadname = "default-savefile.lua"
	self.savename = "default-savefile.lua"
	self.filepath = ""
	
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
	for i = 1, self.gridx * self.gridy do -- Set default phrase data
		self:setDefaultVars(i)
		self:setDefaultNotes(i)
	end
	
	self.midi = {} -- Table for tracking global MIDI sustain values
	for i = 0, 15 do
		self.midi[i] = {}
	end
	
	self.matrix = makeTrMatrix(self.gridx, self.gridy) -- Matrix to link keys to other keys, for transference use
	
	self.queue = {} -- Table for holding all incoming button presses; it is emptied out on every gate-tick
	self.trqueue = {} -- Table for holding all ongoing transference; it is filled and flushed during every tick
	
	self.key = 1 -- Currently active phrase
	
	self.pointer = 1 -- Pointer for note manipulation
	
	self.spacing = 0 -- Spacing of gaps between notes. 0 is no pause; 1 is a tick's worth of pause; and so on
	self.command = 144 -- Command-type for computer-keystrokes
	self.octave = 1 -- Octave
	self.channel = 0 -- MIDI channel
	self.velocity = 127 -- MIDI velocity
	
	self.recording = false -- Toggle whether to record data from incoming keystrokes
	
	self.pitchview = true -- Flag that controls whether editor data values are shown as pitches or numbers
	
	self.inputmode = "note" -- Set to either 'note' or 'tr', depending on which input mode is active
	
	self.midicatch = "all" -- Changes to "all", "notes", "no-offs", or "ignore", to set which sort of MIDI input is accepted
	
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
				
			elseif self.inputmode == "tr" then -- Use incoming keycommands to set the weight of transference values
			
				if rangeCheck(self.channel, 1, 9) then
					self.phrase[self.key].transfer[self.channel] = putnote
					pd.post("Phrase " .. self.key .. ": Set transference direction " .. self.channel .. " to strength " .. putnote)
				else
					self.phrase[self.key].transfer[10] = (self.phrase[self.key].transfer[10] + 1) % 2
					pd.post("Phrase " .. self.key .. ": Persistence set to " .. self.phrase[self.key].transfer[10])
				end
			
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
		
			for k, v in pairs(ltab) do -- Load all data tables
			
				pd.post("loading: " .. k .. " - " .. tostring(v))
				
				if k == "phrase" then
				
					for pnum, pcontents in pairs(v) do
					
						self:setDefaultVars(pnum) -- Set default sequencer variables, which aren't saved by the editor
					
						for kk, vv in pairs(pcontents) do -- Set the phrase values that were saved (transference, notes)
							self.phrase[pnum][kk] = vv
						end
						
						-- Update the phrase's display-value hash
						self.phrase[pnum].dhash = makeDisplayValHash(self.phrase[pnum].notes)
						
					end
					
				else
					self[k] = v -- Set global non-phrase variables
				end
				
			end
			
			-- Reset the editor's key and pointer, to prevent out-of-bounds errors
			self.key = 1
			self.pointer = 1
			
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
		o = o .. "\n"
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
			local sn = 0 -- Track the number of iteration-stopping notes, to properly position gate comments
			local sskip = 0 -- Track the number of non-iteration-stopping notes that the gate-checker has skipped
			local sbr = false -- Track when newlines and tabs are required amongst the note tables
			local sgnum = 0 -- Track which lines should have a gate-note comment
			local sgitem = 0 -- Track which line items are the gate tick, for multi-item lines
			for k2, v2 in ipairs(v.notes) do
			
				if v2[1] == -1 then -- Only increment the note-tracking variable for halting commands
					sn = sn + 1
				else
					sskip = sskip + 1
				end
			
				if ((sn - 1) % self.gate) == 0 then -- If the note falls on a gate tick, set the relevant flag
					if sgnum == 0 then -- Only set the gate-note comment flag if it hasn't been set earlier in the line
						sgnum = sn
					end
				end
				
				if (sbr == true)
				or (k2 == 1)
				then -- Ensure newlines are properly tabbed, checking for multi-item lines
					o = o .. "\t\t\t\t"
					sbr = false -- Unset newline-okay flag
				end
				
				o = o .. "{" -- Open note-value table
				-- Individual MIDI note values
				for k3, v3 in ipairs(v2) do
					if k3 > 1 then
						o = o .. ", "
					end
					o = o .. v3
				end
				o = o .. "}," -- Close note-value table
				
				if (v.notes[k2 + 1] ~= nil) -- Peek at the next note to judge whether a newline is appropriate
				and (
					(v.notes[k2 + 1][1] ~= -1)
					or rangeCheck(v.notes[k2 + 1][1], 128, 159)
				)
				then -- If any notes in the previous line fell on a gate tick, offer up some metadata
					if sgnum > 0 then
						o = o .. " -- Gate tick (note " .. sgnum .. ")"
						o = o .. " (" .. self.gate .. " * " .. math.floor((sgnum - 1) / self.gate) .. " + 1)"
						o = o .. " (line item " .. (sgitem + 1) .. ")"
						if sskip > 0 then
							o = o .. " (skipped " .. sskip .. " instant commands)"
							sskip = 0
						end
						sgnum = 0
					end
					sbr = true -- Set newline-okay flag
				end
				
				if sbr == true then -- If the newline flag is set, insert a newline; else insert a space
					o = o .. "\n"
					sgitem = 0
				else
					o = o .. " "
					if sgnum == 0 then -- If no notes on this line fell on a gate tick yet, increase the line-item number
						sgitem = sgitem + 1
					end
				end
				
			end
			o = o .. "\n"
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
	
	elseif (cmd == "NOTE_NEXT") -- Advance the note pointer
	or (cmd == "NOTE_PREV") -- Retreat the note pointer
	then
	
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
		
		self:updateEditorGUI()
		pd.post("Active note: " .. self.pointer)
	
	elseif cmd == "NOTE_HOME" then -- Set pointer to beginning of phrase
	
		self.pointer = 1
		
		self:updateEditorGUI()
		pd.post("Active note: " .. self.pointer)
	
	elseif cmd == "NOTE_END" then -- Set pointer to end of phrase
	
		self.pointer = #self.phrase[self.key].notes
		
		self:updateEditorGUI()
		pd.post("Active note: " .. self.pointer)
	
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
	
		self.channel = (self.channel - 1) % 16
		
		self:updateEditorGUI()
		pd.post("MIDI Channel set to " .. self.channel)
	
	elseif cmd == "CHANNEL_INC" then -- Increase channel
	
		self.channel = (self.channel + 1) % 16
		
		self:updateEditorGUI()
		pd.post("MIDI Channel set to " .. self.channel)
		
	elseif cmd == "VELOCITY_DEC1" then -- Decrease velocity
	
		self.velocity = (self.velocity - 1) % 128
		
		self:updateVelocityButton()
		pd.post("MIDI Velocity set to " .. self.velocity)
	
	elseif cmd == "VELOCITY_INC1" then -- Increase velocity
	
		self.velocity = (self.velocity + 1) % 128
		
		self:updateVelocityButton()
		pd.post("MIDI Velocity set to " .. self.velocity)
		
	elseif cmd == "VELOCITY_DEC10" then -- Decrease velocity by 10
	
		self.velocity = (self.velocity - 10) % 128
		
		self:updateVelocityButton()
		pd.post("MIDI Velocity set to " .. self.velocity)
	
	elseif cmd == "VELOCITY_INC10" then -- Increase velocity by 10
	
		self.velocity = (self.velocity + 10) % 128
		
		self:updateVelocityButton()
		pd.post("MIDI Velocity set to " .. self.velocity)
		
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
	
	end

end



-- Receive MIDI notes from a MIDI device
function Phrases:in_2_list(note)

	if self.recording == true then -- If recording-mode is toggled on...
	
		if (self.midicatch == "all") -- If all incoming MIDI is captured...
		or (
			(self.midicatch == "notes") -- Or incoming MIDI notes are captured,
			and rangeCheck(note[1], 128, 159) -- And the incoming MIDI byte is a MIDI note...
		) or (
			(self.midicatch == "no-offs") -- Or incoming MIDI bytes are captured except for note-offs,
			and not(rangeCheck(note[1], 128, 143)) -- And the incoming MIDI byte is not a note-off...
		)
		then
	
			-- Interpret the message's channel and command values, and save them internally
			if (self.channel ~= (note[1] % 16))
			and (note[1] >= 128)
			then
				self.channel = note[1] % 16
				self.command = note[1] - self.channel
			end
			
			if rangeCheck(note[1], 128, 159) then
				-- Map the incoming note to the current octave setting, then bound its value to the 0-127 range
				note[2] = (note[2] + (self.octave * 12)) % 128
			end
			
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

			self:updateEditorGUI()

		end
		
	else -- Playing mode
	
		if (k[3] == 1) -- Do this on down-keystrokes only
		and (button <= #self.phrase) -- Only if the button maps to a currently-existant phrase
		then
			
			-- Record a keystroke to the global keystroke-queue, which is emptied and parsed on each gate tick
			table.insert(self.queue, button)
			pd.post("Queued key: " .. button)
			
		end
	
	end
	
end

-- React to incoming tempo ticks
function Phrases:in_4_bang()

	-- Update the gate-button's color, based on the current tick
	local rgbgate = {}
	for i = 1, 3 do
	rgbgate[i] = math.max(1, math.min(255, math.floor(math.abs(
		self.color[5][1][i] + ((self.color[6][1][i] - self.color[5][1][i]) * (self.tick / self.gate))
	))))
	end
	self:outlet(5, "list", rgbOutList("phrases-grid-gate-button", rgbgate, self.color[8][1]))
	
	-- On every tick, do things to every active phrase
	for k, v in ipairs(self.phrase) do
	
		if v.active == true then
		
			-- debugging
			pd.post("phrase" .. k .. " - tick" .. v.tick .. " - point" .. v.pointer .. " - hash" .. v.dhash[v.pointer])
		
			self:iterate(k) -- Run the iterate function once per active phrase per tick
		
			local guix, guiy = keyToCoords(k, self.gridx, self.gridy, 1, 0)
			
			-- Update all active cells' GUI colors
			local rgbout = {}
			for i = 1, 3 do
				rgbout[i] = math.max(1, math.min(255, math.floor(math.abs(
					self.color[5][1][i] + ((self.color[6][1][i] - self.color[5][1][i]) * (v.pointer / #v.dhash))
				))))
			end
			
			local bname = guiy .. "-" .. guix .. "-grid-button"
			self:outlet(5, "list", rgbOutList(bname, rgbout, self.color[8][1]))
		
		end
		
	end
	
	-- Apply the transference matrix to every key-direction pair in the transference queue, and then activate those phrases
	for k, v in pairs(self.trqueue) do
		
		local trnew = self.matrix[k][v]
		
		self.phrase[trnew].active = true
		self.phrase[trnew].pointer = 1
		
	end
	
	self.trqueue = {}

	self.tick = self.tick + 1
	
end

-- React to bangs that signify the gate has been reached
function Phrases:in_5_bang()

	self.tick = 1
	
	for _, v in pairs(self.queue) do
		
		local outx, outy = keyToCoords(v, self.gridx, self.gridy, 1, 0)

		if self.phrase[v].active == false then -- On-toggle
		
			self.phrase[v].active = true
		
			-- Since the phrase was just activated, calculate a new transference direction
			self.phrase[v].tdir = calcTransference(self.phrase[v].transfer)
		
			-- Send a message to the Monome button updater
			self:outlet(3, "list", {outx, outy, 1})
			
			-- Send a color message to the Pd grid GUI, for the phrase that is the transference-target
			local trcell = self.matrix[v][self.phrase[v].tdir]
			if self.phrase[trcell].active == false then
				local toutx, touty = keyToCoords(trcell, self.gridx, self.gridy, 1, 0)
				local toutbutton = touty .. "-" .. toutx .. "-grid-button"
				self:outlet(5, "list", rgbOutList(toutbutton, self.color[7][1], self.color[8][1]))
			end
			
		else -- Off-toggle
		
			self.phrase[v].active = false
		
			-- Turn off all active MIDI sustains in the phrase
			self:haltPhraseMidi(v)
		
			-- Reset the phrase's pointer and tick
			self.phrase[v].pointer = 1
			self.phrase[v].tick = 1
			
			-- Send a message to the Monome button updater
			self:outlet(3, "list", {outx, outy, 0})
			
			-- Send a color message to the Pd grid GUI
			local outbutton = outy .. "-" .. outx .. "-grid-button"
			self:outlet(5, "list", rgbOutList(outbutton, self.color[8][1], self.color[8][1]))
			
		end
		
	end
	
	-- Empty the queue after acting upon it
	self.queue = {}

end

-- Get loadfile name
function Phrases:in_6_list(s)
	-- table.concat() is necessary, because Pd will interpret paths that contain spaces as lists
	self.loadname = table.concat(s, " ")
	pd.post("Current loadfile name is now: " .. self.loadname)
	pd.post("Note: Data has NOT been loaded! To load this loadfile, press: Shift-Esc-Enter")
end

-- Get savefile name
function Phrases:in_7_list(s)
	-- table.concat() is necessary, because Pd will interpret paths that contain spaces as lists
	self.savename = table.concat(s, " ")
	pd.post("Current savefile name (including path) is now: " .. self.filepath .. self.savename)
	pd.post("NOTE: Data has NOT been saved! To save to this savefile, press: Shift-?-|")
end

-- Get savefile path
function Phrases:in_8_list(s)
	-- table.concat() is necessary, because Pd will interpret paths that contain spaces as lists
	self.filepath = table.concat(s, " ")
	pd.post("Current savefile path is now: " .. self.filepath)
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

-- Get global grid-width
function Phrases:in_12_float(x)
	self.gridx = x
	self.matrix = makeTrMatrix(self.gridx, self.gridy)
end

-- Get global grid-height
function Phrases:in_13_float(y)
	self.gridy = y
	self.matrix = makeTrMatrix(self.gridx, self.gridy)
end

-- Get global editor-width
function Phrases:in_14_float(x)
	self.editorx = x
end

-- Get global editor-height
function Phrases:in_15_float(y)
	self.editory = y
end

-- Get GUI color-values
function Phrases:in_16_list(c)
	self.color[1] = modColor(c)
end

-- Get GUI color-value
function Phrases:in_17_list(c)
	self.color[2] = modColor(c)
end

-- Get GUI color-value
function Phrases:in_18_list(c)
	self.color[3] = modColor(c)
end

-- Get GUI color-value
function Phrases:in_19_list(c)
	self.color[4] = modColor(c)
end

-- Get GUI color-value
function Phrases:in_20_list(c)
	self.color[5] = modColor(c)
end

-- Get GUI color-value
function Phrases:in_21_list(c)
	self.color[6] = modColor(c)
end

-- Get GUI color-value
function Phrases:in_22_list(c)
	self.color[7] = modColor(c)
end

-- Get GUI color-value
function Phrases:in_23_list(c)
	self.color[8] = modColor(c)
end

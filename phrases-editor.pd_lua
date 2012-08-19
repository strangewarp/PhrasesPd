--[[

Editor object, designed for the particular requirements of PhrasesPd.

--]]

local Editor = pd.Class:new():register("phrases-editor")



-- Load the code's data tables in a tidy manner
local tabs = require("phrases-editor-tables")
local kbnames = tabs.kbnames
local kbhash = tabs.kbhash(kbnames)
local notenames = tabs.notenames
local cmdtable = tabs.cmdtable
local cmdnames = tabs.cmdnames
local trnames = tabs.trnames
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



-- Update an internal color value and its variants
function Editor:updateColor(ckey, color)

	-- This function expects colors in bursts of 3 (regular, light, dark), so it treats incoming values along those lines
	if #self.color[ckey] < 3 then
		table.insert(self.color[ckey], color)
	else
		self.color[ckey] = {color}
	end
	
end



-- Update the color and contents of a cell in the editor panel
function Editor:updateNoteButton(cellx, celly, k, p) -- editor x pointer, editor y pointer, phrase key, note pointer

	local cout = -1 -- Color-out value
	local mcout = -1 -- Message-color-out value
	local col = {} -- Note-cell color set: blank note
	local message = ""
	
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
	
	local notey = (celly + p) - offsety
	if (notey < 1)
	or (notey > notenum)
	then
		notey = ((notey - 1) % notenum) + 1
	end
	
	local note = self.phrase[notex].notes[notey]
	
	-- Insert a number of periods that properly aligns the note with its column's max note value
	message = notey .. string.rep(".", string.len(tostring(#self.phrase[notex].notes)) - (string.len(tostring(notey)) - 1))
	
	-- Make the relevant data bytes more human-readable, if the pitchview flag is true. Else return their internal values
	if self.pitchview == true then
	
		if rangeCheck(note[1], 128, 159) then -- All NOTE-ONs and NOTE-OFFs
			message = message .. " " .. note[1] .. " " .. readableNote(note[2]) .. " " .. note[3]
		elseif rangeCheck(note[1], 192, 223) then -- All two-byte notes
			message = message .. " " .. note[1] .. " " .. note[2]
		elseif note[1] == -1 then -- Empty notes
			message = message .. " --"
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
			
			mcout = self.color[4][1]
			
			if cellx == offsetx then -- Set active phrase's transference values to the main user-defined color
				if (nakedy == self.channel)
				or (
					(nakedy == 10)
					and (self.channel >= 10)
				)
				then
					cout = self.color[1][1]
				else
					cout = self.color[1][3]
				end
			else -- Set other transference values to the secondary user-defined color
				cout = self.color[2][1]
			end
			
		else
			cout = self.color[3][3]
			mcout = self.color[3][1]
		end
		
		pd.send((celly - 1) .. "-" .. (cellx - 1) .. "-editor-button", "color", {cout, mcout})
		pd.send((celly - 1) .. "-" .. (cellx - 1) .. "-editor-button", "label", {message})
	
	else -- Display colors normally when in other view modes
	
		if note[1] == -1 then -- Blank note color
			col = self.color[3]
		elseif rangeCheck(note[1], 128, 159) then -- Note-on / note-off color
			col = self.color[1]
		else -- Other commands color
			col = self.color[2]
		end
		
		if cellx == offsetx then -- For the active phrase, use regular colors
			cout = col[1]
			mcout = self.color[4][1]
		else -- For all inactive notes, use dark colors
			cout = col[3]
			mcout = self.color[4][3]
		end
			
		if ((notey - 1) % self.gate) == 0 then -- For all gate-key notes, use bright colors
			cout = col[2]
			mcout = self.color[4][2]
		end
		
		if celly == offsety then -- Reverse color values on the active row
			cout, mcout = mcout, cout
		end
		
		pd.send((celly - 1) .. "-" .. (cellx - 1) .. "-editor-button", "color", {cout, mcout})
		pd.send((celly - 1) .. "-" .. (cellx - 1) .. "-editor-button", "label", {message})
	
	end

end

-- Update the toggle-tracking button
function Editor:updateToggleButton()

	if self.recording == true then
		pd.send("phrases-editor-toggle-button", "color", {self.color[1][1], self.color[4][1]})
		pd.send("phrases-editor-toggle-button", "label", {"REC"})
	else
		pd.send("phrases-editor-toggle-button", "color", {self.color[2][1], self.color[4][1]})
		pd.send("phrases-editor-toggle-button", "label", {"PLAY"})
	end

end

-- Update the phrase-key button
function Editor:updateKeyButton()

	pd.send("phrases-editor-key-button", "color", {self.color[2][2], self.color[4][2]})
	pd.send("phrases-editor-key-button", "label", {"Phrase " .. self.key})
	
end

-- Update the note-item button
function Editor:updateItemButton()

	pd.send("phrases-editor-item-button", "color", {self.color[2][2], self.color[4][2]})
	pd.send("phrases-editor-item-button", "label", {"Item " .. self.pointer})
	
end

-- Update the tick-counter button
function Editor:updateTickButton()

	local tcount = 0
	local nbyte = 0
	
	for i = 1, #self.phrase[self.key].notes do -- Count which tick the pointer is on, as opposed to which MIDI command
		nbyte = self.phrase[self.key].notes[i][1]
		if (nbyte == -1)
		or rangeCheck(nbyte, 128, 159)
		then
			tcount = tcount + 1
			if i >= self.pointer then
				do break end -- Break the for loop, after encountering the first note tick at or past the pointer
			end
		end
	end
	
	pd.send("phrases-editor-tick-button", "color", {self.color[2][2], self.color[4][2]})
	pd.send("phrases-editor-tick-button", "label", {"Tick " .. tcount})

end

-- Update the data-entry-mode button
function Editor:updateModeButton()

	if self.inputmode == "note" then
		pd.send("phrases-editor-mode-button", "color", {self.color[2][1], self.color[4][1]})
		pd.send("phrases-editor-mode-button", "label", {"Mode: Note"})
	elseif self.inputmode == "tr" then
		pd.send("phrases-editor-mode-button", "color", {self.color[2][1], self.color[4][1]})
		pd.send("phrases-editor-mode-button", "label", {"Mode: Tr"})
	end

end

-- Update the MIDI-channel button
function Editor:updateChannelButton()

	local chbcolor = -1
	local chbmessage = ""

	if self.inputmode == "tr" then
		chbcolor = self.color[1][1]
		chbmessage = "Tr: " .. trnames[math.min(math.max(self.channel, 1), 10)]
	else
		chbcolor = self.color[2][1]
		chbmessage = "Chan " .. self.channel
	end
	
	pd.send("phrases-editor-channel-button", "color", {self.color[2][1], self.color[4][1]})
	pd.send("phrases-editor-channel-button", "label", {chbmessage})

end

-- Update the MIDI-command button
function Editor:updateCommandButton()

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

	pd.send("phrases-editor-command-button", "color", {cmdbcol, self.color[4][1]})
	pd.send("phrases-editor-command-button", "label", {"Cmd: " .. cmdnames[cmdkey]})

end

-- Update the MIDI-velocity button
function Editor:updateVelocityButton()

	pd.send("phrases-editor-velocity-button", "color", {self.color[2][1], self.color[4][1]})
	pd.send("phrases-editor-velocity-button", "label", {"Velo " .. self.velocity})

end

-- Update the input octave button
function Editor:updateOctaveButton()

	pd.send("phrases-editor-octave-button", "color", {self.color[2][1], self.color[4][1]})
	pd.send("phrases-editor-octave-button", "label", {"Octave " .. self.octave})

end

-- Update the input spacing button
function Editor:updateSpacingButton()

	pd.send("phrases-editor-spacing-button", "color", {self.color[2][1], self.color[4][1]})
	pd.send("phrases-editor-spacing-button", "label", {"Spacing " .. self.spacing})

end

-- Update the global BPM button
function Editor:updateGlobalBPMButton()

	pd.send("phrases-editor-global-bpm-button", "color", {self.color[2][1], self.color[4][1]})
	pd.send("phrases-editor-global-bpm-button", "label", {"BPM " .. self.bpm})

end

-- Update the global TPB button
function Editor:updateGlobalTPBButton()

	pd.send("phrases-editor-global-tpb-button", "color", {self.color[2][1], self.color[4][1]})
	pd.send("phrases-editor-global-tpb-button", "label", {"TPB " .. self.tpb})

end

-- Update the global GATE button
function Editor:updateGlobalGateButton()

	pd.send("phrases-editor-global-gate-button", "color", {self.color[2][1], self.color[4][1]})
	pd.send("phrases-editor-global-gate-button", "label", {"Gate " .. self.gate})

end

-- Update the editor's background color
function Editor:updateBackground()

	pd.send("phrases-editor-bg", "color", {self.color[3][1]})

end

-- Update all cells and buttons in the editor GUI
function Editor:updateEditorGUI()

	self:updateToggleButton()
	self:updateKeyButton()
	self:updateItemButton()
	self:updateTickButton()
	self:updateModeButton()
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



function Editor:initialize(sel, atoms)

	-- 1. Key commands
	-- 2. MIDI-IN
	-- 3. Monome button
	-- 4. loadfile name
	-- 5. savefile name
	-- 6. savepath name
	-- 7. Global BPM
	-- 8. Global TPB
	-- 9. Global GATE
	-- 10. Grid X cells
	-- 11. Grid Y cells
	-- 12. Editor X cells
	-- 13. Editor Y cells
	-- 14. Editor GUI color 1
	-- 15. Editor GUI color 2
	-- 16. Editor GUI color 3
	-- 17. Editor GUI color 4
	self.inlets = 17
	
	-- 1. Note-send out (to delayed note-off as well)
	self.outlets = 1
	
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
	
	-- Default GUI colors: {regular, highlight, dark}
	self.color = {
		{-1, -1, -1}, {-1, -1, -1}, {-1, -1, -1}, {-1, -1, -1}
	}
	
	self.phrase = {}
	for i = 1, self.gridx * self.gridy do -- Set default phrase data
		self.phrase[i] = {
			transfer = { 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, },
			tdir = 5,
			notes = { {-1}, {-1}, {-1}, {-1}, },
			pointer = 1,
			active = false,
		}
	end
	
	self.key = 1 -- Currently active phrase
	
	self.pointer = 1 -- Pointer for note manipulation
	
	self.spacing = 0 -- Spacing of gaps between notes
	self.command = 144 -- Command-type for computer-keystrokes
	self.octave = 1 -- Octave
	self.channel = 0 -- MIDI channel
	self.velocity = 127 -- MIDI velocity
	
	self.recording = false -- Toggle whether to record data from incoming keystrokes
	
	self.inputmode = "note" -- Set to either 'note' or 'tr', depending on which input mode is active
	
	self.pitchview = true -- Flag that controls whether editor data values are shown as pitches or numbers
	
	return true
	
end



-- Control-commands in
function Editor:in_1_list(list)

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
				
			elseif self.inputmode == "tr" then -- Use incoming keycommands to set the weight of transference values
			
				if rangeCheck(self.channel, 1, 9) then
					self.phrase[self.key].transfer[self.channel] = putnote
					pd.post("Phrase " .. self.key .. ": Set transference direction " .. self.channel .. " to strength " .. putnote)
				else
					self.phrase[self.key].transfer[10] = (self.phrase[self.key].transfer[10] + 1) % 2
					pd.post("Phrase " .. self.key .. ": Persistence set to " .. self.phrase[self.key].transfer[10])
				end
			
			end
			
			if (self.inputmode == "note")
			and (
				rangeCheck(self.command, 128, 255)
				or rangeCheck(self.command, -5, -7)
			)
			then
				-- Increase note pointer, and prevent overshooting the limit of the phrase's note array
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
		
	elseif cmd == "RECORD_TOGGLE" then -- Toggle recording mode ON or OFF
	
		self.recording = not(self.recording)
		pd.post("Recording toggled to " .. tostring(self.recording))
	
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
			
			-- Load all data tables
			for k, v in pairs(ltab) do
				pd.post("loading: " .. k .. " - " .. tostring(v))
				self[k] = v
			end
			
			-- Reset the editor's key and pointer, to prevent out-of-bounds errors
			self.key = 1
			self.pointer = 1
			
			self:updateEditorGUI()
			
			pd.post("Phrases Editor: Loaded the contents of " .. self.loadname .. "!")
			
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
			
				if (v2[1] == -1)
				or rangeCheck(v2[1], 128, 159)
				then -- Only increment the note-tracking variable if the note would stop the sequencer's iteration
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
		
		pd.post("Data saved!")
	
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
		
		-- Check pointer against the new phrase's notes, to prevent out-of-bounds errors
		if self.pointer > #self.phrase[self.key].notes then
			self.pointer = #self.phrase[self.key].notes
		end
		
		pd.send("phrases-editor-key-button", "label", {"Key " .. tostring(self.key)})
		
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
function Editor:in_2_list(note)

	if self.recording == true then -- Insert MIDI note at current pointer location
	
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

		self:updateEditorGUI()
		
	end
	
end

-- Interpret an incoming Monome button command, and switch to the relevant phrase
function Editor:in_3_list(k)

	local button = k[1] + (k[2] * self.gridx) + 1

	-- Set active phrase to button value
	if (self.recording == true) -- Prevent the editor GUI from making potentially laggy updates during performance
	and (k[3] == 1) -- Do this on down-keystrokes only
	and (button <= #self.phrase) -- Only if the button maps to a currently-existant phrase
	then
	
		self.key = button
		self.pointer = 1 -- Prevent null-pointer errors by resetting the global pointer
		pd.post("Phrases-Editor: active phrase: " .. button)
		
		self:updateEditorGUI()

	end
	
end

-- Get loadfile name
function Editor:in_4_list(s)
	-- table.concat() is necessary, because Pd will interpret paths that contain spaces as lists
	self.loadname = table.concat(s, " ")
	pd.post("Current loadfile name is now: " .. self.loadname)
end

-- Get savefile name
function Editor:in_5_list(s)
	-- table.concat() is necessary, because Pd will interpret paths that contain spaces as lists
	self.savename = table.concat(s, " ")
	pd.post("Current savefile name (including path) is now: " .. self.filepath .. self.savename)
	pd.post("NOTE: Data has NOT been saved! To save to this savefile, press: Shift-?-|")
end

-- Get savefile path
function Editor:in_6_list(s)
	-- table.concat() is necessary, because Pd will interpret paths that contain spaces as lists
	self.filepath = table.concat(s, " ")
	pd.post("Current savefile path is now: " .. self.filepath)
end

-- Get global BPM value
function Editor:in_7_float(f)
	self.bpm = f
end

-- Get global TPB value
function Editor:in_8_float(f)
	self.tpb = f
end

-- Get global GATE value
function Editor:in_9_float(f)
	self.gate = f
end

-- Get global grid-width
function Editor:in_10_float(x)
	self.gridx = x
end

-- Get global grid-height
function Editor:in_11_float(y)
	self.gridy = y
end

-- Get global editor-width
function Editor:in_12_float(x)
	self.editorx = x
end

-- Get global editor-height
function Editor:in_13_float(y)
	self.editory = y
end

-- Get GUI color-values
function Editor:in_14_color(c)

	self:updateColor(1, c[1])
	
end

-- Get GUI color-value
function Editor:in_15_color(c)

	self:updateColor(2, c[1])
	
end

-- Get GUI color-value
function Editor:in_16_color(c)

	self:updateColor(3, c[1])
	
end

-- Get GUI color-value
function Editor:in_17_color(c)

	self:updateColor(4, c[1])
	
end

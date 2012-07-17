--[[

Editor object, designed for the particular requirements of PhrasesPd.

REMEMBER: Each phrase can only have notes of one channel, to prevent sustain trainwrecks

REMEMBER: Transference, and the toggling of recording, should be handled in Pd itself

--]]

local Editor = pd.Class:new():register("phrases-editor")



local kbkeys = {
	"z", "s", "x", "d", "c", "v", "g", "b", "h", "n", "j", "m",
	{",", "q"},
	{"l", "2"},
	{".", "w"},
	{";", "3"},
	{"/", "e"},
	"r", "5", "t", "6", "y", "7", "u", "i", "9", "o", "0", "p"
}

local kbhash = {}

-- Build a hashmap of keyboard-keys and MIDI-offset values, for the computer-keyboard section of the editor
for k, v in ipairs(kbkeys) do
	if #v > 1 then
		for _, vv in pairs(v) do
			kbhash[vv] = k - 1
		end
	else
		kbhash[v] = k - 1
	end
end



-- Load a Lua savefile and return its table data
local function loadTable(f)

	local data = {}
	
	local fcheck = io.open(f, "r")
	if fcheck ~= nil then
		data = dofile(f)
	else
		pd.post("Error: Attempted to load a file that doesn't exist!")
	end
	io.close(f)
	
	return data
	
end



-- Set default parameters for an empty phrase
function Editor:setDefaults(k)

	self.phrase[k] = {}
	self.phrase[k].transfer = {}
	for i = 1, 10 do -- Spawn all transference slots with empty values
		self.phrase[k].transfer[i] = 0
	end
	self.phrase[k].transfer[5] = 1 -- Default behavior: stationary transference
	self.phrase[k].transfer[10] = 1 -- Default behavior: continue looping when on
	self.phrase[k].tdir = 5
	self.phrase[k].notes = { {-1}, {-1}, {-1}, {-1} }
	self.phrase[k].pointer = 1
	self.phrase[k].active = false
	
end



-- Translate a Pd color value into a table
function Editor:seperateColor(c)

	c = (c + 1) * -1
	local c1 = c / 65536
	local c2 = (c1 - math.floor(c1)) * 256
	local c3 = (c2 - math.floor(c2)) * 256
	
	return { math.floor(c1), math.floor(c2), math.floor(c3) }
	
end

-- Translate a table into a Pd color value
function Editor:buildColor(c)

	local clump = ((c[1] * -65536) + (c[2] * -256) + (c[3] * -1)) - 1
	
	return clump
	
end

-- Update an internal color value and its variants
function Editor:updateColor(ckey, color)

	self.color[ckey][1] = color
	
	local clight = self:seperateColor(color)
	local cdark = clight
	
	for cn = 1, 3 do
		clight[cn] = clight[cn] + ((255 - clight[cn]) / 3)
		cdark[cn] = math.floor(cdark[cn] / 1.5)
	end
	
	self.color[ckey][2] = self:buildColor(clight)
	self.color[ckey][3] = self:buildColor(cdark)

end

-- Update the color and contents of a cell in the editor panel
function Editor:updateButton(cellx, celly, k, p) -- editor x pointer, editor y pointer, phrase key, note pointer

	local cout = -1 -- Color-out value
	local mcout = -1 -- Message-color-out value
	local col = {} -- Note-cell color set: blank note
	local message = ""
	
	local gsize = (self.gridx * self.gridy)
	local offsety = math.floor(self.editory / 4)
	
	local notex = (cellx + k) - 1
	if (notex < 1) or (notex > gsize) then
		notex = ((notex - 1) % gsize) + 1
	end
	
	local notenum = #self.phrase[notex].notes
	
	-- Wrap short, non-active phrases against the active phrase's pointer
	if p > notenum then
		p = ((p - 1) % notenum) + 1
	end
	
	local notey = ((celly + p) - 1) - offsety
	if (notey < 1) or (notey > notenum) then
		notey = ((notey - 1) % notenum) + 1
	end
	
	--pd.post("gsize: " .. gsize)
	--pd.post("offsety: " .. offsety)
	--pd.post("cellx: " .. cellx)
	--pd.post("celly: " .. celly)
	--pd.post("notex: " .. notex)
	--pd.post("notey: " .. notey)
	
	local note = self.phrase[notex].notes[notey]
	
	message = notey .. ". " .. table.concat(note, " ")
	
	if note[1] == -1 then -- Blank note color
		col = self.color[3]
	elseif (note[1] >= 128) and (note[1] <= 159) then -- Note-on / note-off color
		col = self.color[1]
	else -- Other MIDI commands color
		col = self.color[2]
	end
	
	if cellx == 1 then -- For the active phrase, use regular colors
		cout = col[1]
		mcout = self.color[4][1]
	else -- For all inactive notes, use dark colors
		cout = col[3]
		mcout = self.color[4][3]
	end
		
	if notey == 1 then -- For all phrase-starting notes, use bright colors
		cout = col[2]
		mcout = self.color[4][2]
	end
	
	if celly == offsety then -- Reverse color values on the active row
		cout, mcout = mcout, cout
	end
	
	pd.send((celly - 1) .. "-" .. (cellx - 1) .. "-editor-button", "color", {cout, mcout})
	pd.send((celly - 1) .. "-" .. (cellx - 1) .. "-editor-button", "label", {message})

end

-- Update all cells in the editor GUI
function Editor:updateGUI()

	for ey = 1, self.editory do
		for ex = 1, self.editorx do
			self:updateButton(ex, ey, self.key, self.pointer)
		end
	end

end



function Editor:initialize(sel, atoms)

	-- 1. Key commands in
	-- 2. MIDI-IN
	-- 3. Monome button in
	-- 4. Loadfile name in
	-- 5. Savefile name in
	-- 6. Global BPM in
	-- 7. Global TPB in
	-- 8. Global GATE in
	-- 9. Grid width in
	-- 10. Grid height in
	-- 11. Editor width in
	-- 12. Editor height in
	-- 13. Editor GUI color 1 in
	-- 14. Editor GUI color 2 in
	-- 15. Editor GUI color 3 in
	-- 16. Editor GUI color 4 in
	self.inlets = 16
	
	-- 1. Note-send out (to delayed note-off as well)
	self.outlets = 1
	
	-- Default grid height and width
	self.gridx = 8
	self.gridy = 8
	
	-- Default editor height and width
	self.editorx = 6
	self.editory = 32
	
	-- Default file names
	self.loadfile = "phrases-default-testfile.lua"
	self.savefile = "phrases-default-testfile.lua"
	
	-- Default BPM, TPB, GATE values
	self.bpm = 120
	self.tpb = 4
	self.gate = 16
	
	-- Default GUI colors: {regular, highlight, dark}
	self.color = {
		{-1, -1, -1}, {-1, -1, -1}, {-1, -1, -1}, {-1, -1, -1}
	}
	
	self.phrase = {} -- For storing all phrase data
	
	-- Build the phrase-data table, and populate it with defaults
	for n = 1, self.gridx * self.gridy do
		self.phrase[n] = {}
		self:setDefaults(n)
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
	
	return true
	
end



-- Control-commands in
function Editor:in_1_symbol(s)
	
	if not(kbhash[s] == nil) then -- Interpret all possible computer-keyboard-note keys
	
		local putnote = kbhash[s] + (self.octave * 12)
		
		while putnote > 127 do
			putnote = putnote - 12
		end
		
		if self.recording == true then
		
			if self.inputmode == "note" then -- Use incoming keycommands to insert notes in the active phrase
		
				table.insert(self.phrase[self.key].notes, self.pointer, {self.command + self.channel, putnote, self.velocity})
				
				if self.spacing > 0 then
					for i = 1, self.spacing do
						table.insert(self.phrase[self.key].notes, self.pointer, {-1})
						self.pointer = self.pointer + 1
					end
				end

				self.pointer = self.pointer + 1

				pd.post("Inserted note " .. (self.command + self.channel) .. " " .. putnote .. " " .. self.velocity)
				
			elseif self.inputmode == "tr" then -- Use incoming keycommands to set the weight of transference values
			
				if (self.channel >= 1) and (self.channel <= 9) then
					self.phrase[self.key].transfer[self.channel] = putnote
					pd.post("Phrase " .. self.key .. ": Set transference direction " .. self.channel .. " to strength " .. putnote)
				else
					self.phrase[self.key].transfer[10] = (self.phrase[self.key].transfer[10] + 1) % 2
					pd.post("Phrase " .. self.key .. ": Persistence set to " .. self.phrase[self.key].transfer[10])
				end
			
			end
			
			self:updateGUI()
			
		end
		
		-- Send MIDI note to outlet, regardless of whether the editor is recording, so long as the editor is in note mode
		if self.inputmode == "note" then
			self:outlet(1, "list", {144 + self.channel, putnote, self.velocity})
		end
		
	elseif s == "PHRASES-RECORD" then -- Toggle recording mode ON; custom command generated by Pd
	
		self.recording = true
		pd.post("Phrases-Editor: Recording toggled on!")
	
		-- Update GUI
		pd.send("phrases-editor-toggle-button", "color", {self.color[1][1], self.color[4][1]})
		pd.send("phrases-editor-toggle-button", "label", {"REC"})
		self:updateGUI()
		
	elseif s == "PHRASES-IGNORE" then -- Toggle recording mode OFF; custom command generated by Pd
	
		self.recording = false
		pd.post("Phrases-Editor: Recording toggled off!")
		
		-- Update GUI
		pd.send("phrases-editor-toggle-button", "color", {self.color[2][1], self.color[4][1]})
		pd.send("phrases-editor-toggle-button", "label", {"OFF"})
		self:updateGUI()
	
	elseif s == "PHRASES-LOAD" then -- Load a Lua savefile into local variables
	
		if self.recording == true then
		
			local loaddata = loadTable(self.loadfile)
			
			for k, v in pairs(loaddata) do
				self[k] = v
				pd.post("Loaded " .. k)
			end
		
			self:updateGUI()
	
		end
		
	elseif s == "PHRASES-SAVE" then -- Save data as a Lua table in the savefile; custom SAVE command generated through Pd
	
		local o = ""
	
		for k, v in ipairs(self.phrase) do
			
			o = o .. "[\"" .. k .. "\"] = {\n"
			
			o = o .. "\t[\"transfer\"] = {"
			
			for k2, v2 in ipairs(v.transfer) do
				if k2 > 1 then
					o = o .. ", "
				end
				o = o .. v2
			end
			
			o = o .. "}\n\t[\"notes\"] = {\n"
			
			for k2, v2 in ipairs(v.notes) do
			
				o = o .. "\t\t{"
			
				for k3, v3 in ipairs(v2) do
					if k3 > 1 then
						o = o .. ", "
					end
					o = o .. v3
				end
				
				o = o .. "}"
				
			end
			
			o = o .. "\t}\n"
			
			o = o .. "}\n"
			
		end
		
		local f = assert(io.open(self.savefile, "w"))
		f:write(o)
		f:close()
		pd.post("Data saved!")
	
		--local save = {self.bpm, self.tpb, self.gate, self.phrase}
		--io.output(self.savefile)
		--saveTable(save, 1, false)
		--pd.post("Data saved!")
		
		
		
		--local save = {}
		
		--for i = 1, self.gridx * self.gridy do
		
		--	pd.post("Prepping: Phrase " .. i)
		
		--	for k, v in ipairs(self.phrase[i].transfer) do
		--		table.insert(save, "-3")
		--		table.insert(save, k)
		--		table.insert(save, v)
		--		pd.post(k .. " : " .. v)
		--	end
			
		--	for k, v in ipairs(self.phrase[i].notes) do
		--		for _, vv in ipairs(v) do
		--			table.insert(save, vv)
		--		end
		--		pd.post("Prepping: Note" .. k .. " : " .. table.concat(v, " "))
		--	end
			
		--	table.insert(save, "-10")
			
		--end
		
		--pd.post("Sending all prepared phrase data from the editor to the data-save mechanism...")
		--self:outlet(2, "list", save)
	
	elseif s == "Down" then -- Advance pointer
	
		self.pointer = self.pointer + 1
		
		if self.pointer > #self.phrase[self.key].notes then
			self.pointer = 1
		end
	
		self:updateGUI()
	
	elseif s == "Up" then -- Retreat poiner
	
		self.pointer = self.pointer - 1
		
		if self.pointer <= 0 then
			self.pointer = #self.phrase[self.key].notes
		end
	
		self:updateGUI()
	
	elseif s == "Home" then -- Set pointer to beginning of phrase
	
		self.pointer = 1
		
		self:updateGUI()
	
	elseif s == "End" then -- Set pointer to end of phrase
	
		self.pointer = #self.phrase[self.key].notes
		
		self:updateGUI()
	
	elseif (s == "Left") -- Toggle to previous phrase
		or (s == "Right") -- Or next phrase
	then
	
		if s == "Left" then
			self.key = self.key - 1
		else
			self.key = self.key + 1
		end
		
		if self.key < 1 then
			self.key = self.gridy * self.gridx
		elseif self.key > (self.gridy * self.gridx) then
			self.key = 1
		end
		
		-- If the new phrase has no notes, give it default values
		if self.phrase[self.key].notes == nil then
			self:setDefaults(self.key)
		end
		
		-- Check pointer against the new phrase's notes, to prevent out-of-bounds errors
		if self.pointer > #self.phrase[self.key].notes then
			self.pointer = #self.phrase[self.key].notes
		end
		
		pd.post("Toggled to phrase " .. self.key)
		
		self:updateGUI()
	
	elseif s == "Next" then -- Decrease spacing
	
		self.spacing = math.max(0, self.spacing - 1)
		pd.post("Phrases-Editor: Spacing set to " .. self.spacing)
	
	elseif s == "Prior" then -- Increase spacing
	
		self.spacing = self.spacing + 1
		pd.post("Phrases-Editor: Spacing set to " .. self.spacing)
	
	elseif s == "~" then -- Decrease channel
	
		self.channel = (self.channel - 1) % 16
		pd.post("Phrases-Editor: Channel set to " .. self.channel)
	
	elseif s == "`" then -- Increase channel
	
		self.channel = (self.channel + 1) % 16
		pd.post("Phrases-Editor: Channel set to " .. self.channel)
		
	elseif s == "_" then -- Decrease velocity
	
		self.velocity = (self.velocity - 1) % 128
		pd.post("Phrases-Editor: Velocity set to " .. self.velocity)
	
	elseif s == "-" then -- Increase velocity
	
		self.velocity = (self.velocity + 1) % 128
		pd.post("Phrases-Editor: Velocity set to " .. self.velocity)
		
	elseif s == "+" then -- Decrease velocity by 10
	
		self.velocity = (self.velocity - 10) % 128
		pd.post("Phrases-Editor: Velocity set to " .. self.velocity)
	
	elseif s == "=" then -- Increase velocity by 10
	
		self.velocity = (self.velocity + 10) % 128
		pd.post("Phrases-Editor: Velocity set to " .. self.velocity)
		
	elseif s == "[" then -- Lower octave
	
		self.octave = (self.octave - 1) % 10
		pd.post("Phrases-Editor: Octave set to " .. self.octave)
		
	elseif s == "]" then -- Raise octave
	
		self.octave = (self.octave + 1) % 10
		pd.post("Phrases-Editor: Octave set to " .. self.octave)
		
	elseif s == "Insert" then -- Toggle computer-keypress note type
	
		self.command = ((self.command + 16) % 128) + 128
		
		if self.command == 128 then
			pd.post("Phrases-Editor: Command type: NOTE-OFF (128)")
		elseif self.command == 144 then
			pd.post("Phrases-Editor: Command type: NOTE-ON (144)")
		elseif self.command == 160 then
			pd.post("Phrases-Editor: Command type: POLY-KEY PRESSURE (160)")
		elseif self.command == 176 then
			pd.post("Phrases-Editor: Command type: CONTROL CHANGE (176)")
		elseif self.command == 192 then
			pd.post("Phrases-Editor: Command type: PROGRAM CHANGE (192)")
		elseif self.command == 208 then
			pd.post("Phrases-Editor: Command type: MONO KEY PERSSURE (208)")
		elseif self.command == 224 then
			pd.post("Phrases-Editor: Command type: PITCH BEND (224)")
		elseif self.command == 240 then
			pd.post("Phrases-Editor: Command type: SYSTEM (240)")
		end
	
	elseif s == "Delete" then -- Delete current note
	
		if self.recording == true then
	
			if #self.phrase[self.key].notes > 1 then
			
				table.remove(self.phrase[self.key].notes, self.pointer)
				pd.post("Phrases-Editor: Deleted note " .. self.pointer .. " in phrase " .. self.key)
				
				if self.phrase[self.key].notes[self.pointer] == nil then
					self.pointer = self.pointer - 1
					pd.post("Phrases-Editor: Moved pointer to " .. self.pointer .. " after note deletion")
				end
				
				self:updateGUI()
				
			else
			
				pd.post("Phrases-Editor: Could not delete last remaining note in phrase " .. self.key)
			
			end
		
		end
	
	elseif s == "BackSpace" then -- Add a blank note at current pointer position
	
		if self.recording == true then
		
			table.insert(self.phrase[self.key].notes, self.pointer, {-1})
			self.pointer = self.pointer + 1
			
			pd.post("Phrases-Editor: Inserted note -1 at point " .. self.pointer .. " in phrase " .. self.key)
			
			self:updateGUI()
			
		end
	
	elseif s == "Tab" then -- Toggle between transference and note modes
	
		if self.inputmode == "note" then
			self.inputmode = "tr"
			pd.post("Phrases-Editor: Input mode: Transference")
		else
			self.inputmode = "note"
			pd.post("Phrases-Editor: Input mode: Note")
		end
	
	end

end



-- Receive MIDI notes from a MIDI device
function Editor:in_2_list(note)

	if self.recording == true then -- Insert MIDI note at current pointer location
	
		if (not(self.channel == (note[1] % 16)))
			and (note[1] >= 128)
		then
			self.channel = note[1] % 16
			pd.post("Phrases-Editor: Default channel set to " .. self.channel)
		end
		
		-- Insert a dummy byte at byte 3, if the MIDI message has two bytes
		-- if (note[1] >= 192) and (note[1] <= 223) then
		if #note < 3 then
			note[3] = 0
		end

		for i = 1, self.spacing - 1 do
			table.insert(self.phrase[self.key].notes, self.pointer, {-1})
		end
		
		table.insert(self.phrase[self.key].notes, self.pointer, note)
		pd.post("Phrases-Editor: Inserted note " .. table.concat(note, " ") .. " at point " .. self.pointer .. " in phrase " .. self.key)
		
		self:updateGUI()
		
	end
	
	-- Send MIDI note, regardless of whether it was kept or discarded by the editor
	self:outlet(1, "list", note)
	
end

-- Receive Monome button commant, to change the active phrase
function Editor:in_3_float(f)

	if f > 0 then
		self.key = f
		if self.phrase[f] == nil then
			self:setDefaults(f)
		end
	end
	
	self:updateGUI()

end

-- Get loadfile name
function Editor:in_4_symbol(s)
	self.loadfile = s
end

-- Get savefile name
function Editor:in_5_symbol(s)
	self.savefile = s
end

-- Get global BPM value
function Editor:in_6_float(f)
	self.bpm = f
end

-- Get global TPB value
function Editor:in_7_float(f)
	self.tpb = f
end

-- Get global GATE value
function Editor:in_8_float(f)
	self.gate = f
end

-- Get global grid-width
function Editor:in_9_float(x)
	self.gridx = x
end

-- Get global grid-height
function Editor:in_10_float(y)
	self.gridy = y
end

-- Get global editor-width
function Editor:in_11_float(x)
	self.editorx = x
end

-- Get global editor-height
function Editor:in_12_float(y)
	self.editory = y
end

-- Get GUI color-value
function Editor:in_13_color(c)

	self:updateColor(1, c[1])
	
	self:updateGUI()
	
end

-- Get GUI color-value
function Editor:in_14_color(c)

	self:updateColor(2, c[1])
	
	self:updateGUI()
	
end

-- Get GUI color-value
function Editor:in_15_color(c)

	self:updateColor(3, c[1])
	
	self:updateGUI()
	
end

-- Get GUI color-value
function Editor:in_16_color(c)

	self:updateColor(4, c[1])
	
	self:updateGUI()
	
end

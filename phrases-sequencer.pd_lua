--[[

Phrases object, designed for the particular requirements of PhrasesPd.

Note: Phrase keys are 1-indexed.

--]]

local Phrases = pd.Class:new():register("phrases-sequencer")



-- Calculate a random transference direction, from a hash of weighted directions (1-9; 10 is ignored)
local function calcTransference(trhash)
	local total, count, num = 0, 0, 0
	for k, v in pairs(trhash) do
		if k <= 9 then
			total = total + v
		end
	end
	local sel = math.random(total)
	while (count < sel) and (num < 9) do
		num = num + 1
		if not(trhash[num] == nil) then
			count = count + trhash[num]
		end
	end
	return num
end



function Phrases:midiParse(k, midinote)

	local b1, b2, b3 = midinote[1], midinote[2], midinote[3]
	local chan = b1 % 16
	local command = b1 - chan
	
	if command == 128 then -- All note-offs
	
		-- Only send a note-off if this is the only sustain for a note; else reduce the note's sustain counter
		if self.midi[chan][b2] <= 1 then
			self.midi[chan][b2] = 0
			self:outlet(1, "list", midinote)
		elseif self.midi[chan][b2] >= 2 then
			self.midi[chan][b2] = self.midi[chan][b2] - 1
		end
		
		self.phrase[k].sustain = -1
	
	elseif command == 144 then -- All note-ons
	
		-- If the note isn't the same as the sustain var, increment its note-tracking variable
		if not(self.phrase[k].sustain == b2) then
			self.midi[chan][b2] = self.midi[chan][b2] + 1
		end
			
		-- If another note is currently sustained, fully parse a note-off for it before sending the next note-on
		if not(self.phrase[k].sustain == -1) then
			self.midiParse(k, {128 + chan, b2, 127})
		end
		
		self.phrase[k].sustain = b2
		self:outlet(1, "list", midinote)
		
		-- Send a blink command for the given phrase's button
		self:outlet(4, "float", {k})
		
	elseif (command >= 160) and (command <= 240) then -- All other commands
		self:outlet(1, "list", midinote)
	end

end

-- Called to iterate through the notes in various phrases
function Phrases:iterate(k)
	
	local p = self.phrase[k].pointer
	local notes = self.phrase[k].notes
	
	-- Iterate through notes until hitting a note-on, note-off, or silent beat
	repeat
	
		local oldp = p
		
		if notes[p] == -1 then
			p = p + 1
		else
			-- Send MIDI command
			self.midiParse(k, {notes[p], notes[p + 1], notes[p + 2]})
			p = p + 3
		end
	
		-- If the pointer has passed the end of the phrase, add a transference command to the tick's tr-queue
		if p > #notes then
			p = p % #notes
			table.insert(self.tr, k)
			table.insert(self.tr, self.phrase[k].tdir)
		end
		
	until notes[oldp] <= 159
	
	-- Update GUI
	local color = math.max(0, 255 - (#notes - oldp))
	pd.send("phrases-button-colorize", "list", {k, math.abs(color - 255), 0, color})
	
	self.phrase[k].pointer = p
	
end

-- Set default parameters for an empty phrase
function Phrases:setDefaults(k)
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

function Phrases:initialize(sel, atoms)

	-- Tempo bang;
	-- Toggle bang;
	-- Transference-toggle float;
	-- Key number;
	-- Transference list;
	-- Note list;
	self.inlets = 6
	
	-- MIDI-OUT
	-- Transference-modlist-out
	-- Monome-LED-state-out;
	-- Blink-out;
	self.outlets = 4
	
	self.midi = {}
	for i = 0, 15 do
		self.midi[i] = {}
		for j = 0, 127 do
			self.midi[i][j] = 0
		end
	end
	
	self.tr = {} -- For storing up all transference from a given tick
	
	self.phrase = {} -- For storing all phrase data
	
	self.key = 1
	self.x = 1
	self.y = 1
	self.setDefaults(self, 1)
	
	return true
	
end



-- Tempo-bang in
function Phrases:in_1_bang()

	-- Iterate through the current note on every active phrase
	for k, v in ipairs(self.phrase) do
		if self.phrase[k].active == true then
			self.iterate(k)
		end
	end
	
	-- Send and then erase all transference commands from the tick that just occurred
	self:outlet(2, "list", self.tr)
	self.tr = {}

end

-- Toggle-bang in
function Phrases:in_2_bang()

	-- Toggle the phrase's activity: off becomes on, on becomes off
	self.phrase[self.key].active = not(self.phrase[self.key].active)
	
	-- Handle transference and potential note-offs
	if self.phrase[self.key].active == false then
	
		if not(self.phrase[self.key].sustain == -1) then
			self.midiParse(self.key, {128 + self.phrase[self.key].channel, self.phrase[self.key].sustain, 127})
		end
		
		-- Send transference if the phrase has ended
		self:outlet(2, "list", {self.key, self.phrase[self.key].tdir})
		
		-- Send Monome-button-off command
		self:outlet(3, "float", {0})

		-- Update GUI
		pd.send("phrases-button-colorize", "list", {self.key, 220, 220, 220})
	
	else
	
		-- Calculate a transference direction for the newly active phrase
		self.phrase[self.key].tdir = calcTransference(self.phrase[self.key].transfer)
	
		-- Send Monome-button-on command
		self:outlet(3, "float", {1})

		-- Update GUI
		pd.send("phrases-button-colorize", "list", {self.key, 255, 0, 0})
	
	end

end

-- Transference-toggle in
function Phrases:in_3_float(f)

	if not(self.phrase[f] == nil) then
		-- If the phrase is inactive, toggle it active
		if self.phrase[f].active == false then
			self.phrase[f].active = true
		end
		-- Regardless of activity, reset the phrase's pointer
		self.phrase[f].pointer = 1
	end
	
end

-- Key-change in
function Phrases:in_4_float(f)

	if (not(f == nil)) and (f > 0) then
		self.key = f
		self.x = ((self.key - 1) % self.width) + 1
		self.y = math.floor((self.key - 1) / self.width) + 1
		if self.phrase[f] == nil then
			self.setDefaults(f)
		end
	end
	
end

-- Transference-list in
function Phrases:in_5_list(trin)

	self.phrase[self.key].transfer = {} -- Clear previous transference data
	
	for j = 1, #trin, 2 do -- Insert new transference data
		if (trin[j] >= 1) and (trin[j] <= 10) then
			self.phrase[self.key].transfer[trin[j]] = trin[j + 1]
		end
	end
	
	-- Calculate a transference direction after loading all transference values
	self.phrase[self.key].tdir = calcTransference(self.phrase[self.key].transfer)
	
end

-- Note-list in
function Phrases:in_6_list(notesin)

	-- Parse an off-urge if there is active sustain
	if self.phrase[self.key].sustain >= 0 then
		self.midiParse(self.key, {128 + self.phrase[self.key].channel, self.phrase[self.key].sustain, 127})
	end
	self.phrase[self.key].active = false -- Halt any activity on the phrase
	self.phrase[self.key].pointer = 1 -- Reset the phrase's pointer
	self.phrase[self.key].notes = notesin -- Replace previous note data with new note data
	
	-- Update GUI
	pd.send("phrases-button-colorize", "list", {self.key, 220, 220, 220})
	
end

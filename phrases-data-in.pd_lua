--[[

Data-parsing object, designed for the particular requirements of Phrases-pd.

--]]

local DataIn = pd.Class:new():register("phrases-data-in")



function DataIn:initialize(sel, atoms)

	-- 1. Filename in
	-- 2. Grid height
	-- 3. Grid width
	self.inlets = 3
	
	-- 1. Phrase key
	-- 2. Single-phrase-transference out
	-- 3. Single-phrase-notes out
	self.outlets = 3
	
	self.gridx = 8
	self.gridy = 8
	
	return true
	
end

-- Take in data filenames, and parse their contents for the main Phrases object
function DataIn:in_1_symbol(filename)

	local tr = {}
	local notes = {}
	for i = 1, self.gridx * self.gridy do
		tr[i] = {}
		notes[i] = {}
	end
	
	local key = 1
	pd.post("Loading phrase " .. key)

	-- Iterate through all lines in the datafile
	for line in io.lines(filename) do
	
		ldata = {}
	
		-- Correctly retrieve the bytes of multi-byte commands
		for tok in line:gmatch("%S+") do
			table.insert(ldata, tok)
		end
		
		-- Store the retrieved data, if the line contains data AND the key is within the Monome grid
		if (#ldata > 0)
			and (key <= (self.gridx * self.gridy))
		then
		
			if ldata[1] == "tr" then -- Transference command
			
				tr[key][ldata[2]] = ldata[3]
				pd.post("Loaded TRANSFERENCE command: " .. ldata[2] .. ":" .. ldata[3])
			
			elseif ldata[1] == "end" then -- End-of-phrase command
			
				pd.post("Finished loading phrase " .. key)
				
				key = key + 1
				pd.post("Loading phrase " .. key)
			
			elseif ldata[1] == "global-bpm" then -- Global beats-per-minute command
			
				pd.send("phrases-bpm", "float", {ldata[2]})
				pd.post("Loaded global BPM value: " .. ldata[2])
			
			elseif ldata[1] == "global-tpb" then -- Global ticks-per-beat command
			
				pd.send("phrases-tpb", "float", {ldata[2]})
				pd.post("Loaded global TPB value: " .. ldata[2])
			
			elseif ldata[1] == "global-gate" then -- Global gating command
			
				pd.send("phrases-gate", "float", {ldata[2]})
				pd.post("Loaded global GATE value: " .. ldata[2])
			
			elseif ldata[1] == "x" then -- All blank notes
			
				table.insert(notes[key], {-1})
				pd.post("Note " .. #notes[key] .. ": BLANK NOTE (-1)")
			
			elseif ldata[1] == "note" then -- All MIDI commands
			
				table.insert(notes[key], ldata)
				pd.post("Note " .. #notes[key] .. ": " .. table.concat(ldata, " "))
			
			end
		
		end
	
	end
	
	-- Iterate through the collected data, formatting it for transmission to Pd objects
	for i = 1, #notes do
	
		local outtr = {}
		local outn = {}
		
		-- Insert all transference elements into a flat Pd-style list
		for k, v in ipairs(tr[i]) do
			table.insert(outtr, k)
			table.insert(outtr, v)
		end
		
		-- Insert all note elements into a flat Pd-style list
		for _, v in ipairs(notes[i]) do
			for i = 1, #v do
				table.insert(outn, v[i])
			end
		end
		
		-- Send each individual phrase's notes to the sequencer and editor
		self:outlet(1, "float", {i})
		self:outlet(2, "list", outtr)
		self:outlet(3, "list", outn)
	
	end

end



-- Get Monome grid width
function DataIn:in_2_float(f)
	
	self.gridx = f
	
end

-- Get Monome grid height
function DataIn:in_3_float(f)
	
	self.gridy = f
	
end

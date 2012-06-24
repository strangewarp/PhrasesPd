--[[

Data-parsing object, designed for the particular requirements of Phrases-pd.

--]]

local DataStream = pd.Class:new():register("phrases-data-in")



function DataStream:initialize(sel, atoms)
	self.inlets = 2 -- Line-lists from input textfile; key number
	self.outlets = 3 -- Phrase key; transference-list-out; note-list-out
	self.key = 1
	self.tr = {}
	self.notes = {}
	return true
end

-- Take in data lines, and parse them for the main Phrases object
function DataStream:in_1_list(line)

	if line[1] == -50 then -- Phrase divider; send and reset lists
		if #self.tr == 0 then
			self.tr = {5, 5, 10, 0}
		end
		if #self.notes == 0 then -- Insert a dummy note if the phrase is empty, to prevent future infinite loops
			self.notes = {-1}
		end
		self:outlet(1, "float", {self.key})
		self:outlet(2, "list", self.tr)
		self:outlet(3, "list", self.notes)
		self.key = self.key + 1
		self.tr = {}
		self.notes = {}
	elseif line[1] == -3 then -- Transference value
		table.insert(self.tr, line[2])
		table.insert(self.tr, line[3])
	elseif line[1] == -15 then -- Global BPM value
		pd.send("bpm", "float", {line[2]})
		pd.send("bpmin", "float", {line[2]})
	elseif line[1] == -16 then -- Global TPB value
		pd.send("tpb", "float", {line[2]})
		pd.send("tpbin", "float", {line[2]})
	elseif line[1] == -17 then -- Global GATE value
		pd.send("gate", "float", {line[2]})
		pd.send("gatein", "float", {line[2]})
	else -- Regular MIDI commands and/or blank notes
		for _, v in ipairs(line) do
			table.insert(self.notes, v)
		end
	end
	
end

-- Set/reset key number
function DataStream:in_2_float(f)
	self.key = f
end

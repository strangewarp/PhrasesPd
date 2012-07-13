--[[

Data-saving object, designed for the particular requirements of Phrases-pd.

--]]

local DataOut = pd.Class:new():register("phrases-data-out")



function DataOut:initialize(sel, atoms)

	-- 1. Savedata list
	-- 2. Global BPM
	-- 3. Global TPB
	-- 4. Global GATE
	-- 5. Savefile filename
	self.inlets = 5
	
	-- No outlets; everything is sent directly to the savefile by Lua
	self.outlets = 0
	
	-- Placeholders for global song variables
	self.bpm = 120
	self.tpb = 4
	self.gate = 16
	
	self.file = "phrases-default.txt"

	return true

end



-- Send the savedata list, plus global variables, to the active savefile
function DataOut:in_1_list(list)

	local out = "global-bpm " .. self.bpm .. "\n"
	out = out .. "global-tpb " .. self.tpb .. "\n"
	out = out .. "global-gate " .. self.gate .. "\n\n"
	
	-- Format the data-list for the savefile
	while #list > 0 do
	
		if list[1] == -1 then -- Insert a blank-note command
			table.remove(list, 1)
			out = out .. "x\n"
		elseif list[1] == -3 then -- Insert a transference command
			table.remove(list, 1)
			out = out .. "tr " .. table.remove(list, 1) .. " " .. table.remove(list, 1) .. "\n"
		elseif (list[1] >= 0) and (list[1] <= 255) then -- Insert a MIDI-note command
			out = out .. "note " .. table.remove(list, 1) .. " " .. table.remove(list, 1) .. " " .. table.remove(list, 1) .. "\n"
		elseif list[1] == -10 then -- Insert a phrase-end command
			out = out .. "end\n\n"
		else -- Remove unrecognized commands
			table.remove(list, 1)
		end
		
	end
	
	io.output(self.file)
	
	io.write(out)

end



function DataOut:in_2_float(f)
	self.bpm = f
end

function DataOut:in_3_float(f)
	self.tpb = f
end

function DataOut:in_4_float(f)
	self.gate = f
end

function DataOut:in_5_symbol(s)
	self.file = s
end

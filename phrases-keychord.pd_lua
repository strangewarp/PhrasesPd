
local KeyParser = pd.Class:new():register("phrases-keychord")



local commands = require("phrases-keychord-tables")



function KeyParser:initialize(sel, atoms)

	-- 1. A key command in list form, generated by using [pack f s] on the output of [keyname]
	self.inlets = 1
	
	-- 1. Custom commands out
	-- 2. Regular keys out
	self.outlets = 2
	
	self.keysdown = {}
	
	return true

end



function KeyParser:in_1_list(cmd)

	if #cmd[2] >= 3 then
	
		-- Collapse every _L and _R button into the same value (e.g. Shift_L and Shift_R become equivalent)
		local suffix = cmd[2]:sub(#cmd[2] - 1)
		if (suffix == "_L")
		or (suffix == "_R")
		then
			cmd[2] = cmd[2]:sub(1, #cmd[2] - 2)
		end
		
	end

	if cmd[1] == 1 then -- On down-keystrokes, put the keypress into the keysdown table, compute commands, and send out its symbol
	
		if cmd[2] == "Space" then -- Keychord panic command, to flush the keychord array
			self.keysdown = {}
			self:outlet(1, "symbol", {"UPDATE_EDITOR_GUI"})
		end

		self.keysdown[cmd[2]] = cmd[2]
		
		self:outlet(2, "symbol", {cmd[2]})
		
		for k, v in pairs(commands) do
		
			local sendflag = true
			
			-- Reorganize the "v" table to have a comparable layout to the "keysdown" table
			local temptab = {}
			for _, vv in pairs(v) do
				temptab[vv] = vv
			end
			
			-- Ensure that the command is only sent if the contents of "keysdown" are identical to the contents of "temptab"
			for kk, _ in pairs(self.keysdown) do
				if temptab[kk] == nil then
					sendflag = false
				end
			end
			for kk, _ in pairs(temptab) do
				if self.keysdown[kk] == nil then
					sendflag = false
				end
			end
			
			-- If the two tables are identical, send the command and empty all non-modifier keys from the keysdown table
			if sendflag == true then
			
				self:outlet(1, "symbol", {k})
				
				local temptab = self.keysdown
			
				for k, v in pairs(self.keysdown) do
				
					if
					(k ~= "Shift")
					and (k ~= "Ctrl")
					and (k ~= "Alt")
					and (k ~= "Tab")
					then
						temptab[k] = nil
					end
					
				end
				
				self.keysdown = temptab
				
			end
		
		end
		
	elseif self.keysdown[cmd[2]] ~= nil then -- On up-keystrokes, if keysdown[key] isn't nil, remove it from keysdown
	
		self.keysdown[cmd[2]] = nil
		
	end

end

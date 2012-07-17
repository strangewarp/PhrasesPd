--[[

Key-chord-parser object, designed for the particular requirements of PhrasesPd.

--]]

local Parser = pd.Class:new():register("phrases-keychord")



function Parser:initialize(sel, atoms)

	-- Chord-keysrtoke-1
	-- Chord-keystroke-2
	-- Clear-chord bang
	self.inlets = 3
	
	-- Chord-successful bang
	self.outlets = 1
	
	self.c1 = false
	self.c2 = false
	
	return true

end



function Parser:in_1(sel, b)
	self.c1 = true
	if self.c2 == true then
		self:outlet(1, "bang", {})
	end
end

function Parser:in_2(sel, b)
	self.c2 = true
	if self.c1 == true then
		self:outlet(1, "bang", {})
	end
end

function Parser:in_3(sel, b)
	self.c1 = false
	self.c2 = false
end


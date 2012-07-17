--[[

Transference-routing object, designed for the particular requirements of PhrasesPd.

Note: keys are all 1-indexed, for the sake of consistency.

--]]

local Transference = pd.Class:new():register("phrases-tr-route")



function Transference:left(x)
	x = x - 1
	if x <= 0 then
		x = self.width
	end
	return x
end

function Transference:right(x)
	x = x + 1
	if x > self.width then
		x = 1
	end
	return x
end

function Transference:up(y)
	y = y - 1
	if y <= 0 then
		y = self.height
	end
	return y
end

function Transference:down(y)
	y = y + 1
	if y > self.height then
		y = 1
	end
	return y
end

function Transference:initialize(sel, atoms)
	self.inlets = 3 -- Key-and-transfer pairs; grid width; grid height
	self.outlets = 1 -- Transferred key number out
	self.width = 8
	self.height = 8
	self.keys = self.width * self.height
	return true
end

function Transference:in_1_list(keydirs)

	for i = 1, #keydirs, 2 do
	
		local key = keydirs[i] -- Key from which the transference has emerged
		local dir = keydirs[i + 1] -- Transference direction
		local out = 0
		
		-- Break down the original key into x/y coordinates
		local keyx = ((key - 1) % self.width) + 1
		local keyy = math.floor((key - 1) / self.width) + 1
		
		if ((dir - 1) % 3) == 0 then -- All left
			keyx = self.left(keyx)
		elseif (dir % 3) == 0 then -- All right
			keyx = self.right(keyx)
		end
		
		if dir <= 3 then -- All up
			keyy = self.up(keyy)
		elseif dir >= 7 then -- All down
			keyy = self.down(keyy)
		end
		
		-- Rebuild the transference-key out of the modified x/y coordinates
		out = keyx + (self.width * (keyy - 1))
		
		self:outlet(1, "float", {out}) -- Transfer-key number
		
	end
	
end

function Transference:in_2_float(f)
	self.width = f
	self.keys = self.width * self.height
end

function Transference:in_3_float(f)
	self.height = f
	self.keys = self.width * self.height
end

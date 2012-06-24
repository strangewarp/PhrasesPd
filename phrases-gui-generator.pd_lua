--[[

GUI-creation object, designed for the particular requirements of Phrases-pd.

--]]

local GUIGenerator = pd.Class:new():register("phrases-gui-generator")



local function buildObject(title, cx, cy, mx, my, xkey, ykey)

	local obj = {
		"obj", -- Object tag
		(cx + mx) * xkey, -- X-position in pixels
		(cy + my) * ykey, -- Y-position in pixels
		"cnv", -- Canvas tag
		math.min(cx, cy), -- Canvas-box size
		cx, -- Canvas object width in pixels
		cy, -- Canvas object height in pixels
		"empty",
		ykey .. "-" .. xkey .. "-" .. title .. "-button", -- Unique GUI cell name
		"empty",
		1,
		5,
		0,
		10,
		-233017,
		-262144,
		0
	}
	
	return obj
	
end



function GUIGenerator:calcCellSizes()

	-- Grid cell size; X and Y
	self.gridcwidth = math.max(1, math.floor(self.gridpx / self.gridcx) - self.gridmx)
	self.gridcheight = math.max(1, math.floor(self.gridpy / self.gridcy) - self.gridmy)
	
	-- Editor cell size; X and Y
	self.editorcwidth = math.max(1, math.floor(self.editorpx / self.editorcx) - self.editormx)
	self.editorcheight = math.max(1, math.floor(self.editorpy / self.editorcy) - self.editormy)
	
end



function GUIGenerator:initialize(sel, atoms)

	-- GUI-creation bang;
	-- Grid width (cells); grid height (cells); grid width (pixels); grid height (pixels);
	-- Grid margin x (pixels); grid margin y (pixels);
	-- Editor width (notes); editor height (phrases); editor width (pixels); editor height (pixels)
	-- Editor margin x (pixels); editor margin y (pixels)
	self.inlets = 13
	
	-- All GUI data is sent directly to the GUI windows, using pd.send() - thus, no outlets
	self.outlets = 0
	
	-- Grid cell count; X and Y
	self.gridcx = 8
	self.gridcy = 8
	
	-- Grid size in pixels; X and Y
	self.gridpx = 800
	self.gridpy = 800
	
	-- Grid margins; X and Y
	self.gridmx = 2
	self.gridmy = 2
	
	-- Editor cell count; X and Y
	self.editorcx = 6
	self.editorcy = 32
	
	-- Editor size in pixels; X and Y
	self.editorpx = 448
	self.editorpy = 200
	
	-- Editor margins; X and Y
	self.editormx = 1
	self.editormy = 4
	
	self.gridcwidth, self.gridcheight, self.editorcwidth, self.editorcheight = 1, 1, 1, 1
	-- Calculate cell sizes for the grid and editor GUIs
	self:calcCellSizes()

	return true

end



-- Send all GUI elements
function GUIGenerator:in_1_bang()

	local out = {}

	-- Monome grid GUI
	for y = 0, self.gridcy - 1 do
		for x = 0, self.gridcx - 1 do
			out = buildObject(
				"grid",
				self.gridcwidth, self.gridcheight,
				self.gridmx, self.gridmy,
				x, y
			)
			pd.send("phrases-grid-gui-object", "list", out)
			pd.post("Phrases-GUI-Generator: Initialized grid cell " .. out[9])
		end
	end
	
	-- Add gating button to grid window
	out = {
		"obj", -- Object tag
		self.gridpx + self.gridmx, -- X-position in pixels
		self.gridmy, -- Y-position in pixels
		"cnv", -- Canvas tag
		math.min(self.gridcwidth * 1.5, self.gridcheight * 1.5), -- Canvas-box size
		self.gridcwidth * 1.5, -- Canvas object width in pixels
		self.gridcheight * 1.5, -- Canvas object height in pixels
		"empty",
		"phrases-grid-gate-button", -- Unique GUI cell name
		"empty", 20, 12, 0, 14, -233017, -262144, 0
	}
	pd.send("phrases-grid-gui-object", "list", out)
	pd.post("Phrases-GUI-Generator: Initialized grid gating button")
	
	-- Sequence-editor GUI
	for y = 0, self.editorcy - 1 do
		for x = 0, self.editorcx - 1 do
			out = buildObject(
				"editor",
				self.editorcwidth, self.editorcheight,
				self.editormx, self.editormy,
				x, y
			)
			pd.send("phrases-editor-gui-object", "list", out)
			pd.post("Phrases-GUI-Generator: Initialized editor cell " .. out[9])
		end
	end
	
	-- Add toggle button to editor window
	out = {
		"obj", -- Object tag
		self.editorpx + self.editormx, -- X-position in pixels
		self.editormy, -- Y-position in pixels
		"cnv", -- Canvas tag
		math.floor(math.min(self.editorcwidth * 1.5, self.editorcheight * 1.5)), -- Canvas-box size
		self.editorcwidth * 1.5, -- Canvas object width in pixels
		self.editorcheight * 1.5, -- Canvas object height in pixels
		"empty",
		"phrases-editor-toggle-button", -- Unique GUI cell name
		"empty",
		1, 7,
		0,
		math.floor(self.editorcheight * 1.5),
		-233017, -1000000,
		0
	}
	pd.send("phrases-editor-gui-object", "list", out)
	pd.post("Phrases-GUI-Generator: Initialized editor toggle button")

end

function GUIGenerator:in_2_float(n)
	n = math.floor(n)
	self.gridcx = n
	self:calcCellSizes()
end

function GUIGenerator:in_3_float(n)
	n = math.floor(n)
	self.gridcy = n
	self:calcCellSizes()
end

function GUIGenerator:in_4_float(n)
	n = math.floor(n)
	self.gridpx = n
	self:calcCellSizes()
end

function GUIGenerator:in_5_float(n)
	n = math.floor(n)
	self.gridpy = n
	self:calcCellSizes()
end

function GUIGenerator:in_6_float(n)
	n = math.floor(n)
	self.gridmx = n
	self:calcCellSizes()
end

function GUIGenerator:in_7_float(n)
	n = math.floor(n)
	self.gridmy = n
	self:calcCellSizes()
end

function GUIGenerator:in_8_float(n)
	n = math.floor(n)
	self.editorcx = n
	self:calcCellSizes()
end

function GUIGenerator:in_9_float(n)
	n = math.floor(n)
	self.editorcy = n
	self:calcCellSizes()
end

function GUIGenerator:in_10_float(n)
	n = math.floor(n)
	self.editorpx = n
	self:calcCellSizes()
end

function GUIGenerator:in_11_float(n)
	n = math.floor(n)
	self.editorpy = n
	self:calcCellSizes()
end

function GUIGenerator:in_12_float(n)
	n = math.floor(n)
	self.editormx = n
	self:calcCellSizes()
end

function GUIGenerator:in_13_float(n)
	n = math.floor(n)
	self.editormy = n
	self:calcCellSizes()
end

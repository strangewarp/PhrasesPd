--[[

GUI-creation object, designed for the particular requirements of PhrasesPd.

--]]

local GUIGenerator = pd.Class:new():register("phrases-gui-generator")



-- Load data tables for building the GUI's sidepanels
local tab = require("phrases-gui-tables")
local gsnames = tab.gsnames
local esnames = tab.esnames



local function buildObject(xpos, ypos, xsize, ysize, stitle, rtitle, label, labelx, labely, fontnum, fontsize, bgcolor, labelcolor)

	local obj = {
		"obj", -- Object tag
		xpos or 1, -- X-position in pixels
		ypos or 1, -- Y-position in pixels
		"cnv", -- Canvas tag
		math.min(xsize, ysize), -- Selectable box size
		xsize or 20, -- Canvas object width in pixels
		ysize or 20, -- Canvas object height in pixels
		stitle or "empty", -- Name of another object that this object passes its messages onwards to
		rtitle or "empty", -- Object name
		label or "empty", -- Object label
		labelx or 1, -- Label X offset
		labely or 6, -- Label Y offset
		fontnum or 0, -- Label font number
		fontsize or 10, -- Label font size
		bgcolor or -233017, -- Background color
		labelcolor or -262144, -- Label color
		0
	}
	
	return obj
	
end

-- Build a grid of buttons out of a table of object names
local function buildGrid(names, sendto, x, absx, absy, width, height, mx, my, labelx, labely, fsize)

	for k, v in ipairs(names) do
	
		out = buildObject(
			absx + ((width + mx) * ((k - 1) % x)), -- X-position
			absy + ((height + my) * math.floor((k - 1) / x)), -- Y-position
			width, -- Width
			height, -- Height
			_,
			v, -- Addressable object name
			_,
			labelx,
			labely,
			_,
			fsize, -- Font size
			_,
			_,
			_
		)
		
		pd.send(sendto, "list", out)
		pd.post("Phrases-GUI-Generator: Initialized object " .. v)
		
	end
	
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

	-- 1. GUI-creation bang
	-- 2. Grid width (cells)
	-- 3. Grid height (cells)
	-- 4. Grid width (pixels)
	-- 5. Grid height (pixels)
	-- 6. Grid margin x (pixels)
	-- 7. Grid margin y (pixels)
	-- 8. Editor width (cells)
	-- 9. Editor height (cells)
	-- 10. Editor width (pixels)
	-- 11. Editor height (pixels)
	-- 12. Editor margin x (pixels)
	-- 13. Editor margin y (pixels)
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

	-- Generate grid-window background
	buildGrid(
		{"phrases-grid-bg"},
		"phrases-grid-gui-object",
		1,
		0,
		0,
		((self.gridcwidth + self.gridmx) * self.gridcx) + self.gridcwidth + (self.gridmx * 2),
		((self.gridcheight + self.gridmy) * self.gridcy) + self.editormy,
		1,
		1,
		_,
		_,
		_
	)
	
	-- Generate grid-window cells
	local gridnames = {}
	for y = 0, self.gridcy - 1 do
		for x = 0, self.gridcx - 1 do
			table.insert(gridnames, y .. "-" .. x .. "-grid-button")
		end
	end
	buildGrid(
		gridnames, -- List of the object names to make into a grid
		"phrases-grid-gui-object", -- Send generated objects to this object
		self.gridcx, -- X-cells
		self.gridmx, -- Absolute left position
		self.gridmy, -- Absolute top position
		self.gridcwidth, -- Cell width
		self.gridcheight, -- Cell height
		self.gridmx, -- Grid X-margin
		self.gridmy, -- Grid Y-margin
		math.floor(self.gridcwidth / 50), -- Label X-offset
		6, -- Label Y-offset
		self.gridcheight -- Font size
	)

	-- Generate gate-window side-panel
	buildGrid(
		gsnames,
		"phrases-grid-gui-object",
		1,
		((self.gridcwidth + self.gridmx) * self.gridcx) + self.gridmx,
		self.gridmy,
		self.gridcwidth,
		self.gridcheight,
		self.gridmx,
		self.gridmy,
		math.floor(self.gridcwidth / 50),
		6,
		math.floor(self.gridcheight * 1.5)
	)

	-- Generate editor-window background
	buildGrid(
		{"phrases-editor-bg"},
		"phrases-editor-gui-object",
		1,
		0,
		0,
		((self.editorcwidth + self.editormx) * self.editorcx) + (self.editorcwidth * 1.5) + (self.editormx * 2),
		((self.editorcheight + self.editormy) * self.editorcy) + self.editormy,
		1,
		1,
		_,
		_,
		_
	)
	
	-- Generate editor-window cells
	local editornames = {}
	for y = 0, self.editorcy - 1 do
		for x = 0, self.editorcx - 1 do
			table.insert(editornames, y .. "-" .. x .. "-editor-button")
		end
	end
	buildGrid(
		editornames,
		"phrases-editor-gui-object",
		self.editorcx,
		self.editormx,
		self.editormy,
		self.editorcwidth,
		self.editorcheight,
		self.editormx,
		self.editormy,
		math.floor(self.editorcwidth / 50),
		6,
		self.editorcheight
	)
	
	-- Generate editor-window side-panel
	buildGrid(
		esnames,
		"phrases-editor-gui-object",
		1,
		((self.editorcwidth + self.editormx) * self.editorcx) + self.editormx,
		self.editormy,
		self.editorcwidth * 1.5,
		self.editorcheight * 2,
		self.editormx,
		self.editormy,
		math.floor(self.editorcwidth / 50),
		8,
		math.floor(self.editorcheight * 1.5)
	)

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

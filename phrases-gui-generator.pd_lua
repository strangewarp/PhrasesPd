
local GUIGenerator = pd.Class:new():register("phrases-gui-generator")



-- Load data tables for building the GUI's sidepanels
local tab = require("phrases-gui-tables")
local gsnames = tab.gsnames
local esnames = tab.esnames
local hseatnames = tab.hseatnames



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
	-- 2. Preferences list
	self.inlets = 2
	
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
	
	-- Number of ADC buttons
	self.adcnum = 2
	
	-- ADC cell sizes; X and Y
	self.adccwidth = 50
	self.adccheight = 50
	
	-- ADC tile margins; X and Y
	self.adcmx = 5
	self.adcmy = 5
	
	-- Editor cell count; X and Y
	self.editorcx = 6
	self.editorcy = 32
	
	-- Editor size in pixels; X and Y
	self.editorpx = 448
	self.editorpy = 200
	
	-- Editor margins; X and Y
	self.editormx = 1
	self.editormy = 4
	
	self.gridcwidth, self.gridcheight,
	self.editorcwidth, self.editorcheight = 1, 1, 1, 1
	-- Calculate cell sizes for the grid and editor GUIs
	self:calcCellSizes()

	return true

end



-- Send all GUI elements
function GUIGenerator:in_1_bang()

	-- Create name-list for ADC tiles
	local adcnames = {}
	if self.adcnum >= 1 then
		for i = 1, self.adcnum do
			table.insert(adcnames, i .. "-adc-button")
		end
	end

	-- Generate grid-window background
	buildGrid(
		{"phrases-grid-bg"},
		"phrases-grid-gui-object",
		1,
		0,
		0,
		((self.gridcwidth + self.gridmx) * self.gridcx) + self.gridmx + math.max(self.gridcwidth + self.gridmx, self.adccwidth + self.adcmx),
		math.max(
			((self.gridcheight + self.gridmy) * self.gridcy) + self.gridmy, -- Height of main grid
			self.gridcheight + self.gridcy + ((self.adccheight + self.adcmy) * #adcnames) -- Total sidebar height
		),
		1,
		1,
		_,
		_,
		_
	)
	
	-- Generate grid-window cells
	local gridnames = {}
	local subgrids = {}
	for y = 0, self.gridcy - 1 do
	
		subgrids[y] = {}
	
		for x = 0, self.gridcx - 1 do
		
			subgrids[y][x] = {}
			
			local buttonname = y .. "-" .. x .. "-grid"
			
			table.insert(gridnames, buttonname .. "-button")
			
			for subnum = 1, 9 do
				table.insert(subgrids[y][x], buttonname .. "-sub-" .. subnum)
			end
		
		end
		
	end
	
	-- Build main grid cells
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
		math.floor(self.gridcwidth / 8), -- Label X-offset
		math.floor(self.gridcheight / 2), -- Label Y-offset
		self.gridcheight -- Font size
	)
	
	-- Build sub-cells
	for y, v in pairs(subgrids) do
		for x, names in pairs(v) do
			buildGrid(
				names,
				"phrases-grid-gui-object",
				3,
				((self.gridmx + self.gridcwidth) * x) + self.gridmx,
				((self.gridmy + self.gridcheight) * y) + self.gridmy,
				math.floor(self.gridcwidth / 5),
				math.floor(self.gridcheight / 5),
				math.ceil(self.gridcwidth / 5),
				math.ceil(self.gridcheight / 5),
				0,
				0,
				12
			)
		end
	end

	-- Generate first grid-window side-panel (GATING)
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
		_,
		_,
		_
	)

	-- Generate second grid-window side-panel (ADCs)
	buildGrid(
		adcnames,
		"phrases-grid-gui-object",
		1,
		((self.gridcwidth + self.gridmx) * self.gridcx) + self.adcmx,
		self.gridcheight + self.gridmy + self.adcmy,
		self.adccwidth,
		self.adccheight,
		self.adcmx,
		self.adcmy,
		_,
		_,
		_
	)
	
	-- Generate editor-window background
	buildGrid(
		{"phrases-editor-bg"},
		"phrases-editor-gui-object",
		1,
		0,
		0,
		((self.editorcwidth + self.editormx) * (self.editorcx + 2)) + self.editormx,
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
		self.editorcwidth,
		self.editorcheight,
		self.editormx,
		self.editormy,
		math.floor(self.editorcwidth / 50),
		6,
		self.editorcheight
	)
	
	-- Generate editor-window hotseat-panel
	buildGrid(
		hseatnames,
		"phrases-editor-gui-object",
		1,
		((self.editorcwidth + self.editormx) * (self.editorcx + 1)) + self.editormx,
		self.editormy,
		self.editorcwidth,
		self.editorcheight,
		self.editormx,
		self.editormy,
		math.floor(self.editorcwidth / 50),
		6,
		self.editorcheight
	)

end

function GUIGenerator:in_2_list(n)

	self.gridcx = n[1]
	self.gridcy = n[2]
	
	self.adcnum = n[3]
	
	self.gridpx = n[7]
	self.gridpy = n[8]
	self.gridmx = n[9]
	self.gridmy = n[10]
	
	self.adccwidth = n[11]
	self.adccheight = n[12]
	self.adcmx = n[13]
	self.adcmy = n[14]
	
	self.editorcx = n[15]
	self.editorcy = n[16]
	self.editorpx = n[17]
	self.editorpy = n[18]
	self.editormx = n[19]
	self.editormy = n[20]
	
	self:calcCellSizes()
	
end

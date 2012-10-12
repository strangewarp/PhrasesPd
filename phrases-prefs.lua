
return {

	gui = {
	
		grid = { -- Grid GUI window
			xpixels = 400, -- Width (in pixels)
			ypixels = 400, -- Height (in pixels)
			xmargin = 3, -- Horizontal margins (in pixels)
			ymargin = 3, -- Vertical margins (in pixels)
		},
		
		editor = { -- Editor GUI window
			columns = 4, -- Number of GUI columns
			rows = 32, -- Number of GUI rows
			xpixels = 560, -- Width (in pixels)
			ypixels = 400, -- Height (in pixels)
			xmargin = 2, -- Horizontal margins (in pixels)
			ymargin = 1, -- Vertical margins (in pixels)
		},
	
		colors = { -- GUI colors, arranged as such: {R, G, B}
			{180, 50, 50}, -- Editor BG 1
			{50, 50, 180}, -- Editor BG 2
			{40, 40, 40}, -- Editor BG 3
			{230, 250, 230}, -- Editor Labels
			{20, 255, 20}, -- Grid BG 1 (main color 1)
			{30, 30, 230}, -- Grid BG 2 (main color 2)
			{250, 30, 30}, -- Grid BG 3 (transference)
			{120, 120, 120}, -- Grid BG 4 (neutral)
		},
		
	},
	
	dirs = {
	
		savedir = "C:/Users/Christian/My Documents/pd/test/", -- Directory for savefiles
	
	},

	monome = {
	
		width = 8, -- Monome width (in buttons)
		height = 8, -- Monome height (in buttons)
		
		osctype = 0, -- 0 for MonomeSerial; 1 for serialosc
		osclisten = 8000, -- OSC listen port
		oscsend = 8080, -- OSC send port
	
	},

}


return {

	dirs = {
	
		savedir = "C:/Users/Christian/My Documents/MUSIC_STAGING/", -- Directory for savefiles
	
	},

	monome = {
	
		width = 8, -- Monome width (in buttons)
		height = 8, -- Monome height (in buttons)
		
		adcnum = 4, -- Total number of ADCs on the Monome
		
		osctype = 0, -- 0 for MonomeSerial; 1 for serialosc
		osclisten = 8000, -- OSC listen port
		oscsend = 8080, -- OSC send port
	
	},

	gui = {
	
		grid = { -- Grid GUI window
		
			xpixels = 600, -- Width (in pixels)
			ypixels = 600, -- Height (in pixels)
			xmargin = 3, -- Horizontal margins (in pixels)
			ymargin = 3, -- Vertical margins (in pixels)
			
		},
		
		adc = {
			xpixels = 42, -- Width of each ADC tile
			ypixels = 42, -- Height of each ADC tile
			xmargin = 10, -- Horizontal margins (in pixels)
			ymargin = 10, -- Vertical margins (in pixels)
		},
		
		editor = { -- Editor GUI window
		
			columns = 5, -- Number of GUI columns
			rows = 48, -- Number of GUI rows
			xpixels = 720, -- Width (in pixels)
			ypixels = 648, -- Height (in pixels)
			xmargin = 2, -- Horizontal margins (in pixels)
			ymargin = 1, -- Vertical margins (in pixels)
			
		},
	
		colors = { -- GUI colors, arranged as such: {R, G, B}
		
			{180, 50, 50}, -- Editor BG 1
			{50, 50, 180}, -- Editor BG 2
			{40, 40, 40}, -- Editor BG 3
			{230, 250, 230}, -- Editor Labels
			{100, 0, 20}, -- Grid BG 1 (main color 1)
			{200, 255, 250}, -- Grid BG 2 (main color 2)
			{250, 30, 30}, -- Grid BG 3 (transference)
			{120, 120, 120}, -- Grid BG 4 (neutral)
			
		},
		
	},
	
}

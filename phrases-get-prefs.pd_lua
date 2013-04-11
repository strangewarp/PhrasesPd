
local GetPrefs = pd.Class:new():register("phrases-get-prefs")



function GetPrefs:initialize(sel, atoms)

	-- 1. Bang, upon which the object grabs user-preferences from phrases-prefs.lua
	self.inlets = 1
	
	-- All outbound data is sent with pd.send()
	self.outlets = 0
	
	-- Placeholder for the user-preferences table
	self.prefs = {}
	
	return true

end



function GetPrefs:in_1_bang()

	-- Load user-prefs file
	self.prefs = self:dofile("phrases-prefs.lua")
	
	-- Send user-prefs to the relevant Pd receptors
	
	pd.send(
		"phrases-prefs-in",
		"list",
		{
		
			self.prefs.monome.width,
			self.prefs.monome.height,
			self.prefs.monome.adcnum,
			self.prefs.monome.osctype,
			self.prefs.monome.osclisten,
			self.prefs.monome.oscsend,
			
			self.prefs.gui.grid.xpixels,
			self.prefs.gui.grid.ypixels,
			self.prefs.gui.grid.xmargin,
			self.prefs.gui.grid.ymargin,
			
			self.prefs.gui.adc.xpixels,
			self.prefs.gui.adc.ypixels,
			self.prefs.gui.adc.xmargin,
			self.prefs.gui.adc.ymargin,
			
			self.prefs.gui.editor.columns,
			self.prefs.gui.editor.rows,
			self.prefs.gui.editor.xpixels,
			self.prefs.gui.editor.ypixels,
			self.prefs.gui.editor.xmargin,
			self.prefs.gui.editor.ymargin,
			
			self.prefs.dirs.savedir, -- Savedir must be listed last, due to later use of table.concat to clarify spaces in dirnames
			
		}
	)
	
	for k, v in ipairs(self.prefs.gui.colors) do
		table.insert(v, 1, k)
		pd.post("User-defined GUI color: " .. table.concat(v, " "))
		pd.send("phrases-gui-color-list", "list", v)
	end
	
end

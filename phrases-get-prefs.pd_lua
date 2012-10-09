
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
	
	pd.post("User-defined savefile path: " .. self.prefs.dirs.savedir)
	
	pd.send("phrases-save-path-in", "list", {self.prefs.dirs.savedir})
	
	pd.post("User-defined Monome size: Width " .. self.prefs.monome.width .. ", Height " .. self.prefs.monome.height)
	
	pd.send("phrases-monome-x", "float", {self.prefs.monome.width})
	pd.send("phrases-monome-y", "float", {self.prefs.monome.height})
	
	pd.post("User-defined OSC ports: Listen " .. self.prefs.monome.osclisten .. ", Send " .. self.prefs.monome.oscsend)
	if self.prefs.monome.osctype == 0 then
		pd.post("Serial protocol: MonomeSerial")
	else
		pd.post("Serial protocol: serialosc")
	end
	
	pd.send("phrases-osc-serial-type", "float", {self.prefs.monome.osctype})
	pd.send("phrases-osc-in-port", "float", {self.prefs.monome.osclisten})
	pd.send("phrases-osc-out-port", "float", {self.prefs.monome.oscsend})
	
	pd.post("User-defined grid GUI: X-pixels " .. self.prefs.gui.grid.xpixels .. ", Y-pixels " .. self.prefs.gui.grid.ypixels)
	pd.post("User-defined grid GUI: X-margin " .. self.prefs.gui.grid.xmargin .. ", Y-margin " .. self.prefs.gui.grid.ymargin)
	
	pd.send("phrases-grid-pixelsx", "float", {self.prefs.gui.grid.xpixels})
	pd.send("phrases-grid-pixelsy", "float", {self.prefs.gui.grid.ypixels})
	pd.send("phrases-grid-marginx", "float", {self.prefs.gui.grid.xmargin})
	pd.send("phrases-grid-marginy", "float", {self.prefs.gui.grid.ymargin})
	
	pd.post("User-defined editor GUI: X-cells " .. self.prefs.gui.editor.columns .. ", Y-cells " .. self.prefs.gui.editor.rows)
	pd.post("User-defined editor GUI: X-pixels " .. self.prefs.gui.editor.xpixels .. ", Y-pixels " .. self.prefs.gui.editor.ypixels)
	pd.post("User-defined editor GUI: X-margin " .. self.prefs.gui.editor.xmargin .. ", Y-margin " .. self.prefs.gui.editor.ymargin)
	
	pd.send("phrases-editor-cellsx", "float", {self.prefs.gui.editor.columns})
	pd.send("phrases-editor-cellsy", "float", {self.prefs.gui.editor.rows})
	pd.send("phrases-editor-pixelsx", "float", {self.prefs.gui.editor.xpixels})
	pd.send("phrases-editor-pixelsy", "float", {self.prefs.gui.editor.ypixels})
	pd.send("phrases-editor-marginx", "float", {self.prefs.gui.editor.xmargin})
	pd.send("phrases-editor-marginy", "float", {self.prefs.gui.editor.ymargin})
	
	for k, v in ipairs(self.prefs.gui.colors) do
		table.insert(v, 1, k)
		pd.post("User-defined GUI color: " .. table.concat(v, " "))
		pd.send("phrases-gui-color-list", "list", v)
	end
	
end

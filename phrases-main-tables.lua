
return {

	-- Buttons that are used in the editor as a computer-keyboard-piano, indexed by the notes they represent.
	kbnames = {
		"z", "s", "x", "d", "c", "v", "g", "b", "h", "n", "j", "m",
		{",", "q"},
		{"l", "2"},
		"w",
		"3",
		"e",
		"r", "5", "t", "6", "y", "7", "u", "i", "9", "o", "0", "p",
	},

	-- Build a hashmap of keyboard-keys and MIDI-offset values, for the computer-keyboard section of the editor
	kbhash = function(names)
	
		local hash = {}
		
		for k, v in ipairs(names) do
			if #v > 1 then
				for _, vv in pairs(v) do
					hash[vv] = k - 1
				end
			else
				hash[v] = k - 1
			end
		end
		
		return hash
		
	end,

	-- Table of user-readable note values, indexed appropriately
	-- Pd keeps the pound sign (#) as a reserved character, and throws in a glut of annoying backslashes if any pound signs are passed to its parser, so we'll just use flats for now.
	notenames = {
		"C",
		"Db",
		"D",
		"Eb",
		"E",
		"F",
		"Gb",
		"G",
		"Ab",
		"A",
		"Bb",
		"B",
	},

	-- Holds the command-types that the user toggles between, and which when active are held in self.command
	cmdtable = {
		-2, -- Global BPM
		-3, -- Global TPB
		-4, -- Global GATE
		-5, -- Local BPM
		-6, -- Local TPB
		-7, -- Local GATE
		128, -- MIDI NOTE-OFF
		144, -- MIDI NOTE-ON
		160, -- MIDI poly-key pressure
		176, -- MIDI control change
		192, -- MIDI program change
		208, -- MIDI mono-key pressure
		224, -- MIDI pitch bend
		240, -- MIDI system message
	},

	-- MIDI command names, condensed to fit in the GUI
	cmdnames = {
		"GlobalBPM",
		"GlobalTPB",
		"GlobalGATE",
		"LocalBPM",
		"LocalTPB",
		"LocalGATE",
		"NOTE-OFF",
		"NOTE-ON",
		"PolyPress",
		"CtrlChange",
		"ProgChange",
		"MonoPress",
		"PitchBend",
		"System",
	},
	
	-- Table of transference direction names, to make the GUI's transference-mode friendlier
	trnames = {
		"Up-Left",
		"Up",
		"Up-Right",
		"Left",
		"Stationary",
		"Right",
		"Down-Left",
		"Down",
		"Down-Right",
		"Persistence",
	},
	
	-- Table of MIDI-input catching modes, which are tabbed through by the user and acted upon by other code
	catchtypes = {
		"all",
		"no-offs",
		"notes",
		"ignore",
	},

	-- Table of the various input modes, which are toggled by the user and acted upon by other code
	modenames = {
		"note",
		"tr",
	},
	
	directions = {
		"1",
		"2",
		"3",
		"4",
		"",
		"6",
		"7",
		"8",
		"9",
	},
	
}

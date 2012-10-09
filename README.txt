
WARNING PRE-ALPHA

MOST FEATURES ARE ONLY MINIMALLY TESTED

Feel free to play around with the PhrasesPd editor and sequencer. If you are using PhrasesPd in a mission-critical capacity, please double-check everything you want to do in advance, in order to avoid potential unforeseen bugs.



TO-DO LIST (in rough order of desired implementation):

* Debugging: Sequencer
* --- Alpha Release Goes Here ---
* Rewrite code: Rewrite the grid GUI and all of its handlers so that each cell contains 8 sub-cells along its borders, in order to better display active transference.
* Add feature: Customizable ADC settings that can be linked to MIDI values. (User-definable in savefiles. Number of ADCs defined in the user-prefs table file.) (Feature modeled after MidiFling)
* Add feature: MIDI-CLOCK capabilities.
* Refactoring: Shunt as many functions as possible into Lua table files, and require said files into the relevant pdlua objects.
* Refactoring: Replace laggy mechanisms with pre-generated variables wherever possible.
* --- Beta Release Goes Here ---



PhrasesPd

PhrasesPd is a MIDI sequencer, for arbitrarily-sized grid controllers capable of using the Monome OSC communications format.

It has an integrated sequence editor, which is controlled by a combination of computer keyboard, MIDI controller, and grid controller.

Sequences are saved as Lua table files, in a manner that is both executable and decently human-readable. In the future, this may change to a different standardized format, but if so I'll write a converter.



Dependencies:
Puredata-extended 0.43-1 beta



Quick-Start Guide:

1. Put the following files into your /pd/extra directory:
phrases-editor-and-sequencer.pd_lua
phrases-get-prefs.pd_lua
phrases-gui-generator.pd_lua
phrases-gui-tables.lua
phrases-keychord.pd_lua
phrases-keychord-tables.lua
phrases-main-tables.lua

2. Place the following files in the same directory as one another:
phrases-hotseats.lua
phrases-makecolor.pd
phrases-prefs.lua
phrasespd.pd
The directory itself can be wherever, but preferably somewhere convenient in your directory structure, as your savefiles will be loaded from within the same directory (or a subdirectory, if you specify so).

3. Change the settings to reflect your setup and directory structure, by modifying the contents of phrases-prefs.lua.

4. Run "phrasespd.pd" in PureData.

5. Change the Puredata MIDI settings to reflect your default MIDI-IN and MIDI-OUT devices. Remember: This must be done every time Puredata is newly opened.

6. You can now begin assembling phrases of MIDI data in the PhrasesPd editor, and playing them with your Monome.

7. To save your song data: Click the "Custom Savefile" box, type in the desired filename, and hit Enter. Then, to save your data there, type Shift-?-|.

8. To change the default loadfile hotseats, edit the contents of "phrases-hotseats.lua".



Editor Commands (default keystrokes)

Choose savefile name - Click a savefile hotseat in the main phrasespd.pd window
Save file - Shift-?-|

Choose loadfile name - Shift-[number], Shift-BackSpace-[number], or click a loadfile hotseat in the main phrasespd.pd window
Load file - Shift-Backspace-Enter (WARNING: Erases any unsaved changes)

Toggle Recording/Play modes - Esc

Previous note - Up arrow
Next note - Down arrow
First note - Home
Opposite note - End
Page up - PageUp
Page down - PageDown

Insert note - zsxdcvgbhnjm,lq2w3er5t6y7ui9o0p

Delete note - Delete
Insert blank note - Backspace

Previous phrase - Left arrow
Next phrase - Right arrow

Increase spacing - Shift-Up
Decrease spacing - Shift-Down

Toggle between MIDI-Catch modes - Shift-O and Shift-P

MIDI channel +1 - '
MIDI channel -1 - ;

MIDI velocity +1 - =
MIDI velocity -1 - -
MIDI velocity +10 - +
MIDI velocity -10 - _

Octave +1 - ]
Octave -1 - [

Next command type - /
Previous command type - .

Toggle input mode - Insert
Toggle number/pitch modes - Enter

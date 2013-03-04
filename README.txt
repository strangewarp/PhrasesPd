
WARNING ALPHA

MOST FEATURES ARE ONLY MINIMALLY TESTED

Feel free to play around with the PhrasesPd editor and sequencer. If you are using PhrasesPd in a mission-critical capacity, please double-check everything you want to do in advance, in order to avoid potential unforeseen bugs.



PhrasesPd

PhrasesPd is a MIDI sequencer, for arbitrarily-sized grid controllers capable of using the Monome OSC communications format.

It has an integrated sequence editor, which is controlled by a combination of computer keyboard, MIDI controller, and grid controller.

Song data is saved as Lua table files, in a manner that is both executable and decently human-readable.



Dependencies:
Puredata-extended 0.43.4



TO-DO LIST (in rough order of desired implementation):

* Refactoring: Replace nooby table-copy mechanisms with the more robust deepCopy function
* Add feature: ADC note-shifting capabilities, plus editor panel
* --- Beta Release Goes Here ---



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
default.lua
phrases-hotseats.lua
phrases-makecolor.pd
phrases-prefs.lua
phrasespd.pd
The directory itself can be wherever, but preferably somewhere convenient in your directory structure, as your savefiles will be loaded from within the same directory (or a subdirectory, if you specify so).

3. Modify the contents of "phrases-prefs.lua" to reflect your setup and directory structure.

4. Change the Puredata MIDI settings to reflect your default MIDI-IN and MIDI-OUT devices.

5. Run "phrasespd.pd" in PureData.

6. You can now begin assembling phrases of MIDI data in the PhrasesPd editor, and playing them with your Monome.

7. To save your song data: Click the "Custom Savefile" box, type in the desired filename, and hit Enter. Then, to save your data there, type Shift-?-|.

8. To change the default loadfile hotseats, edit the contents of "phrases-hotseats.lua".



Editor Commands (default keystrokes):

Choose savefile name - Enter a custom savefile name in the main phrasespd.pd window
Save file - Shift-?-|

Choose loadfile name - Shift-[number], Shift-BackSpace-[number], or enter a custom loadfile name in the main phrasespd.pd window
Load file - Shift-Tab-Enter (WARNING: Erases any unsaved changes)

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

Undo - Shift-Tab-Z
Redo - Shift-Tab-Y

Previous phrase - Left arrow
Next phrase - Right arrow

Increase spacing - Shift-Up
Decrease spacing - Shift-Down

Toggle between MIDI-Catch modes - Shift-O and Shift-P

MIDI channel +1 - '
MIDI channel -1 - ;

Default MIDI velocity +1 - =
Default MIDI velocity -1 - -
Default MIDI velocity +10 - +
Default MIDI velocity -10 - _

Move active note back by default velocity value - Shift-Q
Move active note forward by default velocity value - Shift-W
Move all notes in active phrase back by default velocity value - Shift-E
Move all notes in active phrase forward by default velocity value - Shift-R

Shift active note-byte down by default velocity value - Shift-A
Shift active note-byte up by default velocity value - Shift-S

Shift all note-bytes in phrase down by default velocity value - Shift-D
Shift all note-bytes in phrase up by default velocity value - Shift-F

Shift active velocity byte down by default velocity value - Shift-Z
Shift active velocity byte up by default velocity value - Shift-X

Shift all velocity-bytes in phrase down by default velocity value - Shift-C
Shift all velocity-bytes in phrase up by default velocity value - Shift-V

Add note-offs to active phrase - Shift-Tab-A
Add note-offs to active phrase based on spacing value - Shift-Tab-S

Octave +1 - ]
Octave -1 - [

Next command type - /
Previous command type - .

Toggle input mode - Insert
Toggle number/pitch modes - Enter

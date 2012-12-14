
WARNING ALPHA

MOST FEATURES ARE ONLY MINIMALLY TESTED

Feel free to play around with the PhrasesPd editor and sequencer. If you are using PhrasesPd in a mission-critical capacity, please double-check everything you want to do in advance, in order to avoid potential unforeseen bugs.



PhrasesPd

PhrasesPd is a MIDI sequencer, for arbitrarily-sized grid controllers capable of using the Monome OSC communications format.

It has an integrated sequence editor, which is controlled by a combination of computer keyboard, MIDI controller, and grid controller.

Song data is saved as Lua table files, in a manner that is both executable and decently human-readable.



Dependencies:
Puredata-extended 0.43-1 beta



TO-DO LIST (in rough order of desired implementation):

* Compatibility: Ensure that PhrasesPd is compatible with the final version of Pd-extended 0.43, once Pd-extended 0.43 is out of beta.
* Debugging: Figure out what's causing lag spikes on weak computers when a phrase with multiple dangling sustains is deactivated. (This can be alleviated by dilligent use of closing NOTE-OFF commands for every NOTE-ON)
* Add feature: ADC capabilities, plus editor panel.
* Add feature: MIDI-CLOCK capabilities.
* Refactoring: Shunt as many functions as possible into Lua table files, and require said files into the relevant pdlua objects.
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

3. Change the settings to reflect your setup and directory structure, by modifying the contents of "phrases-prefs.lua".

4. Run "phrasespd.pd" in PureData.

5. Change the Puredata MIDI settings to reflect your default MIDI-IN and MIDI-OUT devices. Remember: This must be done every time Puredata is newly opened.

6. You can now begin assembling phrases of MIDI data in the PhrasesPd editor, and playing them with your Monome.

7. To save your song data: Click the "Custom Savefile" box, type in the desired filename, and hit Enter. Then, to save your data there, type Shift-?-|.

8. To change the default loadfile hotseats, edit the contents of "phrases-hotseats.lua".



Editor Commands (default keystrokes)

Choose savefile name - Enter a custom savefile name in the main phrasespd.pd window
Save file - Shift-?-|

Choose loadfile name - Shift-[number], Shift-BackSpace-[number], or enter a custom loadfile name in the main phrasespd.pd window
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

Octave +1 - ]
Octave -1 - [

Next command type - /
Previous command type - .

Toggle input mode - Insert
Toggle number/pitch modes - Enter


WARNING PRE-ALPHA

MOST FEATURES ARE BUGGY, MINIMALLY/UNTESTED, OR MISSING

IF YOU TRY USING THIS FOR ANYTHING RIGHT NOW, YOU ARE BEING SILLY

IF YOU TRY USING THE SEQUENCER, IT /WILL/ BREAK IMMEDIATELY

Please note: Currently, only the PhrasesPd Editor is functional. Feel free to play around with it! I still have to debug the PhrasesPd Sequencer. It's based on code I've written before in another language, so it probably won't take too long.



TO-DO LIST (in rough order of desired implementation):

* Thorough Debugging: Sequencer
* --- Alpha Release Goes Here ---
* Add feature: MIDI-CLOCK capabilities.
* Refactoring: Shunt as many functions as possible into Lua table files, and require said files into the relevant pdlua objects.
* Refactoring: Replace laggy loops with pre-generated tables wherever possible.
* --- Beta Release Goes Here ---



PhrasesPd

PhrasesPd is a MIDI sequencer, for arbitrarily-sized grid controllers capable of using the Monome OSC communications format.

It has an integrated sequence editor, which is controlled by a combination of computer keyboard, MIDI controller, and grid controller.

Sequences are saved as Lua table files, in a manner that is both executable and decently human-readable. In the future, this may change to a different standardized format, but if so I'll write a converter.



Dependencies:
Puredata-extended 0.43-1 beta



Installation

1. Put all of PhrasesPd's .pd_lua and .lua files (EXCEPT FOR "phrases-hotseats.lua") into your /pd/extra directory.
2. Make sure all of PhrasesPd's .pd files, plus "phrases-hotseats.lua", are in the same directory as one another. The directory itself can be wherever, but preferably somewhere convenient in your directory structure, as your savefiles will be loaded from within the same directory (or a subdirectory, if you specify so).
3. Run "phrasespd.pd" in PureData.
4. Change the settings to reflect your setup and directory structure, by clicking the "phrases-prefs" and "phrases-gui-prefs" subpatches, toggling into Puredata edit mode (Ctrl+E), and editing their hardcoded variables.
5. Save your custom variables (Ctrl+S), and then close and reopen phrasespd.pd.
6. Change the Puredata MIDI settings to reflect your default MIDI-IN and MIDI-OUT devices. Remember: This must be done every time Puredata is newly opened.
7. Toggle into Puredata edit mode (Ctrl+E) to change the filenames in your savefile and loadfile hotseats, and then toggle back out of edit mode (Ctrl+E again) to click them. (You can save your hotseat configuration at any time with Ctrl+S. No restart required.) Clicking a hotseat will select that savefile or loadfile name. Remember: If these point to a subdirectory, that subdirectory must be made manually before attempting to save or load therein.
8. You can now begin assembling phrases of MIDI data in the PhrasesPd editor, and playing them with your Monome.



Editor Commands

Choose savefile name - Click a savefile hotseat in the main phrasespd.pd window
Save file - Shift-?-|

Choose loadfile name - Shift-[number], Shift-BackSpace-[number], OR click a loadfile hotseat in the main phrasespd.pd window
Load file - Shift-Backspace-Enter (WARNING: Erases any unsaved changes)

Toggle Recording/Play modes - Esc

Previous note - Up arrow
Next note - Down arrow
First note - Home
Last note - End

Insert note - zsxdcvgbhnjm,lq2w3er5t6y7ui9o0p

Delete note - Delete
Insert blank note - Backspace

Previous phrase - Left arrow
Next phrase - Right arrow

Increase spacing - PageDown
Decrease spacing - PageUp

Toggle between MIDI-Catch modes - Shift-O and Shift-P

MIDI channel +1 - '
MIDI channel -1 - ;

MIDI velocity +1 - =
MIDI velocity -1 - -
MIDI velocity +10 - +
MIDI velocity -10 - _

Octave +1 - ]
Octave -1 - [

Next command - /
Previous command - .

Toggle input mode - Insert
Toggle number/pitch modes - Enter


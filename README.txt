
WARNING PRE-ALPHA

MOST FEATURES ARE BUGGY, MINIMALLY/UNTESTED, OR MISSING

IF YOU TRY USING THIS FOR ANYTHING RIGHT NOW, YOU ARE BEING SILLY

Do please note: Currently, only the PhrasesPd Editor is functional. Feel free to play around with it! I still have to rewrite and debug the PhrasesPd Sequencer in Lua. But since the sequencer is heavily derived from code I've already written and rewritten several times in another language, it ought to go moderately quickly.



PhrasesPd

PhrasesPd is a MIDI sequencer, for arbitrarily-sized grid controllers capable of using the Monome OSC communications format.

It has an integrated sequence editor, which is controlled by a combination of computer keyboard, MIDI controller, and grid controller.

Sequences are saved as Lua table files, in a manner that is both executable and decently human-readable. In the future, this may change to YAML or JSON or something, but if so I'll write a converter.



Dependencies:
Puredata-extended 0.43-1 beta
pdlua
mrpeach



Installation

1. Put all of PhrasesPd's .pd_lua and .lua files into your /pd/extra folder.
2. Make sure all of PhrasesPd's .pd files are in the same folder as one another. The directory itself can be wherever, but preferably somewhere convenient in your directory structure, as your savefiles will be loaded from within the same folder (or a sub-folder, if you specify so).
3. Run "phrasespd.pd" in PureData.
4. Change the settings to reflect your setup, in the phrases-prefs and phrases-gui-prefs windows.
5. You can now begin assembling phrases of MIDI data in the PhrasesPd editor.



Editor Commands

Choose savefile name - Click a savefile hotseat in the main window
Save file - Shift-?-|

Reload most recent file - Shift-Esc-Enter (WARNING: Erases any changes)
Load file - Click a loadfile hotseat in the main window

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


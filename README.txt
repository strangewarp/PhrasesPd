
WARNING PRE-ALPHA

MOST FEATURES ARE BUGGY, MINIMALLY/UNTESTED, OR MISSING

IF YOU TRY USING THIS FOR ANYTHING RIGHT NOW, YOU ARE BEING SILLY

Do please note: Currently, only the PhrasesPd Editor is functional. Feel free to play around with it! I still have to rewrite and debug the PhrasesPd Sequencer in Lua, and write all the MIDI/OSC connectors in Pd. But since the sequencer is heavily derived from code I've already written and rewritten several times in another language, it ought to go moderately quickly.



PhrasesPd

PhrasesPd is a MIDI sequencer, for arbitrarily-sized grid controllers capable of using the Monome OSC communications format.

It has an integrated sequence editor, which is controlled by a combination of computer keyboard, MIDI controller, and grid controller.

Sequences are saved as Lua table files, in a manner that is both executable and decently human-readable. In the future, this may change to YAML or JSON or something, but if so I'll write a converter.



Dependencies:
Puredata-extended 0.43-1 beta



Installation

1. Put all of PhrasesPd's .pd_lua and .lua files into your /pd/extra folder.
2. Make sure all of PhrasesPd's .pd files are in the same folder as one another. The directory itself can be wherever, but preferably somewhere convenient in your directory structure, as your savefiles will be loaded from within the same folder (or a sub-folder, if you specify so).
3. Run "phrasespd.pd" in PureData.
4. Change the settings to reflect your setup, in the phrases-prefs and phrases-gui-prefs windows.
5. You can now begin assembling phrases of MIDI data in the PhrasesPd editor.



Editor Commands


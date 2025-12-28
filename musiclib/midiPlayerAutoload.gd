extends Node


########### MIDIPLAYER ############
var midiPlayer:MidiPlayer = null
const mySoundFontPath = "res://soundfonts/Aspirin-Stereo.sf2"
#const mySoundFontPath = "res://soundfonts/FatBoy-v0.786.sf2"
#const mySoundFontPath = "res://soundfonts/GeneralUser-GS.sf2"

#const mySoundFontPath = "res://soundfonts/SteinwayD.sf2"
#const mySoundFontPath = "res://soundfonts/FluidR3_GM.sf2"
#const mySoundFontPath = "res://soundfonts/MuseScore.sf2"

###################################

func _ready():
	pass # Replace with function body.

func setupMidiPlayer():
	if midiPlayer == null :
		midiPlayer = MidiPlayer.new()
		self.add_child(midiPlayer)
		#LogBus.info("MusicLibMidiPlayer","loading SoundFont "+ mySoundFontPath + "...")
		midiPlayer.set_soundfont(mySoundFontPath)
		LogBus.info("MusicLibMidiPlayer","midiPlayer ready !")
		#LogBus.info("MusicLibMidiPlayer","midiPlayer instance:")
		#LogBus.info("MusicLibMidiPlayer","=> musiclibMidiPlayer.midiPlayer")
	#else:
		#LogBus.info("MusicLibMidiPlayer","midiPlayer déjà instancié")

func set_soundfont(path:String):
	midiPlayer.set_soundfont(path)
	

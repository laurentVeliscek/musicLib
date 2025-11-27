extends OptionButton

signal program_changed(program)	# Émis quand la sélection change (0–127)

export(bool) var auto_select_first = true	# Sélectionne le 1er item au _ready()

# Noms General MIDI dans l'ordre officiel. Affichage 1–128, valeur stockée 0–127.
const GM_NAMES = [
	"Acoustic Grand Piano",
	"Bright Acoustic Piano",
	"Electric Grand Piano",
	"Honky-tonk Piano",
	"Electric Piano 1",
	"Electric Piano 2",
	"Harpsichord",
	"Clavinet",
	"Celesta",
	"Glockenspiel",
	"Music Box",
	"Vibraphone",
	"Marimba",
	"Xylophone",
	"Tubular Bells",
	"Dulcimer",
	"Drawbar Organ",
	"Percussive Organ",
	"Rock Organ",
	"Church Organ",
	"Reed Organ",
	"Accordion",
	"Harmonica",
	"Tango Accordion",
	"Acoustic Guitar (nylon)",
	"Acoustic Guitar (steel)",
	"Electric Guitar (jazz)",
	"Electric Guitar (clean)",
	"Electric Guitar (muted)",
	"Overdriven Guitar",
	"Distortion Guitar",
	"Guitar Harmonics",
	"Acoustic Bass",
	"Electric Bass (finger)",
	"Electric Bass (pick)",
	"Fretless Bass",
	"Slap Bass 1",
	"Slap Bass 2",
	"Synth Bass 1",
	"Synth Bass 2",
	"Violin",
	"Viola",
	"Cello",
	"Contrabass",
	"Tremolo Strings",
	"Pizzicato Strings",
	"Orchestral Harp",
	"Timpani",
	"String Ensemble 1",
	"String Ensemble 2",
	"SynthStrings 1",
	"SynthStrings 2",
	"Choir Aahs",
	"Voice Oohs",
	"Synth Voice",
	"Orchestra Hit",
	"Trumpet",
	"Trombone",
	"Tuba",
	"Muted Trumpet",
	"French Horn",
	"Brass Section",
	"SynthBrass 1",
	"SynthBrass 2",
	"Soprano Sax",
	"Alto Sax",
	"Tenor Sax",
	"Baritone Sax",
	"Oboe",
	"English Horn",
	"Bassoon",
	"Clarinet",
	"Piccolo",
	"Flute",
	"Recorder",
	"Pan Flute",
	"Blown Bottle",
	"Shakuhachi",
	"Whistle",
	"Ocarina",
	"Lead 1 (square)",
	"Lead 2 (sawtooth)",
	"Lead 3 (calliope)",
	"Lead 4 (chiff)",
	"Lead 5 (charang)",
	"Lead 6 (voice)",
	"Lead 7 (fifths)",
	"Lead 8 (bass + lead)",
	"Pad 1 (new age)",
	"Pad 2 (warm)",
	"Pad 3 (polysynth)",
	"Pad 4 (choir)",
	"Pad 5 (bowed)",
	"Pad 6 (metallic)",
	"Pad 7 (halo)",
	"Pad 8 (sweep)",
	"FX 1 (rain)",
	"FX 2 (soundtrack)",
	"FX 3 (crystal)",
	"FX 4 (atmosphere)",
	"FX 5 (brightness)",
	"FX 6 (goblins)",
	"FX 7 (echoes)",
	"FX 8 (sci-fi)",
	"Sitar",
	"Banjo",
	"Shamisen",
	"Koto",
	"Kalimba",
	"Bag pipe",
	"Fiddle",
	"Shanai",
	"Tinkle Bell",
	"Agogo",
	"Steel Drums",
	"Woodblock",
	"Taiko Drum",
	"Melodic Tom",
	"Synth Drum",
	"Reverse Cymbal",
	"Guitar Fret Noise",
	"Breath Noise",
	"Seashore",
	"Bird Tweet",
	"Telephone Ring",
	"Helicopter",
	"Applause",
	"Gunshot"
]

func _ready() -> void:
	_populate()
	if auto_select_first and get_item_count() > 0:
		select(0)
		_emit_selected(0)
	connect("item_selected", self, "_on_item_selected")

func _populate() -> void:
	clear()
	var i = 0
	while i < GM_NAMES.size():
		var label = _format_label(i, GM_NAMES[i])	# "001 Acoustic Grand Piano"
		add_item(label)
		set_item_metadata(i, i)	# Program Change = index (0–127)
		i += 1
	# minimum_size_changed() pour recalculer la taille affichée si nécessaire
	if has_method("minimum_size_changed"):
		minimum_size_changed()

func _on_item_selected(index: int) -> void:
	_emit_selected(index)

func _emit_selected(index: int) -> void:
	var program = get_item_metadata(index)
	emit_signal("program_changed", int(program))

func get_program() -> int:
	# Renvoie la valeur Program Change (0–127) pour l'item sélectionné
	var idx = get_selected()
	if idx < 0:
		return -1
	return int(get_item_metadata(idx))

func set_program(program: int) -> void:
	# Sélectionne l'item à partir d'une valeur Program Change (0–127)
	if program < 0:
		return
	if program >= GM_NAMES.size():
		return
	select(program)
	_emit_selected(program)

func _format_label(index: int, name: String) -> String:
	# Affiche "001 <Nom>"… "128 <Nom>"
	var num = index + 1
	var s = str(num)
	while s.length() < 3:
		s = "0" + s
	return s + " " + name

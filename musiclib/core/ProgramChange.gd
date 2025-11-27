# ProgramChange.gd — Godot 3.x
extends Reference
class_name ProgramChange

# 0..15
var channel: int = 0 setget set_channel, get_channel
# 0..127 (GM is 0-based en MIDI)
var program: int = 0 setget set_program, get_program


func clone()-> ProgramChange:
	var p:ProgramChange = get_script().new()
	p.channel = channel
	p.program = program
	return p


func to_dict() -> Dictionary:
	return {
		"channel": int(channel),
		"program": int(program)
	}


func from_dict(data: Dictionary) -> ProgramChange:
	var p: ProgramChange = get_script().new()
	p.channel = data.get("channel", 0)
	p.program = data.get("program", 0)
	return p


# --- API ---
func to_midi_event_dict(tick: int = 0) -> Dictionary:
	var ch = int(clamp(channel, 0, 15))
	var prog = int(clamp(program, 0, 127))
	return {
		"tick": int(tick),
		"status": (0xC0 | ch),   # Program Change + canal (bits 0..3)
		"data1": prog            # 1 seul data byte
	}

func name() -> String:
	return _gm_name(program)

func set_from_name(name: String) -> bool:
	var n = _norm(name)
	# alias rapides
	if _gm_alias_map().has(n):
		program = _gm_alias_map()[n]
		return true
	# recherche exacte dans la table GM
	for i in range(GM_PROGRAMS.size()):
		if _norm(GM_PROGRAMS[i]) == n:
			program = i
			return true
	# recherche par sous-chaîne (ex: "piano", "rhodes", "saw")
	for i in range(GM_PROGRAMS.size()):
		if _norm(GM_PROGRAMS[i]).find(n) != -1:
			program = i
			return true
	return false

# --- Setters/Getters ---
func set_channel(c):
	channel = clamp(int(c), 0, 15)

func get_channel() -> int:
	return channel

func set_program(p):
	program = clamp(int(p), 0, 127)

func get_program() -> int:
	return program

# --- General MIDI 1 Program List (0..127) ---
const GM_PROGRAMS = [
	"Acoustic Grand Piano","Bright Acoustic Piano","Electric Grand Piano","Honky-tonk Piano",
	"Electric Piano 1","Electric Piano 2","Harpsichord","Clavi",
	"Celesta","Glockenspiel","Music Box","Vibraphone",
	"Marimba","Xylophone","Tubular Bells","Dulcimer",
	"Drawbar Organ","Percussive Organ","Rock Organ","Church Organ",
	"Reed Organ","Accordion","Harmonica","Tango Accordion",
	"Acoustic Guitar (nylon)","Acoustic Guitar (steel)","Electric Guitar (jazz)","Electric Guitar (clean)",
	"Electric Guitar (muted)","Overdriven Guitar","Distortion Guitar","Guitar Harmonics",
	"Acoustic Bass","Electric Bass (finger)","Electric Bass (pick)","Fretless Bass",
	"Slap Bass 1","Slap Bass 2","Synth Bass 1","Synth Bass 2",
	"Violin","Viola","Cello","Contrabass",
	"Tremolo Strings","Pizzicato Strings","Orchestral Harp","Timpani",
	"String Ensemble 1","String Ensemble 2","SynthStrings 1","SynthStrings 2",
	"Choir Aahs","Voice Oohs","Synth Voice","Orchestra Hit",
	"Trumpet","Trombone","Tuba","Muted Trumpet",
	"French Horn","Brass Section","SynthBrass 1","SynthBrass 2",
	"Soprano Sax","Alto Sax","Tenor Sax","Baritone Sax",
	"Oboe","English Horn","Bassoon","Clarinet",
	"Piccolo","Flute","Recorder","Pan Flute",
	"Blown Bottle","Shakuhachi","Whistle","Ocarina",
	"Lead 1 (square)","Lead 2 (sawtooth)","Lead 3 (calliope)","Lead 4 (chiff)",
	"Lead 5 (charang)","Lead 6 (voice)","Lead 7 (fifths)","Lead 8 (bass + lead)",
	"Pad 1 (new age)","Pad 2 (warm)","Pad 3 (polysynth)","Pad 4 (choir)",
	"Pad 5 (bowed)","Pad 6 (metallic)","Pad 7 (halo)","Pad 8 (sweep)",
	"FX 1 (rain)","FX 2 (soundtrack)","FX 3 (crystal)","FX 4 (atmosphere)",
	"FX 5 (brightness)","FX 6 (goblins)","FX 7 (echoes)","FX 8 (sci-fi)",
	"Sitar","Banjo","Shamisen","Koto",
	"Kalimba","Bagpipe","Fiddle","Shanai",
	"Tinkle Bell","Agogo","Steel Drums","Woodblock",
	"Taiko Drum","Melodic Tom","Synth Drum","Reverse Cymbal",
	"Guitar Fret Noise","Breath Noise","Seashore","Bird Tweet",
	"Telephone Ring","Helicopter","Applause","Gunshot"
]

# --- Helpers internes ---
static func _norm(s: String) -> String:
	var t = String(s).to_lower()
	t = t.replace(" ", "").replace("-", "").replace("_", "")
	t = t.replace("(", "").replace(")", "")
	t = t.replace(".", "")
	return t

static func _gm_name(p: int) -> String:
	var idx = clamp(int(p), 0, 127)
	return GM_PROGRAMS[idx]

static func _gm_alias_map() -> Dictionary:
	# Alias utiles (0-based)
	return {
		"piano": 0,
		"grandpiano": 0,
		"acousticgrand": 0,
		"brightpiano": 1,
		"electricgrand": 2,
		"honkytonk": 3,
		"epiano1": 4,
		"rhodes": 4,
		"epiano2": 5,
		"dx7": 5,
		"harpsi": 6,
		"clav": 7,
		"drawbarorgan": 16,
		"hammond": 16,
		"rockorgan": 18,
		"churchorgan": 19,
		"acousticguitarnylon": 24,
		"acousticguitarsteel": 25,
		"jazzguitar": 26,
		"cleanguitar": 27,
		"mutedguitar": 28,
		"overdriveguitar": 29,
		"distguitar": 30,
		"acousticbass": 32,
		"fingerbass": 33,
		"pickbass": 34,
		"fretless": 35,
		"slap1": 36,
		"slap2": 37,
		"synthbass1": 38,
		"synthbass2": 39,
		"violin": 40,
		"cello": 42,
		"contrabass": 43,
		"harp": 46,
		"timpani": 47,
		"strings": 48,
		"choir": 52,
		"trumpet": 56,
		"trombone": 57,
		"tuba": 58,
		"horn": 60,
		"brass": 61,
		"soprano": 64,
		"altosax": 65,
		"tenorsax": 66,
		"barisax": 67,
		"oboe": 68,
		"flute": 73,
		"piccolo": 72,
		"lead2": 81,
		"saw": 81,
		"padwarm": 89,
		"sitar": 104,
		"banjo": 105,
		"steeldrums": 114,
		"taikodrum": 116,
		"applause": 126
	}


func to_string() -> String:
	var ch = int(clamp(channel, 0, 15))
	var prog = int(clamp(program, 0, 127))
	var nm = name()  # ex: "Lead 2 (sawtooth)"
	return "ProgramChange(channel=%d, program=%d, name=%s)" % [ch, prog, nm]

"""
var tr = Track.new()
tr.name = "Lead"
tr.channel = 0

# Program Change: Saw lead
var pc = ProgramChange.new()
pc.set_from_name("saw")    # alias → Lead 2 (sawtooth), program=81 → 0-based idx = 81
pc.channel = 0
tr.set_program_change(pc)

# Ajoute 2 notes
var n = Note.new()
n.midi = 72
n.velocity = 100
n.length_beats = 1.0
tr.add_note(0.0, n)

var n2 = n.clone()
n2.midi = 76
tr.add_note(1.0, n2)

# Sauvegarde SMF Type-0 (PC au début)
tr.save_midi_type0("user://lead_saw.mid", 480, 120.0)

"""

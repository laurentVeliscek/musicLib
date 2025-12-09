extends OptionButton

signal program_changed(program)	# Émis quand la sélection change (0–127)

export(bool) var auto_select_first = true	# Sélectionne le 1er item au _ready()

# Noms General MIDI dans l'ordre officiel. Affichage 1–128, valeur stockée 0–127.
const PROGRAM_NAMES = [
	"PIANO Steinway",
	"PIANO Yamaha Grand",
	"PIANO Yamaha C5",
	"PIANO special",
	"PIANO Salamander",
	"PIANO Upright",
	"PIANO DX7",
	"PIANO Fender Rhodes",
	"PIANO Celesta",
	"GTR Nylon Guitar",
	"GTR Jazz",
	"GTR Les Paul",
	"GTR Spanish",
	"GTR Long Ring",
	"GTR Palm Muted",
	"BASS Acoustic",
	"BASS Synth",
	"ORGAN Church",
	"ORGAN B3 Slow Rotor",
	"ORGAN B3 Fast Leslie",
	"ORGAN Rock",
	"PAD Warm",
	"PAD Moog Voyager",
	"PAD Piccolo",
	"PAD Ahh Choi"
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
	while i < PROGRAM_NAMES.size():
		var label = _format_label(i, PROGRAM_NAMES[i])	# "001 Acoustic Grand Piano"
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
	if program >= PROGRAM_NAMES.size():
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

func get_program_change()->ProgramChange:
	var pc:ProgramChange = ProgramChange.new()
	pc.set_program(get_program())
	return pc

func get_program_name()-> String:
	return PROGRAM_NAMES[selected]

extends OptionButton

signal program_changed(program)	# Émis quand la sélection change (0–46)

export(bool) var auto_select_first = true	# Sélectionne le 1er item au _ready()

# Noms des programmes du soundfont personnalisé (Bank 0, Programs 0-46)
const PROGRAM_NAMES = [
	"Yamaha C5 Grand",
	"Mellow C5 Grand",
	"Dark C5 Grand",
	"Rhodes EP",
	"DX7 EP",
	"Rhodes Bell EP",
	"Rotary Organ",
	"Small Pipe Organ",
	"Pipe Organ Full",
	"Small Plein-Jeu",
	"Flute Sml Plein-Jeu",
	"FlutePad Sml Plein-J",
	"Plein-jeu Organ Lge",
	"Pad Plein-Jeu Large",
	"Warm Pad",
	"Synth Strings",
	"Voyager-8",
	"Full Strings Vel",
	"Full Orchestra",
	"Chamber Strings",
	"Violin",
	"Two Violins",
	"Cello",
	"Trumpet",
	"Trumpet+8 Vel",
	"Tuba",
	"Oboe",
	"Tenor Sax",
	"Alto Sax",
	"Flute Expr+8 (SSO)",
	"Flute 2",
	"Timpani",
	"Banjo 5 String",
	"Steel Guitar",
	"Nylon Guitar",
	"Spanish Guitar",
	"Spanish V Slide",
	"Clean Guitar",
	"LP Twin Elec Gtr",
	"LP Twin Dynamic",
	"Muted LP Twin",
	"Jazz Guitar",
	"Chorus Guitar",
	"YamC5+Pad",
	"YamC5+Strings",
	"DX7+Pad",
	"DX7+Strings"
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
		var label = _format_label(i, PROGRAM_NAMES[i])	# "000 Yamaha C5 Grand"
		add_item(label)
		set_item_metadata(i, i)	# Program Change = index (0–46)
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
	# Renvoie la valeur Program Change (0–46) pour l'item sélectionné
	var idx = get_selected()
	if idx < 0:
		return -1
	return int(get_item_metadata(idx))

func set_program(program: int) -> void:
	# Sélectionne l'item à partir d'une valeur Program Change (0–46)
	if program < 0:
		return
	if program >= PROGRAM_NAMES.size():
		return
	select(program)
	_emit_selected(program)

func _format_label(index: int, name: String) -> String:
	# Affiche "000 <Nom>"… "046 <Nom>"
	var num = index
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


extends VBoxContainer
signal chargeScene(text)

# --- Exports (branchements dans l’inspecteur si tu renommes des noeuds)
export(NodePath) var chord_select_path = NodePath("TopBar/ChordSelect")
export(NodePath) var voicings_container_path = NodePath("Voicings")
export(NodePath) var status_label_path = NodePath("TopBar/Status")

# Chemin du JSON tombatossals (adapte-le à ton dossier)
export(String) var json_path = "res://addons/musiclib/guitar/chords-db-master/lib/guitar.json"

# --- Réfs runtime
var chord_select = null
var voicings_container = null
var status_label = null
var loader = null

# Liste compacte pour le menu (on filtrera selon la DB)
var preferred_symbols = [
	"F#m","C#","C#m","Asus4","Csus2","F/A","Gb","F#m7b5","E","Am","A/C#","Bb/D","C5","F#m7b5","Bm7b5"
]

func _ready():
	_resolve_nodes()
	_init_loader()
	_fill_select()
	_connect_signals()
	_autostart()

func _resolve_nodes():
	if chord_select_path and has_node(chord_select_path):
		chord_select = get_node(chord_select_path)
	if voicings_container_path and has_node(voicings_container_path):
		voicings_container = get_node(voicings_container_path)
	if status_label_path and has_node(status_label_path):
		status_label = get_node(status_label_path)

func _init_loader():
	# Garantit qu'on a un Loader typé ChordDBLoader
	if has_node("Loader"):
		loader = get_node("Loader")
		# Si ce n'est pas le bon type, on le remplace proprement
		if not (loader is ChordDBLoader):
			loader.queue_free()
			loader = ChordDBLoader.new()
			loader.name = "Loader"
			add_child(loader)
	else:
		loader = ChordDBLoader.new()
		loader.name = "Loader"
		add_child(loader)

	# Chemin JSON (avec fallback auto si nécessaire)
	var p = json_path
	var f = File.new()
	if not f.file_exists(p):
		p = _guess_db_path()
		if p == "":
			_set_status("DB introuvable → fallback (Am uniquement)")
			return
		json_path = p

	loader.json_path = p
	print("ChordDB path => ", loader.json_path)

	var ok = loader.load_db()
	if ok:
		_set_status("DB chargée: " + loader.json_path)
	else:
		_set_status("DB load failed (format ? chemin ?)")

func _fill_select():
	if chord_select == null:
		return

	chord_select.clear()

	var symbols = []
	if loader and loader.has_method("list_symbols"):
		symbols = loader.list_symbols()

	# Si la DB est dispo, on propose d’abord une petite shortlist lisible,
	# filtrée par ce qui existe réellement; puis on ajoute “(All…)”
	if symbols.size() > 0:
		for s in preferred_symbols:
			if loader.has_chord(s):
				chord_select.add_item(s)
		if chord_select.get_item_count() == 0:
			# pas d’intersection → mets quelques premiers items de la DB
			var take = min(24, symbols.size())
			for i in range(take):
				chord_select.add_item(symbols[i])
		else:
			chord_select.add_separator()
			chord_select.add_item("(All symbols…)")	# index spécial
	else:
		# Pas de DB → juste Am
		chord_select.add_item("Am")

func _connect_signals():
	if chord_select and not chord_select.is_connected("item_selected", self, "_on_chord_selected"):
		chord_select.connect("item_selected", self, "_on_chord_selected")

func _autostart():
	if chord_select == null:
		return
	if chord_select.get_item_count() == 0:
		return
	chord_select.select(0)
	_on_chord_selected(0)

func _on_chord_selected(index):
	if chord_select == null:
		return
	var txt = chord_select.get_item_text(index)
	if txt == "(All symbols…)":
		_show_all_symbols()
		return
	_show_voicings_for(txt)

func _show_all_symbols():
	if loader == null:
		return
	var symbols = loader.list_symbols()
	if symbols.size() == 0:
		return
	_set_status("Affiche les 6 premiers de la DB")
	_clear_voicings()
	# Afficher les 6 premiers symboles, un voicing chacun (vite fait)
	var max_items = min(6, symbols.size())
	for i in range(max_items):
		var sym = symbols[i]
		var gc = loader.get_first(sym)
		if gc != null:
			_add_view(gc)

func _show_voicings_for(symbol):
	if loader and loader.has_chord(symbol):
		var arr = loader.get_voicings(symbol)
		_clear_voicings()

		var view = GuitarChordView.new()
		voicings_container.add_child(view)
		view.rect_min_size = Vector2(280, 260)


		# 1) connecter AVANT d'appeler set_voicings()
		if not view.is_connected("midi_notes_changed", self, "_on_view_midi_notes_changed"):
			view.connect("midi_notes_changed", self, "_on_view_midi_notes_changed")

		# (optionnel) récupérer aussi le voicing courant si besoin
		if not view.is_connected("voicing_changed", self, "_on_view_voicing_changed"):
			view.connect("voicing_changed", self, "_on_view_voicing_changed")

		# 2) maintenant on peut peupler
		view.set_voicings(arr)

		# 3) et si tu veux être 100% sûr de ne rien rater :
		view.emit_current_midi_notes()  # renvoie immédiatement le set courant

		# set status initial
		_set_status(symbol + " • 1/" + str(view._voicings.size()))
	else:
		_set_status("Fallback " + symbol)
		_clear_voicings()
		var gc = _make_builtin(symbol)
		if gc != null:
			var v2 = GuitarChordView.new()
			voicings_container.add_child(v2)
			v2.rect_min_size = Vector2(280, 260)
			v2.set_voicings([gc])

func _add_view(gc):
	if voicings_container == null:
		return
	# instancie un viewer
	var view = GuitarChordView.new()
	voicings_container.add_child(view)
	view.rect_min_size = Vector2(280, 260)
	view.set_chord(gc)

func _clear_voicings():
	if voicings_container == null:
		return
	for c in voicings_container.get_children():
		c.queue_free()

func _set_status(s):
	if status_label:
		status_label.text = s

# --- Fallback minimal (sans DB): quelques shapes usuels
func _make_builtin(symbol):
	var gc = null
	if symbol == "Am":
		gc = GuitarChord.new()
		gc.chord_name = "Am"
		gc.base_fret = 1
		# 6→1 : x 0 2 2 1 0
		gc.frets = PoolIntArray([-1, 0, 2, 2, 1, 0])
		gc.fingers = PoolIntArray([0, 0, 2, 3, 1, 0])
		gc.barres = []
	elif symbol == "C":
		gc = GuitarChord.new()
		gc.chord_name = "C"
		gc.base_fret = 1
		gc.frets = PoolIntArray([-1, 3, 2, 0, 1, 0])
		gc.fingers = PoolIntArray([0, 3, 2, 0, 1, 0])
		gc.barres = []
	return gc
# Cherche un chemin valide vers guitar.json si l'export json_path ne pointe sur rien
func _guess_db_path() -> String:
	var candidates = [
		"res://addons/musiclib/guitar/chords-db-master/lib/guitar.json",
		"res://addons/musiclib/guitar/chords-db/lib/guitar.json",
		"res://chords-db-master/lib/guitar.json",
		"res://chords-db/lib/guitar.json"
	]
	for p in candidates:
		var f = File.new()
		if f.file_exists(p):
			return p
	# recherche récursive sous addons/musiclib/guitar
	var root = "res://addons/musiclib/guitar"
	if _dir_exists(root):
		var found = _find_file_recursive(root, "guitar.json")
		if found != "":
			return found
	return ""

func _find_file_recursive(dir_path: String, target: String) -> String:
	var d = Directory.new()
	if d.open(dir_path) != OK:
		return ""
	d.list_dir_begin(true, true)	# skip hidden, skip . and ..
	var name = d.get_next()
	while name != "":
		var full = dir_path.plus_file(name)
		if d.current_is_dir():
			var sub = _find_file_recursive(full, target)
			if sub != "":
				d.list_dir_end()
				return sub
		else:
			if name == target:
				d.list_dir_end()
				return full
		name = d.get_next()
	d.list_dir_end()
	return ""

# petit utilitaire: existe-t-il un dossier à ce chemin ?
func _dir_exists(path: String) -> bool:
	var d = Directory.new()
	return d.dir_exists(path)

func _on_view_index_changed(current, total):
	# current est 0-based ; on affiche 1-based
	var idx = current + 1
	# le label "Chord:" au-dessus reflète déjà le symbole, on complète dans Status
	if chord_select:
		var i = chord_select.get_selected()
		var sym = chord_select.get_item_text(i)
		_set_status(sym + " • " + str(idx) + "/" + str(total))
		
var _current_notes = PoolIntArray()

func _on_view_midi_notes_changed(notes):
	_current_notes = PoolIntArray(notes)
	print("_on_view_midi_notes_changed")
	print("_on_view_midi_notes_changed(notes) notes -> "+str(notes))
	# print("MIDI notes => ", _current_notes)

# Bonus : si tu veux le GuitarChord courant
func _on_view_voicing_changed(gc):
	print("_on_view_voicing_changed")
	if gc != null:
		print("_on_view_voicing_changed(gc) gc -> "+ str(gc))
		print(gc.chord_name)
		print("voicing:", gc.chord_name, " ", gc.tab_string_compact())


func _on_playChordBTN_pressed():
	var view = $Voicings.get_child(0)   # ta GuitarChordView instanciée
	if view != null and view is GuitarChordView:
		var notes = view.midiNotes
		print("Play clicked, notes=", notes)

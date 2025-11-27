extends HBoxContainer
class_name KeySelect	# OK en 3.x ; on ne s'auto-instancie pas ici donc pas de cyclic ref

signal key_changed(key, root_index, scale_index, display_text)	# émis à chaque modif


# --- Exports (assignables dans l’inspecteur)
export(NodePath) var root_popup_path = "VBoxContainer/selector/rootPopup"
export(NodePath) var scale_popup_path = "VBoxContainer/selector/scalePopup"
export(NodePath) var current_key_line_edit_path = "VBoxContainer/textContainer/currentKeyLineEdit"
export(NodePath) var randomize_root_button_path = "VBoxContainer/random/randomizeRoot"
export(NodePath) var randomize_scale_button_path = "VBoxContainer/random/randomizeScale"

# --- Références runtime (résolues au _ready)
var root_popup = null
var scale_popup = null
var current_key_line_edit = null
var randomize_root_button = null
var randomize_scale_button = null

# --- Données
const ROOT_NAMES = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

var scale_names = []	# rempli via ScaleHelper.list_scales()
var current_root_index = 0
var current_scale_index = 0

# Objet tonalité
var key = null	# HarmonicKey (addon musiclib)

func _ready():
	randomize()
	_resolve_nodes()
	_init_harmonic_key()
	_fill_root_popup()
	_fill_scale_popup()
	_connect_signals()
	_update_ui_from_key()

# --- Résolution des nœuds (exports + fallback par nom)
func _resolve_nodes():
	if root_popup_path:
		root_popup = get_node(root_popup_path)
	elif has_node("rootPopup"):
		root_popup = $rootPopup

	if scale_popup_path:
		scale_popup = get_node(scale_popup_path)
	elif has_node("scalePopup"):
		scale_popup = $scalePopup

	if current_key_line_edit_path:
		current_key_line_edit = get_node(current_key_line_edit_path)
	elif has_node("currentKeyLineEdit"):
		current_key_line_edit = $currentKeyLineEdit

	if randomize_root_button_path:
		randomize_root_button = get_node(randomize_root_button_path)
	elif has_node("randomizeRoot"):
		randomize_root_button = $randomizeRoot

	if randomize_scale_button_path:
		randomize_scale_button = get_node(randomize_scale_button_path)
	elif has_node("randomizeScale"):
		randomize_scale_button = $randomizeScale

func _init_harmonic_key():
	# On crée la tonalité via l’addon (pas d’auto-référence ici, donc safe)
	key = HarmonicKey.new()
	# Récupère les gammes depuis ScaleHelper
	var sc = ScaleHelper.new()
	var listed = sc.list_scales()
	if typeof(listed) == TYPE_ARRAY:
		scale_names = listed.duplicate()
	elif typeof(listed) == TYPE_DICTIONARY:
		scale_names = listed.keys()
	else:
		scale_names = []
	# Garde-fou : au moins une gamme
	if scale_names.empty():
		scale_names = ["Ionian"]
	# Valeur par défaut : C + Major
	current_root_index = 0
	var major_scale_index = _find_scale_index_by_name("Major")
	if major_scale_index > 0 :
		current_scale_index = major_scale_index
	else:
		current_scale_index = 0
	_key_set_from_indices(current_root_index, current_scale_index)

func _fill_root_popup():
	if not root_popup:
		return
	root_popup.clear()
	for i in range(ROOT_NAMES.size()):
		root_popup.add_item(ROOT_NAMES[i], i)
	root_popup.select(current_root_index)

func _fill_scale_popup():
	if not scale_popup:
		return
	scale_popup.clear()
	for i in range(scale_names.size()):
		scale_popup.add_item(str(scale_names[i]), i)
	scale_popup.select(current_scale_index)

func _connect_signals():
	if root_popup and not root_popup.is_connected("item_selected", self, "_on_root_popup_item_selected"):
		root_popup.connect("item_selected", self, "_on_root_popup_item_selected")
	if scale_popup and not scale_popup.is_connected("item_selected", self, "_on_scale_popup_item_selected"):
		scale_popup.connect("item_selected", self, "_on_scale_popup_item_selected")
	if current_key_line_edit:
		if not current_key_line_edit.is_connected("text_entered", self, "_on_current_key_text_entered"):
			current_key_line_edit.connect("text_entered", self, "_on_current_key_text_entered")
		if not current_key_line_edit.is_connected("focus_exited", self, "_on_current_key_focus_exited"):
			current_key_line_edit.connect("focus_exited", self, "_on_current_key_focus_exited")
	if randomize_root_button and not randomize_root_button.is_connected("pressed", self, "_on_randomize_root_pressed"):
		randomize_root_button.connect("pressed", self, "_on_randomize_root_pressed")
	if randomize_scale_button and not randomize_scale_button.is_connected("pressed", self, "_on_randomize_scale_pressed"):
		randomize_scale_button.connect("pressed", self, "_on_randomize_scale_pressed")

# --- Handlers UI → key
func _on_root_popup_item_selected(index):
	if index < 0 or index >= ROOT_NAMES.size():
		return
	current_root_index = index
	_key_set_from_indices(current_root_index, current_scale_index)
	_update_ui_from_key()

func _on_scale_popup_item_selected(index):
	if index < 0 or index >= scale_names.size():
		return
	current_scale_index = index
	_key_set_from_indices(current_root_index, current_scale_index)
	_update_ui_from_key()

func _on_current_key_text_entered(text):
	_apply_lineedit_text(text)

func _on_current_key_focus_exited():
	_apply_lineedit_text(current_key_line_edit.text)

func _on_randomize_root_pressed():
	var idx = int(randi() % ROOT_NAMES.size())
	current_root_index = idx
	_key_set_from_indices(current_root_index, current_scale_index)
	_update_ui_from_key()

func _on_randomize_scale_pressed():
	var idx = int(randi() % scale_names.size())
	current_scale_index = idx
	_key_set_from_indices(current_root_index, current_scale_index)
	_update_ui_from_key()

# --- key helpers
func _key_set_from_indices(root_idx, scale_idx):
	# Utilise set_from_string pour éviter de dépendre d’APIs setters spécifiques
	var key_str = str(ROOT_NAMES[root_idx]) + " " + str(scale_names[scale_idx])
	key.set_from_string(key_str)

func _key_root_display() -> String:
	# Affichage via NoteParser si possible, sinon fallback sur ROOT_NAMES
	if key and key.has_method("get_root_midipitch"):
		var mp = key.get_root_midipitch()
		return NoteParser.midipitch2StringStrictInKey(mp, key)
	return ROOT_NAMES[current_root_index]

func _key_scale_display() -> String:
	if key and key.has_method("get_scale_name"):
		return str(key.get_scale_name())
	return str(scale_names[current_scale_index])

func _find_scale_index_by_name(name: String) -> int:
	var target = name.to_lower()
	for i in range(scale_names.size()):
		if str(scale_names[i]).to_lower() == target:
			return i
	return -1

# --- UI sync key → UI
func _update_ui_from_key():
	if not current_key_line_edit:
		return
	var display = _key_root_display() + " " + _key_scale_display()
	current_key_line_edit.text = display
	current_key_line_edit.caret_position = display.length()
	current_key_line_edit.minimum_size_changed()	# UI 3.x

	# Ajuste les popups si besoin
	if root_popup:
		var rname = _key_root_display()
		var rindex = ROOT_NAMES.find(rname)
		if rindex == -1:
			rindex = current_root_index
		if rindex >= 0:
			root_popup.select(rindex)
	if scale_popup:
		var sname = _key_scale_display()
		var sindex = _find_scale_index_by_name(sname)
		if sindex == -1:
			sindex = current_scale_index
		if sindex >= 0:
			scale_popup.select(sindex)
	_emit_key_changed()

# --- Parsing depuis le LineEdit
func _apply_lineedit_text(text: String):
	if text == null:
		return
	if text.strip_edges() == "":
		_update_ui_from_key()
		return
	key.set_from_string(text)

	# Essaie de répercuter root/scale indices à partir de key
	var rname = _key_root_display()
	var sname = _key_scale_display()
	var ri = ROOT_NAMES.find(rname)
	var si = _find_scale_index_by_name(sname)
	if ri >= 0:
		current_root_index = ri
	if si >= 0:
		current_scale_index = si
	_update_ui_from_key()


func _emit_key_changed():
	var txt = ""
	if current_key_line_edit:
		txt = current_key_line_edit.text
	emit_signal("key_changed", key, current_root_index, current_scale_index, txt)



# --- Public: changer la tonalité depuis une chaîne ("Db Dorian", "Db", "Dorian") ---
func set_key_from_string(key_str: String) -> void:
	var txt = String(key_str).strip_edges()
	if txt == "":
		return

	var have_root = root_popup != null
	var have_scale = scale_popup != null

	var root_candidate = ""
	var scale_candidate = ""

	# Découper "Root Reste..." → root_candidate + scale_candidate
	var sp = txt.find(" ")
	if sp == -1:
#		Si une seule info: on essaie d'abord comme root, sinon comme scale
		root_candidate = txt
	else:
		root_candidate = txt.substr(0, sp)
		scale_candidate = txt.substr(sp + 1, txt.length() - sp - 1).strip_edges()

	var did_root = false
	var did_scale = false

	# 1) Racine (OptionButton root_popup), avec enharmoniques tolérées
	if have_root and root_candidate != "":
		var idx_root = _find_root_index_by_name(root_candidate)
		if idx_root >= 0:
			root_popup.select(idx_root)
			if has_method("_on_root_popup_item_selected"):
				_on_root_popup_item_selected(idx_root)
			elif root_popup.has_signal("item_selected"):
				root_popup.emit_signal("item_selected", idx_root)
			did_root = true

	# 2) Gamme (OptionButton scale_popup)
	if have_scale:
		var scale_text = scale_candidate
		# si la racine n'a pas été reconnue et qu'on n'a pas de "reste",
		# on considère tout le texte comme un nom de gamme
		if not did_root and scale_candidate == "":
			scale_text = txt
		if scale_text != "":
			var idx_scale = -1
			if has_method("_find_scale_index_by_name"):
				idx_scale = _find_scale_index_by_name(scale_text)
			if idx_scale < 0:
				idx_scale = _find_item_index_by_text(scale_popup, scale_text)
			if idx_scale >= 0:
				scale_popup.select(idx_scale)
				if has_method("_on_scale_popup_item_selected"):
					_on_scale_popup_item_selected(idx_scale)
				elif scale_popup.has_signal("item_selected"):
					scale_popup.emit_signal("item_selected", idx_scale)
				did_scale = true

	# Comportement voulu :
	# - si on n'a que la note → on ne change que root_popup
	# - si on n'a que la gamme → on ne change que scale_popup
	# - si on a les deux → on change les deux (quand trouvés)

# --- Helpers ---

# Trouve l'index d'une note (avec enharmoniques) dans root_popup
func _find_root_index_by_name(name: String) -> int:
	if root_popup == null:
		return -1
	var token = _normalize_accidentals(String(name).strip_edges())
	var cands = _enharmonic_candidates(token)
	for i in range(cands.size()):
		var idx = _find_item_index_by_text(root_popup, cands[i])
		if idx >= 0:
			return idx
	return -1

# Recherche d'un item par texte (case-insensitive, ♭/♯ normalisées)
func _find_item_index_by_text(popup, needle: String) -> int:
	if popup == null:
		return -1
	var target = _normalize_accidentals(String(needle)).to_upper()
	var n = popup.get_item_count()
	for i in range(n):
		var t = _normalize_accidentals(String(popup.get_item_text(i))).to_upper()
		if t == target:
			return i
	return -1

# Normalise les altérations Unicode → ASCII (#, b)
func _normalize_accidentals(s: String) -> String:
	var out = s
	out = out.replace("♭", "b")
	out = out.replace("♯", "#")
	return out

# Renvoie [nom, enharmonique] (si existante) pour une note donnée
func _enharmonic_candidates(name: String) -> Array:
	var n = _normalize_accidentals(name)
	var cand = [n]

	# Capitalisation "Db" à partir de "db"
	var norm = ""
	if n.length() >= 1:
		norm = n.substr(0, 1).to_upper()
		if n.length() >= 2:
			norm += n.substr(1, n.length() - 1)
	if cand.find(norm) == -1:
		cand.append(norm)

	# Table d’enharmoniques courantes
	var m = {
		"C#": "Db", "Db": "C#",
		"D#": "Eb", "Eb": "D#",
		"F#": "Gb", "Gb": "F#",
		"G#": "Ab", "Ab": "G#",
		"A#": "Bb", "Bb": "A#",
		"B": "Cb", "Cb": "B",
		"E": "Fb", "Fb": "E",
		"C": "B#", "B#": "C",
		"F": "E#", "E#": "F"
	}
	if m.has(norm):
		var enh = m[norm]
		if cand.find(enh) == -1:
			cand.append(enh)

	return cand


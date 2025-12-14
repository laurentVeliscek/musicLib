# SongTrackView.gd — Godot 3.x (tabs only)
extends Control
class_name SongTrackView

const TAG = "SongTrackView"
#signal element_clicked(element)
signal element_right_clicked(element,wrapper)
signal element_hovered(element)
signal element_unhovered(element)
signal selection_changed(selected_elements)
signal scroll_changed(value_px)
signal element_clicked(element,index,wrapper)

# --- Données / options ---
var song: Song = null setget set_song, get_song
export(String) var trackName = ""
export(float) var scale = 2 setget set_scale, get_scale

# Police pour certaines vues Degree (passe au Degree.get_*_view)
export(String) var font_path = ""

export(bool) var multiple_selection_allowed = true

# Ruler (fond/typo/lignes)
export(Color) var rulerBackgroundColor = Color(0, 0, 0, 1) setget set_ruler_background_color, get_ruler_background_color
export(Color) var rulerFontColor = Color(1, 1, 1, 1) setget set_ruler_font_color, get_ruler_font_color
export(String) var ruler_font_path = "" setget set_ruler_font_path
export(int) var ruler_font_size = 12 setget set_ruler_font_size
export(Color) var rulerLineColor = Color(1, 1, 1, 1)
export(int) var font_size = 12 setget set_font_size
export(Color) var font_color = Color(0, 0, 0, 1) setget set_font_color
export(Color) var selected_border_color = Color(1, 0, 0, 1) setget set_selected_border_color




#fontSize
# Timeline (fond et lignes)
export(Color) var backgroundColor = Color(0, 0, 0, 1) setget set_background_color, get_background_color
export(Color) var timelineBarColor = Color(1, 1, 1, 1)		# lignes de mesures
export(Color) var timelineBeatColor = Color(1, 1, 1, 0.4)	# lignes de temps
export(int) var selection_border_px = 3
# Options d'affichage
export(bool) var hasRuler = true setget set_has_ruler, get_has_ruler
# "midi" | "jazzchord" | "roman" | "keyboard"
export(String) var DegreeDisplay = "midi" setget set_degree_display, get_degree_display


# ROMAN VIEW
export(String) var rn_view_font_path = "" 
export(int) var rn_view_font_size = 24 
export(Color) var rn_view_font_color = Color(0, 0, 0, 1)		# lignes de mesures

export(String) var rn_view_root_font_path = "" 
export(int) var rn_view_root_font_size = 18 
export(Color) var rn_view_root_font_color = Color("#343CA3")		# lignes de mesures

export(String) var rn_view_scale_font_path = "" 
export(int) var rn_view_scale_font_size = 16 
export(Color) var rn_view_scale_font_color = Color(.2, 0.2, 0.2, 1)		# lignes de mesures




# Auto-scroll: ajoute une "traîne" à droite de la timeline pour laisser sortir le contenu hors champ en fin de song
export(bool) var auto_scroll_tail = true
export(int) var scroll_tail_px = 0	# utilisé si auto_scroll_tail == false

# --- Constantes d'UI ---
const RULER_H = 10
const TIMELINE_H = 130
const PX_PER_BEAT_BASE = 12.0

# --- Noeuds internes ---
var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _ruler: Control = null
var _ruler_bg: ColorRect = null
var _timeline: Control = null
var _timeline_bg: ColorRect = null
var _ruler_font: DynamicFont = null

var _playing_pos_ticks = 0

# Sélection
var _wrappers = []				# Array de Panel (wrappers)
var _wrapper_to_model = {}		# wrapper -> (Degree|Note)
var _selected = {}				# wrapper -> bool
var _style_selected: StyleBoxFlat = null
var _style_unselected: StyleBoxFlat = null
var _track:Track

func _ready() -> void:
	_build_nodes()
	_init_selection_styles()
	_reload_ruler_font()
	_update_all()





# --- Setters / Getters ---

func set_selected_border_color(c):
	selected_border_color = c
	update_ui()


func set_song(s):
	song = s
	update_ui()

func get_song():
	return song

func set_scale(s):
	scale = max(1,s)
	update_ui()

func get_scale():
	return scale

func set_ruler_font_color(c):
	rulerFontColor = c
	_redraw_grid()

func get_ruler_font_color():
	return rulerFontColor

func set_background_color(c):
	backgroundColor = c
	if _timeline_bg != null:
		_timeline_bg.color = backgroundColor

func get_background_color():
	return backgroundColor

func set_has_ruler(v):
	hasRuler = bool(v)
	if _ruler != null:
		_ruler.visible = hasRuler
	_vbox.minimum_size_changed()

func get_has_ruler():
	return hasRuler

func set_degree_display(s):
	DegreeDisplay = s
	update_ui()

func get_degree_display():
	return DegreeDisplay

func set_ruler_background_color(c):
	rulerBackgroundColor = c
	if _ruler_bg != null:
		_ruler_bg.color = rulerBackgroundColor

func get_ruler_background_color():
	return rulerBackgroundColor

func set_ruler_font_path(p):
	ruler_font_path = p
	_reload_ruler_font()
	_redraw_grid()

func set_ruler_font_size(s):
	ruler_font_size = int(s)
	_reload_ruler_font()
	_redraw_grid()

func set_font_size(s):
	font_size = int(s)
	_reload_ruler_font()
	_redraw_grid()
	
func set_font_color(s):
	font_color = int(s)
	_reload_ruler_font()
	_redraw_grid()

# --- Construction de la hiérarchie ---
func _build_nodes() -> void:
	# Scroll
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.scroll_horizontal_enabled = true
	_scroll.scroll_vertical_enabled = false
	_scroll.anchor_right = 1.0
	_scroll.anchor_bottom = 1.0
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_scroll)

	# Contenu
	_vbox = VBoxContainer.new()
	_vbox.name = "Content"
	_vbox.size_flags_horizontal = SIZE_FILL
	_vbox.size_flags_vertical = SIZE_FILL
	_scroll.add_child(_vbox)

	# Ruler (10 px)
	_ruler = Control.new()
	_ruler.name = "Ruler"
	_ruler.rect_min_size = Vector2(0, RULER_H)
	_ruler.size_flags_horizontal = SIZE_FILL
	_ruler.size_flags_vertical = 0
	_ruler.visible = hasRuler
	_vbox.add_child(_ruler)

	# Fond du ruler
	_ruler_bg = ColorRect.new()
	_ruler_bg.name = "RulerBg"
	_ruler_bg.color = rulerBackgroundColor
	_ruler_bg.rect_min_size = Vector2(0, RULER_H)
	_ruler_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ruler.add_child(_ruler_bg)
	_ruler.move_child(_ruler_bg, 0)	# fond derrière lignes/labels

	# Timeline (130 px)
	_timeline = Control.new()
	_timeline.name = "Timeline"
	_timeline.rect_min_size = Vector2(0, TIMELINE_H)
	_timeline.size_flags_horizontal = SIZE_FILL
	_timeline.size_flags_vertical = 0
	_vbox.add_child(_timeline)

	# Fond de la timeline (au fond)
	_timeline_bg = ColorRect.new()
	_timeline_bg.name = "Bg"
	_timeline_bg.color = backgroundColor
	_timeline_bg.rect_position = Vector2(0, 0)
	_timeline_bg.rect_min_size = Vector2(0, TIMELINE_H)
	_timeline_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timeline.add_child(_timeline_bg)
	_timeline.move_child(_timeline_bg, 0)

# --- Police du ruler ---
func _reload_ruler_font() -> void:
	_ruler_font = null
	if ruler_font_path != "":
		var fdata = load(ruler_font_path)
		if fdata != null:
			var df = DynamicFont.new()
			df.size = max(8, int(ruler_font_size))
			df.font_data = fdata
			_ruler_font = df

# --- Public: mise à jour complète ---
func update_ui() -> void:
	_update_all()

# --- Position de lecture (ticks PPQ) -> scroll horizontal ---
func set_playing_pos_ticks(ticks: int) -> void:
	_playing_pos_ticks = max(0, int(ticks))
	var px_per_beat = PX_PER_BEAT_BASE * float(scale)
	var px = 0.0
	if song != null and song.ppq > 0:
		px = (float(_playing_pos_ticks) / float(song.ppq)) * px_per_beat
	if _scroll != null:
		_scroll.scroll_horizontal = int(px)

func get_playing_pos_ticks() -> int:
	return _playing_pos_ticks

# --- Interne: calcul tailles + grid + items ---
func _update_all() -> void:
	var width_px = _compute_width_px()
	_size_sections(width_px)
	_clear_grid()
	_draw_grid(width_px)
	_clear_items()
	_build_items()
	#vbox.minimum_size_changed()

func _compute_width_px() -> int:
	var beats = 0.0
	if song != null and song.has_method("duration_beats"):
		beats = float(song.duration_beats())
	var base = int(ceil(max(1.0, beats) * PX_PER_BEAT_BASE * float(scale)))
	var tail = _get_tail_px()
	return base + tail

func _get_tail_px() -> int:
	if auto_scroll_tail:
		var w = 0
		if _scroll != null:
			w = int(_scroll.rect_size.x)
		if w <= 0:
			w = int(rect_size.x)
		if w <= 0:
			w = 256
		# +1 barre au bout pour être tranquille
		var px_per_beat = PX_PER_BEAT_BASE * float(scale)
		var px_per_bar 
		if song != null :
			
			px_per_bar = px_per_beat * float(song.time_num) 
		else: 
			px_per_bar = px_per_beat * 4.0 
		return w + int(round(px_per_bar))
	return int(max(0, int(scroll_tail_px)))


func _size_sections(width_px: int) -> void:
	if _vbox != null:
		_vbox.rect_min_size = Vector2(width_px, RULER_H + TIMELINE_H)
	if _ruler != null:
		_ruler.rect_min_size = Vector2(width_px, RULER_H)
	if _ruler_bg != null:
		_ruler_bg.rect_min_size = Vector2(width_px, RULER_H)
	if _timeline != null:
		_timeline.rect_min_size = Vector2(width_px, TIMELINE_H)
	if _timeline_bg != null:
		_timeline_bg.rect_min_size = Vector2(width_px, TIMELINE_H)

# --- Grille (mesures + temps) avec ColorRect de 1 px ---
func _clear_grid() -> void:
	if _ruler != null:
		for i in range(_ruler.get_child_count() - 1, -1, -1):
			var n = _ruler.get_child(i)
			if n != _ruler_bg:
				n.queue_free()
	if _timeline != null:
		for i in range(_timeline.get_child_count() - 1, -1, -1):
			var n2 = _timeline.get_child(i)
			if n2 != _timeline_bg:
				n2.queue_free()
		# on réinsère le bg au fond
		_timeline.move_child(_timeline_bg, 0)

func _draw_grid(width_px: int) -> void:
	if song == null:
		return

	var beats_per_bar = float(song.time_num)
	var px_per_beat = PX_PER_BEAT_BASE * float(scale)
	var px_per_bar = beats_per_bar * px_per_beat

	# Couleurs séparées
	var bar_col_ruler = rulerLineColor
	var bar_col_tl = timelineBarColor
	var beat_col_tl = timelineBeatColor

	# --- Ruler ---
	if hasRuler and _ruler != null:
		var bars = int(ceil((float(width_px) / px_per_bar))) + 1
		for b in range(bars):
			var x_pos = int(round(float(b) * px_per_bar))
			_add_vline(_ruler, x_pos, RULER_H, bar_col_ruler)
			var lbl = Label.new()
			lbl.text = str(b + 1)	# démarre à 1
			lbl.rect_position = Vector2(x_pos + 2, 0)
			lbl.add_color_override("font_color", rulerFontColor)
			if _ruler_font != null:
				lbl.add_font_override("font", _ruler_font)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ruler.add_child(lbl)

	# --- Timeline ---
	if _timeline != null:
		# Mesures
		var bars2 = int(ceil((float(width_px) / px_per_bar))) + 1
		for b2 in range(bars2):
			var x2 = int(round(float(b2) * px_per_bar))
			_add_vline(_timeline, x2, TIMELINE_H, bar_col_tl)

		# Temps (toutes les battues)
		var total_beats = int(ceil(float(width_px) / px_per_beat)) + 1
		for bt in range(total_beats):
			var is_bar = false
			if beats_per_bar > 0.0:
				is_bar = (bt % int(beats_per_bar) == 0)
			if not is_bar:
				var xb = int(round(float(bt) * px_per_beat))
				_add_vline(_timeline, xb, TIMELINE_H, beat_col_tl)

func _add_vline(parent: Control, x: int, h: int, col: Color) -> void:
	var r = ColorRect.new()
	r.color = col
	r.rect_min_size = Vector2(1, h)
	r.rect_position = Vector2(x, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

# --- Éléments (Notes / Degrees) ---
func _clear_items() -> void:
	_wrappers.clear()
	_wrapper_to_model.clear()
	_selected.clear()
	# Les lignes ont déjà été nettoyées par _clear_grid

func _build_items() -> void:
	if song == null:
		return

	var track = null
	if trackName != "":
		if song.has_method("get_track_by_name"):
			track = song.get_track_by_name(trackName)
	else:
		if song.has_method("get_track"):
			track = song.get_track()

	if track == null:
		return
		
	_track = track
	
	var events = track.get("events")
	if typeof(events) != TYPE_ARRAY:
		return

	var px_per_beat = PX_PER_BEAT_BASE * float(scale)

	# pour ajouter le Meta "index" au wrapper
	var idx_wrapper = 0
	
	
	for i in range(events.size()):
		var e = events[i]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if not e.has("start"):
			continue

		var start_beats = float(e["start"])
		var x = int(round(start_beats * px_per_beat))

		var elem = null
		var view = null
		var is_degree = false

		if e.has("note"):
			elem = e["note"]
			if elem != null and typeof(elem) == TYPE_OBJECT and elem.has_method("get_midi_view"):
				view = elem.get_midi_view(scale)
		elif e.has("degree"):
			elem = e["degree"]
			is_degree = (elem != null and typeof(elem) == TYPE_OBJECT)
			if is_degree:
				if DegreeDisplay == "midi" and elem.has_method("get_midi_view"):
					view = elem.get_midi_view(scale)
				elif DegreeDisplay == "jazzchord" and elem.has_method("get_jazzchord_view"):
					view = elem.get_jazzchord_view(scale, font_path, 16)
						
					
					
				elif DegreeDisplay == "roman" and elem.has_method("get_roman_view"):
					view = elem.get_roman_view(scale,
						rn_view_font_path,
						rn_view_font_size,
						rn_view_font_color,
						Color(1, 1, 1),
						rn_view_root_font_path,
						rn_view_root_font_size,
						rn_view_root_font_color,
						rn_view_scale_font_path,
						rn_view_scale_font_size,
						rn_view_scale_font_color
						)
				elif DegreeDisplay == "keyboard" and elem.has_method("get_keyboard_view"):
					view = elem.get_keyboard_view(scale)
				

#
#		if view == null:
#			continue


		# …
		if view == null:
			continue
		
		 
		# PATCH: rendre les vues non-"midi" cliquables via le wrapper
		# Certaines vues (roman/jazzchord/keyboard) ont mouse_filter=STOP et avalent les clics.
	# PATCH: rendre cliquables les vues Degree non-"midi" via le wrapper
		if is_degree and DegreeDisplay != "midi" and view is Control:
			# On met PASS *récursivement* sur toute la sous-arborescence
			# pour que le Panel wrapper (MOUSE_FILTER_STOP) capte le clic.
			var __stack = [view]
			while __stack.size() > 0:
				var __n = __stack.pop_back()
				if __n is Control:
					__n.mouse_filter = Control.MOUSE_FILTER_PASS
				for __c in __n.get_children():
					if typeof(__c) == TYPE_OBJECT:
						__stack.append(__c)

		# Wrapper cliquable (Panel pour dessiner une bordure)
		var wrapper = Panel.new()
		wrapper.name = "ItemWrapper_" + str(i)
		wrapper.rect_position = Vector2(x, 1)
		
		# Rend le wrapper transparent (sinon Panel a un fond blanc opaque par défaut)
		if _style_unselected != null:
			wrapper.add_stylebox_override("panel", _style_unselected)
		
		# …
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		wrapper.connect("gui_input", self, "_on_item_gui_input", [wrapper])
		wrapper.connect("mouse_entered", self, "_on_item_mouse_entered", [wrapper])
		wrapper.connect("mouse_exited", self, "_on_item_mouse_exited", [wrapper])
		if is_degree and elem != null:
			wrapper.hint_tooltip = elem.to_string()
#
#		# Wrapper cliquable (Panel pour dessiner une bordure)
#		var wrapper = Panel.new()
#		wrapper.name = "ItemWrapper_" + str(i)
#		wrapper.rect_position = Vector2(x, 1)	# décale de 1 px vers le bas

		# on récupère une vraie taille du contenu pour que la bordure soit visible
		var mins = view.get_combined_minimum_size()
		if mins.x < 1:
			mins.x = 1
		if mins.y < 1:
			mins.y = 1
		wrapper.rect_min_size = mins
		wrapper.rect_size = mins

		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP

		# Sélectionnable uniquement si Degree
		wrapper.set_meta("selectable", is_degree)
		wrapper.set_meta("start", e["start"])
		wrapper.set_meta("selected", false)
		wrapper.set_meta("index", idx_wrapper)
		wrapper.set_meta("degree",elem)
		wrapper.set_meta("track_event",e)
		
		idx_wrapper +=1
		
		# Curseur
		if is_degree:
			wrapper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			wrapper.mouse_default_cursor_shape = Control.CURSOR_ARROW

		_timeline.add_child(wrapper)
		view.rect_position = Vector2(0, 0)
		wrapper.add_child(view)
# Overlay de sélection AU-DESSUS (dessiné après la vue)
		var sel = Panel.new()
		sel.name = "Sel"
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sel.add_stylebox_override("panel", _style_selected)
		sel.visible = false
		wrapper.add_child(sel)
		sel.anchor_left = 0
		sel.anchor_top = 0
		sel.anchor_right = 1
		sel.anchor_bottom = 1
		sel.margin_left = 0
		sel.margin_top = 0
		sel.margin_right = 0
		sel.margin_bottom = 0

		# Bind signaux
		#wrapper.connect("gui_input", self, "_on_item_gui_input", [wrapper])
		#wrapper.connect("mouse_entered", self, "_on_item_mouse_entered", [wrapper])
		#wrapper.connect("mouse_exited", self, "_on_item_mouse_exited", [wrapper])

		_wrappers.append(wrapper)
		_wrapper_to_model[wrapper] = elem
		# style "non sélectionné" par défaut
		_apply_selected_alpha(wrapper, false)

# --- Interaction / sélection ---
func _on_item_gui_input(event, wrapper) -> void:
	if typeof(event) == TYPE_OBJECT and event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == BUTTON_LEFT:
			# uniquement si selectable (Degree)
			if not wrapper.get_meta("selectable", false):
				return
			var add = Input.is_key_pressed(KEY_SHIFT)
			if add and multiple_selection_allowed:
				_select_region_to(wrapper)
			else:
				select_only_wrapper(wrapper)
			var elem = _wrapper_to_model.get(wrapper, null)
			var index = _get_index_for_wrapper(wrapper)
			emit_signal("element_clicked", elem,index,wrapper)
		elif mb.pressed and mb.button_index == BUTTON_RIGHT:
			# uniquement si selectable (Degree)
			if not wrapper.get_meta("selectable", false):
				return
			var elem = _wrapper_to_model.get(wrapper, null)
			emit_signal("element_right_clicked", elem,wrapper)
			
func select_only_wrapper(wrapper):
	_selected = {}
	for w in _wrappers:
		if w == wrapper:
			w.set_meta("selected",true)
			_selected[w] = true
		else:
			w.set_meta("selected",false)
		_apply_selected_alpha(w, w.get_meta("selected"))

func select_wrapper(wrapper):
	wrapper.set_meta("selected",true)
	_selected[wrapper] = true
	for w in _wrappers:
		_apply_selected_alpha(w, w.get_meta("selected"))

func _on_item_mouse_entered(wrapper) -> void:
	var elem = _wrapper_to_model.get(wrapper, null)
	emit_signal("element_hovered", elem)

func _on_item_mouse_exited(wrapper) -> void:
	var elem = _wrapper_to_model.get(wrapper, null)
	emit_signal("element_unhovered", elem)

#func _toggle_select(wrapper, additive: bool) -> void:
#	if not wrapper.get_meta("selectable", false):
#		return
#	if not additive:
#		_clear_selection_except(null)
#		for w in _wrappers :
#			w.set_meta("selected",false)
#	var cur = _selected.get(wrapper, false)
#	_selected[wrapper] = not cur
#	#elem = _wrapper_to_model.get(wrapper, null)
#	#_selected_indexes_to_elements[index] = _wrapper_to_model.get(wrapper, null)
#	wrapper.set_meta("selected", true)
#	_apply_selected_alpha(wrapper, _selected[wrapper])
#	_emit_selection()

func _clear_selection_except(keep) -> void:
	for w in _selected.keys():
		if w != keep and _selected[w]:
			_selected[w] = false
			w.set_meta("selected", false)
			_apply_selected_alpha(w, false)

func _apply_selected_alpha(wrapper, selected: bool) -> void:
	var sel = null
	if wrapper != null and wrapper.has_node("Sel"):
		sel = wrapper.get_node("Sel")
	if sel != null:
		sel.visible = selected

func _emit_selection() -> void:
	var arr = []
	for w in _selected.keys():
		if _selected[w]:
			var m = _wrapper_to_model.get(w, null)
			if m != null:
				arr.append(m)
	emit_signal("selection_changed", arr)

func _init_selection_styles() -> void:
	var borderSize:int = 5
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0, 0, 0, 0)
	_style_selected.border_color = selected_border_color
	_style_selected.border_width_left = selection_border_px
	_style_selected.border_width_top = selection_border_px
	_style_selected.border_width_right = selection_border_px
	_style_selected.border_width_bottom = selection_border_px

	_style_selected.corner_radius_top_left = 2
	_style_selected.corner_radius_top_right = 2
	_style_selected.corner_radius_bottom_left = 2
	_style_selected.corner_radius_bottom_right = 2

	_style_unselected = StyleBoxFlat.new()
	_style_unselected.bg_color = Color(0, 0, 0, 0)
	_style_unselected.border_color = Color(0, 0, 0, 0)
	_style_unselected.border_width_left = 0
	_style_unselected.border_width_top = 0
	_style_unselected.border_width_right = 0
	_style_unselected.border_width_bottom = 0

# --- Redessine uniquement la grille ---
func _redraw_grid() -> void:
	var width_px = _compute_width_px()
	_size_sections(width_px)
	_clear_grid()
	_draw_grid(width_px)
	#_vbox.minimum_size_changed()

# --- Resize: recalc traîne & grille ---
func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_update_all()



# --- helpers génériques de click/hover pour n'importe quelle cellule ---
func _make_clickable(ctrl: Control, element) -> void:
	# Rend la cellule interactive quelle que soit la vue (midi/keyboard/roman/…)
	if ctrl == null:
		return
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctrl.focus_mode = Control.FOCUS_NONE
	if not ctrl.is_connected("gui_input", self, "_on_element_gui_input"):
		ctrl.connect("gui_input", self, "_on_element_gui_input", [element])
	if not ctrl.is_connected("mouse_entered", self, "_on_element_mouse_entered"):
		ctrl.connect("mouse_entered", self, "_on_element_mouse_entered", [element])
	if not ctrl.is_connected("mouse_exited", self, "_on_element_mouse_exited"):
		ctrl.connect("mouse_exited", self, "_on_element_mouse_exited", [element])

func _on_element_gui_input(event, element) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		emit_signal("element_clicked", element)
		# si ton code interne maintient une sélection, tu peux l’appeler ici
		# (sinon on se contente du signal) 
		# _select_single(element)  # ← laisse commenté si tu n’as pas cette API

func _on_element_mouse_entered(element) -> void:
	emit_signal("element_hovered", element)

func _on_element_mouse_exited(element) -> void:
	emit_signal("element_unhovered", element)

func get_scroll_px() -> int:
	if _scroll == null:
		return 0
	return int(_scroll.get_h_scrollbar().value)

func get_scroll_beats() -> float:
	# largeur = 12 px * scale par battement (cf. tes vues)
	return float(get_scroll_px()) / float(12 * scale)

func get_scroll_ticks(ticks_per_beat: int) -> int:
	return int(round(get_scroll_beats() * float(ticks_per_beat)))

# Membres (si absent)
var _scroll_tween: Tween = null	# Tween dédié au scroll

func scroll_to_pos(targetPos_in_beats: float = 0, timeInSeconds: float = 1) -> void:
	# 12 px par temps * scale (même convention que tes views)
	var px_per_beat: float = 12.0 * float(scale)
	var target_px: int = int(round(targetPos_in_beats * px_per_beat))
	
	if _scroll == null:
		return
	
	# bornes du scroll
	var hbar = _scroll.get_h_scrollbar()
	var max_px: int = 0
	if hbar != null:
		max_px = int(hbar.max_value)
	
	# clamp pour éviter l'overscroll
	if target_px < 0:
		target_px = 0
	elif target_px > max_px:
		target_px = max_px
	
	# durée <= 0 → saut direct (pas d’anim)
# durée <= 0 → saut direct (pas d’anim)
	if timeInSeconds <= 0.0:
		_scroll.scroll_horizontal = target_px
		# Notifie proprement si le signal existe
		if has_signal("scroll_changed"):
			emit_signal("scroll_changed", int(_scroll.scroll_horizontal))
		return

	
	# prépare/rafraîchit le tween
	if _scroll_tween == null:
		_scroll_tween = Tween.new()
		add_child(_scroll_tween)
	else:
		_scroll_tween.stop_all()
	
	# joli easing
	var from_px: int = int(_scroll.scroll_horizontal)
	_scroll_tween.interpolate_property(
		_scroll, "scroll_horizontal",
		from_px, target_px,
		timeInSeconds,
		Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, 0.0
	)
	
	# optionnel : emettre un signal à la fin
	if not _scroll_tween.is_connected("tween_completed", self, "_on_scroll_tween_completed"):
		_scroll_tween.connect("tween_completed", self, "_on_scroll_tween_completed")
	
	_scroll_tween.start()

func _on_scroll_tween_completed(object, key) -> void:
	if object == _scroll and String(key) == "scroll_horizontal":
		if has_signal("scroll_changed"):
			emit_signal("scroll_changed", int(_scroll.scroll_horizontal))



func _get_index_for_element(element) -> int:
	for i in range(_wrappers.size()):
		var w = _wrappers[i]
		var m = _wrapper_to_model.get(w, null)
		if m == element:
			return i
	return -1

func get_selected_wrappers() -> Array:
	var arr = []
	for w in _wrappers:
		if w.get_meta("selected"):
			arr.append(w)
	return arr
		

func get_wrappers()-> Array:
	return _wrappers

# --- Helpers sélection / indices ---
func _get_index_for_wrapper(wrapper) -> int:
	return _wrappers.find(wrapper)

func _get_selected_indices() -> Array:
	var out = []
	for w in _selected.keys():
		if _selected[w]:
			var i = _wrappers.find(w)
			if i != -1:
				out.append(i)
	return out

func _get_selected_bounds() -> Dictionary:
	var idxs = _get_selected_indices()
	var d = {}
	if idxs.size() == 0:
		d["has"] = false
		return d
	var mn = idxs[0]
	var mx = idxs[0]
	for k in range(1, idxs.size()):
		if idxs[k] < mn:
			mn = idxs[k]
		if idxs[k] > mx:
			mx = idxs[k]
	d["has"] = true
	d["min"] = mn
	d["max"] = mx
	return d


func _select_region_to(wrapper) -> void:
	if wrapper == null:
		return
	var target:int = _get_index_for_wrapper(wrapper)
	if target == -1:
		return

	var bounds:Dictionary = _get_selected_bounds()
	# Si aucune sélection, on fait une sélection simple
	if not bounds.get("has", false):
		_clear_selection_except(null)
		_selected[wrapper] = true
		_apply_selected_alpha(wrapper, true)
		_emit_selection()
		return

	var start_i:int = bounds.get("min", target)
	var end_i:int = bounds.get("max", target)

	if target < start_i:
		start_i = target
	if target > end_i:
		end_i = target

	# La sélection devient une région continue [start_i, end_i]
	_clear_selection_except(null)
	for i in range(start_i, end_i + 1):
		var w = _wrappers[i]
		_selected[w] = true
		w.set_meta("selected", true)
		_apply_selected_alpha(w, true)
	_emit_selection()

func get_track()->Track:
	return _track
	

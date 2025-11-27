extends Control
class_name GuitarChordView

# --- Données à afficher (tu peux aussi appeler set_chord())
export(String) var chord_name = ""
export(int) var base_fret = 1
export(PoolIntArray) var frets = PoolIntArray()
export(PoolIntArray) var fingers = PoolIntArray()
export(Array) var barres = []
export(PoolIntArray) var tuning = PoolIntArray([40,45,50,55,59,64])

# --- Style
export(int) var grid_frets = 5				# nombre de frettes visibles
export(int) var string_spacing = 36
export(int) var fret_spacing = 42
# ⚠️ renommer pour éviter le conflit avec Control.margin_*
export(int) var pad_top = 60
export(int) var pad_bottom = 24
export(int) var pad_left = 36
export(int) var pad_right = 24
export(int) var nut_thickness = 8
export(int) var circle_radius = 13
export(int) var finger_font_size = 18
export(int) var name_font_size = 24
export(Color) var color_grid = Color(0.15,0.15,0.15)
export(Color) var color_text = Color(0.08,0.08,0.08)
export(Color) var color_dot = Color(0.05,0.05,0.05)
export(Color) var color_root = Color(0.85,0.15,0.15)


# --- Fonts (optionnelles). Si null → get_font("font","Label")
export(Font) var font_title = null      # nom d'accord
export(Font) var font_nut = null        # X / 0
export(Font) var font_arrows = null     # < >

# --- Flèches (hors du manche)
export(bool) var enable_navigation = true
export(int) var arrows_outside = 18     # distance du CENTRE de la flèche au bord du manche
export(int) var arrows_gutter = 24      # largeur réservée de chaque côté dans le Control

export(bool) var dedup_ignore_fingers = false	# true => dédup par shape même si doigtés différents


# --- Navigation multi-voicings
signal voicing_index_changed(current, total)
signal midi_notes_changed(notes)	# émis à chaque changement de voicing/symbol
signal voicing_changed(gc)

export(PoolIntArray) var midiNotes = PoolIntArray()	# notes MIDI non muettes, ordre cordes 6→1
var _current_gc = null	# voicing courant (GuitarChord)

var _voicings = []           # liste de GuitarChord
var _voicing_index = -1      # index courant dans _voicings



var _idx = 0
var _nav_left_rect = Rect2()
var _nav_right_rect = Rect2()

func _get_font_title():
	if font_title != null:
		return font_title
	return get_font("font", "Label")

func _get_font_nut():
	if font_nut != null:
		return font_nut
	return get_font("font", "Label")

func _get_font_arrows():
	if font_arrows != null:
		return font_arrows
	return get_font("font", "Label")

func _draw_text_font(p: Vector2, txt: String, col: Color, centered: bool, fnt):
	if fnt == null:
		return
	if centered:
		var w = fnt.get_string_size(txt).x
		var h = fnt.get_height()
		draw_string(fnt, Vector2(p.x - w * 0.5, p.y + h * 0.25), txt, col)
	else:
		draw_string(fnt, p, txt, col)

func _draw_text_center_font(p_center: Vector2, txt: String, col: Color, fnt):
	if fnt == null:
		return
	var size = fnt.get_string_size(txt)
	var w = size.x
	var h = fnt.get_height()
	var descent = fnt.get_descent()
	var x = p_center.x - w * 0.5
	var y = p_center.y + (h * 0.5) - descent
	draw_string(fnt, Vector2(x, y), txt, col)


# appelé par ProgressionGenerator
func set_voicings(a: Array) -> void:
	
	if a != null:
		_voicings = a
	else:
		_voicings = []
	_voicing_index = 0
	_idx = 0
	if _voicings.size() > 0:
		_current_gc = _voicings[0]
		_sync_from_gc()
	else:
		_current_gc = null
		midiNotes = PoolIntArray()
		emit_signal("midi_notes_changed", midiNotes)
	update()

func set_voicing_index(i: int) -> void:
	if _voicings.size() == 0:
		return
	if i < 0:
		i = 0
	if i >= _voicings.size():
		i = _voicings.size() - 1
	_voicing_index = i
	_idx = i
	_current_gc = _voicings[_voicing_index]
	_sync_from_gc()

func _sync_from_gc() -> void:
	if _current_gc == null:
		return
	chord_name = _current_gc.chord_name
	base_fret = _current_gc.base_fret
	frets = _current_gc.frets
	fingers = _current_gc.fingers
	tuning = _current_gc.tuning
	midiNotes = _current_gc.midiNotes()
	emit_signal("midi_notes_changed", midiNotes)
	_update_root_strings()
	update()

func next_voicing():
	if _voicings.size() == 0:
		return
	var n = _voicings.size()
	var i = _idx + 1
	if i >= n:
		return
	_idx = i
	set_chord(_voicings[_idx])
	update()
	emit_signal("voicing_index_changed", _idx, n)

func prev_voicing():
	if _voicings.size() == 0:
		return
	var i = _idx - 1
	if i < 0:
		return
	_idx = i
	set_chord(_voicings[_idx])
	update()
	emit_signal("voicing_index_changed", _idx, _voicings.size())


# --- Interne
var _root_strings = PoolIntArray()

func _ready():
	_update_root_strings()
	minimum_size_changed()
	update()

# Setter pratique


func set_chord(gc):
	# Pose d'abord le voicing courant
	_current_gc = gc

	# Si nul, on vide proprement
	if _current_gc == null:
		chord_name = ""
		base_fret = 1
		frets = PoolIntArray()
		fingers = PoolIntArray()
		barres = []
		_update_root_strings()
		midiNotes = PoolIntArray()
		emit_signal("midi_notes_changed", midiNotes)
		emit_signal("voicing_changed", null)
		minimum_size_changed()
		update()
		return

	# Copie les données d'affichage
	chord_name = _current_gc.chord_name
	base_fret = _current_gc.base_fret
	frets = _current_gc.frets
	fingers = _current_gc.fingers
	barres = _current_gc.barres
	tuning = _current_gc.tuning

	# MAJ des infos dérivées
	_update_root_strings()
	_update_midi_notes()          # <- calcule puis émet le signal avec des notes non vides
	emit_signal("voicing_changed", _current_gc)

	minimum_size_changed()
	update()

func _update_midi_notes():
	# 1) si on a un GuitarChord courant → on lui demande
	if _current_gc != null and _current_gc.has_method("midiNotes"):
		midiNotes = _current_gc.midiNotes()
	else:
		# 2) sinon, calcule depuis nos champs locaux (fallback)
		var out = []
		if frets.size() == 6 and tuning.size() == 6:
			for s in range(6):
				var fr = int(frets[s])
				if fr < 0:
					continue
				var open_midi = int(tuning[s])
				if fr == 0:
					out.append(open_midi)
				else:
					var add = (base_fret - 1) + fr
					out.append(open_midi + add)
		midiNotes = PoolIntArray(out)

	emit_signal("midi_notes_changed", midiNotes)

# petit util si tu veux forcer la réémission juste après t’être connecté
func emit_current_midi_notes():
	emit_signal("midi_notes_changed", midiNotes)
	emit_signal("voicing_changed", _current_gc)


func _update_root_strings():
	# Si on a le voicing courant (avec root_pc potentiellement fixé par le loader), on l'utilise
	if _current_gc != null:
		_root_strings = _current_gc.strings_with_root()
		return

	# Fallback: reconstruit un GuitarChord éphémère depuis les propriétés exposées
	var gc = GuitarChord.new()
	gc.chord_name = chord_name
	gc.base_fret = base_fret
	gc.frets = frets
	gc.fingers = fingers
	gc.tuning = tuning
	_root_strings = gc.strings_with_root()

# --- helpers: géométrie du manche (cohérente partout)
func _board_left() -> float:
	return float(pad_left)
func _board_right() -> float:
	return float(pad_left) + float(string_spacing) * 5.0	# 6 cordes -> 5 intervalles
func _board_top() -> float:
	return float(pad_top)
func _board_bottom() -> float:
	return float(pad_top) + float(fret_spacing) * float(grid_frets)

func get_minimum_size() -> Vector2:
	var w = pad_left + pad_right + string_spacing * 5
	var h = pad_top + pad_bottom + fret_spacing * grid_frets
	return Vector2(w, h)

func _draw():
	# Garde-fous
	if frets.size() != 6:
		return
	if fingers.size() != 6:
		return

	var left = _board_left()
	var right = _board_right()
	var top = _board_top()
	var bottom = _board_bottom()

	# 1) Titre centré au-dessus
	var title_font = _get_font_title()
	var title_y = top - 34
	var title_x = (left + right) * 0.5
	_draw_text_font(Vector2(title_x, title_y), chord_name, color_text, true, title_font)

	# 1) Grille
	# Cordes (6 -> 1) : 6 verticales
	for s in range(6):
		var x = left + float(s) * float(string_spacing)
		draw_line(Vector2(x, top), Vector2(x, bottom), color_grid, 2.0)

	# Frettes horizontales
	for f in range(grid_frets + 1):
		var y = top + float(f) * float(fret_spacing)
		var thick = 2.0
		if base_fret == 1 and f == 0:
			thick = float(nut_thickness)
		draw_line(Vector2(left, y), Vector2(right, y), color_grid, thick)
	
	# base_fret label si > 1 (à gauche, légèrement au-dessus de la 1ère case)
	if base_fret > 1:
		_draw_text(Vector2(left - 28, top + 14), str(base_fret) + "fr", 14, color_text, false)

	# Flèches navigation (discrètes, à L'EXTÉRIEUR du manche)
	_nav_left_rect = Rect2()
	_nav_right_rect = Rect2()
	if enable_navigation and _voicings.size() > 1:
		var a_font = _get_font_arrows()
		if a_font != null:
			var left_glyph = "<"
			var right_glyph = ">"
			var g = a_font.get_string_size(left_glyph)

			# Y: centre de la 3e case
			var y_center = top + float(3) * float(fret_spacing) - float(fret_spacing) * 0.5

			# X: à GAUCHE et à DROITE du manche (hors planche)
			var left_center_x = left - float(arrows_outside)
			var right_center_x = right + float(arrows_outside)

			# Gauche: visible seulement si _idx > 0
			if _idx > 0:
				_draw_text_center_font(Vector2(left_center_x, y_center), left_glyph, color_text, a_font)
				var w = max(12.0, g.x)
				var h = max(12.0, a_font.get_height())
				_nav_left_rect = Rect2(Vector2(left_center_x - w * 0.5, y_center - h * 0.5), Vector2(w, h))
			else:
				_nav_left_rect = Rect2()

			# Droite: visible seulement si _idx < total-1
			if _idx < _voicings.size() - 1:
				_draw_text_center_font(Vector2(right_center_x, y_center), right_glyph, color_text, a_font)
				var w2 = max(12.0, g.x)
				var h2 = max(12.0, a_font.get_height())
				_nav_right_rect = Rect2(Vector2(right_center_x - w2 * 0.5, y_center - h2 * 0.5), Vector2(w2, h2))
			else:
				_nav_right_rect = Rect2()

	# 2) X / 0 par corde (au-dessus du sillet)
	var nut_font = _get_font_nut()
	for s in range(6):
		var x = left + float(s) * float(string_spacing)
		var v = int(frets[s])
		if v < 0:
			_draw_text_font(Vector2(x, top - 16), "X", color_text, true, nut_font)
		elif v == 0 and base_fret == 1:
			var col0 = color_text
			if _root_strings.has(s):
				col0 = color_root
			_draw_text_font(Vector2(x, top - 16), "0", col0, true, nut_font)
			
	# 3) Pastilles doigts
	for s in range(6):
		var fret_rel = int(frets[s])
		if fret_rel <= 0:
			continue
		var x = left + float(s) * float(string_spacing)
		var y = top + float(fret_rel) * float(fret_spacing) - float(fret_spacing) * 0.5
		var is_root = _root_strings.has(s)
		var col = color_dot
		if is_root:
			col = color_root
		draw_circle(Vector2(x, y), float(circle_radius), col)

		var fing = int(fingers[s])
		if fing > 0:
			_draw_text_center(Vector2(x, y), str(fing), Color(1,1,1))


	# 4) Barrés
	for b in barres:
		if typeof(b) != TYPE_DICTIONARY:
			continue
		var fret_rel2 = int(b.get("fret", 0))
		var from_s = int(b.get("from_string", 6))	# 6..1
		var to_s = int(b.get("to_string", 1))
		if fret_rel2 <= 0:
			continue
		var s_min = min(6, max(1, to_s))
		var s_max = min(6, max(1, from_s))
		if s_min > s_max:
			var tmp = s_min
			s_min = s_max
			s_max = tmp
		var x1 = left + float(s_min - 1) * float(string_spacing)
		var x2 = left + float(s_max - 1) * float(string_spacing)
		var yb = top + float(fret_rel2) * float(fret_spacing) - float(fret_spacing) * 0.5
		var r = float(circle_radius) * 0.9
		draw_rect(Rect2(Vector2(x1 - r, yb - r), Vector2((x2 - x1) + 2.0 * r, 2.0 * r)), color_dot, true, 6.0)
		draw_rect(Rect2(Vector2(x1 - r, yb - r), Vector2((x2 - x1) + 2.0 * r, 2.0 * r)), color_grid, false, 2.0)

func _draw_text(p: Vector2, txt: String, size_px: int, col: Color, centered: bool):
	var fnt = get_font("font", "Label")
	if fnt == null:
		return
	if centered:
		var w = fnt.get_string_size(txt).x
		var h = fnt.get_height()
		draw_string(fnt, Vector2(p.x - w * 0.5, p.y + h * 0.25), txt, col)
	else:
		draw_string(fnt, p, txt, col)


func _draw_text_center(p_center: Vector2, txt: String, col: Color):
	var fnt = get_font("font", "Label")
	if fnt == null:
		return
	var size = fnt.get_string_size(txt)
	var w = size.x
	var h = fnt.get_height()
	var descent = fnt.get_descent()
	# baseline centré verticalement
	var x = p_center.x - w * 0.5
	var y = p_center.y + (h * 0.5) - descent
	draw_string(fnt, Vector2(x, y), txt, col)

func _gui_input(ev):
	if not enable_navigation:
		return
	if _voicings.size() <= 1:
		return
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index == BUTTON_LEFT:
			var p = ev.position
			if _nav_left_rect.has_point(p):
				prev_voicing()
				update()
			elif _nav_right_rect.has_point(p):
				next_voicing()
				update()
				


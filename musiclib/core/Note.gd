# Note.gd — Godot 3.x
extends Reference
class_name Note

var midi: int = 60
var velocity: int = 100
var length_beats: float = 1.0
var channel: int = 0

func clone() -> Note:
	# ⚠️ pas de Note.new() ici : utiliser le script courant
	var n = get_script().new()
	n.midi = midi
	n.velocity = velocity
	n.length_beats = length_beats
	n.channel = channel
	return n


func to_dict() -> Dictionary:
	return {
		"midi": int(midi),
		"velocity": int(velocity),
		"length_beats": float(length_beats),
		"channel": int(channel)
	}


func from_dict(data: Dictionary) -> Note:
	var n: Note = get_script().new()
	n.midi = data.get("midi", 60)
	n.velocity = data.get("velocity", 100)
	n.length_beats = data.get("length_beats", 1.0)
	n.channel = data.get("channel", 0)
	return n


func to_string() -> String:
	var s = ""
	s += "Note(midi=%d, velocity=%d, length_beats=%s, channel=%d)" % [
		int(midi),
		int(velocity),
		str(length_beats),
		int(channel)
	]
	return s

func set_length_beats(l):
	length_beats = l

func get_length_beats():
	return length_beats
# Dans Note.gd (Godot 3.x) — Tabs only

func get_midi_view(scale = 1, baseColor: Color = Color(1, 0, 0, 1)) -> Control:
	# 1 temps = 12 px ; hauteur fixe = 128 px
	var lb = 1.0
	if typeof(length_beats) == TYPE_REAL or typeof(length_beats) == TYPE_INT:
		lb = float(length_beats)

	var sc = 1.0
	if typeof(scale) == TYPE_REAL or typeof(scale) == TYPE_INT:
		sc = max(0.1, float(scale))

	var w = int(max(1.0, lb) * 12.0 * sc)
	var h = 128

	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.rect_min_size = Vector2(w, h)
	root.minimum_size_changed()

	# Position Y cohérente avec Degree.get_midi_view (0=haut, 127=bas -> on inverse)
	var mv = clamp(int(midi), 0, 127)
	var y = (h - 1) - mv

	# Couleur en fonction de velocity : baseColor -> blanc
	var vel = clamp(int(velocity), 0, 127)
	var t = float(vel) / 127.0
	var col = baseColor.linear_interpolate(Color(1, 0, 0, 1), t)

	var line = ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = col
	line.rect_position = Vector2(0, y)
	line.rect_min_size = Vector2(w, 1)	# ajuste à 2 si tu veux une ligne plus épaisse
	root.add_child(line)

	return root

# MidiCC.gd — Godot 3.x
extends Reference
class_name MidiCC

# 0..127 Controller Number
var controller: int = 1 setget set_controller, get_controller
# 0..127 Value
var value: int = 0 setget set_value, get_value
# 0..15 Channel
var channel: int = 0 setget set_channel, get_channel


func clone() -> MidiCC:
	# ⚠️ pas de MidiCC.new() ici : utiliser le script courant
	var cc: MidiCC = get_script().new()
	cc.controller = controller
	cc.value = value
	cc.channel = channel
	return cc


func to_dict() -> Dictionary:
	return {
		"controller": int(controller),
		"value": int(value),
		"channel": int(channel)
	}


func from_dict(data: Dictionary) -> MidiCC:
	var cc: MidiCC = get_script().new()
	cc.controller = data.get("controller", 1)
	cc.value = data.get("value", 0)
	cc.channel = data.get("channel", 0)
	return cc


# --- API ---
func to_midi_event_dict(tick: int = 0) -> Dictionary:
	var ch = int(clamp(channel, 0, 15))
	var ctrl = int(clamp(controller, 0, 127))
	var val = int(clamp(value, 0, 127))
	return {
		"tick": int(tick),
		"status": (0xB0 | ch),   # Control Change + canal (bits 0..3)
		"data1": ctrl,            # controller number
		"data2": val             # controller value
	}

func to_string() -> String:
	var ch = int(clamp(channel, 0, 15))
	var ctrl = int(clamp(controller, 0, 127))
	var val = int(clamp(value, 0, 127))
	return "MidiCC(channel=%d, controller=%d, value=%d)" % [ch, ctrl, val]


# --- Setters/Getters ---
func set_controller(c):
	controller = clamp(int(c), 0, 127)

func get_controller() -> int:
	return controller

func set_value(v):
	value = clamp(int(v), 0, 127)

func get_value() -> int:
	return value

func set_channel(c):
	channel = clamp(int(c), 0, 15)

func get_channel() -> int:
	return channel

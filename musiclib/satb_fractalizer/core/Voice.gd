extends Node

const TAG = "Voice"
const Constants = preload("res://addons/musiclib/satb_fractalizer/core/Constants.gd")

var pitch              # int (MIDI pitch)
var role               # String (chord_tone, passing_tone, neighbor_tone, etc.)
var technique          # String (technique ID) or null
var direction          # String "ascending", "descending", "static"
var locked             # bool (if true, this note should not be modified)
var metadata           # Dictionary (additional info)

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(p, r, t, d, l, m):
	pitch = p
	role = r if r else Constants.ROLE_CHORD_TONE
	technique = t
	direction = d if d else Constants.DIRECTION_STATIC
	locked = l if l != null else false
	metadata = m if m else {}

# =============================================================================
# DUPLICATION
# =============================================================================

func copy():
	var new_voice = get_script().new(
		pitch,
		role,
		technique,
		direction,
		locked,
		metadata.duplicate()
	)
	return new_voice

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict():
	return {
		"pitch": pitch,
		"role": role,
		"technique": technique,
		"direction": direction,
		"locked": locked,
		"metadata": metadata.duplicate()
	}

static func from_dict(data):
	var v = load("res://addons/musiclib/satb_fractalizer/core/Voice.gd").new(
		data.pitch,
		data.get("role", Constants.ROLE_CHORD_TONE),
		data.get("technique", null),
		data.get("direction", Constants.DIRECTION_STATIC),
		data.get("locked", false),
		data.get("metadata", {})
	)
	return v

# =============================================================================
# DEBUG
# =============================================================================

func to_string():
	return "Voice(pitch=" + str(pitch) + ", role=" + role + ", technique=" + str(technique) + ", locked=" + str(locked) + ")"

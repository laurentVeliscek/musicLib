extends Node

const TAG = "Chord"
const Constants = preload("res://addons/musiclib/satb_fractalizer/core/Constants.gd")

var id                 # int (unique chord ID, typically index in progression)
var start_time         # float (beats)
var duration           # float (beats)
var voices             # Dictionary {S: Voice, A: Voice, T: Voice, B: Voice}
var scale_context      # ScaleContext
var kind               # String ("diatonic", "N6", "It+6", etc.)
var techniques_applied # Array [technique_ids]
var metadata           # Dictionary (additional info)

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(chord_id, start, dur, v, scale, k):
	id = chord_id
	start_time = start
	duration = dur
	voices = v if v else {}
	scale_context = scale
	kind = k if k else "diatonic"
	techniques_applied = []
	metadata = {}

# =============================================================================
# TIME CALCULATIONS
# =============================================================================

func get_end_time():
	return start_time + duration

# =============================================================================
# VOICE ACCESS
# =============================================================================

func get_voice_pitch(voice_id):
	if voices.has(voice_id):
		return voices[voice_id].pitch
	else:
		LogBus.warn(TAG, "get_voice_pitch: voice " + voice_id + " not found in chord " + str(id))
		return null

func get_voice(voice_id):
	if voices.has(voice_id):
		return voices[voice_id]
	else:
		LogBus.warn(TAG, "get_voice: voice " + voice_id + " not found in chord " + str(id))
		return null

func set_voice_pitch(voice_id, new_pitch):
	if voices.has(voice_id):
		voices[voice_id].pitch = new_pitch
	else:
		LogBus.error(TAG, "set_voice_pitch: voice " + voice_id + " not found in chord " + str(id))

# =============================================================================
# DUPLICATION
# =============================================================================

func copy():
	var new_voices = {}
	for voice_id in voices:
		new_voices[voice_id] = voices[voice_id].copy()

	var new_chord = get_script().new(
		id,
		start_time,
		duration,
		new_voices,
		scale_context,  # ScaleContext is shared (not duplicated)
		kind
	)
	new_chord.techniques_applied = techniques_applied.duplicate()
	new_chord.metadata = metadata.duplicate()

	return new_chord

# =============================================================================
# VALIDATION
# =============================================================================

func validate_voices():
	# Check that all 4 voices exist and are in order (S >= A >= T >= B)
	var required_voices = Constants.VOICES

	for v in required_voices:
		if not voices.has(v):
			LogBus.error(TAG, "validate_voices: missing voice " + v + " in chord " + str(id))
			return false

	var s_pitch = voices[Constants.VOICE_SOPRANO].pitch
	var a_pitch = voices[Constants.VOICE_ALTO].pitch
	var t_pitch = voices[Constants.VOICE_TENOR].pitch
	var b_pitch = voices[Constants.VOICE_BASS].pitch

	if not (s_pitch >= a_pitch and a_pitch >= t_pitch and t_pitch >= b_pitch):
		LogBus.warn(TAG, "validate_voices: voice crossing detected in chord " + str(id) + " (S=" + str(s_pitch) + ", A=" + str(a_pitch) + ", T=" + str(t_pitch) + ", B=" + str(b_pitch) + ")")
		return false

	return true

# =============================================================================
# DEBUG
# =============================================================================

func to_string():
	var voices_str = "{"
	for v in Constants.VOICES:
		if voices.has(v):
			voices_str += v + ":" + str(voices[v].pitch) + " "
	voices_str += "}"

	return "Chord(id=" + str(id) + ", t=" + str(start_time) + ", dur=" + str(duration) + ", voices=" + voices_str + ", kind=" + kind + ")"

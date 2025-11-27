extends Node

const TAG = "ScaleContext"

var root:int              # int (MIDI pitch, e.g., 60 = C4)
var steps              # Array [0, 2, 4, 5, 7, 9, 11] for major
var alterations        # Dictionary {degree: alteration} e.g., {4: 1} for #4
var scale_name         # String "major", "minor", "harmonic_minor", etc.
var real_scale         # Array [pitches in semitones] calculated with alterations

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(midi_root, scale_array, key_alterations, name):
	root = midi_root
	steps = scale_array.duplicate()
	alterations = key_alterations.duplicate() if key_alterations else {}
	scale_name = name if name else "unknown"
	real_scale = _build_real_scale()

	LogBus.debug(TAG, "Created ScaleContext: root=" + str(root) + " name=" + scale_name + " real_scale=" + str(real_scale))

# =============================================================================
# BUILD REAL SCALE WITH ALTERATIONS
# =============================================================================

func _build_real_scale():
	var result = []

	for i in range(steps.size()):
		var step = int(steps[i])  # Force int (JSON parsing may create floats)
		var degree = i  # 0-based degree (0=tonic, 1=2nd, etc.)

		# Check if this degree has an alteration
		if alterations.has(degree):
			step += alterations[degree]
			step = int(step)  # Force int after addition (alterations may be floats)

		result.append(step)

	return result

# =============================================================================
# DIATONIC CHECKS
# =============================================================================

func is_diatonic(pitch):
	var pitch_class = int(pitch) % 12
	var root_class = int(root) % 12
	var relative_pitch = (pitch_class - root_class + 12) % 12

	var result = real_scale.has(relative_pitch)

	# Debug logging
	if not result:
		LogBus.warn(TAG, "is_diatonic FALSE: pitch=" + str(pitch) + " pitch_class=" + str(pitch_class) + " root=" + str(root) + " root_class=" + str(root_class) + " relative_pitch=" + str(relative_pitch) + " real_scale=" + str(real_scale))

	return result

func get_scale_degree(pitch:int):
	var pitch_class = pitch % 12
	var root_class = root % 12
	var relative_pitch = (pitch_class - root_class + 12) % 12

	var idx = real_scale.find(relative_pitch)
	if idx == -1:
		return -1  # Not in scale

	return idx + 1  # 1-based degree (1=tonic, 2=2nd, etc.)

# =============================================================================
# NEIGHBOR PITCHES
# =============================================================================

func get_neighbor_pitches(anchor_pitch:int, direction):
	# Returns the diatonic neighbor pitch (upper or lower)
	# direction: "upper" or "lower"

	if not is_diatonic(anchor_pitch):
		LogBus.warn(TAG, "get_neighbor_pitches: anchor_pitch " + str(anchor_pitch) + " is not diatonic")
		return null

	var degree = get_scale_degree(anchor_pitch)
	if degree == -1:
		return null

	var target_degree = degree
	if direction == "upper":
		target_degree = degree + 1
		if target_degree > real_scale.size():
			target_degree = 1  # Wrap to tonic of next octave
	elif direction == "lower":
		target_degree = degree - 1
		if target_degree < 1:
			target_degree = real_scale.size()  # Wrap to last degree of previous octave
	else:
		LogBus.error(TAG, "get_neighbor_pitches: invalid direction " + str(direction))
		return null

	# Calculate the target pitch
	# We need to stay in the same octave region as anchor_pitch
	var root_class = root % 12
	var anchor_class = anchor_pitch % 12
	var octave_base = anchor_pitch - anchor_class  # Base of the octave containing anchor_pitch
	var target_step = real_scale[target_degree - 1]
	var target_pitch = octave_base + root_class + target_step

	# Adjust octave if necessary
	if direction == "upper" and target_pitch <= anchor_pitch:
		target_pitch += 12
	elif direction == "lower" and target_pitch >= anchor_pitch:
		target_pitch -= 12

	return target_pitch

# =============================================================================
# PASSING PITCHES
# =============================================================================

func get_passing_pitches(from_pitch, to_pitch):
	# Returns Array of diatonic passing pitches between from_pitch and to_pitch
	# Ex: C (60) -> E (64) returns [D (62)]
	# Ex: C (60) -> F (65) returns [D (62), E (64)]

	if from_pitch == to_pitch:
		return []

	var direction_ascending = to_pitch > from_pitch
	var result = []

	var current = from_pitch
	while true:
		if direction_ascending:
			current = get_neighbor_pitches(current, "upper")
		else:
			current = get_neighbor_pitches(current, "lower")

		if current == null:
			break

		if direction_ascending and current >= to_pitch:
			break
		elif not direction_ascending and current <= to_pitch:
			break

		result.append(current)

	return result

# =============================================================================
# CHROMATIC PASSING PITCH
# =============================================================================

func get_chromatic_passing_pitch(from_pitch, to_pitch):
	# Returns the chromatic passing note between from_pitch and to_pitch
	# Only works if interval is a whole tone (2 semitones)
	# Ex: C (60) -> D (62) returns C# (61)

	var interval = abs(to_pitch - from_pitch)

	if interval != 2:
		LogBus.warn(TAG, "get_chromatic_passing_pitch: interval " + str(interval) + " is not a whole tone")
		return null

	if to_pitch > from_pitch:
		return from_pitch + 1
	else:
		return from_pitch - 1

# =============================================================================
# INTERVAL CALCULATION
# =============================================================================

func get_interval_semitones(pitch1, pitch2):
	return abs(pitch2 - pitch1)

func is_conjoint_motion(pitch1, pitch2):
	var interval = get_interval_semitones(pitch1, pitch2)
	return interval == 1 or interval == 2

# =============================================================================
# DEBUG
# =============================================================================

func to_string():
	return "ScaleContext(root=" + str(root) + ", name=" + scale_name + ", steps=" + str(steps) + ", alterations=" + str(alterations) + ", real=" + str(real_scale) + ")"

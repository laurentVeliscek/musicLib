extends Node

const TAG2 = "TechniqueBase"
const Constants = preload("res://addons/musiclib/satb_fractalizer/core/Constants.gd")
const Voice = preload("res://addons/musiclib/satb_fractalizer/core/Voice.gd")
const Chord = preload("res://addons/musiclib/satb_fractalizer/core/Chord.gd")
const VoiceLeading = preload("res://addons/musiclib/satb_fractalizer/utils/VoiceLeading.gd")
const RhythmPattern = preload("res://addons/musiclib/satb_fractalizer/planner/RhythmPattern.gd")

# =============================================================================
# ABSTRACT METHOD (must be overridden in subclass)
# =============================================================================

func apply(progression, params):
	LogBus.error(TAG2, "apply() must be overridden in subclass")
	return progression

# =============================================================================
# UTILITY: SELECT CHORD PAIR
# =============================================================================

func _select_chord_pair(progression, window, strategy, exclude_decorative_pairs = false):
	# window: {"start": float, "end": float}
	# strategy: "earliest" or "longest"
	# exclude_decorative_pairs: if true, only consider pairs of structural (non-decorative) chords

	var pairs = progression.get_chord_pairs_in_window(window.start, window.end, exclude_decorative_pairs)

	if pairs.empty():
		if exclude_decorative_pairs:
			LogBus.warn(TAG2, "_select_chord_pair: no structural chord pairs in window [" + str(window.start) + ", " + str(window.end) + "]")
		else:
			LogBus.warn(TAG2, "_select_chord_pair: no chord pairs in window [" + str(window.start) + ", " + str(window.end) + "]")
		return null

	var selected = progression.select_chord_pair(pairs, strategy)
	return selected

# =============================================================================
# UTILITY: CHOOSE RHYTHM PATTERN
# =============================================================================

func _choose_rhythm_pattern(n_cells, progression, technique_id, triplet_allowed):
	var rhythm_selector = RhythmPattern.new()

	var pattern = rhythm_selector.choose_rhythm_pattern(
		n_cells,
		progression.time_grid.grid_unit,
		Constants.DEFAULT_MIN_NOTE_DURATION,
		technique_id,
		triplet_allowed,
		[],  # beat_positions (TODO: compute from time_grid)
		{}   # params
	)

	return pattern

# =============================================================================
# UTILITY: CREATE NEW CHORDS FROM PATTERN
# =============================================================================

func _create_chords_from_pattern(chord_a, chord_b, pattern, voice_id, pitches, technique_id, role, time_grid, generation_depth, start_time):
	# pattern: {"pattern": [durations...], "triplet": bool}
	# pitches: Array of MIDI pitches (same length as pattern.pattern)
	# time_grid: TimeGrid for beat strength calculation
	# generation_depth: int, how many fractalizer passes have been applied
	# start_time: float, explicit start time for the first decorative chord (typically effective_start from pair_info)
	# Returns: Array of Chord objects

	var new_chords = []
	var durations = pattern.pattern
	var current_time = start_time  # Use explicit start_time instead of chord_a.start_time

	for i in range(durations.size()):
		var dur = durations[i]
		var pitch = pitches[i]

		# Create new voices (copy from chord_a, modify target voice)
		var new_voices = {}
		for v in Constants.VOICES:
			new_voices[v] = chord_a.voices[v].copy()

		# Modify target voice
		new_voices[voice_id].pitch = pitch
		new_voices[voice_id].role = role
		new_voices[voice_id].technique = technique_id

		# Determine direction
		if i < durations.size() - 1:
			var next_pitch = pitches[i + 1]
			if next_pitch > pitch:
				new_voices[voice_id].direction = Constants.DIRECTION_ASCENDING
			elif next_pitch < pitch:
				new_voices[voice_id].direction = Constants.DIRECTION_DESCENDING
			else:
				new_voices[voice_id].direction = Constants.DIRECTION_STATIC

		# Enrich voice metadata
		var beat_strength = time_grid.get_beat_strength(current_time) if time_grid else Constants.BEAT_WEAK
		var scale_degree = chord_a.scale_context.get_scale_degree(pitch) if chord_a.scale_context else -1

		new_voices[voice_id].metadata = {
			"beat_strength": beat_strength,
			"scale_degree": scale_degree,
			"generated_at_time": current_time,
			"from_chord": chord_a.id,
			"to_chord": chord_b.id,
			"pattern_index": i,
			"pattern_total": durations.size()
		}

		# Create new chord
		var new_chord = Chord.new(
			-1,  # ID will be reassigned later
			current_time,
			dur,
			new_voices,
			chord_a.scale_context,  # Inherit scale from chord_a
			"decorative"  # kind
		)
		new_chord.techniques_applied.append(technique_id)

		# Enrich chord metadata
		new_chord.metadata = {
			"generated_by": technique_id,
			"generation_depth": generation_depth,
			"comments": technique_id + " in " + voice_id + " between chord " + str(chord_a.id) + " and " + str(chord_b.id),
			"source_chord_a": chord_a.id,
			"source_chord_b": chord_b.id,
			"modified_voice": voice_id,
			"triplet": pattern.get("triplet", false)
		}

		new_chords.append(new_chord)
		current_time += dur

	return new_chords

# =============================================================================
# UTILITY: VALIDATE VOICE PERMISSIONS
# =============================================================================

func _validate_permissions(progression, voice_id, chord_indices):
	# Check if voice_id is modifiable in all chords at chord_indices

	# For now, simplified: check voice_policy if it exists
	if progression.voice_policy.has(voice_id):
		var policy = progression.voice_policy[voice_id]
		if policy.has("modifiable") and not policy.modifiable:
			LogBus.warn(TAG2, "_validate_permissions: voice " + voice_id + " is not modifiable")
			return false

	# Check if voices are locked in the chords
	for idx in chord_indices:
		var chord = progression.get_chord_at_index(idx)
		if chord and chord.voices.has(voice_id):
			if chord.voices[voice_id].locked:
				LogBus.warn(TAG2, "_validate_permissions: voice " + voice_id + " is locked in chord " + str(idx))
				return false

	return true

# =============================================================================
# UTILITY: VALIDATE NCT PITCHES
# =============================================================================

func _validate_nct_pitches(progression, new_chords, voice_id, original_pitch):
	# Validate range and voice crossing for all new chords

	for chord in new_chords:
		var new_pitch = chord.voices[voice_id].pitch

		# Get adjacent voice pitches at this time
		var adjacent = VoiceLeading._get_adjacent_voices(chord, voice_id)

		# Validate range
		var range_check = VoiceLeading.validate_range(voice_id, new_pitch, original_pitch, adjacent)
		if not range_check.valid:
			LogBus.warn(TAG2, "_validate_nct_pitches: " + range_check.reason)
			return false

		# Validate voice crossing
		var s = chord.voices[Constants.VOICE_SOPRANO].pitch
		var a = chord.voices[Constants.VOICE_ALTO].pitch
		var t = chord.voices[Constants.VOICE_TENOR].pitch
		var b = chord.voices[Constants.VOICE_BASS].pitch

		var crossing_check = VoiceLeading.check_voice_crossing(s, a, t, b)
		if not crossing_check.valid:
			LogBus.warn(TAG2, "_validate_nct_pitches: " + crossing_check.reason)
			return false

	return true

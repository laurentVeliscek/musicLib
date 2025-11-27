extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "Pedal"

# =============================================================================
# PEDAL
# =============================================================================
# A sustained note held constant while harmonies change
# The pedal note must be diatonic in ALL chords being traversed
# Pattern: pedal_pitch sustained throughout the window
# =============================================================================

func apply(progression, params):
	LogBus.info(TAG, "Applying pedal technique")

	# Extract params
	var window = params.get("time_window", {"start": 0.0, "end": 2.0})
	var voice_id = params.get("voice", Constants.VOICE_SOPRANO)
	var strategy = params.get("pair_selection_strategy", Constants.STRATEGY_EARLIEST)
	var triplet_allowed = params.get("triplet_allowed", Constants.DEFAULT_TRIPLET_ALLOWED)
	var exclude_decorative_pairs = params.get("exclude_decorative_pairs", false)

	# 1. Select chord pair
	var pair_info = _select_chord_pair(progression, window, strategy, exclude_decorative_pairs)
	if not pair_info:
		LogBus.warn(TAG, "No chord pair found in window")
		return progression

	var from_idx = pair_info.from_index
	var to_idx = pair_info.to_index

	# 2. Validate permissions
	if not _validate_permissions(progression, voice_id, [from_idx, to_idx]):
		LogBus.warn(TAG, "Voice " + voice_id + " not modifiable")
		return progression

	var chord_a = progression.get_chord_at_index(from_idx)
	var chord_b = progression.get_chord_at_index(to_idx)

	# 3. Get pitches
	var from_pitch = chord_a.get_voice_pitch(voice_id)
	var to_pitch = chord_b.get_voice_pitch(voice_id)

	# For pedal, we need to find a pitch that is diatonic in ALL chords between from_idx and to_idx
	# Try using from_pitch as the pedal note
	var pedal_pitch = from_pitch

	# 4. Validate that pedal_pitch is diatonic in ALL chords in the span
	var all_chords_in_span = []
	for i in range(from_idx, to_idx + 1):
		var chord = progression.get_chord_at_index(i)
		if chord:
			all_chords_in_span.append(chord)

	# Check if pedal_pitch is diatonic in all chords
	var is_valid_pedal = true
	for chord in all_chords_in_span:
		if not chord.scale_context.is_diatonic(pedal_pitch):
			is_valid_pedal = false
			LogBus.debug(TAG, "Pedal pitch " + str(pedal_pitch) + " is not diatonic in chord at " + str(chord.start_time))
			break

	if not is_valid_pedal:
		# Try to_pitch as alternative
		pedal_pitch = to_pitch
		is_valid_pedal = true
		for chord in all_chords_in_span:
			if not chord.scale_context.is_diatonic(pedal_pitch):
				is_valid_pedal = false
				break

	if not is_valid_pedal:
		LogBus.warn(TAG, "No valid pedal pitch found that is diatonic in all chords")
		return progression

	LogBus.debug(TAG, "Pedal: sustaining pitch " + str(pedal_pitch) + " across " + str(all_chords_in_span.size()) + " chords")

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 2:
		LogBus.warn(TAG, "Span too small for pedal (n_cells=" + str(n_cells) + ")")
		return progression

	# For pedal, we create a single sustained note
	# Or we could create multiple chords all with the same pitch
	# Let's create a single chord that spans the entire duration
	var pattern = {
		"pattern": [span],
		"triplet": false
	}
	var pitches = [pedal_pitch]

	# 6. Create new chords
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a,
		chord_b,
		pattern,
		voice_id,
		pitches,
		Constants.TECHNIQUE_PEDAL,
		Constants.ROLE_PEDAL,
		progression.time_grid,
		generation_depth,
		pair_info.effective_start  # Pass explicit start time
	)

	# 7. Validate NCT pitches
	if not _validate_nct_pitches(progression, new_chords, voice_id, from_pitch):
		LogBus.warn(TAG, "NCT validation failed")
		return progression

	# 8. Insert new chords
	if not progression.insert_chords_between(from_idx, to_idx, new_chords):
		LogBus.error(TAG, "Failed to insert chords")
		return progression

	# 9. Log success
	LogBus.info(TAG, "Successfully applied pedal: " + str(new_chords.size()) + " chords inserted")

	return progression

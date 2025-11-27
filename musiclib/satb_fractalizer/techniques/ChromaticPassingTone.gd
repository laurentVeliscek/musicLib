extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "ChromaticPassingTone"

# =============================================================================
# CHROMATIC PASSING TONE TECHNIQUE (§5.2 of spec)
# =============================================================================
# - Beat strength: WEAK
# - Motion: conjoint chromatic
# - Interval: requires whole tone (2 semitones) between from_pitch and to_pitch
# - Creates a single chromatic passing note between the two pitches
# - Example: C (60) → C# (61) → D (62)

func apply(progression, params):
	LogBus.info(TAG, "Applying chromatic_passing_tone technique")

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

	if from_pitch == to_pitch:
		LogBus.warn(TAG, "Chromatic passing tone requires different pitches (from=" + str(from_pitch) + ", to=" + str(to_pitch) + ")")
		return progression

	# 4. Check interval (must be whole tone = 2 semitones)
	var interval = abs(to_pitch - from_pitch)
	if interval != 2:
		LogBus.warn(TAG, "Chromatic passing tone requires whole tone interval (got " + str(interval) + " semitones)")
		return progression

	# 5. Calculate chromatic passing pitch
	var scale = chord_a.scale_context
	var chromatic_pitch = scale.get_chromatic_passing_pitch(from_pitch, to_pitch)

	if chromatic_pitch == null:
		LogBus.warn(TAG, "No chromatic passing pitch found between " + str(from_pitch) + " and " + str(to_pitch))
		return progression

	LogBus.debug(TAG, "Found chromatic passing pitch: " + str(chromatic_pitch))

	# 6. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 1:
		LogBus.warn(TAG, "Not enough cells for chromatic passing tone (need at least 1, got " + str(n_cells) + ")")
		return progression

	# 7. Create rhythm pattern with exactly 1 duration (we insert 1 chromatic note)
	# The chromatic note extends from chord_a to chord_b
	var rhythm_pattern = {
		"pattern": [n_cells * progression.time_grid.grid_unit],
		"triplet": false
	}

	# 8. Create pitches array: just the chromatic pitch
	var pitches = [chromatic_pitch]

	# 9. Create chords from pattern
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a, chord_b, rhythm_pattern, voice_id, pitches,
		Constants.TECHNIQUE_CHROMATIC_PASSING_TONE,
		Constants.ROLE_CHROMATIC_PASSING_TONE,
		progression.time_grid,
		generation_depth,
		pair_info.effective_start  # Pass explicit start time
	)

	# 10. Validate NCT pitches
	if not _validate_nct_pitches(progression, new_chords, voice_id, from_pitch):
		LogBus.warn(TAG, "NCT pitches validation failed")
		return progression

	# 11. Insert new chords
	if not progression.insert_chords_between(from_idx, to_idx, new_chords):
		LogBus.warn(TAG, "Failed to insert chromatic passing tone chords")
		return progression

	LogBus.info(TAG, "Successfully applied chromatic_passing_tone: " + str(new_chords.size()) + " chords inserted")
	return progression

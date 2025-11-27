extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "Appoggiatura"

# =============================================================================
# APPOGGIATURA TECHNIQUE (§5.6 of spec)
# =============================================================================
# - Beat strength: STRONG (critical difference!)
# - Motion: conjoint, can be ascending or descending
# - Preparation: not required (can arrive unprepared)
# - Resolution: must resolve by step to a chord tone
# - Rhythm preference: long-short (tension-resolution)

func apply(progression, params):
	LogBus.info(TAG, "Applying appoggiatura technique")

	# Extract params
	var window = params.get("time_window", {"start": 0.0, "end": 2.0})
	var voice_id = params.get("voice", Constants.VOICE_SOPRANO)
	var strategy = params.get("pair_selection_strategy", Constants.STRATEGY_EARLIEST)
	var triplet_allowed = params.get("triplet_allowed", Constants.DEFAULT_TRIPLET_ALLOWED)
	var exclude_decorative_pairs = params.get("exclude_decorative_pairs", false)
	var direction = params.get("appoggiatura_direction", "upper")  # "upper" or "lower"

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

	# Appoggiatura: dissonance resolves to to_pitch
	# The appoggiatura note is a neighbor of to_pitch

	# 4. Calculate appoggiatura pitch (neighbor of resolution note)
	# NCT always uses the previous chord's scale context
	var scale = chord_a.scale_context
	var appoggiatura_pitch = scale.get_neighbor_pitches(to_pitch, direction)

	if appoggiatura_pitch == null:
		LogBus.warn(TAG, "No diatonic neighbor found for resolution " + str(to_pitch) + " in direction " + direction)
		return progression

	LogBus.debug(TAG, "Appoggiatura pitch: " + str(appoggiatura_pitch) + " resolving to " + str(to_pitch))

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 2:
		LogBus.warn(TAG, "Span too small for subdivision (n_cells=" + str(n_cells) + ")")
		return progression

	var pattern = _choose_rhythm_pattern(n_cells, progression, Constants.TECHNIQUE_APPOGGIATURA, triplet_allowed)
	if not pattern:
		LogBus.warn(TAG, "No rhythm pattern found for n_cells=" + str(n_cells))
		return progression

	# 6. Create pitches array
	var note_count = pattern.pattern.size()
	var pitches = []

	# Simple case: 2 notes (appoggiatura → resolution)
	# Ideal: first note longer than second (tension-resolution)
	if note_count == 2:
		pitches = [appoggiatura_pitch, to_pitch]

	# 3 notes: from_pitch → appoggiatura → resolution
	elif note_count == 3:
		pitches = [from_pitch, appoggiatura_pitch, to_pitch]

	# 4+ notes: fill with intermediate steps
	elif note_count >= 4:
		pitches.append(from_pitch)
		pitches.append(appoggiatura_pitch)
		for i in range(note_count - 3):
			pitches.append(appoggiatura_pitch)
		pitches.append(to_pitch)

	else:
		LogBus.warn(TAG, "Unexpected note_count=" + str(note_count))
		return progression

	# 7. Create new chords
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a,
		chord_b,
		pattern,
		voice_id,
		pitches,
		Constants.TECHNIQUE_APPOGGIATURA,
		Constants.ROLE_APPOGGIATURA,
		progression.time_grid,
		generation_depth,
		pair_info.effective_start  # Pass explicit start time
	)

	# 8. Validate NCT pitches
	if not _validate_nct_pitches(progression, new_chords, voice_id, from_pitch):
		LogBus.warn(TAG, "NCT validation failed")
		return progression

	# 9. Insert new chords
	if not progression.insert_chords_between(from_idx, to_idx, new_chords):
		LogBus.error(TAG, "Failed to insert chords")
		return progression

	# 10. Log success
	LogBus.info(TAG, "Successfully applied appoggiatura: " + str(new_chords.size()) + " chords inserted")

	return progression

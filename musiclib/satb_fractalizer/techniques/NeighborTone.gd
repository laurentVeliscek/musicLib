extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "NeighborTone"

# =============================================================================
# NEIGHBOR TONE / BRODERIE TECHNIQUE (§5.4 of spec)
# =============================================================================
# - Beat strength: WEAK
# - Motion: conjoint, returns to same note
# - Types: upper or lower neighbor
# - Pattern: anchor → neighbor → anchor

func apply(progression, params):
	LogBus.info(TAG, "Applying neighbor_tone technique")

	# Extract params
	var window = params.get("time_window", {"start": 0.0, "end": 2.0})
	var voice_id = params.get("voice", Constants.VOICE_SOPRANO)
	var strategy = params.get("pair_selection_strategy", Constants.STRATEGY_EARLIEST)
	var triplet_allowed = params.get("triplet_allowed", Constants.DEFAULT_TRIPLET_ALLOWED)
	var exclude_decorative_pairs = params.get("exclude_decorative_pairs", false)
	var neighbor_direction = params.get("neighbor_direction", "upper")  # "upper" or "lower"

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

	# Neighbor tone requires same pitch (or very close)
	if from_pitch != to_pitch:
		LogBus.warn(TAG, "Neighbor tone requires same pitch (from=" + str(from_pitch) + ", to=" + str(to_pitch) + ")")
		return progression

	# 4. Calculate neighbor pitch using scale context
	var scale = chord_a.scale_context
	var neighbor_pitch = scale.get_neighbor_pitches(from_pitch, neighbor_direction)

	if neighbor_pitch == null:
		LogBus.warn(TAG, "No diatonic neighbor found for " + str(from_pitch) + " in direction " + neighbor_direction)
		return progression

	LogBus.debug(TAG, "Found neighbor pitch: " + str(neighbor_pitch) + " (" + neighbor_direction + ")")

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 2:
		LogBus.warn(TAG, "Span too small for subdivision (n_cells=" + str(n_cells) + ")")
		return progression

	var pattern = _choose_rhythm_pattern(n_cells, progression, Constants.TECHNIQUE_NEIGHBOR_TONE, triplet_allowed)
	if not pattern:
		LogBus.warn(TAG, "No rhythm pattern found for n_cells=" + str(n_cells))
		return progression

	# 6. Create pitches array
	var note_count = pattern.pattern.size()
	var pitches = []

	# Simple case: 2 notes (anchor → neighbor)
	if note_count == 2:
		pitches = [from_pitch, neighbor_pitch]

	# 3 notes: anchor → neighbor → anchor (ideal for broderie)
	elif note_count == 3:
		pitches = [from_pitch, neighbor_pitch, from_pitch]

	# 4+ notes: anchor → neighbor → neighbor → anchor
	elif note_count >= 4:
		pitches.append(from_pitch)
		for i in range(note_count - 2):
			pitches.append(neighbor_pitch)
		pitches.append(from_pitch)

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
		Constants.TECHNIQUE_NEIGHBOR_TONE,
		Constants.ROLE_NEIGHBOR_TONE,
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
	LogBus.info(TAG, "Successfully applied neighbor_tone: " + str(new_chords.size()) + " chords inserted")

	return progression

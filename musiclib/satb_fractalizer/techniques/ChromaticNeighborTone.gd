extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "ChromaticNeighborTone"

# =============================================================================
# CHROMATIC NEIGHBOR TONE
# =============================================================================
# Similar to neighbor_tone but uses a chromatic (non-diatonic) neighbor
# Pattern: anchor → chromatic_neighbor → anchor
# The chromatic neighbor is ±1 semitone from the anchor
# =============================================================================

func apply(progression, params):
	LogBus.info(TAG, "Applying chromatic_neighbor_tone technique")

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

	# Chromatic neighbor tone requires same pitch (returns to starting pitch)
	if from_pitch != to_pitch:
		LogBus.warn(TAG, "Chromatic neighbor tone requires same pitch (from=" + str(from_pitch) + ", to=" + str(to_pitch) + ")")
		return progression

	# 4. Calculate chromatic neighbor
	# NCT always uses the previous chord's scale context
	var scale = chord_a.scale_context
	var anchor_pitch = from_pitch

	# Check that anchor is diatonic
	if not scale.is_diatonic(anchor_pitch):
		LogBus.warn(TAG, "Anchor pitch " + str(anchor_pitch) + " is not diatonic")
		return progression

	# Choose direction (upper or lower chromatic neighbor)
	var neighbor_direction = params.get("chromatic_neighbor_direction", null)
	if neighbor_direction == null:
		# Random choice
		neighbor_direction = "upper" if (randi() % 2 == 0) else "lower"

	# Chromatic neighbor is ±1 semitone
	var chromatic_neighbor = anchor_pitch + 1 if neighbor_direction == "upper" else anchor_pitch - 1

	# Verify that the chromatic neighbor is NOT diatonic (that's what makes it chromatic!)
	if scale.is_diatonic(chromatic_neighbor):
		# If it's diatonic, it's not a chromatic neighbor - try the other direction
		if neighbor_direction == "upper":
			chromatic_neighbor = anchor_pitch - 1
			neighbor_direction = "lower"
		else:
			chromatic_neighbor = anchor_pitch + 1
			neighbor_direction = "upper"

		# Check again
		if scale.is_diatonic(chromatic_neighbor):
			LogBus.warn(TAG, "No chromatic neighbor found (both ±1 semitones are diatonic)")
			return progression

	LogBus.debug(TAG, "Chromatic neighbor tone: " + str(anchor_pitch) + " → " + str(chromatic_neighbor) + " (chromatic " + neighbor_direction + ") → " + str(anchor_pitch))

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 3:
		LogBus.warn(TAG, "Span too small for 3-note pattern (n_cells=" + str(n_cells) + ")")
		return progression

	var pattern = _choose_rhythm_pattern(n_cells, progression, Constants.TECHNIQUE_CHROMATIC_NEIGHBOR_TONE, triplet_allowed)
	if not pattern:
		LogBus.warn(TAG, "No rhythm pattern found for n_cells=" + str(n_cells))
		return progression

	# 6. Build 3-note pattern: anchor → chromatic_neighbor → anchor
	var note_count = pattern.pattern.size()
	var pitches = []

	if note_count == 3:
		pitches = [anchor_pitch, chromatic_neighbor, anchor_pitch]
	else:
		# Force 3-note pattern
		var cell_per_note = n_cells / 3.0
		pattern = {
			"pattern": [cell_per_note * progression.time_grid.grid_unit,
						cell_per_note * progression.time_grid.grid_unit,
						cell_per_note * progression.time_grid.grid_unit],
			"triplet": false
		}
		pitches = [anchor_pitch, chromatic_neighbor, anchor_pitch]

	# 7. Create new chords
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a,
		chord_b,
		pattern,
		voice_id,
		pitches,
		Constants.TECHNIQUE_CHROMATIC_NEIGHBOR_TONE,
		Constants.ROLE_NEIGHBOR_TONE,  # Use NEIGHBOR_TONE role
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
	LogBus.info(TAG, "Successfully applied chromatic_neighbor_tone: " + str(new_chords.size()) + " chords inserted")

	return progression

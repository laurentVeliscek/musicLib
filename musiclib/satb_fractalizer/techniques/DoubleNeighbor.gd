extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "DoubleNeighbor"

# =============================================================================
# DOUBLE NEIGHBOR TECHNIQUE (§5.5 of spec)
# =============================================================================
# - Beat strength: WEAK
# - Pattern: anchor → upper → anchor → lower → anchor (5 notes)
# - Or: anchor → lower → anchor → upper → anchor
# - Both neighbors are diatonic
# - Creates a complete double broderie pattern

func apply(progression, params):
	LogBus.info(TAG, "Applying double_neighbor technique")

	# Extract params
	var window = params.get("time_window", {"start": 0.0, "end": 2.0})
	var voice_id = params.get("voice", Constants.VOICE_SOPRANO)
	var strategy = params.get("pair_selection_strategy", Constants.STRATEGY_EARLIEST)
	var triplet_allowed = params.get("triplet_allowed", Constants.DEFAULT_TRIPLET_ALLOWED)
	var exclude_decorative_pairs = params.get("exclude_decorative_pairs", false)
	var start_direction = params.get("double_neighbor_start", "upper")  # "upper" or "lower"

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

	# 3. Get anchor pitch (we ignore to_pitch and force the pattern on from_pitch)
	var anchor_pitch = chord_a.get_voice_pitch(voice_id)

	# 4. Calculate both neighbor pitches using scale context
	# NCT always uses the previous chord's scale context
	var scale = chord_a.scale_context
	var upper_neighbor = scale.get_neighbor_pitches(anchor_pitch, "upper")
	var lower_neighbor = scale.get_neighbor_pitches(anchor_pitch, "lower")

	if upper_neighbor == null:
		LogBus.warn(TAG, "No diatonic upper neighbor found for " + str(anchor_pitch))
		return progression

	if lower_neighbor == null:
		LogBus.warn(TAG, "No diatonic lower neighbor found for " + str(anchor_pitch))
		return progression

	LogBus.debug(TAG, "Found neighbors: upper=" + str(upper_neighbor) + ", lower=" + str(lower_neighbor))

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 5:
		LogBus.warn(TAG, "Not enough cells for double neighbor pattern (need at least 5, got " + str(n_cells) + ")")
		return progression

	# 6. Choose rhythm pattern for 5-note pattern
	var rhythm_pattern = _choose_rhythm_pattern(
		n_cells,
		progression,
		Constants.TECHNIQUE_DOUBLE_NEIGHBOR,
		triplet_allowed
	)

	if not rhythm_pattern:
		LogBus.warn(TAG, "No suitable rhythm pattern found for n_cells=" + str(n_cells))
		return progression

	# Force 5-note pattern if the chosen pattern has different count
	if rhythm_pattern.pattern.size() != 5:
		# Create a simple 5-note equal pattern
		var cell_per_note = n_cells / 5.0
		rhythm_pattern = {
			"pattern": [cell_per_note, cell_per_note, cell_per_note, cell_per_note, cell_per_note],
			"triplet": false
		}

	# 7. Create pitches array based on start direction
	var pitches
	if start_direction == "upper":
		# anchor → upper → anchor → lower → anchor
		pitches = [anchor_pitch, upper_neighbor, anchor_pitch, lower_neighbor, anchor_pitch]
	else:
		# anchor → lower → anchor → upper → anchor
		pitches = [anchor_pitch, lower_neighbor, anchor_pitch, upper_neighbor, anchor_pitch]

	# 8. Create chords from pattern
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a, chord_b, rhythm_pattern, voice_id, pitches,
		Constants.TECHNIQUE_DOUBLE_NEIGHBOR,
		Constants.ROLE_DOUBLE_NEIGHBOR,
		progression.time_grid,
		generation_depth,
		pair_info.effective_start  # Pass explicit start time
	)

	# 9. Validate NCT pitches
	if not _validate_nct_pitches(progression, new_chords, voice_id, anchor_pitch):
		LogBus.warn(TAG, "NCT pitches validation failed")
		return progression

	# 10. Insert new chords
	if not progression.insert_chords_between(from_idx, to_idx, new_chords):
		LogBus.warn(TAG, "Failed to insert double neighbor chords")
		return progression

	LogBus.info(TAG, "Successfully applied double_neighbor: " + str(new_chords.size()) + " chords inserted")
	return progression

extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "NeighborToneForced"

# =============================================================================
# NEIGHBOR TONE FORCED TECHNIQUE
# =============================================================================
# Similar to neighbor_tone but FORCES the pattern even when from_pitch != to_pitch
# - Creates 2 chords: from_pitch → neighbor → from_pitch (ignoring to_pitch)
# - Beat strength: WEAK
# - Motion: conjoint, returns to same note (from_pitch)
# - Types: upper or lower neighbor
# - Pattern: anchor → neighbor → anchor

func apply(progression, params):
	LogBus.info(TAG, "Applying neighbor_tone_forced technique")

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

	# 3. Get from_pitch (we'll ignore to_pitch and force neighbor pattern)
	var from_pitch = chord_a.get_voice_pitch(voice_id)

	# 4. Calculate neighbor pitch using scale context
	# NCT always uses the previous chord's scale context
	var scale = chord_a.scale_context
	var neighbor_pitch = scale.get_neighbor_pitches(from_pitch, neighbor_direction)

	if neighbor_pitch == null:
		LogBus.warn(TAG, "No diatonic neighbor found for " + str(from_pitch) + " in direction " + neighbor_direction)
		return progression

	LogBus.debug(TAG, "Found neighbor pitch: " + str(neighbor_pitch) + " (" + neighbor_direction + ")")

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 3:
		LogBus.warn(TAG, "Not enough cells for neighbor_tone_forced pattern (need at least 3, got " + str(n_cells) + ")")
		return progression

	# 6. Choose rhythm pattern for 3-note pattern: anchor → neighbor → anchor
	var rhythm_pattern = _choose_rhythm_pattern(
		n_cells,
		progression,
		Constants.TECHNIQUE_NEIGHBOR_TONE_FORCED,
		triplet_allowed
	)

	if not rhythm_pattern:
		LogBus.warn(TAG, "No suitable rhythm pattern found for n_cells=" + str(n_cells))
		return progression

	# Force 3-note pattern if the chosen pattern has different count
	if rhythm_pattern.pattern.size() != 3:
		# Create a simple 3-note equal pattern
		var cell_per_note = n_cells / 3.0
		rhythm_pattern = {
			"pattern": [cell_per_note, cell_per_note, cell_per_note],
			"triplet": false
		}

	# 7. Create pitches array: from_pitch → neighbor → from_pitch
	var pitches = [from_pitch, neighbor_pitch, from_pitch]

	# 8. Validate NCT pitches
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a, chord_b, rhythm_pattern, voice_id, pitches,
		Constants.TECHNIQUE_NEIGHBOR_TONE_FORCED,
		Constants.ROLE_NEIGHBOR_TONE,
		progression.time_grid,
		generation_depth,
		pair_info.effective_start  # Pass explicit start time
	)

	if not _validate_nct_pitches(progression, new_chords, voice_id, from_pitch):
		LogBus.warn(TAG, "NCT pitches validation failed")
		return progression

	# 9. Insert new chords
	if not progression.insert_chords_between(from_idx, to_idx, new_chords):
		LogBus.warn(TAG, "Failed to insert neighbor_tone_forced chords")
		return progression

	LogBus.info(TAG, "Successfully applied neighbor_tone_forced: " + str(new_chords.size()) + " chords inserted")
	return progression

extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "EscapeTone"

# =============================================================================
# ESCAPE TONE (Échappée)
# =============================================================================
# Pattern: chord_tone → step (up/down) → leap (opposite direction) to target
# Example: C → D (step up) → A (leap down)
# The escape note leaves by step and resolves by leap in the opposite direction
# =============================================================================

func apply(progression, params):
	LogBus.info(TAG, "Applying escape_tone technique")

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

	# Escape tone works best when pitches are different
	if from_pitch == to_pitch:
		LogBus.warn(TAG, "Escape tone requires different pitches (from=" + str(from_pitch) + ", to=" + str(to_pitch) + ")")
		return progression

	# 4. Calculate escape pitch
	# NCT always uses the previous chord's scale context
	var scale = chord_a.scale_context

	# Choose direction for the step (up or down)
	var step_direction = params.get("escape_step_direction", null)
	if step_direction == null:
		# Random choice
		step_direction = "upper" if (randi() % 2 == 0) else "lower"

	# Get the escape pitch (step from anchor)
	var escape_pitch = scale.get_neighbor_pitches(from_pitch, step_direction)
	if escape_pitch == null:
		LogBus.warn(TAG, "No " + step_direction + " neighbor found for escape anchor " + str(from_pitch))
		return progression

	LogBus.debug(TAG, "Escape tone: " + str(from_pitch) + " → " + str(escape_pitch) + " (step " + step_direction + ") → " + str(to_pitch) + " (leap)")

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 3:
		LogBus.warn(TAG, "Span too small for 3-note pattern (n_cells=" + str(n_cells) + ")")
		return progression

	var pattern = _choose_rhythm_pattern(n_cells, progression, Constants.TECHNIQUE_ESCAPE_TONE, triplet_allowed)
	if not pattern:
		LogBus.warn(TAG, "No rhythm pattern found for n_cells=" + str(n_cells))
		return progression

	# 6. Build the 3-note pattern
	var note_count = pattern.pattern.size()
	var pitches = []

	if note_count == 3:
		pitches = [from_pitch, escape_pitch, to_pitch]
	else:
		# Force 3-note pattern
		var cell_per_note = n_cells / 3.0
		pattern = {
			"pattern": [cell_per_note * progression.time_grid.grid_unit,
						cell_per_note * progression.time_grid.grid_unit,
						cell_per_note * progression.time_grid.grid_unit],
			"triplet": false
		}
		pitches = [from_pitch, escape_pitch, to_pitch]

	# 7. Create new chords
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a,
		chord_b,
		pattern,
		voice_id,
		pitches,
		Constants.TECHNIQUE_ESCAPE_TONE,
		Constants.ROLE_ESCAPE_TONE,
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
	LogBus.info(TAG, "Successfully applied escape_tone: " + str(new_chords.size()) + " chords inserted")

	return progression

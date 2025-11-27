extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "Suspension"

# =============================================================================
# SUSPENSION
# =============================================================================
# A note is held over from the previous chord (creating dissonance)
# Then resolves DOWNWARD by step to a chord tone
# Pattern: held_pitch (from chord_a) → resolved_pitch (step down, in chord_b)
# =============================================================================

func apply(progression, params):
	LogBus.info(TAG, "Applying suspension technique")

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

	# Suspension works when pitches are different
	if from_pitch == to_pitch:
		LogBus.warn(TAG, "Suspension requires different pitches (from=" + str(from_pitch) + ", to=" + str(to_pitch) + ")")
		return progression

	# 4. Calculate resolution pitch
	# The held pitch is from_pitch, check if it can resolve DOWN in chord_b's scale
	var scale_b = chord_b.scale_context
	if not scale_b.is_diatonic(from_pitch):
		LogBus.debug(TAG, "Suspension requires from_pitch to be diatonic in chord_b scale")
		return progression

	var held_pitch = from_pitch
	var resolved_pitch = scale_b.get_neighbor_pitches(from_pitch, "lower")

	if resolved_pitch == null:
		LogBus.warn(TAG, "No lower neighbor found for suspension resolution")
		return progression

	LogBus.debug(TAG, "Suspension: " + str(held_pitch) + " (held) → " + str(resolved_pitch) + " (resolved down)")

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 2:
		LogBus.warn(TAG, "Span too small for suspension (n_cells=" + str(n_cells) + ")")
		return progression

	var pattern = _choose_rhythm_pattern(n_cells, progression, Constants.TECHNIQUE_SUSPENSION, triplet_allowed)
	if not pattern:
		LogBus.warn(TAG, "No rhythm pattern found for n_cells=" + str(n_cells))
		return progression

	# 6. Build 2-note pattern: suspension (longer) + resolution (shorter)
	var note_count = pattern.pattern.size()
	var pitches = []

	if note_count == 2:
		pitches = [held_pitch, resolved_pitch]
	else:
		# Force 2-note pattern with 3:1 ratio (suspension longer)
		var suspension_ratio = 0.75
		var suspension_duration = n_cells * suspension_ratio * progression.time_grid.grid_unit
		var resolution_duration = n_cells * (1.0 - suspension_ratio) * progression.time_grid.grid_unit
		pattern = {
			"pattern": [suspension_duration, resolution_duration],
			"triplet": false
		}
		pitches = [held_pitch, resolved_pitch]

	# 7. Create new chords
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a,
		chord_b,
		pattern,
		voice_id,
		pitches,
		Constants.TECHNIQUE_SUSPENSION,
		Constants.ROLE_SUSPENSION,
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
	LogBus.info(TAG, "Successfully applied suspension: " + str(new_chords.size()) + " chords inserted")

	return progression

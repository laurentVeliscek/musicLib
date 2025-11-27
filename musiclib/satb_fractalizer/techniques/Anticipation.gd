extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "Anticipation"

# =============================================================================
# ANTICIPATION
# =============================================================================
# A note from the next chord is played early (anticipation)
# Pattern: from_pitch → to_pitch (early, before chord change)
# The anticipated pitch then continues into the next chord
# =============================================================================

func apply(progression, params):
	LogBus.info(TAG, "Applying anticipation technique")

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

	# Anticipation requires different pitches
	if from_pitch == to_pitch:
		LogBus.warn(TAG, "Anticipation requires different pitches (from=" + str(from_pitch) + ", to=" + str(to_pitch) + ")")
		return progression

	# The anticipated note (to_pitch) should be diatonic in the NEXT chord's scale
	if not chord_b.scale_context.is_diatonic(to_pitch):
		LogBus.warn(TAG, "Anticipated pitch " + str(to_pitch) + " is not diatonic in next chord scale")
		return progression

	LogBus.debug(TAG, "Anticipation: " + str(from_pitch) + " → " + str(to_pitch) + " (early)")

	# 4. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 2:
		LogBus.warn(TAG, "Span too small for anticipation (n_cells=" + str(n_cells) + ")")
		return progression

	var pattern = _choose_rhythm_pattern(n_cells, progression, Constants.TECHNIQUE_ANTICIPATION, triplet_allowed)
	if not pattern:
		LogBus.warn(TAG, "No rhythm pattern found for n_cells=" + str(n_cells))
		return progression

	# 5. Build 2-note pattern: long from_pitch, short to_pitch (anticipation)
	var note_count = pattern.pattern.size()
	var pitches = []

	if note_count == 2:
		pitches = [from_pitch, to_pitch]
	else:
		# Force 2-note pattern favoring first note (75% / 25%)
		var anticipation_ratio = 0.25
		var from_duration = n_cells * (1.0 - anticipation_ratio) * progression.time_grid.grid_unit
		var anticipation_duration = n_cells * anticipation_ratio * progression.time_grid.grid_unit
		pattern = {
			"pattern": [from_duration, anticipation_duration],
			"triplet": false
		}
		pitches = [from_pitch, to_pitch]

	# 6. Create new chords
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a,
		chord_b,
		pattern,
		voice_id,
		pitches,
		Constants.TECHNIQUE_ANTICIPATION,
		Constants.ROLE_ANTICIPATION,
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
	LogBus.info(TAG, "Successfully applied anticipation: " + str(new_chords.size()) + " chords inserted")

	return progression

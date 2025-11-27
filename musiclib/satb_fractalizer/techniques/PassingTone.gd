extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "PassingTone"

# =============================================================================
# PASSING TONE TECHNIQUE (§5.1 of spec)
# =============================================================================
# - Beat strength: WEAK
# - Motion: conjoint (step-wise), ascending or descending
# - Multiple: can chain 2-3 consecutive passing tones if diatonic
# - Resolution: must resolve to a chord tone

func apply(progression, params):
	LogBus.info(TAG, "Applying passing_tone technique")

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
		LogBus.warn(TAG, "Passing tone requires different pitches (from=" + str(from_pitch) + ", to=" + str(to_pitch) + ")")
		return progression

	# 4. Calculate passing pitches using scale context
	# NCT always uses the previous chord's scale context
	var scale = chord_a.scale_context
	var passing_pitches = scale.get_passing_pitches(from_pitch, to_pitch)

	if passing_pitches.empty():
		LogBus.warn(TAG, "No diatonic passing pitches found between " + str(from_pitch) + " and " + str(to_pitch))
		return progression

	LogBus.debug(TAG, "Found " + str(passing_pitches.size()) + " passing pitches: " + str(passing_pitches))

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 2:
		LogBus.warn(TAG, "Span too small for subdivision (n_cells=" + str(n_cells) + ")")
		return progression

	var pattern = _choose_rhythm_pattern(n_cells, progression, Constants.TECHNIQUE_PASSING_TONE, triplet_allowed)
	if not pattern:
		LogBus.warn(TAG, "No rhythm pattern found for n_cells=" + str(n_cells))
		return progression

	# 6. Create pitches array (alternating between chord tones and passing tones)
	var note_count = pattern.pattern.size()
	var pitches = []

	# Simple case: 2 notes (from_pitch → passing_pitch)
	if note_count == 2 and passing_pitches.size() >= 1:
		pitches = [from_pitch, passing_pitches[0]]

	# 3 notes: from_pitch → passing_pitch → to_pitch (or multiple passing tones)
	elif note_count == 3:
		if passing_pitches.size() == 1:
			pitches = [from_pitch, passing_pitches[0], to_pitch]
		elif passing_pitches.size() >= 2:
			pitches = [from_pitch, passing_pitches[0], passing_pitches[1]]

	# 4+ notes: from_pitch → multiple passing → ...
	elif note_count >= 4:
		pitches.append(from_pitch)
		for i in range(min(note_count - 1, passing_pitches.size())):
			pitches.append(passing_pitches[i])

	else:
		LogBus.warn(TAG, "Cannot map " + str(note_count) + " notes to " + str(passing_pitches.size()) + " passing pitches")
		return progression

	# Pad if needed
	while pitches.size() < note_count:
		pitches.append(pitches[pitches.size() - 1])

	# 7. Create new chords
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a,
		chord_b,
		pattern,
		voice_id,
		pitches,
		Constants.TECHNIQUE_PASSING_TONE,
		Constants.ROLE_PASSING_TONE,
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
	LogBus.info(TAG, "Successfully applied passing_tone: " + str(new_chords.size()) + " chords inserted")

	return progression

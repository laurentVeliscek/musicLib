extends "res://addons/musiclib/satb_fractalizer/techniques/TechniqueBase.gd"

const TAG = "ExtendedPassingTones"

# =============================================================================
# EXTENDED PASSING TONES
# =============================================================================
# Chain multiple passing tones to reach the target note
# All passing tones go in the same direction (ascending or descending)
# Max number of passing tones is configurable (default 3, max 5)
# Tests all values from 1 to max to find the best fit
# =============================================================================

func apply(progression, params):
	LogBus.info(TAG, "Applying extended_passing_tones technique")

	# Extract params
	var window = params.get("time_window", {"start": 0.0, "end": 2.0})
	var voice_id = params.get("voice", Constants.VOICE_SOPRANO)
	var strategy = params.get("pair_selection_strategy", Constants.STRATEGY_EARLIEST)
	var triplet_allowed = params.get("triplet_allowed", Constants.DEFAULT_TRIPLET_ALLOWED)
	var exclude_decorative_pairs = params.get("exclude_decorative_pairs", false)
	var max_passing_tones = params.get("max_passing_tones", 3)

	# Clamp max_passing_tones between 1 and 5
	max_passing_tones = int(max(1, min(5, max_passing_tones)))

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
		LogBus.warn(TAG, "Extended passing tones requires different pitches (from=" + str(from_pitch) + ", to=" + str(to_pitch) + ")")
		return progression

	# 4. Calculate all passing pitches using scale context
	# NCT always uses the previous chord's scale context
	var scale = chord_a.scale_context
	var all_passing_pitches = scale.get_passing_pitches(from_pitch, to_pitch)

	if all_passing_pitches.empty():
		LogBus.warn(TAG, "No diatonic passing pitches found between " + str(from_pitch) + " and " + str(to_pitch))
		return progression

	LogBus.debug(TAG, "Found " + str(all_passing_pitches.size()) + " passing pitches: " + str(all_passing_pitches))

	# 5. Compute span and rhythm pattern
	var span = pair_info.effective_end - pair_info.effective_start
	var n_cells = progression.time_grid.time_to_cells(span)

	if n_cells < 2:
		LogBus.warn(TAG, "Span too small for extended passing tones (n_cells=" + str(n_cells) + ")")
		return progression

	# 6. Try different numbers of passing tones (from 1 to max_passing_tones)
	# We want to find the configuration that best fits the available rhythm patterns
	var best_config = null
	var best_score = -1

	for num_passing in range(1, min(max_passing_tones, all_passing_pitches.size()) + 1):
		# Total notes: from_pitch + num_passing + potentially to_pitch
		# Try configurations with and without to_pitch at the end

		for include_target in [true, false]:
			var note_count = 1 + num_passing
			if include_target:
				note_count += 1

			# Check if we have enough cells for this many notes
			if n_cells < note_count:
				continue

			# Try to get a rhythm pattern for this note count
			var pattern = _choose_rhythm_pattern(n_cells, progression, Constants.TECHNIQUE_EXTENDED_PASSING_TONES, triplet_allowed)
			if not pattern:
				continue

			# Check if pattern size matches our note count (or can be adapted)
			if pattern.pattern.size() == note_count or pattern.pattern.size() >= note_count:
				# Build pitches array
				var pitches = [from_pitch]
				for i in range(num_passing):
					if i < all_passing_pitches.size():
						pitches.append(all_passing_pitches[i])
				if include_target:
					pitches.append(to_pitch)

				# Score this configuration (prefer more passing tones up to a point)
				var config_score = num_passing * 10
				if pattern.pattern.size() == note_count:
					config_score += 20  # Bonus for exact match
				if include_target:
					config_score += 15  # Bonus for reaching target

				if config_score > best_score:
					best_score = config_score
					best_config = {
						"num_passing": num_passing,
						"include_target": include_target,
						"note_count": note_count,
						"pitches": pitches,
						"pattern": pattern
					}

	if not best_config:
		LogBus.warn(TAG, "No valid configuration found for extended passing tones")
		return progression

	LogBus.debug(TAG, "Extended passing tones: using " + str(best_config.num_passing) + " passing tones, include_target=" + str(best_config.include_target))

	# 7. Finalize pattern and pitches
	var pattern = best_config.pattern
	var pitches = best_config.pitches

	# Adjust pattern if needed to match pitches count exactly
	if pattern.pattern.size() != pitches.size():
		# Create equal subdivision
		var cell_per_note = n_cells / float(pitches.size())
		var new_pattern = []
		for i in range(pitches.size()):
			new_pattern.append(cell_per_note * progression.time_grid.grid_unit)
		pattern = {
			"pattern": new_pattern,
			"triplet": false
		}

	# Ensure pitches array matches pattern size
	while pitches.size() < pattern.pattern.size():
		pitches.append(pitches[pitches.size() - 1])
	while pitches.size() > pattern.pattern.size():
		pitches.remove(pitches.size() - 1)

	# 8. Create new chords
	var generation_depth = progression.metadata.get("generation_depth", 0) + 1
	var new_chords = _create_chords_from_pattern(
		chord_a,
		chord_b,
		pattern,
		voice_id,
		pitches,
		Constants.TECHNIQUE_EXTENDED_PASSING_TONES,
		Constants.ROLE_PASSING_TONE,  # Use PASSING_TONE role for the notes
		progression.time_grid,
		generation_depth,
		pair_info.effective_start  # Pass explicit start time
	)

	# 9. Validate NCT pitches
	if not _validate_nct_pitches(progression, new_chords, voice_id, from_pitch):
		LogBus.warn(TAG, "NCT validation failed")
		return progression

	# 10. Insert new chords
	if not progression.insert_chords_between(from_idx, to_idx, new_chords):
		LogBus.error(TAG, "Failed to insert chords")
		return progression

	# 11. Log success
	LogBus.info(TAG, "Successfully applied extended_passing_tones: " + str(new_chords.size()) + " chords inserted (" + str(best_config.num_passing) + " passing tones)")

	return progression

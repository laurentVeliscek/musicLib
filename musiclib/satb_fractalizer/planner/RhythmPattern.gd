extends Node

const TAG = "RhythmPattern"
const Constants = preload("res://addons/musiclib/satb_fractalizer/core/Constants.gd")

# =============================================================================
# RHYTHM PATTERN SELECTION (§3 of spec)
# =============================================================================

func choose_rhythm_pattern(n_cells, grid_unit, min_note_duration, technique_id, triplet_allowed, beat_positions, params):
	# Returns: {"pattern": [durations...], "triplet": bool} or null
	# pattern: array of durations in beats (not cells!)

	LogBus.debug(TAG, "choose_rhythm_pattern: n_cells=" + str(n_cells) + " technique=" + technique_id)

	if n_cells < 2:
		LogBus.warn(TAG, "choose_rhythm_pattern: n_cells < 2, cannot subdivide")
		return null

	var span = n_cells * grid_unit
	var candidates = []

	# Generate candidate patterns
	candidates = _generate_candidates(n_cells, grid_unit, min_note_duration, technique_id, triplet_allowed)

	if candidates.empty():
		LogBus.warn(TAG, "choose_rhythm_pattern: no candidates generated")
		return null

	# Score each candidate based on musical criteria
	var scored_candidates = []
	for candidate in candidates:
		var score = _score_pattern(candidate, technique_id, beat_positions, grid_unit)
		scored_candidates.append({"pattern": candidate, "score": score})

	# Sort by score (descending)
	scored_candidates.sort_custom(self, "_compare_by_score")

	# Return best candidate
	var best = scored_candidates[0].pattern
	LogBus.debug(TAG, "choose_rhythm_pattern: selected pattern " + str(best) + " (score=" + str(scored_candidates[0].score) + ")")
	return best

func _compare_by_score(a, b):
	return a.score > b.score

# =============================================================================
# GENERATE CANDIDATES
# =============================================================================

func _generate_candidates(n_cells, grid_unit, min_note_duration, technique_id, triplet_allowed):
	var candidates = []
	var span = n_cells * grid_unit

	# Binary subdivisions (2, 3, 4 notes)
	# For simplicity, we'll generate common patterns

	# 2-note patterns
	if n_cells >= 2:
		# Equal division
		candidates.append({
			"pattern": [span / 2.0, span / 2.0],
			"triplet": false
		})

		# Long-short
		candidates.append({
			"pattern": [span * 0.75, span * 0.25],
			"triplet": false
		})

		# Short-long
		candidates.append({
			"pattern": [span * 0.25, span * 0.75],
			"triplet": false
		})

	# Triplet detection (§ Triplet Rule):
	# - Only quarter notes (1.0 beat) are divided into triplets
	# - Half notes (2.0 beats) and longer remain binary
	# - A triplet divides 1.0 beat into 3 equal parts of 0.333... beats each
	var is_quarter_note_span = abs(span - 1.0) < 0.01  # Tolerance for floating point
	var is_triplet_candidate = triplet_allowed and is_quarter_note_span

	# 3-note patterns
	if n_cells >= 3:
		# Equal division (triplet only if span is exactly 1.0 beat = quarter note)
		candidates.append({
			"pattern": [span / 3.0, span / 3.0, span / 3.0],
			"triplet": is_triplet_candidate
		})

		# Long-short-short (binary subdivision)
		candidates.append({
			"pattern": [span * 0.5, span * 0.25, span * 0.25],
			"triplet": false
		})

	# 4-note patterns (for longer spans)
	if n_cells >= 4:
		# Equal division (always binary)
		candidates.append({
			"pattern": [span / 4.0, span / 4.0, span / 4.0, span / 4.0],
			"triplet": false
		})

	return candidates

# =============================================================================
# SCORE PATTERN
# =============================================================================

func _score_pattern(pattern_dict, technique_id, beat_positions, grid_unit):
	# Score based on musical criteria (§3 of spec)
	var score = 100.0  # Start with base score
	var pattern = pattern_dict.pattern

	# 1. Favor simplicity (2-3 notes preferred over 4+)
	var note_count = pattern.size()
	if note_count == 2:
		score += 20
	elif note_count == 3:
		score += 10
	elif note_count >= 4:
		score -= 10

	# 2. Technique-specific preferences
	if technique_id == Constants.TECHNIQUE_PASSING_TONE:
		# Prefer equal subdivisions
		if _is_equal_division(pattern):
			score += 30

	elif technique_id == Constants.TECHNIQUE_CHROMATIC_PASSING_TONE:
		# Same as passing_tone: prefer equal subdivisions
		if _is_equal_division(pattern):
			score += 30

	elif technique_id == Constants.TECHNIQUE_CHROMATIC_NEIGHBOR_TONE:
		# 3-note pattern: prefer equal subdivisions (anchor → chromatic → anchor)
		if _is_equal_division(pattern):
			score += 20

	elif technique_id == Constants.TECHNIQUE_APPOGGIATURA:
		# Prefer long-short (tension-resolution)
		if note_count == 2 and pattern[0] > pattern[1]:
			score += 30

	elif technique_id == Constants.TECHNIQUE_ANTICIPATION:
		# Prefer short at the end
		if note_count == 2 and pattern[1] < pattern[0]:
			score += 30

	elif technique_id == Constants.TECHNIQUE_NEIGHBOR_TONE:
		# Prefer equal subdivisions (neighbor and return)
		if _is_equal_division(pattern):
			score += 20

	elif technique_id == Constants.TECHNIQUE_NEIGHBOR_TONE_FORCED:
		# Same scoring as neighbor_tone (3-note pattern: anchor → neighbor → anchor)
		if _is_equal_division(pattern):
			score += 20

	elif technique_id == Constants.TECHNIQUE_DOUBLE_NEIGHBOR:
		# 5-note pattern: prefer equal subdivisions
		if _is_equal_division(pattern):
			score += 20

	elif technique_id == Constants.TECHNIQUE_ESCAPE_TONE:
		# 3-note pattern: prefer equal subdivisions
		if _is_equal_division(pattern):
			score += 20

	elif technique_id == Constants.TECHNIQUE_SUSPENSION:
		# Prefer long-short (suspension longer, resolution shorter)
		if note_count == 2 and pattern[0] > pattern[1]:
			score += 30

	elif technique_id == Constants.TECHNIQUE_RETARDATION:
		# Same as suspension: prefer long-short
		if note_count == 2 and pattern[0] > pattern[1]:
			score += 30

	elif technique_id == Constants.TECHNIQUE_PEDAL:
		# Pedal is typically a single sustained note
		# Prefer single-note patterns (long duration)
		if note_count == 1:
			score += 40

	elif technique_id == Constants.TECHNIQUE_EXTENDED_PASSING_TONES:
		# Extended passing tones: prefer equal subdivisions for smooth motion
		if _is_equal_division(pattern):
			score += 30

	# 3. Avoid excessive syncopation
	# (Simplified: just check if notes cross strong beats)
	# For now, we'll skip this check (would require more context)

	return score

func _is_equal_division(pattern):
	if pattern.empty():
		return false

	var first = pattern[0]
	for dur in pattern:
		if abs(dur - first) > 0.001:
			return false

	return true

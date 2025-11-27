extends Node

const TAG = "Progression"
const Constants = preload("res://addons/musiclib/satb_fractalizer/core/Constants.gd")

var chords             # Array [Chord]
var time_grid          # TimeGrid
var global_scale       # ScaleContext (optional, can differ per chord)
var voice_policy       # Dictionary {S: {modifiable, min_pitch, max_pitch}, ...}
var metadata           # Dictionary (history, technique_report, etc.)

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init():
	chords = []
	time_grid = null
	global_scale = null
	voice_policy = {}
	metadata = {
		"history": [],
		"technique_report": {
			"time_windows": []
		}
	}

# =============================================================================
# CHORD MANAGEMENT
# =============================================================================

func add_chord(chord):
	chords.append(chord)
	_sort_chords()

func insert_chord_at_index(chord, index):
	if index < 0 or index > chords.size():
		LogBus.error(TAG, "insert_chord_at_index: index " + str(index) + " out of bounds")
		return

	chords.insert(index, chord)

func remove_chord_at_index(index):
	if index < 0 or index >= chords.size():
		LogBus.error(TAG, "remove_chord_at_index: index " + str(index) + " out of bounds")
		return

	chords.remove(index)

func _sort_chords():
	# Sort chords by start_time
	chords.sort_custom(self, "_compare_chords_by_time")

func _compare_chords_by_time(a, b):
	return a.start_time < b.start_time

# =============================================================================
# CHORD ACCESS
# =============================================================================

func get_chord_at_index(idx):
	if idx >= 0 and idx < chords.size():
		return chords[idx]
	else:
		return null

func get_chord_count():
	return chords.size()

func get_chords_in_time_range(start, end):
	var result = []
	for chord in chords:
		if chord.start_time >= start and chord.start_time < end:
			result.append(chord)
	return result

# =============================================================================
# CHORD PAIR SELECTION
# =============================================================================

func get_chord_pairs_in_window(window_start, window_end, exclude_decorative_pairs = false):
	# Returns Array of {from_index, to_index, span_start, span_end, effective_span}
	# for all consecutive chord pairs that intersect the window
	#
	# If exclude_decorative_pairs = true, only returns pairs where BOTH chords are structural (non-decorative)
	# This is useful for multiple iterations to avoid re-processing already decorated segments

	var pairs = []

	for i in range(chords.size() - 1):
		var chord_a = chords[i]
		var chord_b = chords[i + 1]

		# Filter decorative pairs if requested
		if exclude_decorative_pairs:
			if chord_a.kind == "decorative" or chord_b.kind == "decorative":
				continue  # Skip pairs involving decorative chords

		var pair_start = chord_a.start_time
		var pair_end = chord_b.start_time

		# Check intersection
		var effective_start = max(pair_start, window_start)
		var effective_end = min(pair_end, window_end)

		if effective_start < effective_end:
			pairs.append({
				"from_index": i,
				"to_index": i + 1,
				"pair_start": pair_start,
				"pair_end": pair_end,
				"effective_start": effective_start,
				"effective_end": effective_end,
				"effective_span": effective_end - effective_start
			})

	return pairs

func select_chord_pair(pairs, strategy):
	# Select one pair from the list based on strategy
	# strategy: "earliest" or "longest"

	if pairs.empty():
		return null

	if strategy == Constants.STRATEGY_EARLIEST:
		# Select the pair with earliest start
		var earliest = pairs[0]
		for p in pairs:
			if p.effective_start < earliest.effective_start:
				earliest = p
		return earliest

	elif strategy == Constants.STRATEGY_LONGEST:
		# Select the pair with longest effective span
		var longest = pairs[0]
		for p in pairs:
			if p.effective_span > longest.effective_span:
				longest = p
		return longest

	else:
		LogBus.error(TAG, "select_chord_pair: unknown strategy " + str(strategy))
		return null

# =============================================================================
# CHORD INSERTION BETWEEN TWO CHORDS
# =============================================================================

func insert_chords_between(from_index, to_index, new_chords):
	# Insert new_chords between chords[from_index] and chords[to_index]
	# Adjust duration of chords[from_index] to end at first new chord
	# Last new chord ends at chords[to_index].start_time

	if from_index < 0 or from_index >= chords.size():
		LogBus.error(TAG, "insert_chords_between: from_index " + str(from_index) + " out of bounds")
		return false

	if to_index < 0 or to_index >= chords.size():
		LogBus.error(TAG, "insert_chords_between: to_index " + str(to_index) + " out of bounds")
		return false

	if to_index != from_index + 1:
		LogBus.error(TAG, "insert_chords_between: from_index and to_index must be consecutive")
		return false

	if new_chords.empty():
		LogBus.warn(TAG, "insert_chords_between: no new chords to insert")
		return false

	var chord_a = chords[from_index]
	var chord_b = chords[to_index]

	# Calculate new duration for chord_a
	var new_duration = new_chords[0].start_time - chord_a.start_time

	# If chord_a would have zero or negative duration, remove it instead of keeping it
	if new_duration <= 0.0001:  # Use small epsilon for floating point comparison
		LogBus.debug(TAG, "insert_chords_between: removing chord_a (would have zero/negative duration)")
		# Remove chord_a
		chords.remove(from_index)
		# Adjust indices since we removed chord_a
		# from_index stays the same (now points to what was chord_b)
		# Insert new chords at from_index (before chord_b)
		for i in range(new_chords.size()):
			chords.insert(from_index + i, new_chords[i])
	else:
		# Normal case: adjust chord_a duration and insert after it
		chord_a.duration = new_duration
		# Insert new chords at position from_index + 1
		for i in range(new_chords.size()):
			chords.insert(from_index + 1 + i, new_chords[i])

	# Sort chords by start time to ensure correct order
	# This is critical when multiple techniques are applied
	_sort_chords()

	LogBus.debug(TAG, "insert_chords_between: inserted " + str(new_chords.size()) + " chords")

	return true

# =============================================================================
# DUPLICATION
# =============================================================================

func copy():
	var new_prog = get_script().new()

	for chord in chords:
		new_prog.add_chord(chord.copy())

	new_prog.time_grid = time_grid  # Shared (not duplicated)
	new_prog.global_scale = global_scale  # Shared (not duplicated)
	new_prog.voice_policy = voice_policy.duplicate()
	new_prog.metadata = metadata.duplicate(true)

	return new_prog

# =============================================================================
# VALIDATION
# =============================================================================

func validate():
	# Check for overlapping chords
	for i in range(chords.size() - 1):
		var chord_a = chords[i]
		var chord_b = chords[i + 1]

		if chord_a.get_end_time() > chord_b.start_time:
			LogBus.error(TAG, "validate: chords " + str(i) + " and " + str(i + 1) + " overlap")
			return false

	# Check voice crossing in each chord
	for chord in chords:
		if not chord.validate_voices():
			return false

	return true

# =============================================================================
# DEBUG
# =============================================================================

func to_string():
	return "Progression(" + str(chords.size()) + " chords, " + str(time_grid) + ")"

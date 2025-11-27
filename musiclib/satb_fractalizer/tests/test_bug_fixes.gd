extends Node

# Test script for bug fixes:
# 1. Time management (gaps and overlaps)
# 2. Iteration parameter for time_windows

const TAG = "TestBugFixes"

func _ready():
	LogBus.set_verbose(false)  # Reduce verbosity for cleaner output

	print("\n" + "="*80)
	print("BUG FIXES TEST SUITE")
	print("="*80 + "\n")

	# Test 1: Verify no gaps or overlaps (legato)
	test_legato_chords()

	# Test 2: Test iteration parameter
	test_iteration_parameter()

	print("\n" + "="*80)
	print("ALL TESTS COMPLETE")
	print("="*80 + "\n")

func test_legato_chords():
	print("\n--- TEST 1: Legato Chords (No Gaps/Overlaps) ---\n")

	var Planner = load("res://addons/musiclib/satb_fractalizer/planner/Planner.gd")
	var planner = Planner.new()

	# Create a simple progression
	var chords = [
		{
			"index": 0, "pos": 0.0, "length_beats": 1.0,
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 72, "Alto": 67, "Tenor": 64, "Bass": 48
		},
		{
			"index": 1, "pos": 1.0, "length_beats": 1.0,
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 74, "Alto": 69, "Tenor": 65, "Bass": 50
		},
		{
			"index": 2, "pos": 2.0, "length_beats": 1.0,
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 76, "Alto": 67, "Tenor": 64, "Bass": 48
		},
		{
			"index": 3, "pos": 3.0, "length_beats": 1.0,
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 72, "Alto": 65, "Tenor": 60, "Bass": 48
		}
	]

	var params = {
		"time_num": 4,
		"time_den": 4,
		"grid_unit": 0.25,
		"time_windows": [
			{"start": 0.0, "end": 1.0},
			{"start": 1.0, "end": 2.0},
			{"start": 2.0, "end": 3.0}
		],
		"allowed_techniques": ["passing_tone", "neighbor_tone"],
		"voice_window_pattern": "SA",
		"triplet_allowed": false,
		"rng_seed": 42
	}

	print("Applying fractalizer...")
	var result = planner.apply(chords, params)

	print("\nOriginal chords: " + str(chords.size()))
	print("Enriched chords: " + str(result.chords.size()))

	# Validate legato (no gaps or overlaps)
	var validation = validate_legato(result.chords)

	print("\nValidation Results:")
	print("  Total chords: " + str(result.chords.size()))
	print("  Gaps detected: " + str(validation.gaps))
	print("  Overlaps detected: " + str(validation.overlaps))
	print("  Zero-duration chords: " + str(validation.zero_duration))

	if validation.gaps == 0 and validation.overlaps == 0 and validation.zero_duration == 0:
		print("\n✓ PASS: All chords are legato (no gaps, no overlaps, no zero-duration)")
	else:
		print("\n✗ FAIL: Found issues with chord timing")
		if validation.gaps > 0:
			print("  - Found " + str(validation.gaps) + " gap(s)")
			for gap in validation.gap_details:
				print("    Gap between chord " + str(gap.from_idx) + " and " + str(gap.to_idx) + ": " + str(gap.gap_size) + " beats")
		if validation.overlaps > 0:
			print("  - Found " + str(validation.overlaps) + " overlap(s)")
			for overlap in validation.overlap_details:
				print("    Overlap between chord " + str(overlap.from_idx) + " and " + str(overlap.to_idx) + ": " + str(overlap.overlap_size) + " beats")
		if validation.zero_duration > 0:
			print("  - Found " + str(validation.zero_duration) + " zero-duration chord(s)")
			for zero in validation.zero_duration_details:
				print("    Chord " + str(zero.idx) + " at pos " + str(zero.pos) + " has duration " + str(zero.duration))

func test_iteration_parameter():
	print("\n--- TEST 2: Iteration Parameter ---\n")

	var Planner = load("res://addons/musiclib/satb_fractalizer/planner/Planner.gd")
	var planner = Planner.new()

	# Create a simple progression
	var chords = [
		{
			"index": 0, "pos": 0.0, "length_beats": 2.0,
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 72, "Alto": 67, "Tenor": 64, "Bass": 48
		},
		{
			"index": 1, "pos": 2.0, "length_beats": 2.0,
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 76, "Alto": 67, "Tenor": 64, "Bass": 48
		}
	]

	# Test with iteration = 3
	var params = {
		"time_num": 4,
		"time_den": 4,
		"grid_unit": 0.25,
		"time_windows": [
			{"start": 0.0, "end": 2.0, "iteration": 3}  # 3 iterations on same window
		],
		"allowed_techniques": ["passing_tone", "neighbor_tone"],
		"voice_window_pattern": "S",
		"triplet_allowed": false,
		"rng_seed": 42
	}

	print("Test: 1 window with iteration=3")
	print("Expected: Up to 3 techniques applied")
	var result = planner.apply(chords, params)

	print("\nOriginal chords: " + str(chords.size()))
	print("Enriched chords: " + str(result.chords.size()))
	print("Decorative chords added: " + str(result.chords.size() - chords.size()))

	# Count how many techniques were actually applied
	var techniques_applied = 0
	for entry in result.metadata.history:
		if entry.status == "success":
			techniques_applied += 1

	print("Techniques actually applied: " + str(techniques_applied))

	if techniques_applied >= 1 and techniques_applied <= 3:
		print("\n✓ PASS: Iteration parameter works (applied " + str(techniques_applied) + "/3 techniques)")
	else:
		print("\n✗ FAIL: Iteration parameter not working correctly")

	# Validate legato after iterations
	var validation = validate_legato(result.chords)
	if validation.gaps == 0 and validation.overlaps == 0 and validation.zero_duration == 0:
		print("✓ PASS: Chords remain legato after multiple iterations")
	else:
		print("✗ FAIL: Iteration caused timing issues")

func validate_legato(chords):
	# Validates that chords are perfectly legato (no gaps, no overlaps)
	var gaps = 0
	var overlaps = 0
	var zero_duration = 0
	var gap_details = []
	var overlap_details = []
	var zero_duration_details = []

	for i in range(chords.size()):
		var chord = chords[i]

		# Check for zero-duration chords
		if chord.length_beats <= 0.0001:
			zero_duration += 1
			zero_duration_details.append({
				"idx": i,
				"pos": chord.pos,
				"duration": chord.length_beats
			})

		# Check gaps and overlaps with next chord
		if i < chords.size() - 1:
			var next_chord = chords[i + 1]
			var chord_end = chord.pos + chord.length_beats
			var next_start = next_chord.pos

			var diff = next_start - chord_end

			if diff > 0.0001:  # Gap
				gaps += 1
				gap_details.append({
					"from_idx": i,
					"to_idx": i + 1,
					"gap_size": diff
				})
			elif diff < -0.0001:  # Overlap
				overlaps += 1
				overlap_details.append({
					"from_idx": i,
					"to_idx": i + 1,
					"overlap_size": -diff
				})

	return {
		"gaps": gaps,
		"overlaps": overlaps,
		"zero_duration": zero_duration,
		"gap_details": gap_details,
		"overlap_details": overlap_details,
		"zero_duration_details": zero_duration_details
	}

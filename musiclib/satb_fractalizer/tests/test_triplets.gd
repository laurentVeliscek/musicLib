extends Node

# Test script for triplet implementation
# Tests triplet generation with different grid_unit values

const TAG = "TestTriplets"

func _ready():
	LogBus.set_verbose(true)

	print("\n" + "="*80)
	print("TRIPLET IMPLEMENTATION TEST")
	print("="*80 + "\n")

	# Test 1: grid_unit = 0.25 (eighth notes)
	test_triplets_with_grid_unit(0.25, "eighth notes (croches)")

	# Test 2: grid_unit = 0.125 (sixteenth notes)
	test_triplets_with_grid_unit(0.125, "sixteenth notes (doubles-croches)")

	# Test 3: grid_unit = 0.5 (quarter notes)
	test_triplets_with_grid_unit(0.5, "quarter notes (noires)")

	# Test 4: Verify TimeGrid beat strength for triplet positions
	test_beat_strength_triplets()

	print("\n" + "="*80)
	print("ALL TESTS COMPLETE")
	print("="*80 + "\n")

func test_triplets_with_grid_unit(grid_unit, description):
	print("\n--- TEST: grid_unit = " + str(grid_unit) + " (" + description + ") ---\n")

	var Planner = load("res://addons/musiclib/satb_fractalizer/planner/Planner.gd")
	var planner = Planner.new()

	# Create a simple progression with quarter-note chords
	var chords = [
		{
			"index": 0, "pos": 0.0, "length_beats": 1.0,  # Quarter note
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 72, "Alto": 67, "Tenor": 64, "Bass": 48
		},
		{
			"index": 1, "pos": 1.0, "length_beats": 1.0,  # Quarter note
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 74, "Alto": 69, "Tenor": 65, "Bass": 50
		},
		{
			"index": 2, "pos": 2.0, "length_beats": 1.0,  # Quarter note
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 76, "Alto": 67, "Tenor": 64, "Bass": 48
		},
		{
			"index": 3, "pos": 3.0, "length_beats": 1.0,  # Quarter note
			"key_midi_root": 60, "scale_array": [0,2,4,5,7,9,11],
			"key_alterations": {}, "key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 72, "Alto": 65, "Tenor": 60, "Bass": 48
		}
	]

	# Test with triplet_allowed = true
	var params = {
		"time_num": 4,
		"time_den": 4,
		"grid_unit": grid_unit,
		"time_windows": [
			{"start": 0.0, "end": 1.0},  # First quarter note
			{"start": 1.0, "end": 2.0},  # Second quarter note
		],
		"allowed_techniques": ["passing_tone", "neighbor_tone"],
		"voice_window_pattern": "SA",
		"triplet_allowed": true,  # Enable triplets
		"rng_seed": 42
	}

	LogBus.info(TAG, "Applying fractalizer with triplet_allowed=true...")
	var result = planner.apply(chords, params)

	print("\nOriginal chords: " + str(chords.size()))
	print("Enriched chords: " + str(result.chords.size()))
	print("Chords added: " + str(result.chords.size() - chords.size()))

	# Analyze results for triplets
	var triplet_count = 0
	var total_decorative = 0

	for chord in result.chords:
		if chord.get("kind", "") == "decorative":
			total_decorative += 1
			if chord.get("metadata", {}).get("triplet", false):
				triplet_count += 1
				print("\nTriplet found:")
				print("  Position: " + str(chord.pos))
				print("  Duration: " + str(chord.length_beats))
				print("  Expected duration: ~0.333 beats")

				# Verify duration is approximately 1/3 beat
				var expected_duration = 1.0 / 3.0
				var duration_diff = abs(chord.length_beats - expected_duration)
				if duration_diff < 0.01:
					print("  ✓ Duration is correct (within tolerance)")
				else:
					print("  ✗ WARNING: Duration is incorrect! Diff: " + str(duration_diff))

	print("\nSummary:")
	print("  Decorative chords: " + str(total_decorative))
	print("  Triplet chords: " + str(triplet_count))

	if triplet_count > 0:
		print("  ✓ PASS: Triplets were generated")
	else:
		print("  ⚠ INFO: No triplets generated (may be due to random selection or unsuitable conditions)")

func test_beat_strength_triplets():
	print("\n--- TEST: TimeGrid beat strength for triplet positions ---\n")

	var TimeGrid = load("res://addons/musiclib/satb_fractalizer/core/TimeGrid.gd")
	var time_grid = TimeGrid.new(4, 4, 0.25)  # 4/4 time, eighth note grid

	# Test positions
	var test_positions = [
		{"pos": 0.0, "expected": "strong", "description": "Beat 1 (first triplet note)"},
		{"pos": 0.333, "expected": "weak", "description": "Second triplet note"},
		{"pos": 0.666, "expected": "weak", "description": "Third triplet note"},
		{"pos": 1.0, "expected": "weak", "description": "Beat 2"},
		{"pos": 1.333, "expected": "weak", "description": "Beat 2, second triplet note"},
		{"pos": 2.0, "expected": "medium", "description": "Beat 3"},
		{"pos": 2.333, "expected": "weak", "description": "Beat 3, second triplet note"}
	]

	var pass_count = 0
	var fail_count = 0

	for test in test_positions:
		var pos = test.pos
		var expected = test.expected
		var description = test.description

		var actual = time_grid.get_beat_strength(pos)

		if actual == expected:
			print("✓ PASS: pos=" + str(pos) + " (" + description + ") → " + actual)
			pass_count += 1
		else:
			print("✗ FAIL: pos=" + str(pos) + " (" + description + ") → expected=" + expected + ", got=" + actual)
			fail_count += 1

	print("\nBeat Strength Test Summary:")
	print("  Passed: " + str(pass_count) + "/" + str(test_positions.size()))
	print("  Failed: " + str(fail_count) + "/" + str(test_positions.size()))

	if fail_count == 0:
		print("  ✓ ALL BEAT STRENGTH TESTS PASSED")
	else:
		print("  ✗ SOME TESTS FAILED")

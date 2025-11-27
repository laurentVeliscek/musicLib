extends Node

# Example test script for SATB Fractalizer
# This demonstrates how to use the system

const TAG = "TestExample"

var Planner = load("res://addons/musiclib/satb_fractalizer/planner/Planner.gd")

func run():
	LogBus.info(TAG, "===== SATB Fractalizer Test =====")
	LogBus.set_verbose(true)

	# Load test chords from chords.json
	var test_chords = _load_chords_from_file()
	
	# generation des time_windows
	var begin_pos = test_chords[0]["pos"]
	var end_pos = test_chords[-1]["pos"]+test_chords[-1]["length_beats"]
	var window_length = 4.0
	var number_of_windows = int((end_pos - begin_pos) / window_length)
	
	var generated_time_windows = []
	for i in range(0,number_of_windows):
		generated_time_windows.append( {"start": begin_pos + (window_length * i), "end": begin_pos + (window_length * (i+1))})
		
	#LogBus.debug(TAG,"generated_time_windows: "+ str(generated_time_windows))
	
	
	# Configure planner - First pass
	var planner = Planner.new()
	var params = {
		"time_num": 4,
		"time_den": 4,
		"grid_unit": 0.25,
		"time_windows": generated_time_windows,
		"allowed_techniques": ["passing_tone", "neighbor_tone", "appoggiatura", "chromatic_passing_tone", "double_neighbor"],
		"voice_window_pattern": "SATB",
		"triplet_allowed": false,
		"rng_seed": 42
	}
## ["passing_tone", "neighbor_tone", "appoggiatura", "chromatic_passing_tone", "double_neighbor"]
	# Apply fractalizer - First pass
	LogBus.info(TAG, "\n===== FIRST PASS =====")
	var result = planner.apply(test_chords, params)

	# Display first pass result
#	LogBus.info(TAG, "\n===== First Pass Result =====")
#	LogBus.info(TAG, "Original chords: " + str(test_chords.size()))
#	LogBus.info(TAG, "Result chords: " + str(result.chords.size()))
#	LogBus.info(TAG, "Result (first 3 chords): " + JSON.print(result.chords.slice(0, 2), "\t"))
#	LogBus.info(TAG, "\n--- Progression Metadata ---")
#	LogBus.info(TAG, "Generation depth: " + str(result.metadata.get("generation_depth", 0)))
#	LogBus.info(TAG, "RNG seed: " + str(result.metadata.get("rng_seed", "N/A")))
#	LogBus.info(TAG, "History entries: " + str(result.metadata.history.size()))
#	LogBus.info(TAG, "Time windows processed: " + str(result.metadata.technique_report.time_windows.size()))

	# Re-inject result into planner for second pass
	LogBus.info(TAG, "\n===== SECOND PASS (RE-INJECTION) =====")
	var planner2 = Planner.new()
	var params2 = {
		"time_num": 4,
		"time_den": 4,
		"grid_unit": 0.125,
		"time_windows": generated_time_windows,
		"allowed_techniques": ["passing_tone", "neighbor_tone", "appoggiatura", "chromatic_passing_tone", "double_neighbor"],
		"voice_window_pattern": "SATB",
		"triplet_allowed": false,
		"rng_seed": 55
	}

	var result2 = planner2.apply(result.chords, params2)

	# Display second pass result
#	LogBus.info(TAG, "\n===== Second Pass Result =====")
#	LogBus.info(TAG, "First pass chords: " + str(result.chords.size()))
#	LogBus.info(TAG, "Second pass chords: " + str(result2.chords.size()))
#	LogBus.info(TAG, "Result2 (first 3 chords): " + JSON.print(result2.chords.slice(0, 2), "\t"))
#	LogBus.info(TAG, "\n--- Second Pass Metadata ---")
#	LogBus.info(TAG, "Generation depth: " + str(result2.metadata.get("generation_depth", 0)))
#	LogBus.info(TAG, "History entries: " + str(result2.metadata.history.size()))
#	LogBus.info(TAG, "Time windows processed: " + str(result2.metadata.technique_report.time_windows.size()))

	LogBus.info(TAG, "\n===== Test Complete =====")
	
#	LogBus.info(TAG, "\n===== RESULT FULL =====")
#	LogBus.info(TAG, "\n\nResult (full): " + JSON.print(result, "\t"))
#	LogBus.info(TAG, "\n\n===== RESULT2 FULL =====")
#	LogBus.info(TAG, "\n\nResult2 (full): " + JSON.print(result2, "\t"))
	
	LogBus.info(TAG, "\n===== Bilan =====")
	LogBus.info(TAG, "\n===== PASS 1 =====")
	LogBus.info(TAG, "Total chords: " + str(result.chords.size()))
	LogBus.info(TAG, "\n===== PASS 2 =====")
	LogBus.info(TAG, "Total chords: " + str(result2.chords.size()))
	LogBus.info(TAG, "\n\n*******************************************")
	LogBus.info(TAG, "\n\n===== Result (full) =====")
	LogBus.info(TAG, "\nResult (full): " + JSON.print(result, "\t"))
	LogBus.info(TAG, "\n\n===== Result2 (full) =====")
	LogBus.info(TAG, "Result2 (full): " + JSON.print(result2, "\t"))
	
#	for c in result2.chords:
#		if c["kind"] == "decorative":
#			LogBus.info(TAG, JSON.print(c, "\t"))
		
	#LogBus.info(TAG, "\n\nResult2 (full): " + JSON.print(result2.chords, "\t"))
	

func _load_chords_from_file():
	# Load chords from chords.json file
	var file = File.new()
	var path = "res://chords.json"

	if not file.file_exists(path):
		LogBus.error(TAG, "chords.json not found at " + path)
		return _create_test_chords()

	var error = file.open(path, File.READ)
	if error != OK:
		LogBus.error(TAG, "Failed to open chords.json: " + str(error))
		return _create_test_chords()

	var content = file.get_as_text()
	file.close()

	var parse_result = JSON.parse(content)
	if parse_result.error != OK:
		LogBus.error(TAG, "Failed to parse chords.json: " + parse_result.error_string)
		return _create_test_chords()

	var chords = parse_result.result
	LogBus.info(TAG, "Loaded " + str(chords.size()) + " chords from chords.json")
	return chords

func _create_test_chords():
	# Create a simple 4-chord progression in C major
	return [
		{
			"index": 0,
			"pos": 0,
			"length_beats": 2,
			"key_midi_root": 60,
			"scale_array": [0, 2, 4, 5, 7, 9, 11],
			"key_alterations": {},
			"key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 72,
			"Alto": 67,
			"Tenor": 64,
			"Bass": 48
		},
		{
			"index": 1,
			"pos": 2,
			"length_beats": 2,
			"key_midi_root": 60,
			"scale_array": [0, 2, 4, 5, 7, 9, 11],
			"key_alterations": {},
			"key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 76,
			"Alto": 69,
			"Tenor": 64,
			"Bass": 52
		},
		{
			"index": 2,
			"pos": 4,
			"length_beats": 2,
			"key_midi_root": 60,
			"scale_array": [0, 2, 4, 5, 7, 9, 11],
			"key_alterations": {},
			"key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 74,
			"Alto": 67,
			"Tenor": 62,
			"Bass": 50
		},
		{
			"index": 3,
			"pos": 6,
			"length_beats": 2,
			"key_midi_root": 60,
			"scale_array": [0, 2, 4, 5, 7, 9, 11],
			"key_alterations": {},
			"key_scale_name": "major",
			"kind": "diatonic",
			"Soprano": 72,
			"Alto": 64,
			"Tenor": 60,
			"Bass": 48
		}
	]

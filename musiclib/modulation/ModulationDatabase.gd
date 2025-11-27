# ModulationDatabase.gd
# Database querying system for modulation progressions
extends Resource
class_name ModulationDatabase
# Loaded database
var db_metadata: Dictionary = {}
var db_progressions: Array = []

func _ready():
	load_database()

func load_database(path: String = "res://addons/musiclib/modulation/modulationDB.json"):
	"""Load the modulation database from JSON file"""
	var file = File.new()
	
	if not file.file_exists(path):
		print("Error: Modulation database not found at ", path)
		return
	
	if file.open(path, File.READ) != OK:
		print("Error: Cannot open modulation database")
		return
	
	var json_result = JSON.parse(file.get_as_text())
	file.close()
	
	if json_result.error != OK:
		print("Error parsing JSON: ", json_result.error_string)
		return
	
	var data = json_result.result
#	db_metadata = data.get("metadata", {})
#	db_progressions = data.get("progressions", [])
	
	print("✓ Loaded ", db_progressions.size(), " progressions")
#	print("  Offsets available: ", db_metadata.get("offsets_available", []))
#	print("  Techniques: ", db_metadata.get("techniques_available", []))


#
#func query(request: Dictionary) -> Array:
#	"""
#	Query progressions matching criteria
#
#	Args:
#		request = {
#			# --- Option 1: Specify keys directly ---
#			"from_key_midi_root": int (0-11),
#			"to_key_midi_root": int (0-11),
#
#			# --- Option 2: Specify offset directly ---
#			"offset": int (1-11),
#
#			# --- Common filters ---
#			"from_degree": int (1-7),
#			"from_mode": String ("major", "minor", "harmonic_minor", "melodic_minor"),
#			"from_inversion": int (0-3),
#			"seventh": bool,
#			"to_degree": int (1, 5, or 6),
#			"to_mode": String,
#			"techniques": Array of String (["pivot_chord", ...]),
#
#			# --- Quality filters ---
#			"min_quality": float (0.0-1.0),
#			"min_voice_leading": float,
#			"min_chromatic_direction": float,
#			"min_functional_coherence": float,
#
#			# --- Metadata filters ---
#			"max_difficulty": int (1-5),
#			"min_difficulty": int (1-5),
#			"style": String ("classical", "jazz", "pop", "romantic"),
#			"max_length": int (number of chords),
#			"min_length": int
#		}
#
#	Returns:
#		Array of progression dictionaries matching ALL criteria
#	"""
#
#	var results = []
#
#	# Calculate offset if needed
#	var offset = request.get("offset", -1)
#	if offset == -1:
#		if request.has("from_key_midi_root") and request.has("to_key_midi_root"):
#			offset = (request["to_key_midi_root"] - request["from_key_midi_root"]) % 12
#			if offset == 0:
#				# Same key, no modulation
#				return []
#
#	# Filter progressions
#	for prog in db_progressions:
#		# Offset filter
#		if offset != -1 and prog["offset"] != offset:
#			continue
#
#		# From degree filter
#		if request.has("from_degree") and prog["from_degree"] != request["from_degree"]:
#			continue
#
#		# From mode filter
#		if request.has("from_mode") and prog["from_mode"] != request["from_mode"]:
#			continue
#
#		# From inversion filter
#		if request.has("from_inversion") and prog["from_inversion"] != request["from_inversion"]:
#			continue
#
#		# Seventh filter
#		if request.has("seventh") and prog["seventh"] != request["seventh"]:
#			continue
#
#		# To degree filter
#		if request.has("to_degree") and prog["to_degree"] != request["to_degree"]:
#			continue
#
#		# To mode filter
#		if request.has("to_mode") and prog["to_mode"] != request["to_mode"]:
#			continue
#
#		# Techniques filter
#		if request.has("techniques"):
#			if not request["techniques"].has(prog["technique"]):
#				continue
#
#		# Quality filters
#		if request.has("min_quality"):
#			if prog["quality"]["overall"] < request["min_quality"]:
#				continue
#
#		if request.has("min_voice_leading"):
#			if prog["quality"]["voice_leading"] < request["min_voice_leading"]:
#				continue
#
#		if request.has("min_chromatic_direction"):
#			if prog["quality"]["chromatic_direction"] < request["min_chromatic_direction"]:
#				continue
#
#		if request.has("min_functional_coherence"):
#			if prog["quality"]["functional_coherence"] < request["min_functional_coherence"]:
#				continue
#
#		# Difficulty filters
#		if request.has("max_difficulty"):
#			if prog["metadata"]["difficulty"] > request["max_difficulty"]:
#				continue
#
#		if request.has("min_difficulty"):
#			if prog["metadata"]["difficulty"] < request["min_difficulty"]:
#				continue
#
#		# Style filter
#		if request.has("style"):
#			var found_style = false
#			for s in prog["metadata"]["style"]:
#				if s == request["style"]:
#					found_style = true
#					break
#			if not found_style:
#				continue
#
#		# Length filters
#		if request.has("max_length"):
#			if prog["metadata"]["length"] > request["max_length"]:
#				continue
#
#		if request.has("min_length"):
#			if prog["metadata"]["length"] < request["min_length"]:
#				continue
#
#		# Match! Add to results
#		results.append(prog)
#
#	return results
#
#func query_best(request: Dictionary, sort_by: String = "overall") -> Dictionary:
#	"""
#	Query and return the BEST progression matching criteria
#
#	Args:
#		request: Same as query()
#		sort_by: "overall", "voice_leading", "difficulty", "length"
#
#	Returns:
#		Single best progression or empty dict if none found
#	"""
#	var results = query(request)
#
#	if results.empty():
#		return {}
#
#	# Sort results
#	match sort_by:
#		"overall":
#			results.sort_custom(self, "_sort_by_overall_quality")
#		"voice_leading":
#			results.sort_custom(self, "_sort_by_voice_leading")
#		"difficulty":
#			results.sort_custom(self, "_sort_by_difficulty_asc")
#		"length":
#			results.sort_custom(self, "_sort_by_length")
#
#	return results[0]
#
## Sorting functions
#func _sort_by_overall_quality(a, b) -> bool:
#	return a["quality"]["overall"] > b["quality"]["overall"]
#
#func _sort_by_voice_leading(a, b) -> bool:
#	return a["quality"]["voice_leading"] > b["quality"]["voice_leading"]
#
#func _sort_by_difficulty_asc(a, b) -> bool:
#	return a["metadata"]["difficulty"] < b["metadata"]["difficulty"]
#
#func _sort_by_length(a, b) -> bool:
#	return a["metadata"]["length"] < b["metadata"]["length"]
#
## ============================================================================
## USAGE EXAMPLES
## ============================================================================
#
#func example_simple_query():
#	"""Example: Simple modulation C major to G major"""
#	var progs = query({
#		"from_key_midi_root": 0,  # C
#		"to_key_midi_root": 7,     # G
#		"from_degree": 1,
#		"to_degree": 1,
#		"techniques": ["pivot_chord"]
#	})
#
#	print("\nSimple query: C major I → G major I")
#	print("Found ", progs.size(), " progressions")
#
#	if progs.size() > 0:
#		var best = progs[0]
#		print("  Best: quality=", best["quality"]["overall"], 
#			  " difficulty=", best["metadata"]["difficulty"],
#			  " length=", best["metadata"]["length"])
#
#func example_filtered_query():
#	"""Example: High-quality, easy modulations"""
#	var progs = query({
#		"offset": 7,               # Fifth up
#		"min_quality": 0.90,       # Very high quality only
#		"max_difficulty": 2,       # Easy to moderate
#		"style": "classical"       # Classical style
#	})
#
#	print("\nFiltered query: High quality, easy, classical")
#	print("Found ", progs.size(), " progressions")
#
#func example_flexible_query():
#	"""Example: Any modulation from I major, with seventh chords"""
#	var progs = query({
#		"from_degree": 1,
#		"from_mode": "major",
#		"seventh": true,           # Tetrads only
#		"min_quality": 0.80
#	})
#
#	print("\nFlexible query: From I major, sevenths, good quality")
#	print("Found ", progs.size(), " progressions")
#
#	# Show offsets available
#	var offsets = {}
#	for prog in progs:
#		var off = prog["offset"]
#		if not offsets.has(off):
#			offsets[off] = 0
#		offsets[off] += 1
#
#	print("  Offsets available:")
#	for offset in offsets.keys():
#		print("    +", offset, ": ", offsets[offset], " progressions")
#
#func example_get_best():
#	"""Example: Get single best progression"""
#	var best = query_best({
#		"from_key_midi_root": 0,
#		"to_key_midi_root": 9,  # C to A
#		"techniques": ["pivot_chord"]
#	}, "overall")  # Sort by overall quality
#
#	if not best.empty():
#		print("\nBest progression C → A:")
#		print("  Quality: ", best["quality"]["overall"])
#		print("  Technique: ", best["technique"])
#		print("  Chords: ", best["metadata"]["length"])
#
## Example usage in your game
#func play_modulation(from_key: int, to_key: int):
#	"""Play a modulation between two keys"""
#
#	# Query for best progression
#	var best = query_best({
#		"from_key_midi_root": from_key,
#		"to_key_midi_root": to_key,
#		"from_degree": 1,
#		"to_degree": 1,
#		"max_difficulty": 3
#	}, "overall")
#
#	if best.empty():
#		print("No modulation found!")
#		return
#
#	print("Playing modulation ", best["id"])
#	print("  Quality: ", best["quality"]["overall"])
#	print("  Length: ", best["metadata"]["length"], " chords")
#
#	# Play each chord
#	for chord_data in best["chords"]:
#		var absolute_key = (from_key + chord_data["key_midi_root"]) % 12
#		play_chord(absolute_key, chord_data)
#		#yield(get_tree().create_timer(1.0), "timeout")
#
#func play_chord(key_midi: int, chord_data: Dictionary):
#	"""Your chord playing logic here"""
#	print("  Playing: ", chord_data.get("comment", "chord"), 
#		  " - deg ", chord_data["degree_number"],
#		  " in key ", key_midi)
#	# Your actual SATB or audio playing code here

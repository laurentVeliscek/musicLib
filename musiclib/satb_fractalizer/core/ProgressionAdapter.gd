extends Node

const TAG = "ProgressionAdapter"
const Constants = preload("res://addons/musiclib/satb_fractalizer/core/Constants.gd")

var ScaleContext = load("res://addons/musiclib/satb_fractalizer/core/ScaleContext.gd")
var Voice = load("res://addons/musiclib/satb_fractalizer/core/Voice.gd")
var Chord = load("res://addons/musiclib/satb_fractalizer/core/Chord.gd")
var TimeGrid = load("res://addons/musiclib/satb_fractalizer/core/TimeGrid.gd")
var Progression = load("res://addons/musiclib/satb_fractalizer/core/Progression.gd")

# =============================================================================
# JSON ARRAY → PROGRESSION
# =============================================================================

func from_json_array(chords_array, time_num, time_den, grid_unit):
	LogBus.info(TAG, "Converting JSON array to Progression (" + str(chords_array.size()) + " chords)")

	var prog = Progression.new()
	prog.time_grid = TimeGrid.new(time_num, time_den, grid_unit)

	for i in range(chords_array.size()):
		var json_chord = chords_array[i]

		# Convert key_alterations string keys to integers
		var alterations = {}
		var json_alterations = json_chord.get("key_alterations", {})
		for key in json_alterations.keys():
			var int_key = int(key)
			alterations[int_key] = json_alterations[key]

		# Build ScaleContext
		var scale = ScaleContext.new(
			json_chord.key_midi_root,
			json_chord.scale_array,
			alterations,
			json_chord.get("key_scale_name", "unknown")
		)

		# Build Voices
		var voices = {}
		var json_voices_metadata = json_chord.get("voices_metadata", {})

		for voice_id in Constants.VOICES:
			var json_voice_name = Constants.VOICE_TO_JSON[voice_id]

			if not json_chord.has(json_voice_name):
				LogBus.error(TAG, "from_json_array: missing voice " + json_voice_name + " in chord " + str(i))
				return null

			# Get voice metadata if present
			var voice_metadata = {}
			if json_voices_metadata.has(voice_id):
				voice_metadata = json_voices_metadata[voice_id].duplicate(true)

			voices[voice_id] = Voice.new(
				json_chord[json_voice_name],  # pitch
				Constants.ROLE_CHORD_TONE,
				null,  # technique
				Constants.DIRECTION_STATIC,
				false,  # locked
				voice_metadata
			)

		# Build Chord
		var chord = Chord.new(
			json_chord.get("index", i),
			float(json_chord.pos),
			float(json_chord.length_beats),
			voices,
			scale,
			json_chord.get("kind", "diatonic")
		)

		# Restore chord metadata if present
		if json_chord.has("chord_metadata"):
			chord.metadata = json_chord["chord_metadata"].duplicate(true)

		prog.add_chord(chord)

	LogBus.info(TAG, "Conversion complete: " + str(prog.get_chord_count()) + " chords")
	return prog

# =============================================================================
# PROGRESSION → JSON ARRAY
# =============================================================================

func to_json_array(progression):
	LogBus.info(TAG, "Converting Progression to JSON array (" + str(progression.get_chord_count()) + " chords)")

	var result = []

	for chord in progression.chords:
		# Convert integer alteration keys back to strings for JSON
		var json_alterations = {}
		for key in chord.scale_context.alterations.keys():
			json_alterations[str(key)] = chord.scale_context.alterations[key]

		var json_chord = {
			"pos": chord.start_time,
			"length_beats": chord.duration,
			"key_midi_root": chord.scale_context.root,
			"scale_array": chord.scale_context.steps.duplicate(),
			"key_alterations": json_alterations,
			"key_scale_name": chord.scale_context.scale_name,
			"kind": chord.kind
		}

		# Add voices
		for voice_id in Constants.VOICES:
			var json_voice_name = Constants.VOICE_TO_JSON[voice_id]

			if chord.voices.has(voice_id):
				json_chord[json_voice_name] = chord.voices[voice_id].pitch
			else:
				LogBus.error(TAG, "to_json_array: missing voice " + voice_id + " in chord " + str(chord.id))
				return null

		# Add chord metadata if present
		if chord.metadata and not chord.metadata.empty():
			json_chord["chord_metadata"] = chord.metadata.duplicate(true)

		# Add voice metadata if present
		var voices_metadata = {}
		for voice_id in Constants.VOICES:
			if chord.voices.has(voice_id):
				var voice = chord.voices[voice_id]
				if voice.metadata and not voice.metadata.empty():
					voices_metadata[voice_id] = voice.metadata.duplicate(true)

		if not voices_metadata.empty():
			json_chord["voices_metadata"] = voices_metadata

		result.append(json_chord)

	LogBus.info(TAG, "Conversion complete: " + str(result.size()) + " chords")
	return result

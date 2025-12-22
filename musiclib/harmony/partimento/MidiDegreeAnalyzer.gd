extends Reference
class_name MidiDegreeAnalyzer

const TAG = "MidiDegreeAnalyzer"


func analyze(track: Track, tonic_key: HarmonicKey) -> Array:
	var candidates: Array = []
	if track == null or tonic_key == null:
		return candidates

	if track.events == null:
		return candidates

	var events: Array = []
	for ev in track.events:
		if typeof(ev) != TYPE_DICTIONARY or not ev.has("note"):
			continue

		var note: Note = ev["note"]
		if note == null:
			continue

		var degree_info = _degree_from_midi(note.midi, tonic_key)
		var item = {
			"start": float(ev.get("start", 0.0)),
			"length_beats": float(note.length_beats),
			"degree_number": int(degree_info.get("degree_number", 1)),
			"alteration": int(degree_info.get("alteration", 0)),
			"midi": int(note.midi)
		}
		events.append(item)

	candidates.append({"events": events})
	return candidates


func _degree_from_midi(midi: int, key: HarmonicKey) -> Dictionary:
	var scale: Array = key.get_scale_array()
	if scale.size() == 0:
		return {"degree_number": 1, "alteration": 0}

	var root_pc = key.root_midi % 12
	var pc = int(midi) % 12

	var best_degree = 1
	var best_diff = 999
	var best_alt = 0

	for i in range(scale.size()):
		var degree_pc = (root_pc + int(scale[i])) % 12
		var diff = _signed_mod_interval(pc - degree_pc)
		var abs_diff = abs(diff)

		if abs_diff < best_diff:
			best_diff = abs_diff
			best_degree = i + 1
			best_alt = diff

	return {"degree_number": best_degree, "alteration": best_alt}


func _signed_mod_interval(semitones: int) -> int:
	var wrapped = ((semitones % 12) + 12) % 12
	if wrapped > 6:
		wrapped -= 12
	return wrapped

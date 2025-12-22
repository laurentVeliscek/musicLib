extends Reference
class_name MidiDegreeAnalyzer

# Analyse basique d'une mélodie MIDI pour générer des candidats de degrés

const DEFAULT_DIATONIC_WEIGHT := 1.0
const DEFAULT_SECONDARY_WEIGHT := 0.6

# Propositions chromatiques (majeur) : offsets depuis la tonique (mod 12)
const CHROMATIC_SUGGESTIONS_MAJOR := [
	{
		"offset": 1, # #I -> sensible secondaire vers ii
		"degree_hint": 2,
		"kind": "secondary",
		"label": "Leading tone vers ii (V/ii)",
		"resolves_to": [2],
		"weight": DEFAULT_SECONDARY_WEIGHT
	},
	{
		"offset": 6, # #4 -> sensible secondaire vers V
		"degree_hint": 5,
		"kind": "secondary",
		"label": "Leading tone vers V (V/V)",
		"resolves_to": [5],
		"weight": DEFAULT_SECONDARY_WEIGHT
	},
	{
		"offset": 8, # #6 -> sensible secondaire vers vi
		"degree_hint": 6,
		"kind": "secondary",
		"label": "Leading tone vers vi (V/vi)",
		"resolves_to": [6],
		"weight": DEFAULT_SECONDARY_WEIGHT
	},
	{
		"offset": 10, # b7 empruntée / mixolydienne
		"degree_hint": 5,
		"kind": "borrowed",
		"label": "Dominante mixolydienne empruntée",
		"resolves_to": [1],
		"weight": 0.4
	}
]

# Propositions chromatiques (mineur relatif)
const CHROMATIC_SUGGESTIONS_MINOR := [
	{
		"offset": 4, # #3 -> couleur harmonique / sensible vers iv
		"degree_hint": 4,
		"kind": "secondary",
		"label": "Leading tone vers iv (V/iv)",
		"resolves_to": [4],
		"weight": DEFAULT_SECONDARY_WEIGHT
	},
	{
		"offset": 8, # #7 -> sensible classique
		"degree_hint": 1,
		"kind": "secondary",
		"label": "Sensible de la tonalité mineure",
		"resolves_to": [1],
		"weight": DEFAULT_SECONDARY_WEIGHT
	},
	{
		"offset": 10, # b2 / Neapolitan flavour
		"degree_hint": 2,
		"kind": "borrowed",
		"label": "Couleur napolitaine (bII)",
		"resolves_to": [1],
		"weight": 0.4
	}
]


func analyze(track_notes: Array, tonic_major: int) -> Dictionary:
	var midi_notes := _extract_midi(track_notes)
	var contexts := _build_contexts(tonic_major)

	var candidate_grid: Array = []
	for n in midi_notes:
		var note_candidates: Array = []
		for ctx in contexts:
			note_candidates += _analyze_note_in_context(n, ctx)
		candidate_grid.append(note_candidates)

	candidate_grid = _filter_secondary_retrograde(candidate_grid, midi_notes, contexts)

	var summary_contexts: Array = []
	for ctx in contexts:
		summary_contexts.append({
			"label": ctx["label"],
			"root_midi": ctx["key"].root_midi,
			"scale": ctx["key"].scale_name
		})

	var result := {
		"notes": midi_notes,
		"contexts": summary_contexts,
		"candidates": candidate_grid
	}
	result["json"] = JSON.print(result)
	return result


func _build_contexts(tonic_major: int) -> Array:
	var major_key := HarmonicKey.new()
	major_key.root_midi = tonic_major
	major_key.scale_name = "major"

	var relative_minor_key := HarmonicKey.new()
	relative_minor_key.root_midi = tonic_major - 3
	relative_minor_key.scale_name = "minor"

	return [
		{"label": "major", "key": major_key, "chromatic": CHROMATIC_SUGGESTIONS_MAJOR},
		{"label": "relative_minor", "key": relative_minor_key, "chromatic": CHROMATIC_SUGGESTIONS_MINOR}
	]


func _extract_midi(track_notes: Array) -> Array:
	var out: Array = []
	for n in track_notes:
		if typeof(n) == TYPE_INT:
			out.append(int(n))
		elif typeof(n) == TYPE_OBJECT and n.has("midi"):
			out.append(int(n.midi))
	return out


func _analyze_note_in_context(note_midi: int, ctx: Dictionary) -> Array:
	var key: HarmonicKey = ctx["key"]
	var out: Array = []
	var offset := _pitch_class(note_midi - key.root_midi)

	var degree := _offset_to_degree(offset, key)
	if degree != -1:
		out.append(_make_candidate(note_midi, ctx, degree, "diatonic", DEFAULT_DIATONIC_WEIGHT, [], offset, ""))

	for entry in ctx["chromatic"]:
		if entry.get("offset", -99) == offset:
			var kind := entry.get("kind", "secondary")
			var degree_hint := entry.get("degree_hint", degree)
			var resolves := entry.get("resolves_to", [])
			var label := entry.get("label", "")
			var weight := entry.get("weight", DEFAULT_SECONDARY_WEIGHT)
			out.append(_make_candidate(note_midi, ctx, degree_hint, kind, weight, resolves, offset, label))

	return out


func _filter_secondary_retrograde(grid: Array, notes: Array, contexts: Array) -> Array:
	var out: Array = []
	for i in range(grid.size()):
		var next_note = null
		if i + 1 < notes.size():
			next_note = notes[i + 1]
		var filtered: Array = []
		for cand in grid[i]:
			if cand.get("kind", "") != "secondary":
				filtered.append(cand)
				continue
			if next_note == null:
				continue
			var root_midi: int = cand.get("root_midi", 0)
			var next_offset := _pitch_class(next_note - root_midi)
			var resolves: Array = cand.get("resolves_to", [])
			if resolves.has(next_offset):
				filtered.append(cand)
		out.append(filtered)
	return out


func _make_candidate(note_midi: int, ctx: Dictionary, degree: int, kind: String, weight: float, resolves_to: Array, offset: int, label: String) -> Dictionary:
	return {
		"context": ctx["label"],
		"root_midi": ctx["key"].root_midi,
		"note": note_midi,
		"offset": offset,
		"degree": degree,
		"kind": kind,
		"label": label,
		"weight": weight,
		"resolves_to": resolves_to
	}


func _offset_to_degree(offset: int, key: HarmonicKey) -> int:
	var arr: Array = key.get_scale_array()
	for i in range(arr.size()):
		if int(arr[i]) % 12 == offset % 12:
			return i + 1
	return -1


func _pitch_class(v: int) -> int:
	return int((v % 12 + 12) % 12)

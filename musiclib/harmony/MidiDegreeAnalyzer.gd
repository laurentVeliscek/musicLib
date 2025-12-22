extends Reference
class_name MidiDegreeAnalyzer

# Analyse basique d'une mélodie MIDI pour générer des candidats de degrés
# dans deux contextes : tonalité majeure donnée et relative mineure.
# Inclut des suggestions chromatiques pondérées (dominantes secondaires,
# emprunts) et une étape de filtrage rétrograde simple pour éliminer les
# secondary sans résolution plausible.

const DEFAULT_DIATONIC_WEIGHT := 1.0
const DEFAULT_SECONDARY_WEIGHT := 0.6
const DEFAULT_BORROWED_WEIGHT := 0.5

# Propositions chromatiques (majeur) : offsets depuis la tonique (mod 12)
const CHROMATIC_SUGGESTIONS_MAJOR := [
	{
		"offset": 1, # #1 -> sensible secondaire vers ii
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
		"offset": 10, # b7 -> emprunt mixolydien (bVII) ou IV/IV
		"degree_hint": 7,
		"kind": "borrowed",
		"label": "bVII ou IV emprunté",
		"resolves_to": [],
		"weight": DEFAULT_BORROWED_WEIGHT
	},
	{
		"offset": 3, # b3 -> emprunt mineur
		"degree_hint": 3,
		"kind": "borrowed",
		"label": "bIII (emprunt mineur)",
		"resolves_to": [],
		"weight": DEFAULT_BORROWED_WEIGHT
	}
]

# Propositions chromatiques (mineur) : offsets depuis la tonique mineure (mod 12)
const CHROMATIC_SUGGESTIONS_MINOR := [
	{
		"offset": 1, # b2 -> Neapolitan / iv phrygien
		"degree_hint": 2,
		"kind": "borrowed",
		"label": "bII (Neapolitan) / iv phrygien",
		"resolves_to": [],
		"weight": DEFAULT_BORROWED_WEIGHT
	},
	{
		"offset": 4, # #3 -> V/iv ou vii°/iv
		"degree_hint": 3,
		"kind": "secondary",
		"label": "Leading tone vers iv (V/iv)",
		"resolves_to": [4],
		"weight": DEFAULT_SECONDARY_WEIGHT
	},
	{
		"offset": 8, # #6 -> V/vi° ou coloration
		"degree_hint": 6,
		"kind": "secondary",
		"label": "Leading tone vers vi° (couleur)",
		"resolves_to": [6],
		"weight": DEFAULT_SECONDARY_WEIGHT
	},
	{
		"offset": 9, # #7 -> sensible principale
		"degree_hint": 7,
		"kind": "secondary",
		"label": "Sensible de la tonique (vii°/i)",
		"resolves_to": [1],
		"weight": DEFAULT_SECONDARY_WEIGHT
	},
	{
		"offset": 3, # b3 -> bIII emprunt dorien/majeur relatif
		"degree_hint": 3,
		"kind": "borrowed",
		"label": "bIII (emprunt)",
		"resolves_to": [],
		"weight": DEFAULT_BORROWED_WEIGHT
	},
	{
		"offset": 8, # b6 -> bVI (emprunt modal)
		"degree_hint": 6,
		"kind": "borrowed",
		"label": "bVI (emprunt modal)",
		"resolves_to": [],
		"weight": DEFAULT_BORROWED_WEIGHT
	}
]

const DIATONIC_MAJOR := {
	0: 1, 2: 2, 4: 3, 5: 4, 7: 5, 9: 6, 11: 7
}

const DIATONIC_MINOR := {
	0: 1, 2: 2, 3: 3, 5: 4, 7: 5, 8: 6, 10: 7
}

func analyze(track_notes: Array, tonic_major) -> Dictionary:
	# track_notes est un Array de dictionnaires { "midi": int, "length_beats": float, "start": float }
	var result := {
		"contexts": []
	}
	if track_notes == null or tonic_major == null:
		return result
	
	var tonic_pc := int(tonic_major.root_midi) % 12
	var tonic_relative_minor := (tonic_pc + 9) % 12
	
	var major_ctx := _analyze_context(track_notes, tonic_pc, "major", DIATONIC_MAJOR, CHROMATIC_SUGGESTIONS_MAJOR)
	var minor_ctx := _analyze_context(track_notes, tonic_relative_minor, "minor_relative", DIATONIC_MINOR, CHROMATIC_SUGGESTIONS_MINOR)
	
	result.contexts.append(major_ctx)
	result.contexts.append(minor_ctx)
	# Filtrage rétrograde léger : retire les secondary sans résolution plausible.
	_filter_secondary_paths(result)
	return result


func _analyze_context(track_notes: Array, tonic_pc: int, label: String, diatonic_map: Dictionary, chroma_table: Array) -> Dictionary:
	var candidates := []
	for note_info in track_notes:
		if typeof(note_info) != TYPE_DICTIONARY or not note_info.has("midi"):
			continue
		var midi := int(note_info["midi"])
		var pc := midi % 12
		var offset := (pc - tonic_pc + 12) % 12
		
		var note_candidates := []
		# Diatonique
		if diatonic_map.has(offset):
			note_candidates.append({
				"degree": diatonic_map[offset],
				"kind": "diatonic",
				"weight": DEFAULT_DIATONIC_WEIGHT
			})
		# Chromatique
		for entry in chroma_table:
			if entry.get("offset", -1) == offset:
				note_candidates.append({
					"degree": entry.get("degree_hint", 0),
					"kind": entry.get("kind", "secondary"),
					"label": entry.get("label", ""),
					"resolves_to": entry.get("resolves_to", []),
					"weight": entry.get("weight", DEFAULT_SECONDARY_WEIGHT)
				})
		# S'il n'y a rien, au moins un placeholder pour debug
		if note_candidates.empty():
			note_candidates.append({
				"degree": null,
				"kind": "unknown",
				"weight": 0.0
			})
		candidates.append(note_candidates)
	
	return {
		"scale_label": label,
		"tonic_pc": tonic_pc,
		"candidates": candidates
	}


func _filter_secondary_paths(result: Dictionary) -> void:
	# Parcours fin->début : si une note est taggée secondary avec une résolution attendue,
	# on vérifie que la note suivante contient l'un des degrés cibles. Sinon, on baisse son poids.
	if not result.has("contexts"):
		return
	for ctx in result.contexts:
		var candidates: Array = ctx.get("candidates", [])
		for i in range(candidates.size() - 2, -1, -1):
			var current_candidates: Array = candidates[i]
			var next_candidates: Array = candidates[i + 1]
			for cand in current_candidates:
				if cand.get("kind", "") != "secondary":
					continue
				var resolutions: Array = cand.get("resolves_to", [])
				if resolutions.empty():
					continue
				var ok := false
				for nxt in next_candidates:
					if resolutions.has(nxt.get("degree", -1)):
						ok = true
						break
				if not ok:
					# baisse le poids pour signaler une résolution faible
					cand["weight"] = cand.get("weight", DEFAULT_SECONDARY_WEIGHT) * 0.25

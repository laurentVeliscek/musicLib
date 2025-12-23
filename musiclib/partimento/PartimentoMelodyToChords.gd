# PartimentoMelodyToChords.gd
# Interface principale pour convertir une mélodie MIDI en degrés harmoniques
# Étape 1 du partimento: mélodie -> interprétations possibles

extends Reference
class_name PartimentoMelodyToChords

const TAG = "PartimentoMelodyToChords"

var _analyzer: PartimentoMelodyAnalyzer = null
var _generator: PartimentoSolutionGenerator = null


func _init():
	_analyzer = PartimentoMelodyAnalyzer.new()
	_generator = PartimentoSolutionGenerator.new()


# === API PRINCIPALE ===

# Convertit une mélodie en toutes les solutions possibles
# song: Song contenant une Track nommée "midi_melody" (ou track_name spécifié)
# reference_key: HarmonicKey majeure de référence
# track_name: Nom de la track de mélodie (défaut: "midi_melody")
# Retourne: Array de Track (chaque Track = une solution possible)
func convert_melody_to_solutions(song: Song, reference_key: HarmonicKey, track_name: String = "midi_melody") -> Array:
	# Récupérer la track de mélodie
	var melody_track = song.get_track_by_name(track_name)
	if melody_track == null:
		LogBus.debug(TAG, "Track '%s' non trouvée dans la Song" % track_name)
		return []

	# Analyser la mélodie
	var interpretations = _analyzer.analyze_melody(melody_track, reference_key)
	if interpretations.empty():
		LogBus.debug(TAG, "Aucune interprétation trouvée")
		return []

	# Afficher les statistiques
	var stats = _generator.get_statistics(interpretations)
	LogBus.debug(TAG, "Statistiques: %s" % str(stats))

	# Générer les solutions
	var solutions = _generator.generate_solution_tracks(interpretations)

	return solutions


# Convertit une mélodie et retourne uniquement les interprétations brutes
# (sans générer le produit cartésien)
# Utile pour l'inspection ou le traitement personnalisé
func get_melody_interpretations(song: Song, reference_key: HarmonicKey, track_name: String = "midi_melody") -> Array:
	var melody_track = song.get_track_by_name(track_name)
	if melody_track == null:
		LogBus.debug(TAG, "Track '%s' non trouvée dans la Song" % track_name)
		return []

	return _analyzer.analyze_melody(melody_track, reference_key)


# === CONFIGURATION ===

# Définit le nombre maximum de solutions à générer
func set_max_solutions(max_sol: int) -> void:
	_generator.max_solutions = max_sol


# Active/désactive le tri par poids
func set_sort_by_weight(enabled: bool) -> void:
	_generator.sort_by_weight = enabled


# === FILTRAGE ===

# Filtre les solutions selon des critères
# criteria peut contenir:
# - "min_weight": float - poids minimum total
# - "no_secondary": bool - exclure les dominantes/diminués secondaires
# - "no_borrowed": bool - exclure les emprunts modaux
# - "triads_only": bool - exclure les tétrades
func filter_solutions(solutions: Array, criteria: Dictionary) -> Array:
	return _generator.filter_solutions(solutions, criteria)


# === UTILITAIRES ===

# Retourne le catalogue d'accords utilisé
func get_chord_catalog() -> PartimentoChordCatalog:
	return _analyzer.get_catalog()


# Retourne les statistiques pour les interprétations données
func get_statistics(interpretations: Array) -> Dictionary:
	return _generator.get_statistics(interpretations)


# Affiche une solution sous forme lisible
func solution_to_string(solution_track: Track) -> String:
	var result = "Solution (poids total: %.2f):\n" % _get_track_weight(solution_track)

	var degree_events = solution_track.get_degree_events()
	for event in degree_events:
		var degree: Degree = event["degree"]
		var start: float = event["start"]

		var data = _parse_partimento_json(degree)
		var chord_id = data.get("chord_id", "?")
		var func_num = data.get("function_in_chord", "?")
		var midi = data.get("original_midi", "?")

		result += "  [%.1f] MIDI %s -> %s (fonction %s)\n" % [start, str(midi), chord_id, str(func_num)]

	return result


# Affiche toutes les interprétations possibles pour chaque note
func interpretations_to_string(interpretations: Array) -> String:
	var result = "Interprétations par note:\n"

	for i in range(interpretations.size()):
		var options = interpretations[i]
		result += "\nNote %d (%d interprétations):\n" % [i + 1, options.size()]

		for degree in options:
			var data = _parse_partimento_json(degree)
			var chord_id = data.get("chord_id", "?")
			var func_num = data.get("function_in_chord", "?")
			var weight = data.get("weight", 1.0)
			var midi = data.get("original_midi", "?")

			result += "  - MIDI %s -> %s (f=%s, w=%.2f)\n" % [str(midi), chord_id, str(func_num), weight]

	return result


func _get_track_weight(track: Track) -> float:
	var total = 0.0
	var degree_events = track.get_degree_events()
	for event in degree_events:
		var degree = event["degree"]
		var data = _parse_partimento_json(degree)
		total += data.get("weight", 1.0)
	return total


func _parse_partimento_json(degree: Degree) -> Dictionary:
	if degree.partimento_json.empty():
		return {}

	var parse_result = JSON.parse(degree.partimento_json)
	if parse_result.error != OK:
		return {}

	return parse_result.result


# === EXEMPLE D'UTILISATION ===

# Exemple complet d'utilisation:
#
# ```gdscript
# # 1. Créer une Song avec une mélodie
# var song = Song.new()
# var melody_track = song.get_track_by_name("midi_melody")
#
# # Ajouter des notes MIDI
# var note1 = Note.new()
# note1.midi = 60  # Do
# note1.length_beats = 1
# melody_track.add_note(0, note1)
#
# var note2 = Note.new()
# note2.midi = 64  # Mi
# note2.length_beats = 1
# melody_track.add_note(1, note2)
#
# # 2. Définir la tonalité de référence
# var key = HarmonicKey.new()
# key.root_midi = 0  # Do
# key.scale_name = "major"
#
# # 3. Convertir
# var converter = PartimentoMelodyToChords.new()
# converter.set_max_solutions(100)  # Limiter à 100 solutions
#
# var solutions = converter.convert_melody_to_solutions(song, key)
#
# # 4. Afficher les résultats
# print("Nombre de solutions: ", solutions.size())
# for i in range(min(5, solutions.size())):
#     print(converter.solution_to_string(solutions[i]))
#
# # 5. Filtrer si nécessaire
# var filtered = converter.filter_solutions(solutions, {"triads_only": true})
# print("Solutions avec triades uniquement: ", filtered.size())
# ```

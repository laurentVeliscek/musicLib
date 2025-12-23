# PartimentoSolutionGenerator.gd
# Génère toutes les solutions possibles (produit cartésien des interprétations)
# Avec gestion de l'explosion combinatoire

extends Reference
class_name PartimentoSolutionGenerator

const TAG = "PartimentoSolutionGenerator"

# Limite maximale de solutions à générer (pour éviter l'explosion mémoire)
var max_solutions: int = 10000

# Si true, trie les solutions par poids total décroissant
var sort_by_weight: bool = true


func _init():
	pass


# Génère toutes les solutions sous forme de Tracks
# interpretations: Array de Array de Degree (résultat de PartimentoMelodyAnalyzer)
# Retourne: Array de Track
func generate_solution_tracks(interpretations: Array) -> Array:
	if interpretations.empty():
		LogBus.debug(TAG, "Aucune interprétation fournie")
		return []

	# Calculer le nombre total de combinaisons
	var total_combinations = _count_combinations(interpretations)
	LogBus.debug(TAG, "Nombre total de combinaisons: %d" % total_combinations)

	if total_combinations == 0:
		LogBus.debug(TAG, "Aucune combinaison possible (une note n'a aucune interprétation)")
		return []

	# Générer les combinaisons
	var combinations: Array = []
	if total_combinations <= max_solutions:
		combinations = _generate_all_combinations(interpretations)
	else:
		LogBus.debug(TAG, "Trop de combinaisons, limitation à %d solutions" % max_solutions)
		combinations = _generate_limited_combinations(interpretations, max_solutions)

	# Convertir en Tracks
	var tracks: Array = []
	for combo in combinations:
		var track = _combination_to_track(combo)
		tracks.append(track)

	# Trier par poids si demandé
	if sort_by_weight:
		tracks.sort_custom(self, "_compare_tracks_by_weight")

	LogBus.debug(TAG, "%d solutions générées" % tracks.size())
	return tracks


# Compte le nombre total de combinaisons possibles
func _count_combinations(interpretations: Array) -> int:
	var count = 1
	for options in interpretations:
		if options.empty():
			return 0
		count *= options.size()
		# Éviter les overflows
		if count > 1000000000:
			return 1000000000
	return count


# Génère toutes les combinaisons (produit cartésien)
func _generate_all_combinations(interpretations: Array) -> Array:
	var result: Array = [[]]

	for options in interpretations:
		var new_result: Array = []
		for combo in result:
			for option in options:
				var new_combo = combo.duplicate()
				new_combo.append(option)
				new_result.append(new_combo)
		result = new_result

	return result


# Génère un nombre limité de combinaisons en priorisant les meilleurs poids
func _generate_limited_combinations(interpretations: Array, limit: int) -> Array:
	# Stratégie: génération avec élagage basé sur les poids
	# On trie d'abord les options par poids décroissant pour chaque note
	var sorted_interpretations: Array = []
	for options in interpretations:
		var sorted_options = options.duplicate()
		sorted_options.sort_custom(self, "_compare_degrees_by_weight")
		sorted_interpretations.append(sorted_options)

	# Générer avec limite
	var result: Array = []
	_generate_combinations_recursive(sorted_interpretations, [], 0, result, limit)

	return result


# Génération récursive avec limite
func _generate_combinations_recursive(interpretations: Array, current: Array, index: int, result: Array, limit: int) -> void:
	if result.size() >= limit:
		return

	if index >= interpretations.size():
		result.append(current.duplicate())
		return

	var options = interpretations[index]
	for option in options:
		if result.size() >= limit:
			return
		current.append(option)
		_generate_combinations_recursive(interpretations, current, index + 1, result, limit)
		current.pop_back()


# Convertit une combinaison de Degrees en Track
func _combination_to_track(combination: Array) -> Track:
	var track = Track.new()
	track.name = "partimento_solution"

	for degree in combination:
		# Récupérer la position depuis partimento_json
		var start = _get_start_from_degree(degree)
		track.add_degree(start, degree, true, false)

	return track


# Récupère la position de départ depuis le partimento_json du Degree
func _get_start_from_degree(degree: Degree) -> float:
	if degree.partimento_json.empty():
		return 0.0

	var parse_result = JSON.parse(degree.partimento_json)
	if parse_result.error != OK:
		return 0.0

	var data = parse_result.result
	if data.has("start"):
		return float(data["start"])

	return 0.0


# Compare deux Degrees par poids (pour le tri)
func _compare_degrees_by_weight(a: Degree, b: Degree) -> bool:
	var weight_a = _get_weight_from_degree(a)
	var weight_b = _get_weight_from_degree(b)
	return weight_a > weight_b  # Décroissant


# Compare deux Tracks par poids total (pour le tri)
func _compare_tracks_by_weight(a: Track, b: Track) -> bool:
	var weight_a = _get_track_total_weight(a)
	var weight_b = _get_track_total_weight(b)
	return weight_a > weight_b  # Décroissant


# Récupère le poids d'un Degree depuis son partimento_json
func _get_weight_from_degree(degree: Degree) -> float:
	if degree.partimento_json.empty():
		return 1.0

	var parse_result = JSON.parse(degree.partimento_json)
	if parse_result.error != OK:
		return 1.0

	var data = parse_result.result
	if data.has("weight"):
		return float(data["weight"])

	return 1.0


# Calcule le poids total d'une Track (somme des poids des Degrees)
func _get_track_total_weight(track: Track) -> float:
	var total = 0.0
	var degree_events = track.get_degree_events()

	for event in degree_events:
		var degree = event["degree"]
		total += _get_weight_from_degree(degree)

	return total


# === API PUBLIQUE ADDITIONNELLE ===

# Retourne les statistiques sur les interprétations
func get_statistics(interpretations: Array) -> Dictionary:
	var stats = {
		"note_count": interpretations.size(),
		"total_combinations": _count_combinations(interpretations),
		"interpretations_per_note": [],
		"min_interpretations": 999999,
		"max_interpretations": 0,
		"avg_interpretations": 0.0
	}

	var total = 0
	for options in interpretations:
		var count = options.size()
		stats["interpretations_per_note"].append(count)
		total += count
		if count < stats["min_interpretations"]:
			stats["min_interpretations"] = count
		if count > stats["max_interpretations"]:
			stats["max_interpretations"] = count

	if interpretations.size() > 0:
		stats["avg_interpretations"] = float(total) / interpretations.size()

	return stats


# Filtre les solutions selon des critères
func filter_solutions(tracks: Array, criteria: Dictionary) -> Array:
	var filtered: Array = []

	for track in tracks:
		if _track_matches_criteria(track, criteria):
			filtered.append(track)

	return filtered


# Vérifie si une Track correspond aux critères
func _track_matches_criteria(track: Track, criteria: Dictionary) -> bool:
	# Critère: poids minimum
	if criteria.has("min_weight"):
		if _get_track_total_weight(track) < criteria["min_weight"]:
			return false

	# Critère: pas de secondaires
	if criteria.has("no_secondary") and criteria["no_secondary"]:
		var degree_events = track.get_degree_events()
		for event in degree_events:
			var degree = event["degree"]
			var data = _parse_partimento_json(degree)
			if data.has("is_secondary") and data["is_secondary"]:
				return false

	# Critère: pas d'emprunts
	if criteria.has("no_borrowed") and criteria["no_borrowed"]:
		var degree_events = track.get_degree_events()
		for event in degree_events:
			var degree = event["degree"]
			var data = _parse_partimento_json(degree)
			if data.has("is_borrowed") and data["is_borrowed"]:
				return false

	# Critère: uniquement triades
	if criteria.has("triads_only") and criteria["triads_only"]:
		var degree_events = track.get_degree_events()
		for event in degree_events:
			var degree = event["degree"]
			var data = _parse_partimento_json(degree)
			if data.has("is_tetrad") and data["is_tetrad"]:
				return false

	return true


func _parse_partimento_json(degree: Degree) -> Dictionary:
	if degree.partimento_json.empty():
		return {}

	var parse_result = JSON.parse(degree.partimento_json)
	if parse_result.error != OK:
		return {}

	return parse_result.result

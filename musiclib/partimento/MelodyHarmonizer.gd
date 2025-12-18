extends Reference
class_name MelodyHarmonizer

const TAG = "MelodyHarmonizer"

# ==============================================================================
# MELODY HARMONIZER v2
# Harmonise une partition en utilisant les règles du partimento
# Basé sur des fenêtres harmoniques avec détection de schémas
# ==============================================================================

var key: HarmonicKey = null
var rng: RandomNumberGenerator = null

# Configuration
var window_size: float = 4.0
var max_solutions: int = 5
var beam_width: int = 15
var seventh_allowed: bool = true
var ninth_allowed: bool = false
var allow_secondary_dominants: bool = true

# Pondération des schémas (configurable)
var schema_weights: Dictionary = {
	"romanesca": 1.0,
	"prinner": 1.0,
	"monte": 1.0,
	"fonte": 1.0,
	"folia": 1.0,
	"pachelbel": 1.0,
	"cadence_parfaite": 1.5,
	"cadence_64": 1.2
}

# Composants internes
var _analyzer: WindowAnalyzer = null
var _windows: Array = []

# ==============================================================================
# API PRINCIPALE
# ==============================================================================

func harmonize(notes: Array, harmonic_key: HarmonicKey, options: Dictionary = {}) -> Dictionary:
	"""
	Harmonise une partition avec les règles du partimento.

	Arguments:
		notes: Array de {midi: int, start: float, duration: float}
		harmonic_key: La tonalité (HarmonicKey)
		options: {
			window_size: float (défaut 4.0 = ronde),
			max_solutions: int (défaut 5),
			seventh_allowed: bool (défaut true),
			ninth_allowed: bool (défaut false),
			schema_weights: Dictionary,
			key_regions: Array de {start_beat, key}
		}

	Retourne: {
		solutions: Array de {
			progression: Array[Degree],
			melody_track: Array[Degree],
			score: float,
			schemas_applied: Array
		},
		report: Dictionary
	}
	"""
	key = harmonic_key
	_apply_options(options)

	if notes.empty():
		return _empty_result()

	# Phase 1: Analyser la partition en fenêtres
	_analyzer = WindowAnalyzer.new()
	_windows = _analyzer.analyze_partition(notes, key, window_size, {
		"seventh_allowed": seventh_allowed,
		"ninth_allowed": ninth_allowed,
		"key_regions": options.get("key_regions", [])
	})

	if _windows.empty():
		return _empty_result()

	# Phase 2: Détecter les schémas potentiels
	var detected_schemas = _detect_schemas()

	# Phase 3: Trouver les meilleures harmonisations
	var raw_solutions = _find_best_harmonizations()

	# Phase 4: Convertir en format de sortie avec melody_track
	var solutions = _build_output_solutions(raw_solutions, notes)

	# Phase 5: Construire le rapport
	var report = _build_report(detected_schemas)

	return {
		"solutions": solutions,
		"report": report
	}

func _apply_options(options: Dictionary):
	window_size = options.get("window_size", 4.0)
	max_solutions = options.get("max_solutions", 5)
	beam_width = options.get("beam_width", 15)
	seventh_allowed = options.get("seventh_allowed", true)
	ninth_allowed = options.get("ninth_allowed", false)
	allow_secondary_dominants = options.get("allow_secondary_dominants", true)

	if options.has("schema_weights"):
		for k in options.schema_weights.keys():
			schema_weights[k] = options.schema_weights[k]

func _empty_result() -> Dictionary:
	return {
		"solutions": [],
		"report": {"error": "No notes provided", "windows_analyzed": 0}
	}

# ==============================================================================
# DÉTECTION DE SCHÉMAS
# ==============================================================================

func _detect_schemas() -> Array:
	"""
	Détecte les schémas partimento potentiels basés sur le contour mélodique.
	"""
	var detected = []
	var contour = _analyzer.get_downbeat_contour()

	# Nettoyer le contour (enlever les nulls)
	var clean_contour = []
	var contour_positions = []
	for i in range(contour.size()):
		if contour[i] != null:
			clean_contour.append(contour[i])
			contour_positions.append(i)

	if clean_contour.size() < 3:
		return detected

	# Chercher chaque schéma
	for schema_name in PartimentoRules.list_schemas():
		var schema = PartimentoRules.get_schema(schema_name)
		if schema.empty():
			continue

		var matches = _find_schema_matches(clean_contour, contour_positions, schema)
		detected.append_array(matches)

	return detected

func _find_schema_matches(contour: Array, positions: Array, schema: Dictionary) -> Array:
	"""
	Cherche les occurrences d'un schéma dans le contour mélodique.
	"""
	var matches = []
	var schema_soprano = schema.get("typical_soprano", [])
	var schema_name = schema.get("name", "Unknown")

	if schema_soprano.empty():
		return matches

	var pattern_length = schema_soprano.size()

	# Glisser le pattern sur le contour
	for start_idx in range(contour.size() - pattern_length + 1):
		var match_score = _compute_pattern_match(contour, start_idx, schema_soprano)

		if match_score > 0.6:  # Seuil de correspondance
			matches.append({
				"schema": schema_name,
				"start_window": positions[start_idx],
				"end_window": positions[start_idx + pattern_length - 1],
				"match_score": match_score,
				"weight": schema_weights.get(schema_name.to_lower(), 1.0)
			})

	return matches

func _compute_pattern_match(contour: Array, start: int, pattern: Array) -> float:
	"""
	Calcule le score de correspondance entre un segment de contour et un pattern.
	Retourne un score entre 0 et 1.
	"""
	var matches = 0
	var total = pattern.size()

	for i in range(total):
		if start + i >= contour.size():
			break

		var contour_degree = contour[start + i]
		var pattern_degree = pattern[i]

		# Correspondance exacte
		if contour_degree == pattern_degree:
			matches += 1
		# Correspondance à l'octave (même classe de degré)
		elif (contour_degree - 1) % 7 == (pattern_degree - 1) % 7:
			matches += 0.8

	return float(matches) / float(total)

# ==============================================================================
# RECHERCHE D'HARMONISATION (Beam Search)
# ==============================================================================

func _find_best_harmonizations() -> Array:
	"""
	Utilise beam search pour trouver les meilleures progressions.
	"""
	# Générer tous les candidats pour chaque fenêtre
	var candidates_per_window = []
	for w in _windows:
		var candidates = _get_candidates_for_window(w)
		candidates_per_window.append(candidates)

	# Beam search
	var beams = []

	# Initialiser avec les candidats de la première fenêtre
	if candidates_per_window.empty() or candidates_per_window[0].empty():
		return []

	for cand in candidates_per_window[0]:
		beams.append({
			"path": [cand.chord],
			"scores": [cand.score],
			"total_score": cand.score,
			"schemas": []
		})

	# Parcourir les fenêtres suivantes
	for i in range(1, candidates_per_window.size()):
		var window_candidates = candidates_per_window[i]
		var new_beams = []

		for beam in beams:
			var prev_chord = beam.path[beam.path.size() - 1]

			for cand in window_candidates:
				# Score de transition
				var trans_score = _score_transition(prev_chord, cand.chord)
				var new_score = beam.total_score + cand.score + trans_score

				var new_path = beam.path.duplicate()
				new_path.append(cand.chord)

				var new_scores = beam.scores.duplicate()
				new_scores.append(cand.score + trans_score)

				new_beams.append({
					"path": new_path,
					"scores": new_scores,
					"total_score": new_score,
					"schemas": beam.schemas.duplicate()
				})

		# Garder les meilleurs
		new_beams.sort_custom(self, "_compare_beams")
		beams = new_beams.slice(0, min(beam_width, new_beams.size()) - 1)

	# Trier les résultats finaux
	beams.sort_custom(self, "_compare_beams")
	return beams.slice(0, min(max_solutions, beams.size()) - 1)

func _compare_beams(a: Dictionary, b: Dictionary) -> bool:
	return a.total_score > b.total_score

# ==============================================================================
# GÉNÉRATION DES CANDIDATS PAR FENÊTRE
# ==============================================================================

func _get_candidates_for_window(window: HarmonicWindow) -> Array:
	"""
	Génère les accords candidats pour une fenêtre.
	"""
	var candidates = []
	var is_minor = _is_minor_mode()

	# Tester chaque degré diatonique
	for degree in range(1, 8):
		for realization in [[1, 3, 5], [1, 3, 5, 7]]:
			for inversion in range(realization.size()):
				var score_result = window.score_chord_candidate(degree, realization, inversion)

				if score_result.valid or not window.has_notes:
					var chord = _create_degree(degree, realization, inversion, window.key)

					# Bonus pour schémas détectés à cette position
					var schema_bonus = _get_schema_bonus(window.window_index, degree)
					score_result.score += schema_bonus

					candidates.append({
						"chord": chord,
						"score": score_result.score,
						"details": score_result.details
					})

	# Trier par score décroissant
	candidates.sort_custom(self, "_compare_candidates")

	# Garder les meilleurs (éviter explosion combinatoire)
	return candidates.slice(0, min(8, candidates.size()) - 1)

func _compare_candidates(a: Dictionary, b: Dictionary) -> bool:
	return a.score > b.score

func _create_degree(degree_num: int, realization: Array, inversion: int, window_key: HarmonicKey) -> Degree:
	"""
	Crée un objet Degree pour un accord.
	"""
	var d = Degree.new()
	d.key = window_key.clone() if window_key != null and window_key.has_method("clone") else window_key
	d.degree_number = degree_num
	d.realization = realization.duplicate()
	d.inversion = inversion
	d.kind = "diatonic"
	d.harmonic_function = _get_harmonic_function(degree_num)
	return d

func _get_harmonic_function(degree: int) -> String:
	var is_minor = _is_minor_mode()
	if is_minor:
		match degree:
			1: return "T"
			2: return "PD"
			3: return "T"
			4: return "PD"
			5: return "D"
			6: return "T"
			7: return "D"
	else:
		match degree:
			1: return "T"
			2: return "PD"
			3: return "T"
			4: return "PD"
			5: return "D"
			6: return "T"
			7: return "D"
	return "?"

func _get_schema_bonus(window_index: int, degree: int) -> float:
	"""
	Retourne un bonus si un schéma détecté suggère ce degré à cette position.
	"""
	# TODO: Implémenter la correspondance schéma -> degré attendu
	return 0.0

# ==============================================================================
# SCORING DE TRANSITION
# ==============================================================================

func _score_transition(from_chord: Degree, to_chord: Degree) -> float:
	"""
	Score la qualité de l'enchaînement entre deux accords.
	"""
	var score = 0.0

	# Score des fonctions harmoniques
	score += PartimentoRules.get_transition_score(
		from_chord.harmonic_function,
		to_chord.harmonic_function
	) * 5.0

	# Bonus pour progressions idiomatiques
	var from_label = _degree_to_label(from_chord.degree_number)
	var to_label = _degree_to_label(to_chord.degree_number)
	score += PartimentoRules.get_progression_bonus(
		from_chord.degree_number,
		to_chord.degree_number,
		from_label,
		to_label
	) * 3.0

	# Pénalité légère pour répétition
	if from_chord.degree_number == to_chord.degree_number:
		score -= 3.0

	return score

func _degree_to_label(degree: int) -> String:
	var is_minor = _is_minor_mode()
	if is_minor:
		match degree:
			1: return "i"
			2: return "iio"
			3: return "III"
			4: return "iv"
			5: return "V"
			6: return "VI"
			7: return "viio"
	else:
		match degree:
			1: return "I"
			2: return "ii"
			3: return "iii"
			4: return "IV"
			5: return "V"
			6: return "vi"
			7: return "viio"
	return str(degree)

# ==============================================================================
# CONSTRUCTION DE LA SORTIE
# ==============================================================================

func _build_output_solutions(raw_solutions: Array, original_notes: Array) -> Array:
	"""
	Convertit les solutions brutes en format de sortie avec melody_track.
	"""
	var solutions = []

	for sol in raw_solutions:
		var progression = sol.path
		var melody_track = _create_melody_track(progression, original_notes)

		# Annoter les degrés avec les schémas
		_annotate_with_schemas(progression, sol.schemas)

		solutions.append({
			"progression": progression,
			"melody_track": melody_track,
			"score": sol.total_score,
			"schemas_applied": sol.schemas
		})

	return solutions

func _create_melody_track(progression: Array, notes: Array) -> Array:
	"""
	Crée la track mélodique: chaque note exprimée en Degree "melodic"
	par rapport à son accord.
	"""
	var melody_track = []

	for note in notes:
		# Trouver la fenêtre de cette note
		var window_idx = _get_window_index_for_beat(note.start)
		if window_idx < 0 or window_idx >= progression.size():
			continue

		var chord = progression[window_idx]
		var window = _windows[window_idx]

		# Créer le Degree melodic
		var melodic_degree = window.create_melodic_degree(
			note.midi,
			chord.degree_number,
			chord.realization
		)

		# Copier les infos temporelles
		melodic_degree.length_beats = note.get("duration", 1.0)

		melody_track.append({
			"degree": melodic_degree,
			"start": note.start,
			"original_midi": note.midi,
			"chord_degree": chord.degree_number
		})

	return melody_track

func _get_window_index_for_beat(beat: float) -> int:
	for i in range(_windows.size()):
		var w = _windows[i]
		if beat >= w.start_beat and beat < w.end_beat:
			return i
	return -1

func _annotate_with_schemas(progression: Array, schemas: Array):
	"""
	Annote chaque Degree avec le schéma appliqué (dans comment).
	"""
	for schema_info in schemas:
		var start = schema_info.get("start_window", 0)
		var end = schema_info.get("end_window", 0)
		var name = schema_info.get("schema", "")

		for i in range(start, min(end + 1, progression.size())):
			var pos_in_schema = i - start + 1
			var total_in_schema = end - start + 1
			progression[i].comment = "%s[%d/%d]" % [name, pos_in_schema, total_in_schema]

# ==============================================================================
# RAPPORT
# ==============================================================================

func _build_report(detected_schemas: Array) -> Dictionary:
	return {
		"windows_analyzed": _windows.size(),
		"window_size": window_size,
		"global_contour": _analyzer.get_global_contour() if _analyzer else [],
		"downbeat_contour": _analyzer.get_downbeat_contour() if _analyzer else [],
		"schemas_detected": detected_schemas,
		"seventh_allowed": seventh_allowed,
		"ninth_allowed": ninth_allowed
	}

# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _is_minor_mode() -> bool:
	if key == null:
		return false
	var scale_name = key.scale_name.to_lower()
	return scale_name.find("minor") >= 0 or scale_name == "aeolian" or scale_name == "dorian" or scale_name == "phrygian"

func set_rng(new_rng: RandomNumberGenerator):
	rng = new_rng

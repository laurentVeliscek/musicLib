extends Reference
class_name MelodyHarmonizer

const TAG = "MelodyHarmonizer"

# ==============================================================================
# MELODY HARMONIZER
# Harmonise une mélodie en utilisant les règles du partimento
# Approche: recherche de chemin dans un graphe d'accords pondéré
# ==============================================================================

var key: HarmonicKey = null
var rng: RandomNumberGenerator = null

# Configuration
var max_solutions: int = 5
var beam_width: int = 10
var prefer_diatonic: bool = true
var allow_secondary_dominants: bool = true

# Cache interne
var _scale_helper: ScaleHelper = null
var _scale_degrees: Array = []

func _init():
	_scale_helper = ScaleHelper.new()

# ------------------------------------------------------------------------------
# API PRINCIPALE
# ------------------------------------------------------------------------------

func harmonize(melody: Array, harmonic_key: HarmonicKey, options: Dictionary = {}) -> Array:
	"""
	Harmonise une mélodie avec les règles du partimento.

	Arguments:
		melody: Array de notes (MIDI int ou Dictionary {midi, duration})
		harmonic_key: La tonalité (HarmonicKey)
		options: {
			max_solutions: int (défaut 5),
			prefer_common_tones: bool,
			start_on_tonic: bool,
			end_on_tonic: bool
		}

	Retourne:
		Array de solutions, chaque solution est un Array de Degree
	"""
	key = harmonic_key
	_apply_options(options)
	_build_scale_cache()

	if melody.empty():
		return []

	# Convertir la mélodie en degrés de gamme
	var melody_degrees = _melody_to_scale_degrees(melody)

	if melody_degrees.empty():
		LogBus.warn(TAG, "Impossible de convertir la mélodie en degrés")
		return []

	# Construire le graphe et chercher les meilleurs chemins
	var solutions = _find_best_harmonizations(melody_degrees, options)

	return solutions

func harmonize_with_degrees(melody_degrees: Array, harmonic_key: HarmonicKey, options: Dictionary = {}) -> Array:
	"""
	Harmonise une mélodie déjà exprimée en degrés de gamme (1-7).
	Plus direct si la mélodie est déjà analysée.
	"""
	key = harmonic_key
	_apply_options(options)
	_build_scale_cache()

	return _find_best_harmonizations(melody_degrees, options)

# ------------------------------------------------------------------------------
# CONVERSION MÉLODIE -> DEGRÉS
# ------------------------------------------------------------------------------

func _melody_to_scale_degrees(melody: Array) -> Array:
	var result = []

	for note in melody:
		var midi_pitch = _extract_midi(note)
		var degree_info = _midi_to_scale_degree(midi_pitch)
		result.append(degree_info)

	return result

func _extract_midi(note) -> int:
	if typeof(note) == TYPE_INT:
		return note
	if typeof(note) == TYPE_DICTIONARY:
		return int(note.get("midi", 60))
	return 60

func _midi_to_scale_degree(midi: int) -> Dictionary:
	"""
	Convertit un pitch MIDI en degré de gamme + info d'altération.
	Retourne { degree: 1-7, alteration: -1/0/+1, original_midi: int }
	"""
	var root = key.root_midi % 12
	var pitch_class = midi % 12
	var interval = (pitch_class - root + 12) % 12

	# Chercher le degré le plus proche dans la gamme
	var scale_array = _scale_helper.get_scale_array(key.scale_name)

	var best_degree = 1
	var best_alteration = 0
	var min_distance = 12

	for i in range(scale_array.size() - 1):  # -1 car le dernier est l'octave
		var scale_interval = scale_array[i]
		var distance = interval - scale_interval

		if abs(distance) < min_distance:
			min_distance = abs(distance)
			best_degree = i + 1  # degrés 1-7
			best_alteration = distance  # -1, 0, ou +1

	return {
		"degree": best_degree,
		"alteration": best_alteration,
		"original_midi": midi
	}

# ------------------------------------------------------------------------------
# ALGORITHME DE RECHERCHE (Beam Search)
# ------------------------------------------------------------------------------

func _find_best_harmonizations(melody_degrees: Array, options: Dictionary) -> Array:
	"""
	Utilise beam search pour trouver les k meilleures harmonisations.
	"""
	var start_on_tonic = options.get("start_on_tonic", true)
	var end_on_tonic = options.get("end_on_tonic", true)

	# État initial: liste de (chemin, score)
	var beams = []

	# Premier accord
	var first_note = melody_degrees[0]
	var first_candidates = _get_chord_candidates(first_note, null, 0, melody_degrees.size())

	# Filtrer pour commencer sur tonique si demandé
	if start_on_tonic:
		var tonic_candidates = []
		for c in first_candidates:
			if c.degree_number == 1:
				tonic_candidates.append(c)
		if not tonic_candidates.empty():
			first_candidates = tonic_candidates

	# Initialiser les beams
	for candidate in first_candidates:
		beams.append({
			"path": [candidate],
			"score": candidate.get("_search_score", 0)
		})

	# Parcourir le reste de la mélodie
	for i in range(1, melody_degrees.size()):
		var note_info = melody_degrees[i]
		var is_last = (i == melody_degrees.size() - 1)
		var new_beams = []

		for beam in beams:
			var prev_chord = beam.path[beam.path.size() - 1]
			var candidates = _get_chord_candidates(note_info, prev_chord, i, melody_degrees.size())

			# Filtrer pour finir sur tonique si demandé
			if is_last and end_on_tonic:
				var tonic_candidates = []
				for c in candidates:
					if c.degree_number == 1 and c.inversion == 0:
						tonic_candidates.append(c)
				if not tonic_candidates.empty():
					candidates = tonic_candidates

			for candidate in candidates:
				var transition_score = _score_transition(prev_chord, candidate)
				var new_path = beam.path.duplicate()
				new_path.append(candidate)
				var new_score = beam.score + candidate.get("_search_score", 0) + transition_score

				new_beams.append({
					"path": new_path,
					"score": new_score
				})

		# Garder les meilleurs beams
		new_beams.sort_custom(self, "_compare_beams")
		beams = new_beams.slice(0, min(beam_width, new_beams.size()) - 1)

	# Extraire les solutions finales
	beams.sort_custom(self, "_compare_beams")
	var solutions = []

	for i in range(min(max_solutions, beams.size())):
		var path = beams[i].path
		# Nettoyer les métadonnées de recherche
		var clean_path = []
		for degree in path:
			var clean_degree = degree.clone() if degree.has_method("clone") else degree
			clean_path.append(clean_degree)
		solutions.append(clean_path)

	return solutions

func _compare_beams(a: Dictionary, b: Dictionary) -> bool:
	return a.score > b.score  # Plus haut score = meilleur

# ------------------------------------------------------------------------------
# GÉNÉRATION DES CANDIDATS
# ------------------------------------------------------------------------------

func _get_chord_candidates(note_info: Dictionary, prev_chord, position: int, total_length: int) -> Array:
	"""
	Pour une note mélodique, retourne les accords candidats possibles.
	"""
	var degree = note_info.degree
	var alteration = note_info.alteration
	var candidates = []

	# Obtenir les accords de base depuis les règles partimento
	var is_minor = _is_minor_mode()
	var base_chords = PartimentoRules.get_chords_for_melody_note(degree, is_minor)

	for chord_info in base_chords:
		var candidate = _create_degree_from_chord_info(chord_info, note_info)

		# Calculer le score de ce candidat
		var score = chord_info.get("weight", 1) * 10

		# Bonus/malus contextuels
		score += _contextual_score(candidate, prev_chord, position, total_length)

		# Gérer les altérations chromatiques
		if alteration != 0:
			score += _chromatic_score(candidate, alteration, degree)

		candidate.set("_search_score", score)
		candidates.append(candidate)

	# Ajouter des dominantes secondaires si autorisé et note altérée
	if allow_secondary_dominants and alteration != 0:
		var secondary = _get_secondary_dominant_candidates(note_info)
		candidates.append_array(secondary)

	return candidates

func _create_degree_from_chord_info(chord_info: Dictionary, note_info: Dictionary) -> Degree:
	"""
	Crée un objet Degree à partir des infos d'accord partimento.
	"""
	var d = Degree.new()
	d.key = key.clone() if key.has_method("clone") else key
	d.degree_number = chord_info.degree
	d.inversion = chord_info.get("inversion", 0)
	d.realization = chord_info.get("realization", [1, 3, 5]).duplicate()
	d.kind = chord_info.get("kind", "diatonic")
	d.harmonic_function = chord_info.get("function", "T")
	d.length_beats = 1.0  # Par défaut, sera ajusté selon la mélodie

	# Stocker la position de la note mélodique dans l'accord (metadata)
	d._comment = chord_info.get("position", "")

	return d

func _get_secondary_dominant_candidates(note_info: Dictionary) -> Array:
	"""
	Génère des candidats de dominantes secondaires pour les notes altérées.
	"""
	var candidates = []
	var degree = note_info.degree
	var alteration = note_info.alteration

	# Note haussée d'un demi-ton -> possible sensible d'une dominante secondaire
	if alteration == 1:
		# La note altérée pourrait être la tierce d'un V/x
		var target_degree = (degree + 1 - 1) % 7 + 1  # Degré suivant

		var secondary_v = Degree.new()
		secondary_v.key = key.clone() if key.has_method("clone") else key
		secondary_v.degree_number = 5
		secondary_v.kind = "secondary"
		secondary_v._is_secondary = true
		secondary_v._secondary_roman_spelling = "V/" + _degree_to_roman(target_degree)
		secondary_v.harmonic_function = "D"
		secondary_v.realization = [1, 3, 5]
		secondary_v.set("_search_score", 30)  # Score élevé pour les secondaires appropriées

		candidates.append(secondary_v)

	return candidates

# ------------------------------------------------------------------------------
# SCORING
# ------------------------------------------------------------------------------

func _score_transition(from_chord: Degree, to_chord: Degree) -> int:
	"""
	Score la transition entre deux accords.
	"""
	if from_chord == null:
		return 0

	var score = 0

	# Score basé sur les fonctions harmoniques
	var func_score = PartimentoRules.get_transition_score(
		from_chord.harmonic_function,
		to_chord.harmonic_function
	)
	score += func_score * 5

	# Bonus/malus pour progressions spécifiques
	var prog_bonus = PartimentoRules.get_progression_bonus(
		from_chord.degree_number,
		to_chord.degree_number,
		_degree_to_roman(from_chord.degree_number),
		_degree_to_roman(to_chord.degree_number)
	)
	score += prog_bonus * 3

	# Pénalité pour répétition exacte (sauf si voulu)
	if from_chord.degree_number == to_chord.degree_number and from_chord.inversion == to_chord.inversion:
		score -= 5

	# Bonus pour mouvement de basse par quinte descendante
	var bass_interval = _get_bass_interval(from_chord, to_chord)
	if bass_interval == 5 or bass_interval == -7:  # Quinte descendante
		score += 8
	elif bass_interval == 4 or bass_interval == -8:  # Quarte ascendante
		score += 6

	return score

func _contextual_score(candidate: Degree, prev_chord, position: int, total_length: int) -> int:
	"""
	Score contextuel basé sur la position dans la phrase.
	"""
	var score = 0

	# Bonus pour tonique au début
	if position == 0 and candidate.degree_number == 1:
		score += 15

	# Bonus pour cadence à la fin
	if position == total_length - 1:
		if candidate.degree_number == 1 and candidate.inversion == 0:
			score += 20

	# Avant-dernière position: préférer dominante
	if position == total_length - 2:
		if candidate.harmonic_function == "D":
			score += 15

	# Antépénultième: préférer pré-dominante
	if position == total_length - 3:
		if candidate.harmonic_function == "PD":
			score += 10

	return score

func _chromatic_score(candidate: Degree, alteration: int, original_degree: int) -> int:
	"""
	Score pour les notes chromatiques.
	"""
	# Si la note est altérée mais l'accord ne le reflète pas, pénalité
	# Si l'accord est une dominante secondaire appropriée, bonus

	if candidate.kind == "secondary":
		return 20  # Les secondaires sont bonnes pour les chromatismes

	return -5  # Pénalité par défaut pour chromatisme non résolu

func _get_bass_interval(from_chord: Degree, to_chord: Degree) -> int:
	"""
	Calcule l'intervalle de basse entre deux accords (en degrés).
	"""
	var from_bass = _get_bass_degree(from_chord)
	var to_bass = _get_bass_degree(to_chord)
	return to_bass - from_bass

func _get_bass_degree(chord: Degree) -> int:
	"""
	Retourne le degré de la note de basse d'un accord.
	"""
	if chord.realization.empty():
		return chord.degree_number

	var bass_index = chord.inversion % chord.realization.size()
	var bass_interval = chord.realization[bass_index]

	return ((chord.degree_number - 1) + (bass_interval - 1)) % 7 + 1

# ------------------------------------------------------------------------------
# UTILITAIRES
# ------------------------------------------------------------------------------

func _apply_options(options: Dictionary):
	max_solutions = options.get("max_solutions", 5)
	beam_width = options.get("beam_width", 10)
	prefer_diatonic = options.get("prefer_diatonic", true)
	allow_secondary_dominants = options.get("allow_secondary_dominants", true)

func _build_scale_cache():
	if key != null:
		_scale_degrees = _scale_helper.get_scale_array(key.scale_name)

func _is_minor_mode() -> bool:
	if key == null:
		return false
	var scale_name = key.scale_name.to_lower()
	return scale_name.find("minor") >= 0 or scale_name == "aeolian" or scale_name == "dorian" or scale_name == "phrygian"

func _degree_to_roman(degree: int) -> String:
	var is_minor = _is_minor_mode()
	if is_minor:
		match degree:
			1: return "i"
			2: return "iio"
			3: return "III"
			4: return "iv"
			5: return "V"
			6: return "VI"
			7: return "VII"
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

# ------------------------------------------------------------------------------
# MÉTHODES DE COMMODITÉ
# ------------------------------------------------------------------------------

func set_key(new_key: HarmonicKey):
	key = new_key
	_build_scale_cache()

func set_rng(new_rng: RandomNumberGenerator):
	rng = new_rng

func get_possible_chords_for_note(midi_note: int, harmonic_key: HarmonicKey) -> Array:
	"""
	Méthode utilitaire: retourne les accords possibles pour une note MIDI donnée.
	Utile pour l'UI ou le débogage.
	"""
	key = harmonic_key
	_build_scale_cache()

	var note_info = _midi_to_scale_degree(midi_note)
	var candidates = _get_chord_candidates(note_info, null, 0, 1)

	return candidates

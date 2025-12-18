extends Reference
class_name HarmonicWindow

const TAG = "HarmonicWindow"

# ==============================================================================
# HARMONIC WINDOW
# Représente une fenêtre temporelle pour l'analyse harmonique
# Contient les notes MIDI et leur analyse par rapport à la tonalité
# ==============================================================================

# --- Propriétés de la fenêtre ---
var start_beat: float = 0.0
var end_beat: float = 4.0
var window_size: float = 4.0

# --- Contexte tonal ---
var key: HarmonicKey = null
var _scale_helper: ScaleHelper = null
var _scale_array: Array = []  # Cache des intervalles de la gamme

# --- Notes MIDI dans cette fenêtre ---
# Array de {midi: int, start: float, duration: float}
var notes: Array = []

# --- Analyse mélodique ---
# Notes sur le temps fort (start de la fenêtre)
var downbeat_notes: Array = []  # [{midi, start, duration}]

# Degrés de gamme des notes (calculés)
var note_scale_degrees: Array = []  # [{midi, degree, alteration, start}]

# Intervalles entre notes consécutives
var intervals: Array = []

# Intervalles disjoints uniquement (sauts)
var disjunct_intervals: Array = []

# Contour mélodique simplifié (liste des degrés)
var melodic_contour: Array = []

# Notes chromatiques (altérées) détectées
var chromatic_notes: Array = []

# --- Options ---
var seventh_allowed: bool = true
var ninth_allowed: bool = false

# --- Métadonnées ---
var window_index: int = 0
var has_notes: bool = false

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _init(p_start: float = 0.0, p_size: float = 4.0, p_key: HarmonicKey = null):
	start_beat = p_start
	window_size = p_size
	end_beat = p_start + p_size
	key = p_key
	_scale_helper = ScaleHelper.new()
	if key != null:
		_scale_array = _scale_helper.get_scale_array(key.scale_name)

func set_options(p_seventh_allowed: bool, p_ninth_allowed: bool):
	seventh_allowed = p_seventh_allowed
	ninth_allowed = p_ninth_allowed

# ==============================================================================
# AJOUT DE NOTES MIDI
# ==============================================================================

func add_note(midi: int, note_start: float, duration: float = 1.0):
	"""
	Ajoute une note MIDI à cette fenêtre.
	"""
	var note_data = {
		"midi": midi,
		"start": note_start,
		"duration": duration,
		"is_downbeat": _is_on_downbeat(note_start)
	}
	notes.append(note_data)
	has_notes = true

	if note_data.is_downbeat:
		downbeat_notes.append(note_data)

func _is_on_downbeat(note_start: float) -> bool:
	"""
	Vérifie si une note est sur le temps fort de la fenêtre.
	Tolérance de 0.1 beat.
	"""
	return abs(note_start - start_beat) < 0.1

# ==============================================================================
# ANALYSE (à appeler après avoir ajouté toutes les notes)
# ==============================================================================

func analyze():
	"""
	Analyse complète de la fenêtre : degrés, intervalles, chromatismes.
	"""
	if key == null:
		LogBus.warn(TAG, "Pas de tonalité définie pour l'analyse")
		return

	_analyze_scale_degrees()
	_analyze_intervals()

func _analyze_scale_degrees():
	"""
	Convertit chaque note MIDI en degré de gamme + altération.
	"""
	note_scale_degrees.clear()
	melodic_contour.clear()
	chromatic_notes.clear()

	# Trier les notes par position
	var sorted_notes = notes.duplicate()
	sorted_notes.sort_custom(self, "_sort_by_start")

	var prev_midi = -1
	for note in sorted_notes:
		var degree_info = _midi_to_scale_degree(note.midi, prev_midi)
		degree_info.start = note.start
		degree_info.is_downbeat = note.is_downbeat
		note_scale_degrees.append(degree_info)

		melodic_contour.append(degree_info.degree)

		if degree_info.alteration != 0:
			chromatic_notes.append(degree_info)

		prev_midi = note.midi

func _midi_to_scale_degree(midi: int, prev_midi: int = -1) -> Dictionary:
	"""
	Convertit un pitch MIDI en degré de gamme + altération.
	Utilise le mouvement mélodique pour déterminer l'altération.
	"""
	var root = key.root_midi % 12
	var pitch_class = midi % 12
	var interval_from_root = (pitch_class - root + 12) % 12

	# Trouver le degré diatonique le plus proche
	var best_degree = 1
	var best_alteration = 0
	var min_distance = 12

	for i in range(_scale_array.size() - 1):  # -1 car le dernier est l'octave
		var scale_interval = _scale_array[i] % 12
		var distance = (interval_from_root - scale_interval + 12) % 12

		# Normaliser la distance (-6 à +6)
		if distance > 6:
			distance = distance - 12

		if abs(distance) < abs(min_distance):
			min_distance = distance
			best_degree = i + 1
			best_alteration = distance

	# Si distance exacte de 0, pas d'altération
	if min_distance == 0:
		best_alteration = 0
	else:
		# Utiliser le mouvement pour déterminer le sens de l'altération
		var ascending = prev_midi >= 0 and midi > prev_midi

		if min_distance > 0:
			# Note au-dessus du degré diatonique
			if ascending:
				# Mouvement montant : degré inférieur + dièse(s)
				best_alteration = min_distance
			else:
				# Mouvement descendant : degré supérieur + bémol(s)
				best_degree = (best_degree % 7) + 1
				best_alteration = min_distance - _get_interval_to_next_degree(best_degree - 1)
		elif min_distance < 0:
			# Note en-dessous du degré diatonique
			if ascending:
				# Garder le degré avec bémol
				best_alteration = min_distance
			else:
				# Descendre au degré précédent avec dièse
				best_degree = ((best_degree - 2 + 7) % 7) + 1
				best_alteration = min_distance + _get_interval_to_next_degree(best_degree)

	return {
		"midi": midi,
		"degree": best_degree,
		"alteration": best_alteration
	}

func _get_interval_to_next_degree(degree_index: int) -> int:
	"""
	Retourne l'intervalle en demi-tons vers le degré suivant.
	"""
	if degree_index < 0 or degree_index >= _scale_array.size() - 1:
		return 2  # Défaut: ton
	return _scale_array[degree_index + 1] - _scale_array[degree_index]

func _analyze_intervals():
	"""
	Analyse les intervalles entre notes consécutives.
	"""
	intervals.clear()
	disjunct_intervals.clear()

	if note_scale_degrees.size() < 2:
		return

	for i in range(note_scale_degrees.size() - 1):
		var from_info = note_scale_degrees[i]
		var to_info = note_scale_degrees[i + 1]

		var interval_info = _compute_interval(from_info, to_info)
		intervals.append(interval_info)

		if not interval_info.is_conjunct:
			disjunct_intervals.append(interval_info)

func _compute_interval(from_info: Dictionary, to_info: Dictionary) -> Dictionary:
	"""
	Calcule l'intervalle entre deux notes.
	"""
	var from_degree = from_info.degree
	var to_degree = to_info.degree

	# Distance en degrés (1 = seconde = conjoint)
	var degree_distance = abs(to_degree - from_degree)

	# Gérer le passage 7->1 ou 1->7
	if degree_distance == 6:
		degree_distance = 1

	# Un demi-ton est toujours conjoint
	var semitone_distance = abs(to_info.midi - from_info.midi)
	var is_conjunct = degree_distance <= 1 or semitone_distance == 1

	var direction = "static"
	if to_info.midi > from_info.midi:
		direction = "ascending"
	elif to_info.midi < from_info.midi:
		direction = "descending"

	return {
		"from_degree": from_degree,
		"to_degree": to_degree,
		"from_midi": from_info.midi,
		"to_midi": to_info.midi,
		"degree_distance": degree_distance,
		"semitone_distance": semitone_distance,
		"is_conjunct": is_conjunct,
		"direction": direction
	}

func _sort_by_start(a: Dictionary, b: Dictionary) -> bool:
	return a.start < b.start

# ==============================================================================
# SCORING D'UN ACCORD CANDIDAT
# ==============================================================================

func score_chord_candidate(chord_degree: int, chord_realization: Array, inversion: int = 0) -> Dictionary:
	"""
	Score un accord candidat par rapport au contenu de cette fenêtre.

	chord_degree: le degré de l'accord dans la tonalité (1-7)
	chord_realization: les degrés de l'accord [1,3,5] ou [1,3,5,7]
	inversion: 0, 1, 2, 3

	Retourne: {score: float, details: {...}, valid: bool}
	"""
	var score = 0.0
	var valid = true
	var details = {
		"downbeat_match": 0,
		"downbeat_miss": 0,
		"interval_match": 0,
		"chromatic_bonus": 0,
		"reasons": []
	}

	# Calculer les degrés de gamme couverts par l'accord
	var chord_scale_degrees = _chord_to_scale_degrees(chord_degree, chord_realization)

	# Degrés étendus si seventh/ninth allowed
	var extended_degrees = chord_scale_degrees.duplicate()
	if seventh_allowed:
		var seventh_degree = ((chord_degree - 1) + 6) % 7 + 1  # 7ème de l'accord
		if not seventh_degree in extended_degrees:
			extended_degrees.append(seventh_degree)
	if ninth_allowed:
		var ninth_degree = ((chord_degree - 1) + 8) % 7 + 1  # 9ème = 2ème au-dessus
		if not ninth_degree in extended_degrees:
			extended_degrees.append(ninth_degree)

	# 1. Notes sur downbeat DOIVENT être dans l'accord
	for note in downbeat_notes:
		var note_info = _find_note_info(note.midi)
		if note_info == null:
			continue

		var note_degree = note_info.degree
		if note_degree in extended_degrees:
			score += 30.0
			details.downbeat_match += 1
			details.reasons.append("downbeat_%d_in_chord" % note_degree)
		else:
			score -= 100.0  # Pénalité très forte
			valid = false
			details.downbeat_miss += 1
			details.reasons.append("FAIL:downbeat_%d_not_in_chord" % note_degree)

	# 2. Intervalles disjoints suggèrent les notes dans l'accord
	for interval in disjunct_intervals:
		var from_in = interval.from_degree in chord_scale_degrees
		var to_in = interval.to_degree in chord_scale_degrees

		if from_in and to_in:
			score += 25.0
			details.interval_match += 1
			details.reasons.append("disjunct_%d-%d_match" % [interval.from_degree, interval.to_degree])
		elif from_in or to_in:
			score += 8.0
			details.reasons.append("disjunct_partial_%d-%d" % [interval.from_degree, interval.to_degree])

	# 3. Notes chromatiques
	for chrom in chromatic_notes:
		# Une note chromatique dans l'accord suggère dominante secondaire
		if chrom.degree in chord_scale_degrees:
			score += 15.0
			details.chromatic_bonus += 1
			details.reasons.append("chromatic_%d_supported" % chrom.degree)

	# 4. Fenêtre vide = liberté totale
	if not has_notes:
		score += 5.0
		valid = true
		details.reasons.append("empty_window_free")

	return {
		"score": score,
		"valid": valid,
		"details": details
	}

func _chord_to_scale_degrees(chord_degree: int, chord_realization: Array) -> Array:
	"""
	Convertit les notes d'un accord en degrés absolus de la gamme.
	chord_degree=5, chord_realization=[1,3,5] -> [5, 7, 2]
	"""
	var result = []
	for note in chord_realization:
		var scale_degree = ((chord_degree - 1) + (note - 1)) % 7 + 1
		result.append(scale_degree)
	return result

func _find_note_info(midi: int) -> Dictionary:
	"""
	Trouve les infos de degré pour une note MIDI.
	"""
	for info in note_scale_degrees:
		if info.midi == midi:
			return info
	return {}

# ==============================================================================
# CONVERSION NOTE MIDI -> DEGREE MELODIC (post-harmonisation)
# ==============================================================================

func create_melodic_degree(midi: int, chord_degree: int, chord_realization: Array) -> Degree:
	"""
	Crée un Degree "melodic" pour une note MIDI par rapport à l'accord choisi.

	midi: la note MIDI
	chord_degree: le degré de l'accord dans la tonalité
	chord_realization: [1,3,5] ou [1,3,5,7]

	Retourne: un Degree avec kind="melodic", degree_number=chord_degree,
	          realization=[position_dans_accord], et altérations si nécessaire
	"""
	var d = Degree.new()
	d.key = key.clone() if key != null and key.has_method("clone") else key
	d.degree_number = chord_degree
	d.set_melodic()  # kind="melodic", realization=[1]

	# Trouver la position de la note dans l'accord
	var note_info = _midi_to_scale_degree(midi, -1)
	var note_scale_degree = note_info.degree
	var note_alteration = note_info.alteration

	# Calculer les degrés de gamme de l'accord
	var chord_scale_degrees = _chord_to_scale_degrees(chord_degree, chord_realization)

	# Chercher la position de la note dans l'accord
	var position_in_chord = _find_position_in_chord(note_scale_degree, chord_degree, chord_realization)

	# Si la note n'est pas exactement dans l'accord, trouver le degré le plus proche
	if position_in_chord == -1:
		position_in_chord = _find_closest_chord_position(midi, chord_degree, note_info)

	d.realization = [position_in_chord]

	# Calculer l'altération par rapport à l'accord
	var expected_midi = _get_chord_note_midi(chord_degree, position_in_chord)
	var chord_alteration = midi - expected_midi

	if chord_alteration != 0:
		d.set_chord_alteration(position_in_chord, chord_alteration)

	return d

func _find_position_in_chord(note_scale_degree: int, chord_degree: int, chord_realization: Array) -> int:
	"""
	Trouve la position (1,3,5,7...) d'un degré de gamme dans un accord.
	Retourne -1 si pas trouvé.
	"""
	for i in range(chord_realization.size()):
		var pos = chord_realization[i]
		var scale_deg = ((chord_degree - 1) + (pos - 1)) % 7 + 1
		if scale_deg == note_scale_degree:
			return pos
	return -1

func _find_closest_chord_position(midi: int, chord_degree: int, note_info: Dictionary) -> int:
	"""
	Pour une note hors de l'accord, trouve la position la plus proche
	et détermine l'altération nécessaire.
	"""
	# Déterminer si mouvement ascendant ou descendant (basé sur les notes précédentes)
	var ascending = true  # Par défaut
	if note_scale_degrees.size() > 1:
		var prev = note_scale_degrees[note_scale_degrees.size() - 2]
		ascending = midi > prev.midi

	# Calculer toutes les positions possibles (1 à 9 environ)
	var positions = []
	for pos in range(1, 10):
		var expected_midi = _get_chord_note_midi(chord_degree, pos)
		var distance = midi - expected_midi
		positions.append({"pos": pos, "expected_midi": expected_midi, "distance": distance})

	# Trouver la position juste en dessous (si ascendant) ou au-dessus (si descendant)
	var best_pos = 1
	var best_distance = 100

	for p in positions:
		if ascending:
			# Mouvement ascendant : prendre le degré juste en dessous
			if p.distance > 0 and p.distance < best_distance:
				best_distance = p.distance
				best_pos = p.pos
		else:
			# Mouvement descendant : prendre le degré juste au-dessus
			if p.distance < 0 and abs(p.distance) < best_distance:
				best_distance = abs(p.distance)
				best_pos = p.pos

	# Si aucun trouvé, prendre le plus proche
	if best_distance == 100:
		for p in positions:
			if abs(p.distance) < best_distance:
				best_distance = abs(p.distance)
				best_pos = p.pos

	return best_pos

func _get_chord_note_midi(chord_degree: int, position_in_chord: int) -> int:
	"""
	Calcule le MIDI d'une note de l'accord (sans altération).
	chord_degree: degré de l'accord dans la tonalité
	position_in_chord: position dans l'accord (1=fond, 3=tierce, 5=quinte...)
	"""
	if key == null:
		return 60

	var root = key.root_midi
	var scale_degree = ((chord_degree - 1) + (position_in_chord - 1)) % 7 + 1

	# Trouver l'intervalle de ce degré dans la gamme
	var interval = 0
	if scale_degree - 1 < _scale_array.size():
		interval = _scale_array[scale_degree - 1]

	return (root % 12) + interval + 60  # Octave 4 par défaut

# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_summary() -> String:
	var summary = "Window %d [%.1f-%.1f]: " % [window_index, start_beat, end_beat]

	if not has_notes:
		summary += "(vide)"
	else:
		summary += "notes=%d " % notes.size()
		if not melodic_contour.empty():
			summary += "contour=%s " % str(melodic_contour)
		if not disjunct_intervals.empty():
			summary += "sauts=%d " % disjunct_intervals.size()
		if not chromatic_notes.empty():
			summary += "chrom=%d" % chromatic_notes.size()

	return summary

func to_dict() -> Dictionary:
	return {
		"start_beat": start_beat,
		"end_beat": end_beat,
		"window_size": window_size,
		"window_index": window_index,
		"has_notes": has_notes,
		"notes_count": notes.size(),
		"melodic_contour": melodic_contour.duplicate(),
		"disjunct_intervals_count": disjunct_intervals.size(),
		"chromatic_notes_count": chromatic_notes.size()
	}

func clone() -> HarmonicWindow:
	var w = HarmonicWindow.new(start_beat, window_size, key)
	w.window_index = window_index
	w.notes = notes.duplicate(true)
	w.downbeat_notes = downbeat_notes.duplicate(true)
	w.note_scale_degrees = note_scale_degrees.duplicate(true)
	w.intervals = intervals.duplicate(true)
	w.disjunct_intervals = disjunct_intervals.duplicate(true)
	w.melodic_contour = melodic_contour.duplicate()
	w.chromatic_notes = chromatic_notes.duplicate(true)
	w.seventh_allowed = seventh_allowed
	w.ninth_allowed = ninth_allowed
	w.has_notes = has_notes
	return w

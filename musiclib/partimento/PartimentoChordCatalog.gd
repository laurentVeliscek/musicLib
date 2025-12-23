# PartimentoChordCatalog.gd
# Catalogue exhaustif des accords du partimento
# Génère tous les accords possibles pour une tonalité donnée (majeure et mineure relative)

extends Reference
class_name PartimentoChordCatalog

const TAG = "PartimentoChordCatalog"

# Structure d'un accord dans le catalogue
# {
#   "id": String,                    # Identifiant unique (ex: "V/ii", "N6", "I")
#   "degree_number": int,            # Numéro du degré (1-7)
#   "key": HarmonicKey,              # Tonalité de l'accord
#   "kind": String,                  # "diatonic", "N6", "It+6", "Fr+6", "Ger+6"
#   "pitch_classes": Array,          # [0-11] des notes de l'accord
#   "functions": Dictionary,         # {pitch_class: [1,3,5,7]} fonction dans l'accord
#   "is_secondary": bool,            # True si dominante/diminué secondaire
#   "secondary_target": int,         # Degré cible si secondaire
#   "is_borrowed": bool,             # True si emprunt modal
#   "borrowed_from": String,         # "parallel_minor", "parallel_major", "N6_key", etc.
#   "is_tetrad": bool,               # True si accord de 7ème
#   "weight": float,                 # Poids pour le tri des solutions (1.0 = standard)
# }

var _catalog: Array = []
var _pitch_class_index: Dictionary = {}  # {pitch_class: [chord_entries]}
var _reference_key: HarmonicKey = null


func _init():
	pass


# Génère le catalogue complet pour une tonalité de référence
func build_catalog(reference_key: HarmonicKey) -> void:
	_reference_key = reference_key
	_catalog.clear()
	_pitch_class_index.clear()

	# 1. Accords en tonalité majeure
	if reference_key.scale_name == "major":
		_build_major_key_chords(reference_key)

	# 2. Accords en tonalité mineure relative
	var relative_minor_key = _get_relative_minor(reference_key)
	_build_minor_key_chords(relative_minor_key)

	# 3. Si la tonalité de référence est mineure, construire aussi les accords majeurs
	if reference_key.scale_name in ["minor", "harmonic_minor", "melodic_minor"]:
		_build_minor_key_chords(reference_key)
		var relative_major_key = _get_relative_major(reference_key)
		_build_major_key_chords(relative_major_key)

	# Construire l'index inversé
	_build_pitch_class_index()

	LogBus.debug(TAG, "Catalogue construit: %d accords" % _catalog.size())


# Construit tous les accords pour une tonalité majeure
func _build_major_key_chords(major_key: HarmonicKey) -> void:
	# A. Diatoniques (triades et tétrades)
	_add_diatonic_chords(major_key, false)
	_add_diatonic_chords(major_key, true)

	# B. Dominantes secondaires
	_add_secondary_dominants(major_key)

	# C. Diminués secondaires
	_add_secondary_diminished(major_key)

	# D. Emprunts au mineur parallèle
	_add_parallel_minor_borrowings(major_key)

	# E. Sixte Napolitaine
	_add_neapolitan_sixth(major_key)

	# F. Sixtes Augmentées
	_add_augmented_sixths(major_key)


# Construit tous les accords pour une tonalité mineure
func _build_minor_key_chords(minor_key: HarmonicKey) -> void:
	# A. Diatoniques en mineur harmonique (triades et tétrades)
	var harm_minor_key = minor_key.clone() if minor_key.has_method("clone") else _clone_key(minor_key)
	harm_minor_key.scale_name = "harmonic_minor"
	_add_diatonic_chords(harm_minor_key, false)
	_add_diatonic_chords(harm_minor_key, true)

	# Diatoniques en mineur naturel (pour III, v, VII)
	var nat_minor_key = _clone_key(minor_key)
	nat_minor_key.scale_name = "minor"
	_add_natural_minor_specifics(nat_minor_key)

	# B. Dominantes secondaires
	_add_secondary_dominants_minor(harm_minor_key)

	# C. Diminués secondaires
	_add_secondary_diminished_minor(harm_minor_key)

	# D. Emprunts au majeur parallèle
	_add_parallel_major_borrowings(minor_key)

	# E. Sixte Napolitaine
	_add_neapolitan_sixth(harm_minor_key)

	# F. Sixtes Augmentées
	_add_augmented_sixths(harm_minor_key)


# Ajoute les accords diatoniques (triades ou tétrades)
func _add_diatonic_chords(key: HarmonicKey, is_tetrad: bool) -> void:
	for deg in range(1, 8):
		var chord_entry = _create_diatonic_chord(key, deg, is_tetrad)
		_catalog.append(chord_entry)


# Crée un accord diatonique
func _create_diatonic_chord(key: HarmonicKey, degree_num: int, is_tetrad: bool) -> Dictionary:
	var realization = [1, 3, 5, 7] if is_tetrad else [1, 3, 5]
	var pitch_classes = _get_chord_pitch_classes(key, degree_num, realization, {})
	var functions = _map_pitch_to_functions(pitch_classes, realization)

	var id = _degree_to_roman(key, degree_num)
	if is_tetrad:
		id += "7"

	return {
		"id": id,
		"degree_number": degree_num,
		"key": key,
		"kind": "diatonic",
		"pitch_classes": pitch_classes,
		"functions": functions,
		"is_secondary": false,
		"secondary_target": 0,
		"is_borrowed": false,
		"borrowed_from": "",
		"is_tetrad": is_tetrad,
		"weight": 1.0,
		"realization": realization
	}


# Ajoute les dominantes secondaires (V/x)
func _add_secondary_dominants(major_key: HarmonicKey) -> void:
	# Cibles possibles en majeur: ii, iii, IV, V, vi
	var targets = [2, 3, 4, 5, 6]

	for target in targets:
		# Créer la tonalité de la cible
		var target_root = (major_key.root_midi + _get_scale_degree_semitones(major_key, target)) % 12
		var target_key = HarmonicKey.new()
		target_key.root_midi = target_root
		# La cible ii, iii, vi sont mineures -> leur V est majeur
		# La cible IV, V sont majeures -> leur V est aussi majeur
		target_key.scale_name = "major"

		# V de la cible (triade)
		var chord_entry_triad = _create_secondary_dominant(major_key, target_key, target, false)
		_catalog.append(chord_entry_triad)

		# V7 de la cible (tétrade)
		var chord_entry_tetrad = _create_secondary_dominant(major_key, target_key, target, true)
		_catalog.append(chord_entry_tetrad)


# Crée une dominante secondaire
func _create_secondary_dominant(original_key: HarmonicKey, target_key: HarmonicKey, target_degree: int, is_tetrad: bool) -> Dictionary:
	var realization = [1, 3, 5, 7] if is_tetrad else [1, 3, 5]
	var pitch_classes = _get_chord_pitch_classes(target_key, 5, realization, {})
	var functions = _map_pitch_to_functions(pitch_classes, realization)

	var id = "V"
	if is_tetrad:
		id += "7"
	id += "/" + _degree_to_roman_simple(target_degree)

	return {
		"id": id,
		"degree_number": 5,
		"key": target_key,
		"kind": "diatonic",
		"pitch_classes": pitch_classes,
		"functions": functions,
		"is_secondary": true,
		"secondary_target": target_degree,
		"is_borrowed": false,
		"borrowed_from": "",
		"is_tetrad": is_tetrad,
		"weight": 0.9,
		"realization": realization,
		"original_key": original_key
	}


# Ajoute les diminués secondaires (vii°/x)
func _add_secondary_diminished(major_key: HarmonicKey) -> void:
	var targets = [2, 3, 4, 5, 6]

	for target in targets:
		var target_root = (major_key.root_midi + _get_scale_degree_semitones(major_key, target)) % 12
		var target_key = HarmonicKey.new()
		target_key.root_midi = target_root
		target_key.scale_name = "major"

		# vii° de la cible (triade)
		var chord_entry_triad = _create_secondary_diminished(major_key, target_key, target, false)
		_catalog.append(chord_entry_triad)

		# vii°7 de la cible (tétrade)
		var chord_entry_tetrad = _create_secondary_diminished(major_key, target_key, target, true)
		_catalog.append(chord_entry_tetrad)


# Crée un diminué secondaire
func _create_secondary_diminished(original_key: HarmonicKey, target_key: HarmonicKey, target_degree: int, is_tetrad: bool) -> Dictionary:
	var realization = [1, 3, 5, 7] if is_tetrad else [1, 3, 5]
	var pitch_classes = _get_chord_pitch_classes(target_key, 7, realization, {})
	var functions = _map_pitch_to_functions(pitch_classes, realization)

	var id = "vii°"
	if is_tetrad:
		id += "7"
	id += "/" + _degree_to_roman_simple(target_degree)

	return {
		"id": id,
		"degree_number": 7,
		"key": target_key,
		"kind": "diatonic",
		"pitch_classes": pitch_classes,
		"functions": functions,
		"is_secondary": true,
		"secondary_target": target_degree,
		"is_borrowed": false,
		"borrowed_from": "",
		"is_tetrad": is_tetrad,
		"weight": 0.8,
		"realization": realization,
		"original_key": original_key
	}


# Ajoute les emprunts au mineur parallèle
func _add_parallel_minor_borrowings(major_key: HarmonicKey) -> void:
	# Mineur harmonique par défaut
	var parallel_minor = HarmonicKey.new()
	parallel_minor.root_midi = major_key.root_midi
	parallel_minor.scale_name = "harmonic_minor"

	# Degrés à emprunter: i, ii°, iv, VI (bVI), vii°
	var degrees_harm = [1, 2, 4, 6, 7]
	for deg in degrees_harm:
		var chord_triad = _create_borrowed_chord(major_key, parallel_minor, deg, false, "parallel_minor")
		_catalog.append(chord_triad)
		var chord_tetrad = _create_borrowed_chord(major_key, parallel_minor, deg, true, "parallel_minor")
		_catalog.append(chord_tetrad)

	# Mineur naturel pour III, v, VII (bVII)
	var parallel_minor_nat = HarmonicKey.new()
	parallel_minor_nat.root_midi = major_key.root_midi
	parallel_minor_nat.scale_name = "minor"

	var degrees_nat = [3, 5, 7]
	for deg in degrees_nat:
		var chord_triad = _create_borrowed_chord(major_key, parallel_minor_nat, deg, false, "parallel_minor_natural")
		_catalog.append(chord_triad)
		var chord_tetrad = _create_borrowed_chord(major_key, parallel_minor_nat, deg, true, "parallel_minor_natural")
		_catalog.append(chord_tetrad)


# Ajoute les emprunts au majeur parallèle (quand on est en mineur)
func _add_parallel_major_borrowings(minor_key: HarmonicKey) -> void:
	var parallel_major = HarmonicKey.new()
	parallel_major.root_midi = minor_key.root_midi
	parallel_major.scale_name = "major"

	# Tous les degrés du majeur peuvent être empruntés
	for deg in range(1, 8):
		var chord_triad = _create_borrowed_chord(minor_key, parallel_major, deg, false, "parallel_major")
		_catalog.append(chord_triad)
		var chord_tetrad = _create_borrowed_chord(minor_key, parallel_major, deg, true, "parallel_major")
		_catalog.append(chord_tetrad)


# Crée un accord emprunté
func _create_borrowed_chord(original_key: HarmonicKey, borrowed_key: HarmonicKey, degree_num: int, is_tetrad: bool, borrowed_from: String) -> Dictionary:
	var realization = [1, 3, 5, 7] if is_tetrad else [1, 3, 5]
	var pitch_classes = _get_chord_pitch_classes(borrowed_key, degree_num, realization, {})
	var functions = _map_pitch_to_functions(pitch_classes, realization)

	var id = _degree_to_roman(borrowed_key, degree_num)
	if is_tetrad:
		id += "7"
	id += " (borrowed)"

	return {
		"id": id,
		"degree_number": degree_num,
		"key": borrowed_key,
		"kind": "diatonic",
		"pitch_classes": pitch_classes,
		"functions": functions,
		"is_secondary": false,
		"secondary_target": 0,
		"is_borrowed": true,
		"borrowed_from": borrowed_from,
		"is_tetrad": is_tetrad,
		"weight": 0.85,
		"realization": realization,
		"original_key": original_key
	}


# Ajoute la sixte napolitaine
func _add_neapolitan_sixth(key: HarmonicKey) -> void:
	# Gamme d'emprunt: majeur, root + 1 demi-ton
	var n6_key = HarmonicKey.new()
	n6_key.root_midi = (key.root_midi + 1) % 12
	n6_key.scale_name = "major"

	# L'accord est le degré I de cette gamme d'emprunt
	# Mais le kind est "N6" et on garde cette info
	var realization = [1, 3, 5]
	var pitch_classes = _get_chord_pitch_classes(n6_key, 1, realization, {})
	var functions = _map_pitch_to_functions(pitch_classes, realization)

	# Aussi ajouter toutes les notes de la gamme N6 comme possibilités mélodiques
	var n6_scale_pcs = _get_scale_pitch_classes(n6_key)

	var chord_entry = {
		"id": "N6",
		"degree_number": 1,
		"key": n6_key,
		"kind": "N6",
		"pitch_classes": pitch_classes,
		"functions": functions,
		"is_secondary": false,
		"secondary_target": 0,
		"is_borrowed": true,
		"borrowed_from": "N6_key",
		"is_tetrad": false,
		"weight": 0.7,
		"realization": realization,
		"original_key": key,
		"n6_scale_pitch_classes": n6_scale_pcs
	}
	_catalog.append(chord_entry)


# Ajoute les sixtes augmentées
func _add_augmented_sixths(key: HarmonicKey) -> void:
	# It+6
	_add_augmented_sixth_type(key, "It+6", [1, 3, 5])
	# Fr+6
	_add_augmented_sixth_type(key, "Fr+6", [1, 3, 5, 6])
	# Ger+6
	_add_augmented_sixth_type(key, "Ger+6", [1, 3, 5, 7])


func _add_augmented_sixth_type(key: HarmonicKey, kind: String, realization: Array) -> void:
	# Créer un Degree temporaire pour obtenir les altérations correctes
	var temp_degree = Degree.new()
	temp_degree.key = key

	match kind:
		"It+6":
			temp_degree.set_aug6_It()
		"Fr+6":
			temp_degree.set_aug6_Fr()
		"Ger+6":
			temp_degree.set_aug6_Ger()

	# Récupérer les pitch classes du Degree
	var midi_notes = temp_degree.get_chord_midi()
	var pitch_classes = []
	for m in midi_notes:
		pitch_classes.append(m % 12)

	var functions = _map_pitch_to_functions(pitch_classes, realization)

	# Calculer les pitch classes de la gamme altérée pour les notes mélodiques
	var altered_scale_pcs = _get_altered_scale_for_aug6(key, kind)

	var chord_entry = {
		"id": kind,
		"degree_number": 4,
		"key": key,
		"kind": kind,
		"pitch_classes": pitch_classes,
		"functions": functions,
		"is_secondary": false,
		"secondary_target": 0,
		"is_borrowed": false,
		"borrowed_from": "",
		"is_tetrad": realization.size() > 3,
		"weight": 0.7,
		"realization": realization,
		"altered_scale_pitch_classes": altered_scale_pcs
	}
	_catalog.append(chord_entry)


# Ajoute les degrés spécifiques au mineur naturel (III, v, VII)
func _add_natural_minor_specifics(nat_minor_key: HarmonicKey) -> void:
	# III majeur (au lieu de III+)
	var chord_III_triad = _create_diatonic_chord(nat_minor_key, 3, false)
	chord_III_triad["id"] = "III (natural)"
	chord_III_triad["weight"] = 0.95
	_catalog.append(chord_III_triad)

	var chord_III_tetrad = _create_diatonic_chord(nat_minor_key, 3, true)
	chord_III_tetrad["id"] = "III7 (natural)"
	chord_III_tetrad["weight"] = 0.95
	_catalog.append(chord_III_tetrad)

	# v mineur (au lieu de V majeur)
	var chord_v_triad = _create_diatonic_chord(nat_minor_key, 5, false)
	chord_v_triad["id"] = "v (natural)"
	chord_v_triad["weight"] = 0.9
	_catalog.append(chord_v_triad)

	var chord_v_tetrad = _create_diatonic_chord(nat_minor_key, 5, true)
	chord_v_tetrad["id"] = "v7 (natural)"
	chord_v_tetrad["weight"] = 0.9
	_catalog.append(chord_v_tetrad)

	# VII majeur (au lieu de vii°)
	var chord_VII_triad = _create_diatonic_chord(nat_minor_key, 7, false)
	chord_VII_triad["id"] = "VII (natural)"
	chord_VII_triad["weight"] = 0.9
	_catalog.append(chord_VII_triad)

	var chord_VII_tetrad = _create_diatonic_chord(nat_minor_key, 7, true)
	chord_VII_tetrad["id"] = "VII7 (natural)"
	chord_VII_tetrad["weight"] = 0.9
	_catalog.append(chord_VII_tetrad)


# Dominantes secondaires en mineur
func _add_secondary_dominants_minor(minor_key: HarmonicKey) -> void:
	# Cibles possibles en mineur: III, iv, V, VI, VII
	var targets = [3, 4, 5, 6, 7]

	for target in targets:
		var target_root = (minor_key.root_midi + _get_scale_degree_semitones(minor_key, target)) % 12
		var target_key = HarmonicKey.new()
		target_key.root_midi = target_root
		target_key.scale_name = "major"

		# V de la cible
		var chord_triad = _create_secondary_dominant(minor_key, target_key, target, false)
		_catalog.append(chord_triad)
		var chord_tetrad = _create_secondary_dominant(minor_key, target_key, target, true)
		_catalog.append(chord_tetrad)


# Diminués secondaires en mineur
func _add_secondary_diminished_minor(minor_key: HarmonicKey) -> void:
	var targets = [3, 4, 5, 6, 7]

	for target in targets:
		var target_root = (minor_key.root_midi + _get_scale_degree_semitones(minor_key, target)) % 12
		var target_key = HarmonicKey.new()
		target_key.root_midi = target_root
		target_key.scale_name = "major"

		var chord_triad = _create_secondary_diminished(minor_key, target_key, target, false)
		_catalog.append(chord_triad)
		var chord_tetrad = _create_secondary_diminished(minor_key, target_key, target, true)
		_catalog.append(chord_tetrad)


# === FONCTIONS UTILITAIRES ===

# Clone une HarmonicKey
func _clone_key(key: HarmonicKey) -> HarmonicKey:
	var new_key = HarmonicKey.new()
	new_key.root_midi = key.root_midi
	new_key.scale_name = key.scale_name
	return new_key


# Obtient la relative mineure d'une tonalité majeure
func _get_relative_minor(major_key: HarmonicKey) -> HarmonicKey:
	var minor_key = HarmonicKey.new()
	minor_key.root_midi = (major_key.root_midi + 9) % 12  # -3 demi-tons = +9
	minor_key.scale_name = "harmonic_minor"
	return minor_key


# Obtient la relative majeure d'une tonalité mineure
func _get_relative_major(minor_key: HarmonicKey) -> HarmonicKey:
	var major_key = HarmonicKey.new()
	major_key.root_midi = (minor_key.root_midi + 3) % 12
	major_key.scale_name = "major"
	return major_key


# Obtient les demi-tons d'un degré dans une gamme
func _get_scale_degree_semitones(key: HarmonicKey, degree: int) -> int:
	var scale_intervals = _get_scale_intervals(key.scale_name)
	var idx = (degree - 1) % 7
	return scale_intervals[idx]


# Intervalles des gammes
func _get_scale_intervals(scale_name: String) -> Array:
	match scale_name:
		"major", "ionian":
			return [0, 2, 4, 5, 7, 9, 11]
		"minor", "aeolian":
			return [0, 2, 3, 5, 7, 8, 10]
		"harmonic_minor":
			return [0, 2, 3, 5, 7, 8, 11]
		"melodic_minor":
			return [0, 2, 3, 5, 7, 9, 11]
		_:
			return [0, 2, 4, 5, 7, 9, 11]  # majeur par défaut


# Obtient les pitch classes d'un accord
func _get_chord_pitch_classes(key: HarmonicKey, degree_num: int, realization: Array, alterations: Dictionary) -> Array:
	var pitch_classes = []
	var scale_intervals = _get_scale_intervals(key.scale_name)

	for func_num in realization:
		# Le degré dans la gamme = degree_num + (func_num - 1)
		# func_num: 1=fond, 3=tierce, 5=quinte, 7=septième
		var scale_degree = degree_num + func_num - 1
		var idx = ((scale_degree - 1) % 7)
		var semitones = scale_intervals[idx]

		# Appliquer les altérations
		if alterations.has(scale_degree):
			semitones += alterations[scale_degree]

		var pc = (key.root_midi + semitones) % 12
		pitch_classes.append(pc)

	return pitch_classes


# Obtient les pitch classes d'une gamme complète
func _get_scale_pitch_classes(key: HarmonicKey) -> Array:
	var pitch_classes = []
	var scale_intervals = _get_scale_intervals(key.scale_name)
	for interval in scale_intervals:
		pitch_classes.append((key.root_midi + interval) % 12)
	return pitch_classes


# Obtient la gamme altérée pour les sixtes augmentées
func _get_altered_scale_for_aug6(key: HarmonicKey, kind: String) -> Array:
	# Les sixtes augmentées altèrent le 4ème degré (+1) et potentiellement le 6ème (-1)
	var scale_intervals = _get_scale_intervals(key.scale_name).duplicate()

	# Altération du 4ème degré (raised)
	scale_intervals[3] += 1  # index 3 = degré 4

	# En majeur ou mélodique mineur, le 6ème est abaissé
	if key.scale_name in ["major", "melodic_minor"]:
		scale_intervals[5] -= 1  # index 5 = degré 6

	# Pour Ger+6 en majeur, le 3ème est aussi abaissé
	if kind == "Ger+6" and key.scale_name == "major":
		scale_intervals[2] -= 1  # index 2 = degré 3

	var pitch_classes = []
	for interval in scale_intervals:
		pitch_classes.append((key.root_midi + interval) % 12)
	return pitch_classes


# Mappe les pitch classes aux fonctions
func _map_pitch_to_functions(pitch_classes: Array, realization: Array) -> Dictionary:
	var functions = {}
	for i in range(pitch_classes.size()):
		var pc = pitch_classes[i]
		var func_num = realization[i]
		if not functions.has(pc):
			functions[pc] = []
		functions[pc].append(func_num)
	return functions


# Convertit un degré en chiffre romain
func _degree_to_roman(key: HarmonicKey, degree: int) -> String:
	var romans_major = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
	var romans_harm_minor = ["i", "ii°", "III+", "iv", "V", "VI", "vii°"]
	var romans_nat_minor = ["i", "ii°", "III", "iv", "v", "VI", "VII"]

	var idx = degree - 1
	if idx < 0 or idx > 6:
		return "?"

	match key.scale_name:
		"major":
			return romans_major[idx]
		"harmonic_minor":
			return romans_harm_minor[idx]
		"minor":
			return romans_nat_minor[idx]
		_:
			return romans_major[idx]


func _degree_to_roman_simple(degree: int) -> String:
	var romans = ["I", "ii", "iii", "IV", "V", "vi", "vii"]
	if degree >= 1 and degree <= 7:
		return romans[degree - 1]
	return "?"


# Construit l'index inversé pitch class -> accords
func _build_pitch_class_index() -> void:
	_pitch_class_index.clear()

	for i in range(12):
		_pitch_class_index[i] = []

	for chord_entry in _catalog:
		for pc in chord_entry["pitch_classes"]:
			_pitch_class_index[pc].append(chord_entry)


# === API PUBLIQUE ===

# Retourne tous les accords contenant un pitch class donné
func get_chords_for_pitch_class(pitch_class: int) -> Array:
	var pc = pitch_class % 12
	if _pitch_class_index.has(pc):
		return _pitch_class_index[pc]
	return []


# Retourne le catalogue complet
func get_catalog() -> Array:
	return _catalog


# Retourne l'index inversé complet
func get_pitch_class_index() -> Dictionary:
	return _pitch_class_index


# Retourne la tonalité de référence
func get_reference_key() -> HarmonicKey:
	return _reference_key

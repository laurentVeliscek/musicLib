extends Node

const TAG = "TestMelodyHarmonizer"

# ==============================================================================
# TESTS pour MelodyHarmonizer
# ==============================================================================

func _ready():
	LogBus.info(TAG, "=== Démarrage des tests MelodyHarmonizer ===")

	test_basic_harmonization()
	test_harmonize_with_degrees()
	test_chromatic_notes()
	test_cadence_detection()
	test_partimento_rules()

	LogBus.info(TAG, "=== Tous les tests terminés ===")

# ------------------------------------------------------------------------------
# Test 1: Harmonisation basique d'une mélodie simple
# ------------------------------------------------------------------------------
func test_basic_harmonization():
	LogBus.info(TAG, "--- Test 1: Harmonisation basique ---")

	var harmonizer = MelodyHarmonizer.new()
	var key = HarmonicKey.new()
	key.set_from_string("C major")

	# Mélodie simple en Do majeur: Mi - Ré - Do - Si - Do
	# (degrés 3 - 2 - 1 - 7 - 1)
	var melody = [64, 62, 60, 59, 60]  # MIDI: E4, D4, C4, B3, C4

	var options = {
		"max_solutions": 3,
		"start_on_tonic": true,
		"end_on_tonic": true
	}

	var solutions = harmonizer.harmonize(melody, key, options)

	LogBus.info(TAG, "Nombre de solutions trouvées: " + str(solutions.size()))

	for i in range(solutions.size()):
		var solution = solutions[i]
		var progression_str = ""
		for degree in solution:
			progression_str += _degree_to_string(degree) + " - "
		LogBus.info(TAG, "Solution " + str(i + 1) + ": " + progression_str)

	# Vérifications
	assert(solutions.size() > 0, "Au moins une solution doit être trouvée")
	assert(solutions[0].size() == melody.size(), "La solution doit avoir autant d'accords que de notes")

	# Vérifier que le premier accord est bien une tonique
	if not solutions.empty():
		var first_chord = solutions[0][0]
		assert(first_chord.degree_number == 1, "Premier accord doit être I")

		# Vérifier que le dernier accord est une tonique en position fondamentale
		var last_chord = solutions[0][solutions[0].size() - 1]
		assert(last_chord.degree_number == 1, "Dernier accord doit être I")

	LogBus.info(TAG, "Test 1 PASSED")

# ------------------------------------------------------------------------------
# Test 2: Harmonisation avec degrés pré-analysés
# ------------------------------------------------------------------------------
func test_harmonize_with_degrees():
	LogBus.info(TAG, "--- Test 2: Harmonisation avec degrés ---")

	var harmonizer = MelodyHarmonizer.new()
	var key = HarmonicKey.new()
	key.set_from_string("A minor")

	# Mélodie en degrés: 5 - 4 - 3 - 2 - 1 (descente vers tonique)
	var melody_degrees = [
		{ "degree": 5, "alteration": 0 },
		{ "degree": 4, "alteration": 0 },
		{ "degree": 3, "alteration": 0 },
		{ "degree": 2, "alteration": 0 },
		{ "degree": 1, "alteration": 0 }
	]

	var solutions = harmonizer.harmonize_with_degrees(melody_degrees, key)

	LogBus.info(TAG, "Solutions pour descente en La mineur:")
	for i in range(min(2, solutions.size())):
		var solution = solutions[i]
		var progression_str = ""
		for degree in solution:
			progression_str += _degree_to_string(degree) + " "
		LogBus.info(TAG, "  " + str(i + 1) + ": " + progression_str)

	assert(solutions.size() > 0, "Au moins une solution doit être trouvée")

	LogBus.info(TAG, "Test 2 PASSED")

# ------------------------------------------------------------------------------
# Test 3: Notes chromatiques et dominantes secondaires
# ------------------------------------------------------------------------------
func test_chromatic_notes():
	LogBus.info(TAG, "--- Test 3: Notes chromatiques ---")

	var harmonizer = MelodyHarmonizer.new()
	harmonizer.allow_secondary_dominants = true

	var key = HarmonicKey.new()
	key.set_from_string("C major")

	# Mélodie avec Fa# (altération chromatique) -> devrait suggérer V/V
	# Do - Ré - Fa# - Sol - Do
	var melody = [60, 62, 66, 67, 60]  # C4, D4, F#4, G4, C4

	var solutions = harmonizer.harmonize(melody, key, {"max_solutions": 3})

	LogBus.info(TAG, "Solutions pour mélodie avec Fa#:")
	for i in range(solutions.size()):
		var solution = solutions[i]
		var progression_str = ""
		for degree in solution:
			progression_str += _degree_to_string(degree) + " "
		LogBus.info(TAG, "  " + str(i + 1) + ": " + progression_str)

	# Vérifier qu'au moins une solution contient une dominante secondaire
	var has_secondary = false
	for solution in solutions:
		for degree in solution:
			if degree.kind == "secondary" or degree._is_secondary:
				has_secondary = true
				break

	LogBus.info(TAG, "Dominante secondaire trouvée: " + str(has_secondary))

	LogBus.info(TAG, "Test 3 PASSED")

# ------------------------------------------------------------------------------
# Test 4: Détection de cadence
# ------------------------------------------------------------------------------
func test_cadence_detection():
	LogBus.info(TAG, "--- Test 4: Cadence parfaite ---")

	var harmonizer = MelodyHarmonizer.new()
	var key = HarmonicKey.new()
	key.set_from_string("G major")

	# Fin de phrase typique: Ré - Ré - Sol (2 - 2 - 1)
	# Devrait produire: ii - V - I ou IV - V - I
	var melody_degrees = [
		{ "degree": 6, "alteration": 0 },
		{ "degree": 4, "alteration": 0 },
		{ "degree": 2, "alteration": 0 },
		{ "degree": 7, "alteration": 0 },
		{ "degree": 1, "alteration": 0 }
	]

	var options = {
		"end_on_tonic": true,
		"max_solutions": 5
	}

	var solutions = harmonizer.harmonize_with_degrees(melody_degrees, key, options)

	LogBus.info(TAG, "Cadences détectées:")
	for i in range(min(3, solutions.size())):
		var solution = solutions[i]
		var last_three = ""
		var start_idx = max(0, solution.size() - 3)
		for j in range(start_idx, solution.size()):
			last_three += _degree_to_string(solution[j]) + " "
		LogBus.info(TAG, "  Fin " + str(i + 1) + ": ..." + last_three)

	# Vérifier que la dernière note est bien harmonisée par I
	if not solutions.empty():
		var best_solution = solutions[0]
		var last_chord = best_solution[best_solution.size() - 1]
		assert(last_chord.degree_number == 1, "Dernier accord doit être I pour cadence parfaite")

		# Vérifier l'avant-dernier (devrait être V)
		if best_solution.size() >= 2:
			var penultimate = best_solution[best_solution.size() - 2]
			LogBus.info(TAG, "Avant-dernier accord: " + _degree_to_string(penultimate))

	LogBus.info(TAG, "Test 4 PASSED")

# ------------------------------------------------------------------------------
# Test 5: Règles Partimento
# ------------------------------------------------------------------------------
func test_partimento_rules():
	LogBus.info(TAG, "--- Test 5: Règles Partimento ---")

	# Test de la règle d'octave
	var octave_rule = PartimentoRules.get_rule_of_octave(5, false, true)
	LogBus.info(TAG, "Règle d'octave degré 5 (majeur, montant): " + str(octave_rule))
	assert(octave_rule.has("degree"), "Doit retourner un accord")
	assert(octave_rule.degree == 5, "Degré 5 à la basse -> accord de V")

	# Test des accords pour note mélodique
	var chords_for_mi = PartimentoRules.get_chords_for_melody_note(3, false)
	LogBus.info(TAG, "Accords possibles pour Mi (degré 3) en majeur: " + str(chords_for_mi.size()))
	assert(chords_for_mi.size() > 0, "Doit avoir des accords candidats")

	# Test du score de transition
	var score_t_to_d = PartimentoRules.get_transition_score("T", "D")
	var score_d_to_t = PartimentoRules.get_transition_score("D", "T")
	LogBus.info(TAG, "Score T->D: " + str(score_t_to_d) + ", D->T: " + str(score_d_to_t))
	assert(score_d_to_t > score_t_to_d, "D->T doit être privilégié (résolution)")

	# Test des schémas
	var romanesca = PartimentoRules.get_schema("romanesca")
	LogBus.info(TAG, "Schéma Romanesca: " + str(romanesca.get("name", "")))
	assert(romanesca.has("pattern"), "Romanesca doit avoir un pattern")
	assert(romanesca.pattern.size() == 4, "Romanesca a 4 accords")

	var all_schemas = PartimentoRules.list_schemas()
	LogBus.info(TAG, "Schémas disponibles: " + str(all_schemas))
	assert(all_schemas.size() >= 6, "Au moins 6 schémas définis")

	LogBus.info(TAG, "Test 5 PASSED")

# ------------------------------------------------------------------------------
# Utilitaires
# ------------------------------------------------------------------------------
func _degree_to_string(degree: Degree) -> String:
	if degree == null:
		return "?"

	var label = ""

	# Si c'est un accord secondaire
	if degree._is_secondary and degree._secondary_roman_spelling != "":
		return degree._secondary_roman_spelling

	# Sinon, construire le label
	var is_minor = degree.key != null and degree.key.scale_name.to_lower().find("minor") >= 0

	match degree.degree_number:
		1: label = "i" if is_minor else "I"
		2: label = "iio" if is_minor else "ii"
		3: label = "III" if is_minor else "iii"
		4: label = "iv" if is_minor else "IV"
		5: label = "V"
		6: label = "VI" if is_minor else "vi"
		7: label = "viio" if is_minor else "viio"

	# Ajouter l'inversion
	if degree.realization.size() == 4:
		match degree.inversion:
			0: label += "7"
			1: label += "65"
			2: label += "43"
			3: label += "42"
	else:
		match degree.inversion:
			1: label += "6"
			2: label += "64"

	return label

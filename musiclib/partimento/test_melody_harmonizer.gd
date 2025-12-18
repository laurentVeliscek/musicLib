extends Node

const TAG = "TestMelodyHarmonizer"

# ==============================================================================
# TESTS pour le système d'harmonisation Partimento v2
# ==============================================================================

func _ready():
	LogBus.info(TAG, "=== Démarrage des tests Partimento v2 ===\n")

	test_harmonic_window_basic()
	test_harmonic_window_intervals()
	test_harmonic_window_scoring()
	test_harmonic_window_melodic_degree()
	test_window_analyzer()
	test_melody_harmonizer_full()
	test_melody_harmonizer_with_options()

	LogBus.info(TAG, "\n=== Tous les tests terminés ===")

# ==============================================================================
# Tests HarmonicWindow
# ==============================================================================

func test_harmonic_window_basic():
	LogBus.info(TAG, "--- Test 1: HarmonicWindow basique ---")

	var key = HarmonicKey.new()
	key.set_from_string("C major")

	var window = HarmonicWindow.new(0.0, 4.0, key)
	window.add_note(60, 0.0, 1.0)  # Do sur downbeat
	window.add_note(64, 1.0, 1.0)  # Mi
	window.add_note(67, 2.0, 1.0)  # Sol
	window.analyze()

	LogBus.info(TAG, "  Notes ajoutées: %d" % window.notes.size())
	LogBus.info(TAG, "  Notes downbeat: %d" % window.downbeat_notes.size())
	LogBus.info(TAG, "  Contour mélodique: %s" % str(window.melodic_contour))

	assert(window.notes.size() == 3, "Doit avoir 3 notes")
	assert(window.downbeat_notes.size() == 1, "Doit avoir 1 note downbeat")
	assert(window.melodic_contour == [1, 3, 5], "Contour doit être [1, 3, 5] (Do-Mi-Sol)")

	LogBus.info(TAG, "  Test 1 PASSED\n")

func test_harmonic_window_intervals():
	LogBus.info(TAG, "--- Test 2: Détection intervalles conjoints/disjoints ---")

	var key = HarmonicKey.new()
	key.set_from_string("A harmonic_minor")

	var window = HarmonicWindow.new(0.0, 4.0, key)
	# La - Si - Do - Ré# (mouvement conjoint puis saut)
	window.add_note(69, 0.0, 0.5)  # La (degré 1)
	window.add_note(71, 0.5, 0.5)  # Si (degré 2)
	window.add_note(72, 1.0, 0.5)  # Do (degré 3)
	window.add_note(77, 1.5, 0.5)  # Fa (degré 6) - saut de tierce
	window.add_note(80, 2.0, 0.5)  # Sol# (degré 7) - 3 demi-tons mais conjoint!
	window.analyze()

	LogBus.info(TAG, "  Contour: %s" % str(window.melodic_contour))
	LogBus.info(TAG, "  Intervalles totaux: %d" % window.intervals.size())
	LogBus.info(TAG, "  Intervalles disjoints: %d" % window.disjunct_intervals.size())

	# Vérifier que Fa-Sol# est considéré conjoint (degrés 6-7)
	var found_conjunct_aug2 = false
	for interval in window.intervals:
		if interval.from_degree == 6 and interval.to_degree == 7:
			found_conjunct_aug2 = interval.is_conjunct
			LogBus.info(TAG, "  Intervalle 6->7 (Fa-Sol#): conjoint=%s" % str(interval.is_conjunct))

	assert(found_conjunct_aug2, "L'intervalle Fa-Sol# doit être conjoint (degrés 6-7)")
	assert(window.disjunct_intervals.size() >= 1, "Doit avoir au moins 1 saut (Do-Fa)")

	LogBus.info(TAG, "  Test 2 PASSED\n")

func test_harmonic_window_scoring():
	LogBus.info(TAG, "--- Test 3: Scoring des accords candidats ---")

	var key = HarmonicKey.new()
	key.set_from_string("C major")

	var window = HarmonicWindow.new(0.0, 4.0, key)
	window.add_note(64, 0.0, 2.0)  # Mi sur downbeat
	window.analyze()

	# Mi est dans I (Do-Mi-Sol) et vi (La-Do-Mi) et iii (Mi-Sol-Si)
	var score_I = window.score_chord_candidate(1, [1, 3, 5], 0)
	var score_vi = window.score_chord_candidate(6, [1, 3, 5], 0)
	var score_V = window.score_chord_candidate(5, [1, 3, 5], 0)  # Mi n'est pas dans V

	LogBus.info(TAG, "  Note downbeat: Mi (degré 3)")
	LogBus.info(TAG, "  Score I (Do-Mi-Sol): %.1f, valid=%s" % [score_I.score, score_I.valid])
	LogBus.info(TAG, "  Score vi (La-Do-Mi): %.1f, valid=%s" % [score_vi.score, score_vi.valid])
	LogBus.info(TAG, "  Score V (Sol-Si-Ré): %.1f, valid=%s" % [score_V.score, score_V.valid])

	assert(score_I.valid, "I doit être valide (contient Mi)")
	assert(score_vi.valid, "vi doit être valide (contient Mi)")
	assert(not score_V.valid, "V ne doit PAS être valide (ne contient pas Mi)")
	assert(score_I.score > score_V.score, "I doit avoir un meilleur score que V")

	LogBus.info(TAG, "  Test 3 PASSED\n")

func test_harmonic_window_melodic_degree():
	LogBus.info(TAG, "--- Test 4: Création Degree melodic ---")

	var key = HarmonicKey.new()
	key.set_from_string("C major")

	var window = HarmonicWindow.new(0.0, 4.0, key)
	window.add_note(64, 0.0, 1.0)  # Mi
	window.analyze()

	# Mi dans accord I (Do majeur) -> tierce de l'accord
	var melodic_deg = window.create_melodic_degree(64, 1, [1, 3, 5])

	LogBus.info(TAG, "  Note MIDI 64 (Mi) dans accord I")
	LogBus.info(TAG, "  degree_number: %d (doit être 1 = accord I)" % melodic_deg.degree_number)
	LogBus.info(TAG, "  realization: %s (doit être [3] = tierce)" % str(melodic_deg.realization))
	LogBus.info(TAG, "  kind: %s (doit être 'melodic')" % melodic_deg.kind)

	assert(melodic_deg.degree_number == 1, "degree_number doit être 1 (accord I)")
	assert(melodic_deg.realization == [3], "realization doit être [3] (tierce)")
	assert(melodic_deg.kind == "melodic", "kind doit être 'melodic'")

	# Test avec note altérée: Fa# dans accord I
	var melodic_deg2 = window.create_melodic_degree(66, 1, [1, 3, 5])  # Fa#
	LogBus.info(TAG, "  Note MIDI 66 (Fa#) dans accord I")
	LogBus.info(TAG, "  realization: %s" % str(melodic_deg2.realization))

	LogBus.info(TAG, "  Test 4 PASSED\n")

# ==============================================================================
# Tests WindowAnalyzer
# ==============================================================================

func test_window_analyzer():
	LogBus.info(TAG, "--- Test 5: WindowAnalyzer ---")

	var key = HarmonicKey.new()
	key.set_from_string("G major")

	var notes = [
		{"midi": 67, "start": 0.0, "duration": 2.0},   # Sol
		{"midi": 69, "start": 2.0, "duration": 2.0},   # La
		{"midi": 71, "start": 4.0, "duration": 2.0},   # Si
		{"midi": 72, "start": 6.0, "duration": 2.0},   # Do
		{"midi": 74, "start": 8.0, "duration": 4.0}    # Ré
	]

	var analyzer = WindowAnalyzer.new()
	var windows = analyzer.analyze_partition(notes, key, 4.0)

	LogBus.info(TAG, "  Notes: 5 sur 12 beats")
	LogBus.info(TAG, "  Fenêtres créées: %d (attendu: 3)" % windows.size())
	LogBus.info(TAG, "  Contour downbeat: %s" % str(analyzer.get_downbeat_contour()))

	assert(windows.size() == 3, "Doit créer 3 fenêtres (0-4, 4-8, 8-12)")

	# Vérifier la distribution des notes
	LogBus.info(TAG, "  Fenêtre 0: %d notes" % windows[0].notes.size())
	LogBus.info(TAG, "  Fenêtre 1: %d notes" % windows[1].notes.size())
	LogBus.info(TAG, "  Fenêtre 2: %d notes" % windows[2].notes.size())

	assert(windows[0].notes.size() == 2, "Fenêtre 0 doit avoir 2 notes")
	assert(windows[1].notes.size() == 2, "Fenêtre 1 doit avoir 2 notes")
	assert(windows[2].notes.size() == 1, "Fenêtre 2 doit avoir 1 note")

	LogBus.info(TAG, "  Test 5 PASSED\n")

# ==============================================================================
# Tests MelodyHarmonizer complet
# ==============================================================================

func test_melody_harmonizer_full():
	LogBus.info(TAG, "--- Test 6: MelodyHarmonizer complet ---")

	var key = HarmonicKey.new()
	key.set_from_string("C major")

	# Mélodie simple: Mi - Ré - Do (descente vers tonique)
	var notes = [
		{"midi": 64, "start": 0.0, "duration": 4.0},   # Mi
		{"midi": 62, "start": 4.0, "duration": 4.0},   # Ré
		{"midi": 60, "start": 8.0, "duration": 4.0}    # Do
	]

	var harmonizer = MelodyHarmonizer.new()
	var result = harmonizer.harmonize(notes, key, {
		"window_size": 4.0,
		"max_solutions": 3
	})

	LogBus.info(TAG, "  Solutions trouvées: %d" % result.solutions.size())
	LogBus.info(TAG, "  Fenêtres analysées: %d" % result.report.windows_analyzed)

	assert(result.solutions.size() > 0, "Doit trouver au moins une solution")
	assert(result.report.windows_analyzed == 3, "Doit analyser 3 fenêtres")

	# Afficher la meilleure solution
	if result.solutions.size() > 0:
		var best = result.solutions[0]
		var prog_str = ""
		for deg in best.progression:
			prog_str += _degree_to_roman(deg) + " "
		LogBus.info(TAG, "  Meilleure progression: %s" % prog_str)
		LogBus.info(TAG, "  Score: %.1f" % best.score)
		LogBus.info(TAG, "  Melody track: %d éléments" % best.melody_track.size())

		# Vérifier que la progression a 3 accords
		assert(best.progression.size() == 3, "Progression doit avoir 3 accords")

		# Vérifier le melody_track
		assert(best.melody_track.size() == 3, "Melody track doit avoir 3 éléments")

		# Afficher les degrés mélodiques
		LogBus.info(TAG, "  Détail melody_track:")
		for item in best.melody_track:
			var md = item.degree
			LogBus.info(TAG, "    MIDI %d -> accord %s, position %s" % [
				item.original_midi,
				_degree_to_roman_simple(md.degree_number),
				str(md.realization)
			])

	LogBus.info(TAG, "  Test 6 PASSED\n")

func test_melody_harmonizer_with_options():
	LogBus.info(TAG, "--- Test 7: MelodyHarmonizer avec options ---")

	var key = HarmonicKey.new()
	key.set_from_string("A minor")

	# Mélodie avec 7ème: La - Sol# - La
	var notes = [
		{"midi": 69, "start": 0.0, "duration": 4.0},   # La
		{"midi": 68, "start": 4.0, "duration": 4.0},   # Sol# (sensible)
		{"midi": 69, "start": 8.0, "duration": 4.0}    # La
	]

	var harmonizer = MelodyHarmonizer.new()

	# Test SANS seventh_allowed
	var result1 = harmonizer.harmonize(notes, key, {
		"window_size": 4.0,
		"seventh_allowed": false,
		"max_solutions": 2
	})

	# Test AVEC seventh_allowed
	var result2 = harmonizer.harmonize(notes, key, {
		"window_size": 4.0,
		"seventh_allowed": true,
		"max_solutions": 2
	})

	LogBus.info(TAG, "  Sans seventh_allowed: %d solutions" % result1.solutions.size())
	LogBus.info(TAG, "  Avec seventh_allowed: %d solutions" % result2.solutions.size())

	if result1.solutions.size() > 0:
		var prog1 = ""
		for deg in result1.solutions[0].progression:
			prog1 += _degree_to_roman(deg) + " "
		LogBus.info(TAG, "  Progression (sans 7th): %s" % prog1)

	if result2.solutions.size() > 0:
		var prog2 = ""
		for deg in result2.solutions[0].progression:
			prog2 += _degree_to_roman(deg) + " "
		LogBus.info(TAG, "  Progression (avec 7th): %s" % prog2)

	# Vérifier le rapport
	LogBus.info(TAG, "  Contour downbeat: %s" % str(result2.report.downbeat_contour))

	LogBus.info(TAG, "  Test 7 PASSED\n")

# ==============================================================================
# Utilitaires
# ==============================================================================

func _degree_to_roman(degree: Degree) -> String:
	if degree == null:
		return "?"

	var is_minor = degree.key != null and degree.key.scale_name.to_lower().find("minor") >= 0
	var label = _degree_to_roman_simple(degree.degree_number, is_minor)

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

	# Ajouter le commentaire (schéma) si présent
	if degree.comment != "":
		label += " (%s)" % degree.comment

	return label

func _degree_to_roman_simple(degree_num: int, is_minor: bool = false) -> String:
	if is_minor:
		match degree_num:
			1: return "i"
			2: return "iio"
			3: return "III"
			4: return "iv"
			5: return "V"
			6: return "VI"
			7: return "viio"
	else:
		match degree_num:
			1: return "I"
			2: return "ii"
			3: return "iii"
			4: return "IV"
			5: return "V"
			6: return "vi"
			7: return "viio"
	return str(degree_num)

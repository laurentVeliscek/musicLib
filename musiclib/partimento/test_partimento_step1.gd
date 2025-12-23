# test_partimento_step1.gd
# Test de l'étape 1 du partimento: mélodie -> interprétations

extends Node

const TAG = "TestPartimentoStep1"


func _ready():
	test_single_note_do()
	test_chromatic_note()
	test_melody_sequence()
	print("\n=== Tous les tests terminés ===")


# Test 1: Une seule note Do en Do majeur
func test_single_note_do():
	print("\n=== Test 1: Note Do en Do majeur ===")

	# Créer la Song et la Track
	var song = Song.new()
	var melody_track = song.get_track_by_name("midi_melody")

	# Ajouter un Do (MIDI 60)
	var note = Note.new()
	note.midi = 60
	note.length_beats = 1
	melody_track.add_note(0, note)

	# Tonalité: Do majeur
	var key = HarmonicKey.new()
	key.root_midi = 0
	key.scale_name = "major"

	# Convertir
	var converter = PartimentoMelodyToChords.new()
	var interpretations = converter.get_melody_interpretations(song, key)

	print("Nombre d'interprétations pour Do: ", interpretations[0].size())
	print(converter.interpretations_to_string(interpretations))

	# Vérifications attendues:
	# Do peut être:
	# - Fondamentale de I (Do majeur)
	# - Tierce de vi (La mineur)
	# - Quinte de IV (Fa majeur)
	# - Quinte de V/IV (Do7 -> dominante de Fa)
	# - etc.


# Test 2: Note chromatique Do# en Do majeur
func test_chromatic_note():
	print("\n=== Test 2: Note Do# en Do majeur ===")

	var song = Song.new()
	var melody_track = song.get_track_by_name("midi_melody")

	# Ajouter un Do# (MIDI 61)
	var note = Note.new()
	note.midi = 61
	note.length_beats = 1
	melody_track.add_note(0, note)

	# Tonalité: Do majeur
	var key = HarmonicKey.new()
	key.root_midi = 0
	key.scale_name = "major"

	# Convertir
	var converter = PartimentoMelodyToChords.new()
	var interpretations = converter.get_melody_interpretations(song, key)

	print("Nombre d'interprétations pour Do#: ", interpretations[0].size())
	print(converter.interpretations_to_string(interpretations))

	# Vérifications attendues:
	# Do# peut être:
	# - Tierce de V/ii (La majeur -> dominante de Ré mineur)
	# - Fondamentale de vii°/ii
	# - Note de la gamme N6 (Réb majeur)
	# - etc.


# Test 3: Séquence mélodique Do-Mi-Sol
func test_melody_sequence():
	print("\n=== Test 3: Séquence Do-Mi-Sol en Do majeur ===")

	var song = Song.new()
	var melody_track = song.get_track_by_name("midi_melody")

	# Ajouter Do-Mi-Sol
	var notes_midi = [60, 64, 67]
	for i in range(notes_midi.size()):
		var note = Note.new()
		note.midi = notes_midi[i]
		note.length_beats = 1
		melody_track.add_note(i, note)

	# Tonalité: Do majeur
	var key = HarmonicKey.new()
	key.root_midi = 0
	key.scale_name = "major"

	# Convertir
	var converter = PartimentoMelodyToChords.new()
	converter.set_max_solutions(50)  # Limiter pour le test

	# D'abord les interprétations brutes
	var interpretations = converter.get_melody_interpretations(song, key)
	var stats = converter.get_statistics(interpretations)
	print("Statistiques: ", stats)

	# Puis les solutions complètes
	var solutions = converter.convert_melody_to_solutions(song, key)
	print("\nNombre de solutions générées: ", solutions.size())

	# Afficher les 5 premières solutions
	print("\nTop 5 solutions:")
	for i in range(min(5, solutions.size())):
		print(converter.solution_to_string(solutions[i]))

	# Filtrer: triades uniquement
	var filtered = converter.filter_solutions(solutions, {"triads_only": true})
	print("\nSolutions avec triades uniquement: ", filtered.size())

	# Filtrer: pas de secondaires ni emprunts
	var filtered2 = converter.filter_solutions(solutions, {
		"no_secondary": true,
		"no_borrowed": true
	})
	print("Solutions diatoniques pures: ", filtered2.size())


# Test du catalogue directement
func test_catalog():
	print("\n=== Test du catalogue ===")

	var key = HarmonicKey.new()
	key.root_midi = 0
	key.scale_name = "major"

	var catalog = PartimentoChordCatalog.new()
	catalog.build_catalog(key)

	print("Nombre total d'accords dans le catalogue: ", catalog.get_catalog().size())

	# Afficher les accords pour chaque pitch class
	for pc in range(12):
		var chords = catalog.get_chords_for_pitch_class(pc)
		var note_name = ["Do", "Do#", "Ré", "Ré#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"][pc]
		print("%s (%d): %d accords" % [note_name, pc, chords.size()])

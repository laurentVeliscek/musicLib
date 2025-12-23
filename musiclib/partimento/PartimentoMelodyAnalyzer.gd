# PartimentoMelodyAnalyzer.gd
# Analyse une mélodie MIDI et génère toutes les interprétations possibles en degrés

extends Reference
class_name PartimentoMelodyAnalyzer

const TAG = "PartimentoMelodyAnalyzer"

var _catalog: PartimentoChordCatalog = null
var _reference_key: HarmonicKey = null


func _init():
	_catalog = PartimentoChordCatalog.new()


# Analyse une track de mélodie et retourne toutes les interprétations possibles
# Retourne un Array de Array de Degree (options par note)
# melody_track: Track contenant des notes MIDI
# reference_key: HarmonicKey de référence (majeure)
func analyze_melody(melody_track: Track, reference_key: HarmonicKey) -> Array:
	_reference_key = reference_key

	# Construire le catalogue pour cette tonalité
	_catalog.build_catalog(reference_key)

	# Récupérer les événements de notes
	var note_events = melody_track.get_note_events()

	if note_events.empty():
		LogBus.debug(TAG, "Track vide, aucune note à analyser")
		return []

	# Pour chaque note, trouver toutes les interprétations
	var all_interpretations: Array = []

	for event in note_events:
		var note: Note = event["note"]
		var start: float = event["start"]

		var interpretations = _get_interpretations_for_note(note, start)
		all_interpretations.append(interpretations)

		LogBus.debug(TAG, "Note MIDI %d: %d interprétations possibles" % [note.midi, interpretations.size()])

	return all_interpretations


# Retourne toutes les interprétations possibles pour une note MIDI
func _get_interpretations_for_note(note: Note, start: float) -> Array:
	var interpretations: Array = []
	var pitch_class = note.midi % 12

	# Chercher tous les accords contenant ce pitch class
	var matching_chords = _catalog.get_chords_for_pitch_class(pitch_class)

	for chord_entry in matching_chords:
		# Trouver la fonction de cette note dans l'accord
		var functions = chord_entry["functions"]
		if functions.has(pitch_class):
			for func_num in functions[pitch_class]:
				var degree = _create_melodic_degree(note, start, chord_entry, func_num)
				interpretations.append(degree)

	# Ajouter les interprétations pour N6 (notes de la gamme d'emprunt)
	interpretations.append_array(_get_n6_scale_interpretations(note, start, pitch_class))

	# Ajouter les interprétations pour les sixtes augmentées (notes de la gamme altérée)
	interpretations.append_array(_get_aug6_scale_interpretations(note, start, pitch_class))

	return interpretations


# Crée un Degree melodic à partir d'une interprétation
func _create_melodic_degree(note: Note, start: float, chord_entry: Dictionary, func_num: int) -> Degree:
	var d = Degree.new()

	# Configurer la tonalité
	d.key = chord_entry["key"]

	# Configurer le degré
	d.degree_number = chord_entry["degree_number"]

	# Configurer le kind et la réalisation
	var kind = chord_entry["kind"]
	if kind == "diatonic":
		d.set_melodic()
		d.realization = [func_num]
	elif kind == "N6":
		d.set_N6()
		d.realization = [func_num]
	elif kind == "It+6":
		d.set_aug6_It()
		d.realization = [func_num]
	elif kind == "Fr+6":
		d.set_aug6_Fr()
		d.realization = [func_num]
	elif kind == "Ger+6":
		d.set_aug6_Ger()
		d.realization = [func_num]
	else:
		d.set_melodic()
		d.realization = [func_num]

	# Durée
	d.length_beats = note.length_beats

	# Stocker les métadonnées dans partimento_json
	var partimento_data = {
		"start": start,
		"original_midi": note.midi,
		"chord_id": chord_entry["id"],
		"function_in_chord": func_num,
		"is_secondary": chord_entry["is_secondary"],
		"secondary_target": chord_entry["secondary_target"],
		"is_borrowed": chord_entry["is_borrowed"],
		"borrowed_from": chord_entry["borrowed_from"],
		"is_tetrad": chord_entry["is_tetrad"],
		"weight": chord_entry["weight"]
	}

	# Ajouter info sur la tonalité originale si secondaire ou emprunt
	if chord_entry.has("original_key"):
		partimento_data["original_key_root"] = chord_entry["original_key"].root_midi
		partimento_data["original_key_scale"] = chord_entry["original_key"].scale_name

	d.partimento_json = JSON.print(partimento_data)

	return d


# Interprétations N6 pour les notes de la gamme d'emprunt (pas seulement l'accord)
func _get_n6_scale_interpretations(note: Note, start: float, pitch_class: int) -> Array:
	var interpretations: Array = []

	# Chercher les entrées N6 dans le catalogue
	for chord_entry in _catalog.get_catalog():
		if chord_entry["kind"] != "N6":
			continue

		if not chord_entry.has("n6_scale_pitch_classes"):
			continue

		var n6_scale = chord_entry["n6_scale_pitch_classes"]
		if pitch_class in n6_scale:
			# Trouver le degré dans la gamme N6
			var scale_degree = n6_scale.find(pitch_class) + 1

			# Créer un Degree N6 avec cette note comme degré de la gamme
			var d = Degree.new()
			d.key = chord_entry["key"]
			d.set_N6()
			d.degree_number = 1  # L'accord N6 est basé sur le degré 1 de la gamme d'emprunt
			d.realization = [scale_degree]  # Le degré dans la gamme
			d.length_beats = note.length_beats

			var partimento_data = {
				"start": start,
				"original_midi": note.midi,
				"chord_id": "N6 (scale degree %d)" % scale_degree,
				"function_in_chord": scale_degree,
				"is_secondary": false,
				"secondary_target": 0,
				"is_borrowed": true,
				"borrowed_from": "N6_scale",
				"is_tetrad": false,
				"weight": 0.6,
				"n6_scale_degree": scale_degree
			}

			if chord_entry.has("original_key"):
				partimento_data["original_key_root"] = chord_entry["original_key"].root_midi
				partimento_data["original_key_scale"] = chord_entry["original_key"].scale_name

			d.partimento_json = JSON.print(partimento_data)
			interpretations.append(d)

	return interpretations


# Interprétations pour les sixtes augmentées (notes de la gamme altérée)
func _get_aug6_scale_interpretations(note: Note, start: float, pitch_class: int) -> Array:
	var interpretations: Array = []

	for chord_entry in _catalog.get_catalog():
		if chord_entry["kind"] not in ["It+6", "Fr+6", "Ger+6"]:
			continue

		if not chord_entry.has("altered_scale_pitch_classes"):
			continue

		var altered_scale = chord_entry["altered_scale_pitch_classes"]

		# Vérifier si le pitch_class est dans la gamme altérée mais PAS dans l'accord
		# (les notes de l'accord sont déjà gérées par _get_interpretations_for_note)
		if pitch_class in altered_scale and pitch_class not in chord_entry["pitch_classes"]:
			var scale_degree = altered_scale.find(pitch_class) + 1

			var d = Degree.new()
			d.key = chord_entry["key"]

			# Appliquer le bon type de sixte augmentée
			match chord_entry["kind"]:
				"It+6":
					d.set_aug6_It()
				"Fr+6":
					d.set_aug6_Fr()
				"Ger+6":
					d.set_aug6_Ger()

			d.degree_number = 4
			d.realization = [scale_degree]
			d.length_beats = note.length_beats

			var partimento_data = {
				"start": start,
				"original_midi": note.midi,
				"chord_id": "%s (scale degree %d)" % [chord_entry["kind"], scale_degree],
				"function_in_chord": scale_degree,
				"is_secondary": false,
				"secondary_target": 0,
				"is_borrowed": false,
				"borrowed_from": "",
				"is_tetrad": false,
				"weight": 0.5,
				"aug6_scale_degree": scale_degree,
				"aug6_type": chord_entry["kind"]
			}

			d.partimento_json = JSON.print(partimento_data)
			interpretations.append(d)

	return interpretations


# Retourne le catalogue utilisé
func get_catalog() -> PartimentoChordCatalog:
	return _catalog


# Retourne la tonalité de référence
func get_reference_key() -> HarmonicKey:
	return _reference_key

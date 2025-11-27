extends Node
class_name GuitarChordDatabase

var TAG = "GuitarChordDatabase"

# Structure interne: { "chord_name": [GuitarChord, GuitarChord, ...], ... }
var _chords_by_name: Dictionary = {}
var _all_chords: Array = []  # Liste plate de tous les GuitarChord

# --- Chargement de la base
func load_from_json(json_path: String) -> bool:
	var file = File.new()
	if not file.file_exists(json_path):
		push_error("GuitarChordDatabase: file not found: " + json_path)
		return false
	
	if file.open(json_path, File.READ) != OK:
		push_error("GuitarChordDatabase: cannot open file: " + json_path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var parse_result = JSON.parse(json_text)
	if parse_result.error != OK:
		push_error("GuitarChordDatabase: JSON parse error at line " + str(parse_result.error_line))
		return false
	
	var data = parse_result.result
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GuitarChordDatabase: root is not a dictionary")
		return false
	
	_chords_by_name.clear()
	_all_chords.clear()
	
	# Accéder à la clé "chords" du JSON
	var chords_dict = data.get("chords", {})
	if typeof(chords_dict) != TYPE_DICTIONARY:
		push_error("GuitarChordDatabase: 'chords' key not found or invalid")
		return false
	
	# Parcourir chaque tonalité (C, C#, D, etc.)
	for key_note in chords_dict:
		var chord_list = chords_dict[key_note]
		if typeof(chord_list) != TYPE_ARRAY:
			continue
		
		# Chaque tonalité contient un array d'objets d'accords
		for chord_data in chord_list:
			if typeof(chord_data) != TYPE_DICTIONARY:
				continue
			
			var key = chord_data.get("key", "")
			var suffix = chord_data.get("suffix", "")
			var positions = chord_data.get("positions", [])
			
			# Nom complet de l'accord (ex: "A", "Am", "A7", etc.)
			var chord_name = key + suffix
			
			if not _chords_by_name.has(chord_name):
				_chords_by_name[chord_name] = []
			
			# Créer un GuitarChord pour chaque position
			for pos in positions:
				if typeof(pos) != TYPE_DICTIONARY:
					continue
				var gc = GuitarChord.from_tombatossals_position(chord_name, pos)
				if gc.is_valid():
					_chords_by_name[chord_name].append(gc)
					_all_chords.append(gc)
	
	LogBus.info(TAG,"GuitarChordDatabase: loaded " + str(_all_chords.size()) + " chord positions")
	return true

# --- Recherche par nom
func search_by_name(chord_name: String) -> Array:

	if _chords_by_name.has(chord_name):
		return _chords_by_name[chord_name]
	return []

# --- Recherche par pitch classes
func search_by_pitches(
	pitches: PoolIntArray,
	tonality: PoolIntArray = PoolIntArray(),
	bass_note: int = -1
) -> Array:
	var results = []
	
	# Convertir pitches en pitch classes (0-11)
	var target_pcs = _to_pitch_classes(pitches)
	if target_pcs.empty():
		return results
	
	# Tonalité en pitch classes (si fournie)
	var tonality_pcs = []
	if tonality.size() > 0:
		tonality_pcs = _to_pitch_classes(tonality)
	
	# Basse en pitch class (si fournie)
	var bass_pc = -1
	if bass_note >= 0:
		bass_pc = bass_note % 12
	
	# Filtrer tous les accords
	for chord in _all_chords:
		if _matches_criteria(chord, target_pcs, tonality_pcs, bass_pc):
			results.append(chord)
	
	return results

# --- Utilitaires privés
func _to_pitch_classes(midi_notes: PoolIntArray) -> Array:
	var pcs = []
	for note in midi_notes:
		var pc = int(note) % 12
		if not pc in pcs:
			pcs.append(pc)
	return pcs

func _matches_criteria(
	chord: GuitarChord,
	target_pcs: Array,
	tonality_pcs: Array,
	bass_pc: int
) -> bool:
	# Notes MIDI de l'accord
	var chord_midi = chord.midiNotes()
	if chord_midi.size() == 0:
		return false
	
	# Pitch classes de l'accord
	var chord_pcs = []
	for note in chord_midi:
		var pc = int(note) % 12
		if not pc in chord_pcs:
			chord_pcs.append(pc)
	
	# Vérifier la basse si spécifiée
	if bass_pc >= 0:
		var lowest_note = _get_lowest_note(chord_midi)
		if (lowest_note % 12) != bass_pc:
			return false
	
	# Cas 1: Sans tonalité -> l'accord doit contenir exactement les pitch classes demandées
	if tonality_pcs.empty():
		if chord_pcs.size() != target_pcs.size():
			return false
		for pc in target_pcs:
			if not pc in chord_pcs:
				return false
		return true
	
	# Cas 2: Avec tonalité -> l'accord doit contenir les pitch classes demandées
	# + éventuellement d'autres notes de la tonalité
	for pc in target_pcs:
		if not pc in chord_pcs:
			return false
	
	# Toutes les autres notes de l'accord doivent être dans la tonalité
	for pc in chord_pcs:
		if not pc in target_pcs and not pc in tonality_pcs:
			return false
	
	return true

func _get_lowest_note(midi_notes: PoolIntArray) -> int:
	if midi_notes.size() == 0:
		return -1
	var lowest = int(midi_notes[0])
	for i in range(1, midi_notes.size()):
		var n = int(midi_notes[i])
		if n < lowest:
			lowest = n
	return lowest

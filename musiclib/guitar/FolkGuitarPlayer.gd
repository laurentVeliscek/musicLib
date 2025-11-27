extends Reference
class_name FolkGuitarPlayer

"""
Simulates realistic folk guitar strumming patterns with humanized MIDI output.

The player interprets a chord grid by applying a sequence of 16-step patterns.
It adapts to chords of different sizes (4, 5, or 6 notes).

The duration of the generated output is the maximum of:
- Total duration of all chords in chord_grid
- Total duration of all patterns in pattern_sequence

Both chord_grid and pattern_sequence loop as needed to fill the full duration.

Usage:
	var player = FolkGuitarPlayer.new()

	# Create patterns (each is exactly 16 steps)
	var pattern1 = StrumPattern.create("D.uDudu D.uDudu ", 0.25)
	var pattern2 = StrumPattern.create("D...d...D...d...", 0.25, {"velocity_down_base": 90})
	player.pattern_sequence = [pattern1, pattern2]

	player.set_chord_grid(chords_array) # Array of GuitarChord objects
	var midi_notes = player.generate()  # Returns MIDI note events

Pattern symbols:
	D = Down fort, d = down léger, U = Up fort, u = up léger
	X = Muté fort, x = muté léger
	F = Flam DU (rapide, fort), f = flam du (rapide, léger)
	W = Double mute fort, w = double mute léger
	B = Basse principale, b = basse alternative
	0, 1, 2, 3, 4 = Notes d'arpège (0=grave, 4=aigu)
	' ' = silence, '.' = laisser sonner
"""

# Configuration globale - Paramètres de réalisme
var config = {
	"strum_duration_min": 0.05,  # Durée minimale de balayette (en beats)
	"strum_duration_max": 0.1,  # Durée maximale de balayette (en beats)
	"velocity_curve_shape": "gaussian",  # gaussian, linear, flat
	"velocity_randomization": 0.05,  # Facteur de randomisation (0-1)
	"accent_downbeat_factor": 1.3,  # Multiplication vélocité temps forts
	"mute_duration": 0.02,  # Durée des notes mutées (en beats)
	"humanize_timing": true,  # Micro-décalages temporels
	"timing_variance": 0.005,  # Variance temporelle (en beats)
	"velocity_down_base": 100,  # Vélocité de base pour Down fort
	"velocity_down_light": 50,  # Vélocité de base pour down léger
	"velocity_up_base": 90,  # Vélocité de base pour Up fort
	"velocity_up_light": 40,  # Vélocité de base pour up léger
	"note_overlap": 0.02,  # Léger overlap pour éviter les trous (en beats)
	"pick_position": 0.75,  # Position du médiateur: -1.0 (graves) à 1.0 (aiguës), 0.0 = neutre
	"pick_position_influence": .9,  # Intensité de l'effet (0.0 = aucun, 1.0 = maximum)
	"swing_amount": 0.2,  # Swing: 0.0 = binaire pur, 1.0 = ternaire, entre = intermédiaire
	"chord_transition_gap": 0.95,  # Facteur de raccourcissement des notes avant transition (0.8 = 80%)
	"single_note_velocity": 90,  # Vélocité pour les notes simples (basses, arpèges)
	"max_chords_strings": 6,  # Nombre de cordes max pour accords/mutes (1-6), filtre les graves
}

# Grille d'accords
var chord_grid: Array = []

# Sequence of StrumPattern objects (each pattern is 16 steps)
var pattern_sequence: Array = []

# Notes MIDI en sortie
var output_notes: Array = []

# Notes actuellement actives (pour gérer le '.')
var active_notes: Array = []

# Tracking des dernières notes par pitch (pour éviter les chevauchements)
# Dictionary: pitch -> note Dictionary reference
var _last_note_by_pitch: Dictionary = {}

# Notes d'arpège actives (qui doivent être prolongées jusqu'à interruption)
var _active_arpeggio_notes: Array = []

# Configuration sauvegardée (pour restaurer après config_override)
var _saved_config: Dictionary = {}

# Random number generator
var rng = RandomNumberGenerator.new()


func _init():
	rng.randomize()


# ============================================================================
# API PUBLIQUE
# ============================================================================

func set_chord_grid(chords: Array) -> void:
	"""Définit la grille d'accords à jouer."""
	chord_grid = chords


func set_configuration(params: Dictionary) -> void:
	"""Met à jour la configuration avec des paramètres personnalisés."""
	for key in params:
		if config.has(key):
			config[key] = params[key]


func get_configuration() -> Dictionary:
	"""Retourne la configuration actuelle."""
	return config.duplicate()

#get_strum_pattern_index_at_pos
func get_strum_pattern_index_at_pos(pos_in_beats: float)-> int:
	"""
	Retourne l'index StrumPattern qui joue à une position donnée (en beats).

	Args:
		pos_in_beats: Position en beats

	Returns:
		StrumPattern actif à cette position, ou -1 si :
		- chord_grid est vide
		- pattern_sequence est vide
		- position est hors de la plage de chord_grid

	Note:
		Prend en compte le bouclage de pattern_sequence.
	"""
	if chord_grid.empty():
		return -1

	if pattern_sequence.empty():
		return -1

	# Calculer la durée de chord_grid
	var chords_duration = _calculate_chords_duration()

	# Vérifier que la position est dans la plage
	if pos_in_beats < 0 or pos_in_beats >= chords_duration:
		return -1

	# Calculer la durée totale des patterns
	var patterns_duration = _calculate_patterns_duration()

	# Calculer quelle position dans la séquence de patterns
	var time_in_patterns = fmod(pos_in_beats, patterns_duration) if patterns_duration > 0 else pos_in_beats

	# Trouver le pattern correspondant
	var accumulated_time = 0.0
	var pattern_index = 0
	for pattern in pattern_sequence:
		var pattern_duration = pattern.get_duration()
		if time_in_patterns >= accumulated_time and time_in_patterns < accumulated_time + pattern_duration:
			return pattern_index
		accumulated_time += pattern_duration
		pattern_index += 1

	# Fallback: retourner le dernier pattern
	return pattern_sequence.size() - 1


func get_strum_pattern_at_pos(pos_in_beats: float):
	"""
	Retourne le StrumPattern qui joue à une position donnée (en beats).

	Args:
		pos_in_beats: Position en beats

	Returns:
		StrumPattern actif à cette position, ou null si :
		- chord_grid est vide
		- pattern_sequence est vide
		- position est hors de la plage de chord_grid

	Note:
		Prend en compte le bouclage de pattern_sequence.
	"""
	if chord_grid.empty():
		return null

	if pattern_sequence.empty():
		return null

	# Calculer la durée de chord_grid
	var chords_duration = _calculate_chords_duration()

	# Vérifier que la position est dans la plage
	if pos_in_beats < 0 or pos_in_beats >= chords_duration:
		return null

	# Calculer la durée totale des patterns
	var patterns_duration = _calculate_patterns_duration()

	# Calculer quelle position dans la séquence de patterns
	var time_in_patterns = fmod(pos_in_beats, patterns_duration) if patterns_duration > 0 else pos_in_beats

	# Trouver le pattern correspondant
	var accumulated_time = 0.0
	for pattern in pattern_sequence:
		var pattern_duration = pattern.get_duration()
		if time_in_patterns >= accumulated_time and time_in_patterns < accumulated_time + pattern_duration:
			return pattern
		accumulated_time += pattern_duration

	# Fallback: retourner le dernier pattern
	return pattern_sequence[pattern_sequence.size() - 1]


func generate() -> Array:
	"""
	Génère toutes les notes MIDI à partir de la grille d'accords et de la séquence de patterns.

	La durée totale est le maximum entre:
	- La durée totale des accords (chord_grid)
	- La durée totale des patterns (pattern_sequence)

	Les deux bouclent si nécessaire pour remplir la durée totale.

	Retourne un Array de Dictionary avec: pitch, position, duration, velocity, string_index
	"""
	output_notes.clear()
	active_notes.clear()
	_last_note_by_pitch.clear()
	_active_arpeggio_notes.clear()

	if chord_grid.empty():
		push_warning("FolkGuitarPlayer: Chord grid is empty")
		return output_notes

	if pattern_sequence.empty():
		push_warning("FolkGuitarPlayer: pattern_sequence is empty")
		return output_notes

	# Calculer les durées totales
	var chords_duration = _calculate_chords_duration()
	var patterns_duration = _calculate_patterns_duration()
	var total_duration = max(chords_duration, patterns_duration)

	if total_duration <= 0:
		push_warning("FolkGuitarPlayer: Total duration is 0")
		return output_notes

	# Générer les notes en parcourant le temps
	var current_time = 0.0
	var pattern_seq_index = 0
	var pattern_step_index = 0
	var previous_chord = null

	while current_time < total_duration:
		# Obtenir le pattern courant (boucler si nécessaire)
		var current_pattern = pattern_sequence[pattern_seq_index % pattern_sequence.size()]

		# Appliquer config_override pour ce pattern
		_apply_config_override(current_pattern.config_override)

		# Obtenir l'accord courant à cette position temporelle (avec boucle)
		var current_chord = _get_chord_at_time(current_time, chords_duration)

		# Détecter les changements d'accord et interrompre les arpèges
		if previous_chord != null and current_chord != previous_chord:
			_interrupt_arpeggio_notes(current_time)

		previous_chord = current_chord

		if current_chord == null:
			# Ne devrait pas arriver, mais sécurité
			current_time += current_pattern.step_beat_length
			pattern_step_index += 1
			if pattern_step_index >= 16:
				pattern_step_index = 0
				pattern_seq_index += 1
				_restore_config()
			continue

		# Obtenir le symbole du pattern
		var symbol = current_pattern.pattern[pattern_step_index]
		var step_length = current_pattern.step_beat_length

		# Traiter le symbole
		_process_symbol(symbol, current_chord, current_time, step_length, pattern_step_index)

		# Avancer dans le temps
		current_time += step_length
		pattern_step_index += 1

		# Passer au pattern suivant si on a fini les 16 pas
		if pattern_step_index >= 16:
			pattern_step_index = 0
			pattern_seq_index += 1
			_restore_config()

	# Restaurer la config au cas où
	_restore_config()

	# Tronquer les notes d'arpège restantes à la fin du morceau
	_interrupt_arpeggio_notes(total_duration)

	# Post-traitement: transitions d'accords
	_process_chord_transitions()

	# Trier les notes par position
	output_notes.sort_custom(self, "_sort_notes_by_position")

	return output_notes


func _calculate_chords_duration() -> float:
	"""Calcule la durée totale de tous les accords."""
	if chord_grid.empty():
		return 0.0

	var max_end = 0.0
	for chord in chord_grid:
		var end = chord.time + chord.beat_length
		if end > max_end:
			max_end = end
	return max_end


func _calculate_patterns_duration() -> float:
	"""Calcule la durée totale de tous les patterns."""
	var total = 0.0
	for pattern in pattern_sequence:
		total += pattern.get_duration()
	return total


func _get_chord_at_time(time: float, chords_duration: float) -> GuitarChord:
	"""Retourne l'accord actif à un temps donné, avec boucle sur chord_grid."""
	if chord_grid.empty():
		return null

	# Appliquer la boucle sur le temps
	var looped_time = fmod(time, chords_duration) if chords_duration > 0 else time

	# Trouver l'accord qui contient ce temps
	for chord in chord_grid:
		if looped_time >= chord.time and looped_time < chord.time + chord.beat_length:
			return chord

	# Fallback: retourner le dernier accord
	return chord_grid[chord_grid.size() - 1]


func _apply_config_override(overrides: Dictionary) -> void:
	"""Applique les overrides de configuration et sauvegarde les valeurs originales."""
	if overrides.empty():
		return

	_saved_config.clear()
	for key in overrides:
		if config.has(key):
			_saved_config[key] = config[key]
			config[key] = overrides[key]


func _restore_config() -> void:
	"""Restaure la configuration originale après un pattern."""
	for key in _saved_config:
		config[key] = _saved_config[key]
	_saved_config.clear()


func _process_symbol(symbol: String, chord: GuitarChord, time: float, step_length: float, step_index: int) -> void:
	"""Traite un symbole du pattern et génère les notes appropriées."""
	var beat_position = time

	# Appliquer le swing si nécessaire
	var swung_time = _apply_swing(time, step_index, step_length)

	match symbol:
		'D':  # Down fort
			_interrupt_arpeggio_notes(swung_time)
			_generate_strum(chord, swung_time, "down", config.velocity_down_base, beat_position, false, step_length)
		'd':  # Down léger
			_interrupt_arpeggio_notes(swung_time)
			_generate_strum(chord, swung_time, "down", config.velocity_down_light, beat_position, false, step_length)
		'U':  # Up fort
			_interrupt_arpeggio_notes(swung_time)
			_generate_strum(chord, swung_time, "up", config.velocity_up_base, beat_position, false, step_length)
		'u':  # Up léger
			_interrupt_arpeggio_notes(swung_time)
			_generate_strum(chord, swung_time, "up", config.velocity_up_light, beat_position, false, step_length)
		'X':  # Muté fort
			_interrupt_arpeggio_notes(swung_time)
			_generate_strum(chord, swung_time, "down", config.velocity_down_base, beat_position, true, step_length)
		'x':  # Muté léger (plus court et plus doux)
			_interrupt_arpeggio_notes(swung_time)
			_generate_strum(chord, swung_time, "down", config.velocity_down_light * 0.8, beat_position, true, step_length, true)
		'F':  # Flam DU fort (Down-Up rapide legato)
			_interrupt_arpeggio_notes(swung_time)
			_generate_flam(chord, swung_time, step_length, true)
		'f':  # Flam du léger (down-up rapide legato)
			_interrupt_arpeggio_notes(swung_time)
			_generate_flam(chord, swung_time, step_length, false)
		'W':  # Double mute fort
			_interrupt_arpeggio_notes(swung_time)
			_generate_double_mute(chord, swung_time, step_length, true)
		'w':  # Double mute léger
			_interrupt_arpeggio_notes(swung_time)
			_generate_double_mute(chord, swung_time, step_length, false)
		'B':  # Basse principale
			_generate_bass_note(chord, swung_time, step_length, 0, beat_position)
		'b':  # Basse alternative
			_generate_bass_note(chord, swung_time, step_length, 1, beat_position)
		'0', '1', '2', '3', '4':  # Notes d'arpège
			var arp_idx = int(symbol)
			_generate_arpeggio_note(chord, swung_time, step_length, arp_idx, beat_position)
		'.':  # Laisser sonner
			_prolong_active_notes(step_length)
		' ':  # Silence
			_interrupt_arpeggio_notes(swung_time)
		_:
			push_warning("FolkGuitarPlayer: Unknown pattern symbol '%s' at time %s" % [symbol, time])


func clear() -> void:
	"""Réinitialise le player."""
	chord_grid.clear()
	pattern_sequence.clear()
	output_notes.clear()
	active_notes.clear()
	_last_note_by_pitch.clear()
	_active_arpeggio_notes.clear()
	_saved_config.clear()


# ============================================================================
# GÉNÉRATION DE STRUM
# ============================================================================

func _generate_strum(chord: GuitarChord, time: float, direction: String, base_velocity: float, beat_pos: float, is_muted: bool, step_length: float, is_light_mute: bool = false) -> void:
	"""
	Génère un strum complet (balayette) avec toutes les cordes.

	Args:
		chord: L'accord à jouer
		time: Position temporelle du strum
		direction: "down" ou "up"
		base_velocity: Vélocité de base
		beat_pos: Position en beats (pour déterminer les accents)
		is_muted: Si true, génère des notes très courtes
		step_length: Durée du pas (en beats)
		is_light_mute: Si true, muté encore plus court (pour 'x')
	"""

	var chord_notes = chord.get_notes()
	var num_chord_notes = chord_notes.size()

	# Appliquer le filtre max_chords_strings (garder les notes les plus aiguës)
	var max_strings = int(clamp(config.max_chords_strings, 1, 6))
	var start_index = 0
	if num_chord_notes > max_strings:
		# Filtrer les notes les plus graves, garder les plus aiguës
		start_index = num_chord_notes - max_strings

	# Calculer la durée du strum
	var strum_duration = _calculate_strum_duration()

	# Déterminer l'ordre des cordes (adaptation automatique à 4, 5, ou 6 notes)
	var string_order = []
	if direction == "down":
		# Graves vers aiguës (start_index -> n)
		for i in range(start_index, num_chord_notes):
			if not chord.is_string_muted(i):
				string_order.append(i)
	else:  # "up"
		# Aiguës vers graves (n -> start_index)
		for i in range(num_chord_notes - 1, start_index - 1, -1):
			if not chord.is_string_muted(i):
				string_order.append(i)

	if string_order.empty():
		return

	# Calculer le délai entre chaque corde
	var num_strings = string_order.size()
	var delay_per_string = strum_duration / max(1, num_strings - 1)

	# Déterminer si on est sur un temps fort (accent)
	var accent_factor = 1.0
	if direction == "down":
		# Temps forts = multiples de 1.0 beat (simplification)
		var beat_mod = fmod(beat_pos, 1.0)
		if beat_mod < 0.01:  # Tolérance pour erreurs de floating point
			accent_factor = config.accent_downbeat_factor

	# Générer chaque note du strum
	active_notes.clear()  # Réinitialiser les notes actives

	# Nombre total de cordes de la guitare (pour le calcul de position du médiateur)
	var total_guitar_strings = chord.notes.size()

	for i in range(string_order.size()):
		var string_index = string_order[i]
		var pitch = chord_notes[string_index]

		# Calculer le timing de cette corde
		var note_time = time + (i * delay_per_string)

		# Appliquer humanisation temporelle si activée
		if config.humanize_timing:
			var timing_offset = rng.randf_range(-config.timing_variance, config.timing_variance)
			note_time += timing_offset

		# Calculer la vélocité pour cette corde
		var velocity = _calculate_velocity(i, num_strings, base_velocity, accent_factor, string_index, total_guitar_strings, direction)

		# Calculer la durée de la note
		var duration = step_length + config.note_overlap
		if is_muted:
			if is_light_mute:
				duration = config.mute_duration * 0.5  # Encore plus court pour 'x'
			else:
				duration = config.mute_duration

		# Gérer le chevauchement des notes de même pitch
		_handle_pitch_overlap(pitch, note_time)

		# Créer la note
		var note = {
			"pitch": pitch,
			"position": note_time,
			"duration": duration,
			"velocity": int(clamp(velocity, 1, 127)),
			"string_index": string_index
		}

		output_notes.append(note)

		# Tracker cette note pour les futurs chevauchements
		_last_note_by_pitch[pitch] = note

		# Sauvegarder pour gérer le '.'
		if not is_muted:
			active_notes.append(note)


func _generate_flam(chord: GuitarChord, time: float, step_length: float, is_strong: bool) -> void:
	"""
	Génère un flam (Down-Up rapide) dans un seul step.

	Le flam est composé de deux strums:
	- Down au début du step
	- Up à la moitié du step
	Les deux sont legato (pas de silence entre eux).

	Args:
		chord: L'accord à jouer
		time: Position temporelle du flam
		step_length: Durée totale du step
		is_strong: Si true, utilise les vélocités fortes (F), sinon légères (f)
	"""
	var half_step = step_length / 2.0

	if is_strong:
		# F = DU fort
		_generate_strum(chord, time, "down", config.velocity_down_base, time, false, half_step)
		_generate_strum(chord, time + half_step, "up", config.velocity_up_base, time + half_step, false, half_step)
	else:
		# f = du léger
		_generate_strum(chord, time, "down", config.velocity_down_light, time, false, half_step)
		_generate_strum(chord, time + half_step, "up", config.velocity_up_light, time + half_step, false, half_step)


func _handle_pitch_overlap(pitch: int, new_note_time: float) -> void:
	"""
	Gère le chevauchement des notes de même pitch.
	Tronque la note précédente si elle chevaucherait la nouvelle.
	"""
	if not _last_note_by_pitch.has(pitch):
		return

	var prev_note = _last_note_by_pitch[pitch]
	var prev_end = prev_note.position + prev_note.duration

	# Si la note précédente chevauche la nouvelle, la tronquer
	if prev_end > new_note_time:
		# Laisser un petit gap pour éviter les artefacts MIDI
		var gap = 0.001  # 1ms
		var new_duration = new_note_time - prev_note.position - gap
		if new_duration > 0:
			prev_note.duration = new_duration
		else:
			# La note est trop courte, la supprimer ou la garder minimale
			prev_note.duration = 0.001


func _generate_double_mute(chord: GuitarChord, time: float, step_length: float, is_strong: bool) -> void:
	"""
	Génère un double mute (deux mutes rapides: down puis up) dans un seul step.

	Args:
		chord: L'accord à jouer
		time: Position temporelle
		step_length: Durée totale du step
		is_strong: Si true, utilise velocity_down_base, sinon velocity_down_light
	"""
	var half_step = step_length / 2.0

	if is_strong:
		# W = double mute fort
		_generate_strum(chord, time, "down", config.velocity_down_base, time, true, half_step)
		_generate_strum(chord, time + half_step, "up", config.velocity_down_base, time + half_step, true, half_step)
	else:
		# w = double mute léger
		_generate_strum(chord, time, "down", config.velocity_down_light, time, true, half_step)
		_generate_strum(chord, time + half_step, "up", config.velocity_down_light, time + half_step, true, half_step)


func _generate_bass_note(chord: GuitarChord, time: float, step_length: float, bass_index: int, beat_position: float = 0.0) -> void:
	"""
	Génère une note de basse unique.

	Args:
		chord: L'accord courant
		time: Position temporelle
		step_length: Durée du step
		bass_index: 0 pour basse principale (B), 1 pour basse alternative (b)
		beat_position: Position en beats (pour déterminer les accents)
	"""
	var bass_notes = chord.get_bass_notes()
	var pitch = bass_notes[bass_index]

	# Gérer le chevauchement
	_handle_pitch_overlap(pitch, time)

	# Déterminer si on est sur un temps fort (accent)
	var accent_factor = 1.0
	var beat_mod = fmod(beat_position, 1.0)
	if beat_mod < 0.01:  # Tolérance pour erreurs de floating point
		accent_factor = config.accent_downbeat_factor

	# Calculer la vélocité avec accent
	var velocity = config.single_note_velocity * accent_factor

	# Créer la note de basse
	var note = {
		"pitch": pitch,
		"position": time,
		"duration": step_length + config.note_overlap,
		"velocity": int(clamp(velocity, 1, 127)),
		"string_index": -1  # Pas de string_index pour les basses isolées
	}

	output_notes.append(note)
	_last_note_by_pitch[pitch] = note
	active_notes.clear()
	active_notes.append(note)


func _interrupt_arpeggio_notes(time: float) -> void:
	"""
	Interrompt (tronque) toutes les notes d'arpège actives au temps spécifié.

	Cette fonction est appelée quand :
	- Un accord est strummé (D, d, U, u, X, x, F, f, W, w)
	- Un silence est rencontré (espace)
	- Un changement d'accord se produit

	Args:
		time: Le temps auquel interrompre les notes d'arpège
	"""
	for note in _active_arpeggio_notes:
		if note.position < time:
			# Tronquer la note à ce moment (avec un petit gap)
			var gap = 0.001
			note.duration = time - note.position - gap
			if note.duration < 0.001:
				note.duration = 0.001

	# Vider la liste des notes d'arpège actives
	_active_arpeggio_notes.clear()


func _generate_arpeggio_note(chord: GuitarChord, time: float, step_length: float, arp_index: int, beat_position: float = 0.0) -> void:
	"""
	Génère une note d'arpège unique avec sustain prolongé.

	Les notes d'arpège se prolongent jusqu'à ce qu'elles soient interrompues par :
	- La même note jouée à nouveau
	- Un changement d'accord
	- Un accord strummé (D, d, U, u, X, x, F, f, W, w)
	- Un silence (espace)

	Args:
		chord: L'accord courant
		time: Position temporelle
		step_length: Durée du step
		arp_index: Index de la note d'arpège (0-4, de grave vers aigu)
		beat_position: Position en beats (pour déterminer les accents)
	"""
	var pitch = chord.get_arp_note(arp_index)

	# Gérer le chevauchement
	_handle_pitch_overlap(pitch, time)

	# Déterminer si on est sur un temps fort (accent)
	var accent_factor = 1.0
	var beat_mod = fmod(beat_position, 1.0)
	if beat_mod < 0.01:  # Tolérance pour erreurs de floating point
		accent_factor = config.accent_downbeat_factor

	# Calculer la vélocité avec accent
	var velocity = config.single_note_velocity * accent_factor

	# Créer la note d'arpège avec une durée longue par défaut (1000 beats)
	# Elle sera tronquée plus tard par _interrupt_arpeggio_notes()
	var note = {
		"pitch": pitch,
		"position": time,
		"duration": 1000.0,  # Durée très longue, sera tronquée par interruption
		"velocity": int(clamp(velocity, 1, 127)),
		"string_index": -1  # Pas de string_index pour les arpèges
	}

	output_notes.append(note)
	_last_note_by_pitch[pitch] = note
	_active_arpeggio_notes.append(note)  # Ajouter aux notes d'arpège actives
	active_notes.clear()
	active_notes.append(note)


func _apply_swing(time: float, step_index: int, step_length: float) -> float:
	"""
	Applique le swing aux beats syncopés (positions impaires dans un pattern 16 steps).

	Le swing retarde les beats en positions impaires (1, 3, 5, 7, 9, 11, 13, 15):
	- swing_amount = 0.0: aucun swing (binaire pur)
	- swing_amount = 1.0: swing ternaire complet (ratio 2:1)
	- swing_amount entre 0 et 1: swing intermédiaire

	Args:
		time: Position temporelle originale
		step_index: Index du step dans le pattern (0-15)
		step_length: Durée du step

	Returns:
		Position temporelle avec swing appliqué
	"""
	if config.swing_amount <= 0.0:
		return time

	# Appliquer le swing seulement sur les positions impaires (syncopées)
	if step_index % 2 == 1:
		# En swing ternaire (2:1), le beat syncopé est retardé de step_length/3
		# swing_amount contrôle l'intensité du retard
		var swing_offset = (step_length / 3.0) * config.swing_amount
		return time + swing_offset

	return time


func _process_chord_transitions() -> void:
	"""
	Post-traitement des transitions d'accords.

	Raccourcit les notes non communes entre deux accords consécutifs pour simuler
	le changement de position du guitariste. Les notes communes peuvent rester legato.
	"""
	if chord_grid.size() < 2:
		return  # Pas de transitions avec un seul accord ou moins

	# Trier les accords par temps
	var sorted_chords = chord_grid.duplicate()
	sorted_chords.sort_custom(self, "_sort_by_time")

	# Pour chaque transition
	for i in range(sorted_chords.size() - 1):
		var chord_before = sorted_chords[i]
		var chord_after = sorted_chords[i + 1]

		var transition_time = chord_after.time

		# Obtenir les notes des deux accords
		var notes_before = chord_before.get_notes()
		var notes_after = chord_after.get_notes()

		# Identifier les notes communes (même pitch)
		var common_pitches = []
		for pitch in notes_before:
			if pitch in notes_after:
				common_pitches.append(pitch)

		# Raccourcir les notes non communes qui traversent la transition
		for note in output_notes:
			# Vérifier si la note appartient à l'accord précédent
			if note.position >= chord_before.time and note.position < transition_time:
				var note_end = note.position + note.duration

				# Si la note traverse la transition et n'est pas commune
				if note_end > transition_time and not (note.pitch in common_pitches):
					# Raccourcir la note
					var max_duration = (transition_time - note.position) * config.chord_transition_gap
					note.duration = max_duration


# ============================================================================
# CALCULS DE RÉALISME
# ============================================================================

func _calculate_strum_duration() -> float:
	"""Calcule une durée de strum aléatoire."""
	var min_dur = config.strum_duration_min
	var max_dur = config.strum_duration_max
	return rng.randf_range(min_dur, max_dur)


func _calculate_velocity(string_pos: int, total_strings: int, base_velocity: float, accent_factor: float, string_index: int, total_guitar_strings: int, direction: String) -> float:
	"""
	Calcule la vélocité d'une corde selon sa position dans le strum.

	Args:
		string_pos: Position de la corde dans le strum (0 = première jouée)
		total_strings: Nombre total de cordes jouées
		base_velocity: Vélocité de base
		accent_factor: Facteur d'accent (temps forts)
		string_index: Index de la corde sur la guitare (0 = grave, n = aigu)
		total_guitar_strings: Nombre total de cordes de la guitare
		direction: Direction du strum ("down" ou "up")
	"""

	var velocity = base_velocity

	# Appliquer la courbe de vélocité selon la position
	if config.velocity_curve_shape == "gaussian":
		velocity *= _gaussian_curve(string_pos, total_strings)
	elif config.velocity_curve_shape == "linear":
		velocity *= _linear_curve(string_pos, total_strings)
	# "flat" = pas de modification

	# Appliquer l'accent
	velocity *= accent_factor

	# Appliquer le facteur de position du médiateur
	var pick_factor = _calculate_pick_position_factor(string_index, total_guitar_strings, direction)
	velocity *= pick_factor

	# Appliquer la randomisation
	if config.velocity_randomization > 0:
		var random_factor = 1.0 + rng.randf_range(-config.velocity_randomization, config.velocity_randomization)
		velocity *= random_factor

	return velocity


func _gaussian_curve(pos: int, total: int) -> float:
	"""
	Courbe gaussienne centrée sur le milieu du strum.
	Les cordes au milieu sont plus fortes.
	"""
	if total <= 1:
		return 1.0

	# Normaliser la position entre 0 et 1
	var normalized_pos = float(pos) / float(total - 1)

	# Gaussienne centrée sur 0.5
	var center = 0.5
	var sigma = 0.3  # Largeur de la courbe
	var gaussian = exp(-pow(normalized_pos - center, 2) / (2 * sigma * sigma))

	# Mapper entre 0.75 et 1.15 pour éviter de trop diminuer les extrémités
	return 0.75 + (gaussian * 0.4)


func _linear_curve(pos: int, total: int) -> float:
	"""
	Courbe linéaire: augmente jusqu'au milieu puis redescend.
	"""
	if total <= 1:
		return 1.0

	var normalized_pos = float(pos) / float(total - 1)

	# Triangle: monte jusqu'à 0.5, puis descend
	if normalized_pos < 0.5:
		return 0.8 + (normalized_pos * 0.8)  # 0.8 -> 1.2
	else:
		return 1.6 - (normalized_pos * 0.8)  # 1.2 -> 0.8


func _calculate_pick_position_factor(string_index: int, total_guitar_strings: int, direction: String) -> float:
	"""
	Calcule un facteur de vélocité basé sur la position du médiateur.

	Le guitariste place son médiateur plus près des cordes graves ou aiguës,
	ce qui influence le volume relatif des différentes cordes.

	Args:
		string_index: Index de la corde (0 = grave, n = aigu)
		total_guitar_strings: Nombre total de cordes de la guitare
		direction: Direction du strum ("down" ou "up")

	Returns:
		Facteur multiplicateur de vélocité (0.4 à 1.3)
	"""

	# Si l'influence est désactivée, retourner 1.0 (aucun effet)
	if config.pick_position_influence <= 0.0:
		return 1.0

	# Normaliser la position de la corde (0.0 = grave, 1.0 = aigu)
	var normalized_string_pos = 0.5  # Valeur par défaut
	if total_guitar_strings > 1:
		normalized_string_pos = float(string_index) / float(total_guitar_strings - 1)

	# La direction influence légèrement la position effective du médiateur
	# Down : favorise légèrement les graves (le médiateur "pousse" vers les aiguës)
	# Up : favorise légèrement les aiguës (le médiateur "tire" vers les graves)
	var direction_bias = 0.0
	if direction == "down":
		direction_bias = -0.12  # Décalage vers les graves
	else:  # "up"
		direction_bias = 0.12   # Décalage vers les aiguës

	# Position effective du médiateur (combinaison de pick_position et direction)
	var effective_pick_pos = clamp(config.pick_position + direction_bias, -1.0, 1.0)

	# Convertir effective_pick_pos de [-1.0, 1.0] vers [0.0, 1.0]
	# -1.0 (graves) → 0.0
	#  0.0 (neutre) → 0.5
	#  1.0 (aiguës) → 1.0
	var pick_pos_normalized = (effective_pick_pos + 1.0) / 2.0

	# Calculer la distance entre le médiateur et la corde
	var distance = abs(pick_pos_normalized - normalized_string_pos)

	# Appliquer une courbe pour convertir la distance en facteur de volume
	# Distance 0.0 (corde = position médiateur) → facteur maximum (1.3)
	# Distance 1.0 (corde opposée au médiateur) → facteur minimum (0.4)
	# Utiliser une courbe exponentielle douce pour un effet naturel
	var base_factor = 1.0 - (distance * 0.6)  # Range: 1.0 à 0.4
	base_factor = pow(base_factor, 0.7)  # Adoucir la courbe

	# Mapper le facteur entre 0.4 et 1.3
	var factor = 0.4 + (base_factor * 0.9)

	# Appliquer l'intensité de l'effet
	# Si influence = 0.0 → facteur = 1.0 (neutre)
	# Si influence = 1.0 → facteur = factor calculé
	var final_factor = 1.0 + ((factor - 1.0) * config.pick_position_influence)

	return final_factor


func _prolong_active_notes(duration: float) -> void:
	"""Prolonge les notes actives de la durée spécifiée (symbole '.')."""
	for note in active_notes:
		note.duration += duration


# ============================================================================
# UTILITAIRES
# ============================================================================

func _sort_by_time(a: GuitarChord, b: GuitarChord) -> bool:
	"""Trie les accords par time croissante."""
	return a.time < b.time


func _sort_notes_by_position(a: Dictionary, b: Dictionary) -> bool:
	"""Trie les notes par position croissante."""
	return a.position < b.position


func print_notes(notes: Array = []) -> void:
	"""Affiche les notes pour debug."""
	var notes_to_print = notes if not notes.empty() else output_notes

	print("\n=== MIDI Notes Output (%d notes) ===" % notes_to_print.size())
	for note in notes_to_print:
		print("  Pitch: %3d | Pos: %6.3f | Dur: %5.3f | Vel: %3d | String: %d" % [
			note.pitch,
			note.position,
			note.duration,
			note.velocity,
			note.string_index
		])
	print("========================================")


func get_stats() -> Dictionary:
	"""Retourne des statistiques sur les notes générées."""
	if output_notes.empty():
		return {}

	var velocities = []
	var durations = []

	for note in output_notes:
		velocities.append(note.velocity)
		durations.append(note.duration)

	# Calculer min, max, moyenne
	var vel_min = velocities.min()
	var vel_max = velocities.max()
	var vel_avg = 0.0
	for v in velocities:
		vel_avg += v
	vel_avg /= velocities.size()

	var dur_min = durations.min()
	var dur_max = durations.max()
	var dur_avg = 0.0
	for d in durations:
		dur_avg += d
	dur_avg /= durations.size()

	return {
		"total_notes": output_notes.size(),
		"velocity_min": vel_min,
		"velocity_max": vel_max,
		"velocity_avg": vel_avg,
		"duration_min": dur_min,
		"duration_max": dur_max,
		"duration_avg": dur_avg
	}


func generate_ascii_tab(chars_per_beat: int = 4, line_width: int = 80, show_time_markers: bool = true) -> String:
	"""
	Génère une tablature ASCII quantizée à partir de la grille d'accords et du pattern.

	Format: ASCII tab standard avec 6 cordes (E A D G B e du grave vers aigu)
	La tablature est quantizée (comme une partition) : pas de swing, strum aligné.

	Args:
		chars_per_beat: Nombre de caractères par beat (résolution horizontale, défaut: 4)
		line_width: Largeur maximale d'une ligne avant de couper (défaut: 80)
		show_time_markers: Afficher les marqueurs de temps au-dessus (défaut: true)

	Returns:
		String contenant la tablature ASCII complète

	Example:
		var player = FolkGuitarPlayer.new()
		# ... configuration et generate() ...
		var tab = player.generate_ascii_tab(4, 80, true)
		print(tab)
	"""
	if chord_grid.empty():
		return "# No chords in chord_grid.\n"

	if pattern_sequence.empty():
		return "# No patterns in pattern_sequence.\n"

	var string_names = ["E", "A", "D", "G", "B", "e"]  # Notation standard (grave vers aigu)

	# Calculer les durées
	var chords_duration = _calculate_chords_duration()
	var patterns_duration = _calculate_patterns_duration()
	var total_duration = max(chords_duration, patterns_duration)
	var total_chars = int(ceil(total_duration * chars_per_beat))

	# Créer une grille pour chaque corde (6 cordes × total_chars colonnes)
	# Chaque cellule contient soit "-" soit un caractère de frette ("0", "1", ..., "x")
	var grid = []
	for i in range(6):
		var line = []
		for j in range(total_chars):
			line.append("-")
		grid.append(line)

	# Parcourir le temps quantizé selon les patterns
	var current_time = 0.0
	var pattern_seq_index = 0
	var pattern_step_index = 0

	while current_time < total_duration:
		# Obtenir le pattern et l'accord courants
		var current_pattern = pattern_sequence[pattern_seq_index % pattern_sequence.size()]
		var current_chord = _get_chord_at_time(current_time, chords_duration)

		if current_chord == null:
			# Avancer au prochain step
			current_time += current_pattern.step_beat_length
			pattern_step_index += 1
			if pattern_step_index >= 16:
				pattern_step_index = 0
				pattern_seq_index += 1
			continue

		# Obtenir le symbole du pattern
		var symbol = current_pattern.pattern[pattern_step_index]

		# Position quantizée dans la grille (en caractères)
		var char_pos = int(current_time * chars_per_beat)

		if char_pos >= total_chars:
			break

		# Traiter le symbole et placer dans la grille
		_place_symbol_in_tab_grid(grid, symbol, current_chord, char_pos, total_chars)

		# Avancer dans le temps
		current_time += current_pattern.step_beat_length
		pattern_step_index += 1

		# Passer au pattern suivant si on a fini les 16 pas
		if pattern_step_index >= 16:
			pattern_step_index = 0
			pattern_seq_index += 1

	# Formater la sortie en plusieurs lignes si nécessaire
	var result = ""
	var num_lines = int(ceil(float(total_chars) / line_width))

	for line_idx in range(num_lines):
		var start_char = line_idx * line_width
		var end_char = min((line_idx + 1) * line_width, total_chars)
		var line_length = end_char - start_char

		# Marqueurs de temps si demandé
		if show_time_markers:
			var time_marker = "  "
			var i = 0
			while i < line_length:
				var abs_pos = start_char + i
				if abs_pos % chars_per_beat == 0:
					var beat = int(abs_pos / chars_per_beat)
					var beat_str = str(beat)
					time_marker += beat_str
					i += beat_str.length()
				else:
					time_marker += " "
					i += 1

			result += time_marker.rstrip(" ") + "\n"

		# Les 6 cordes (de l'aigu vers le grave en affichage)
		for string_idx in range(5, -1, -1):
			var line_str = string_names[string_idx] + "|"

			for i in range(start_char, end_char):
				line_str += grid[string_idx][i]

			line_str += "|"
			result += line_str + "\n"

		# Ligne vide entre les sections
		if line_idx < num_lines - 1:
			result += "\n"

	return result


func _place_symbol_in_tab_grid(grid: Array, symbol: String, chord: GuitarChord, char_pos: int, total_chars: int) -> void:
	"""
	Place un symbole dans la grille de tablature.

	Args:
		grid: Grille 6×total_chars
		symbol: Symbole du pattern ('D', 'B', '0', etc.)
		chord: Accord courant
		char_pos: Position en caractères dans la grille
		total_chars: Nombre total de caractères
	"""
	match symbol:
		'D', 'd', 'U', 'u', 'X', 'x', 'F', 'f', 'W', 'w':
			# Strum ou mute : afficher l'accord complet (toutes les cordes alignées)
			var tab_array = chord.get_tab_absolute_as_array()

			# tab_array va de la 6ème corde (grave) à la 1ère (aigu)
			# grid[0] = corde E grave (6ème corde)
			# grid[5] = corde e aigu (1ère corde)
			for string_idx in range(6):
				if string_idx < tab_array.size():
					var fret_str = tab_array[string_idx]
					_place_string_in_grid(grid, string_idx, char_pos, fret_str, total_chars)

		'B':  # Basse principale
			var bass_notes = chord.get_bass_notes_with_string()
			if bass_notes.size() > 0:
				var bass_note = bass_notes[0]  # {midi: int, string: int}
				var string_idx = bass_note.string
				var fret = _calculate_fret_from_midi(bass_note.midi, string_idx)
				_place_string_in_grid(grid, string_idx, char_pos, str(fret), total_chars)

		'b':  # Basse alternative
			var bass_notes = chord.get_bass_notes_with_string()
			if bass_notes.size() > 1:
				var bass_note = bass_notes[1]  # {midi: int, string: int}
				var string_idx = bass_note.string
				var fret = _calculate_fret_from_midi(bass_note.midi, string_idx)
				_place_string_in_grid(grid, string_idx, char_pos, str(fret), total_chars)

		'0', '1', '2', '3', '4':  # Notes d'arpège
			var arp_idx = int(symbol)
			var arp_note = chord.get_arp_note_with_string(arp_idx)  # {midi: int, string: int}
			var string_idx = arp_note.string
			var fret = _calculate_fret_from_midi(arp_note.midi, string_idx)
			_place_string_in_grid(grid, string_idx, char_pos, str(fret), total_chars)

		'.', ' ':
			# Laisser sonner ou silence : ne rien placer
			pass


func _place_string_in_grid(grid: Array, string_idx: int, char_pos: int, fret_str: String, total_chars: int) -> void:
	"""
	Place une chaîne de caractères (numéro de frette ou "x") dans la grille.

	Args:
		grid: Grille de tablature
		string_idx: Index de la corde (0=E grave, 5=e aigu)
		char_pos: Position de départ en caractères
		fret_str: Chaîne à placer ("0", "12", "x", etc.)
		total_chars: Nombre total de caractères dans la grille
	"""
	if string_idx < 0 or string_idx >= 6:
		return

	# Placer chaque caractère de la chaîne
	for i in range(fret_str.length()):
		var pos = char_pos + i
		if pos < total_chars:
			grid[string_idx][pos] = fret_str[i]


func _calculate_fret_from_midi(midi_pitch: int, string_idx: int) -> int:
	"""
	Calcule le numéro de frette à partir du pitch MIDI et de l'index de corde.

	Args:
		midi_pitch: Pitch MIDI
		string_idx: Index de la corde (0=E grave, 5=e aigu)

	Returns:
		Numéro de frette (0-22)
	"""
	var string_tuning = [40, 45, 50, 55, 59, 64]  # E2, A2, D3, G3, B3, E4

	if string_idx < 0 or string_idx >= 6:
		return 0

	var fret = midi_pitch - string_tuning[string_idx]
	return int(clamp(fret, 0, 22))

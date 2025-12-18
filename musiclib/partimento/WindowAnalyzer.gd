extends Reference
class_name WindowAnalyzer

const TAG = "WindowAnalyzer"

# ==============================================================================
# WINDOW ANALYZER
# Découpe une partition (notes MIDI) en fenêtres harmoniques et les analyse
# ==============================================================================

var key: HarmonicKey = null
var window_size: float = 4.0  # Taille de fenêtre en beats (défaut: ronde)

# Options
var seventh_allowed: bool = true
var ninth_allowed: bool = false

# Régions tonales (pour modulations)
# Array de {start_beat: float, key: HarmonicKey}
var key_regions: Array = []

# Fenêtres générées
var windows: Array = []  # Array de HarmonicWindow

# ==============================================================================
# API PRINCIPALE
# ==============================================================================

func analyze_partition(notes: Array, harmonic_key: HarmonicKey, p_window_size: float = 4.0, options: Dictionary = {}) -> Array:
	"""
	Analyse une partition et la découpe en fenêtres harmoniques.

	Arguments:
		notes: Array de {midi: int, start: float, duration: float}
		harmonic_key: Tonalité principale
		p_window_size: Taille de fenêtre en beats
		options: {
			seventh_allowed: bool,
			ninth_allowed: bool,
			key_regions: Array de {start_beat, key}  # Pour modulations
		}

	Retourne: Array de HarmonicWindow analysées
	"""
	key = harmonic_key
	window_size = p_window_size
	_apply_options(options)

	if notes.empty():
		return []

	# Déterminer l'étendue temporelle
	var start_beat = _get_earliest_beat(notes)
	var end_beat = _get_latest_beat(notes)

	# Quantifier le début sur la grille
	start_beat = floor(start_beat / window_size) * window_size

	# Créer les fenêtres
	windows = _create_windows(start_beat, end_beat)

	# Distribuer les notes dans les fenêtres
	_distribute_notes(notes)

	# Analyser chaque fenêtre
	for w in windows:
		w.analyze()

	return windows

func _apply_options(options: Dictionary):
	seventh_allowed = options.get("seventh_allowed", true)
	ninth_allowed = options.get("ninth_allowed", false)
	key_regions = options.get("key_regions", [])

func _get_earliest_beat(notes: Array) -> float:
	var earliest = INF
	for note in notes:
		if note.start < earliest:
			earliest = note.start
	return earliest if earliest != INF else 0.0

func _get_latest_beat(notes: Array) -> float:
	var latest = 0.0
	for note in notes:
		var note_end = note.start + note.get("duration", 1.0)
		if note_end > latest:
			latest = note_end
	return latest

# ==============================================================================
# CRÉATION DES FENÊTRES
# ==============================================================================

func _create_windows(start_beat: float, end_beat: float) -> Array:
	var result = []
	var current_beat = start_beat
	var index = 0

	while current_beat < end_beat:
		# Déterminer la tonalité pour cette fenêtre
		var window_key = _get_key_at_beat(current_beat)

		var w = HarmonicWindow.new(current_beat, window_size, window_key)
		w.window_index = index
		w.set_options(seventh_allowed, ninth_allowed)

		result.append(w)
		current_beat += window_size
		index += 1

	return result

func _get_key_at_beat(beat: float) -> HarmonicKey:
	"""
	Retourne la tonalité active à un moment donné.
	Utilise key_regions si définies, sinon la tonalité principale.
	"""
	if key_regions.empty():
		return key

	# Trouver la région active (la dernière dont start_beat <= beat)
	var active_key = key
	for region in key_regions:
		if region.start_beat <= beat:
			active_key = region.key
		else:
			break  # Les régions sont supposées triées

	return active_key

# ==============================================================================
# DISTRIBUTION DES NOTES
# ==============================================================================

func _distribute_notes(notes: Array):
	"""
	Distribue chaque note dans la/les fenêtre(s) correspondante(s).
	Une note peut appartenir à plusieurs fenêtres si elle les chevauche.
	"""
	for note in notes:
		var note_start = note.start
		var note_duration = note.get("duration", 1.0)
		var note_end = note_start + note_duration
		var note_midi = note.midi

		# Trouver toutes les fenêtres que cette note touche
		for w in windows:
			# La note touche cette fenêtre si:
			# note_start < window_end ET note_end > window_start
			if note_start < w.end_beat and note_end > w.start_beat:
				w.add_note(note_midi, note_start, note_duration)

# ==============================================================================
# ANALYSE DU CONTOUR MÉLODIQUE GLOBAL
# ==============================================================================

func get_global_contour() -> Array:
	"""
	Retourne le contour mélodique global (degrés principaux par fenêtre).
	Utile pour la détection de schémas sur plusieurs fenêtres.
	"""
	var contour = []
	for w in windows:
		if w.has_notes and not w.melodic_contour.empty():
			# Prendre le premier degré de chaque fenêtre (note sur downbeat ou première note)
			contour.append(w.melodic_contour[0])
		else:
			contour.append(null)  # Fenêtre vide
	return contour

func get_downbeat_contour() -> Array:
	"""
	Retourne uniquement les degrés des notes sur les temps forts.
	"""
	var contour = []
	for w in windows:
		if not w.downbeat_notes.empty() and not w.note_scale_degrees.empty():
			# Trouver le degré de la première note downbeat
			for info in w.note_scale_degrees:
				if info.is_downbeat:
					contour.append(info.degree)
					break
		else:
			contour.append(null)
	return contour

# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_window_at_beat(beat: float) -> HarmonicWindow:
	"""
	Retourne la fenêtre qui contient un beat donné.
	"""
	for w in windows:
		if beat >= w.start_beat and beat < w.end_beat:
			return w
	return null

func get_window_count() -> int:
	return windows.size()

func get_summary() -> String:
	var summary = "WindowAnalyzer: %d fenêtres (taille=%.1f beats)\n" % [windows.size(), window_size]
	for w in windows:
		summary += "  " + w.get_summary() + "\n"
	return summary

func to_dict() -> Dictionary:
	var windows_data = []
	for w in windows:
		windows_data.append(w.to_dict())

	return {
		"window_size": window_size,
		"window_count": windows.size(),
		"seventh_allowed": seventh_allowed,
		"ninth_allowed": ninth_allowed,
		"windows": windows_data,
		"global_contour": get_global_contour(),
		"downbeat_contour": get_downbeat_contour()
	}

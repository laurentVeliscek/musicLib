extends Reference
class_name GuitarPatternGenerator

"""
Générateur de patterns de guitare folk non-déterministes.

Génère des patterns de 16 caractères compatibles avec FolkGuitarPlayer
dans différents styles musicaux : Funky, Folk, Bossa, R'n B.

Usage:
	var generator = GuitarPatternGenerator.new()
	var result = generator.generate("Folk")
	print("Pattern: %s, Step: %.3f" % [result.pattern, result.step_beat_length])
"""

var rng = RandomNumberGenerator.new()


func _init(seed_value: int = -1):
	"""
	Initialise le générateur.

	Args:
		seed_value: Graine pour le RNG (-1 = aléatoire)
	"""
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func generate(style: String) -> Dictionary:
	"""
	Génère un pattern de 16 caractères dans le style demandé.

	Args:
		style: Style de pattern ("Funky", "Folk", "Bossa", "R'n B")

	Returns:
		Dictionary avec {pattern: String, step_beat_length: float}
	"""
	match style.to_lower():
		"funky":
			return _generate_funky()
		"folk":
			return _generate_folk()
		"bossa":
			return _generate_bossa()
		"r'n b", "rnb":
			return _generate_rnb()
		_:
			push_warning("GuitarPatternGenerator: Unknown style '%s', defaulting to Folk" % style)
			return _generate_folk()


# ============================================================================
# FUNKY - Double croches rythmiques avec mutes
# ============================================================================

func _generate_funky() -> Dictionary:
	"""
	Génère un pattern funky : double croches, mutes, symétrie.

	Caractéristiques :
	- Double croches (step = 0.125)
	- Alternance D/U sur temps forts/faibles
	- Mutes intercalés (x X w W)
	- Peu ou pas de silences
	- Symétrie : motifs de 2-6 pas répétés
	"""
	var pattern = ""
	var step = 0.125

	# Choisir une structure symétrique
	var structure = rng.randi_range(0, 4)

	match structure:
		0:  # 4 pas × 4 répétitions
			var motif = _generate_funky_motif(4)
			pattern = motif + motif + motif + motif
		1:  # 8 pas × 2 répétitions
			var motif = _generate_funky_motif(8)
			pattern = motif + motif
		2:  # 2 motifs de 4 pas alternés : ABAB
			var motif_a = _generate_funky_motif(4)
			var motif_b = _generate_funky_motif(4)
			pattern = motif_a + motif_b + motif_a + motif_b
		3:  # 3 pas × 5 répétitions + 1 note finale
			var motif = _generate_funky_motif(3)
			pattern = motif + motif + motif + motif + motif + _pick_funky_hit()
		4:  # 2 motifs de 5 pas + 2 motifs de 3 pas
			var motif_a = _generate_funky_motif(5)
			var motif_b = _generate_funky_motif(3)
			pattern = motif_a + motif_a + motif_b + motif_b

	return {"pattern": pattern, "step_beat_length": step}


func _generate_funky_motif(length: int) -> String:
	"""Génère un motif funky de longueur donnée."""
	var motif = ""
	var down_up_phase = 0  # Alterne D et U

	for i in range(length):
		var rand = rng.randf()

		if rand < 0.65:  # 65% : coup normal
			if down_up_phase % 2 == 0:
				motif += "D" if rng.randf() < 0.7 else "d"
			else:
				motif += "U" if rng.randf() < 0.6 else "u"
			down_up_phase += 1

		elif rand < 0.90:  # 25% : mute
			var mute_choice = rng.randf()
			if mute_choice < 0.5:
				motif += "x"
			elif mute_choice < 0.75:
				motif += "X"
			elif mute_choice < 0.90:
				motif += "w"
			else:
				motif += "W"
			down_up_phase += 1

		else:  # 10% : note seule (rare)
			motif += _pick_single_note()

	return motif


func _pick_funky_hit() -> String:
	"""Retourne un coup funky aléatoire."""
	var options = ["D", "d", "U", "u", "x", "X"]
	return options[rng.randi_range(0, options.size() - 1)]


# ============================================================================
# FOLK - Croches classiques avec points
# ============================================================================

func _generate_folk() -> Dictionary:
	"""
	Génère un pattern folk : croches, D/U, beaucoup de points.

	Caractéristiques :
	- Croches (step = 0.25)
	- Down sur temps forts (0, 4, 8, 12)
	- Up entre les temps
	- Beaucoup de points
	- Exceptionnellement une note seule
	"""
	var pattern = ""
	var step = 0.25

	# Choisir un pattern de base folk
	var style_choice = rng.randi_range(0, 3)

	match style_choice:
		0:  # Pattern classique D.uDudu. répété
			pattern = "D.uDudu." + "D.uDudu."
		1:  # Pattern D..du..D répété avec variations
			var base = "D..du.."
			pattern = base + base.replace("d", _pick_down_light())
		2:  # Pattern alterné avec basse occasionnelle
			if rng.randf() < 0.3:  # 30% chance d'avoir une basse
				pattern = "B.uDudu.D.uDudu."
			else:
				pattern = "D.uDudu.D.uduDu."
		3:  # Pattern swing folk
			pattern = "D..Du.u.D..Du.u."

	# Ajouter quelques variations aléatoires
	pattern = _add_folk_variations(pattern)

	return {"pattern": pattern, "step_beat_length": step}


func _add_folk_variations(base_pattern: String) -> String:
	"""Ajoute des variations subtiles à un pattern folk."""
	var chars = []
	for i in range(base_pattern.length()):
		chars.append(base_pattern[i])

	# Remplacer 1-2 caractères aléatoirement
	for _i in range(rng.randi_range(0, 2)):
		var pos = rng.randi() % chars.size()
		var current = chars[pos]

		if current == "D":
			chars[pos] = "d" if rng.randf() < 0.3 else "D"
		elif current == "u":
			chars[pos] = "U" if rng.randf() < 0.2 else "u"
		elif current == "." and rng.randf() < 0.1:
			chars[pos] = _pick_single_note()

	var result = ""
	for c in chars:
		result += c
	return result


func _pick_down_light() -> String:
	"""Retourne un down léger avec variation."""
	return "d" if rng.randf() < 0.8 else "D"


# ============================================================================
# BOSSA - Croche pointée et syncope
# ============================================================================

func _generate_bossa() -> Dictionary:
	"""
	Génère un pattern bossa : croche pointée, syncopes.

	Caractéristiques :
	- Croches (step = 0.25)
	- Rythme 3+3+2 typique (ou variations)
	- Syncopes et silences stratégiques
	- Alternance légère/fort
	"""
	var pattern = ""
	var step = 0.25

	# Patterns bossa typiques basés sur la clave
	var bossa_patterns = [
		"..D..u.D..D.u...",  # Motif 3+3+2
		"..d..uD...d.u...",  # Variation légère
		" .D..u. ..D.u...",  # Avec silences
		"..D..uD...D..u..",  # Syncope
	]

	pattern = bossa_patterns[rng.randi_range(0, bossa_patterns.size() - 1)]

	# Ajouter des variations subtiles (mutes légers occasionnels)
	if rng.randf() < 0.3:
		pattern = pattern.replace(".", "x")  # Remplacer 1 point par un mute

	return {"pattern": pattern, "step_beat_length": step}


# ============================================================================
# R'n B - Arpèges et notes seules avec symétrie
# ============================================================================

func _generate_rnb() -> Dictionary:
	"""
	Génère un pattern R'n B : arpèges, symétrie.

	Caractéristiques :
	- Croches ou double croches
	- Succession de notes (0 1 2 3 4)
	- Grappes avec symétrie
	- Répétition/translation/inversion/renversement
	"""
	var step = 0.25 if rng.randf() < 0.6 else 0.125
	var pattern = ""

	# Choisir une structure symétrique
	var symmetry_type = rng.randi_range(0, 4)

	match symmetry_type:
		0:  # Montée-descente : 01234321
			pattern = _generate_rnb_scale_up(8) + _generate_rnb_scale_down(8)
		1:  # Répétition de motif court
			var motif = _generate_rnb_motif(4)
			pattern = motif + motif + motif + motif
		2:  # ABBA (palindrome)
			var motif_a = _generate_rnb_motif(4)
			var motif_b = _generate_rnb_motif(4)
			var motif_a_reversed = _reverse_arpeggio_motif(motif_a)
			var motif_b_reversed = _reverse_arpeggio_motif(motif_b)
			pattern = motif_a + motif_b + motif_b_reversed + motif_a_reversed
		3:  # Grappes répétées : 00.11.22.33.
			var note = rng.randi_range(0, 4)
			for i in range(4):
				pattern += str(note) + str(note) + "." + str((note + 1) % 5)
			pattern = pattern.substr(0, 16)
		4:  # Pattern alterné avec silences
			var motif = _generate_rnb_motif(5)
			pattern = motif + "." + motif + "." + motif.substr(0, 4)

	return {"pattern": pattern, "step_beat_length": step}


func _generate_rnb_scale_up(length: int) -> String:
	"""Génère une montée d'arpège."""
	var scale = ""
	var current_note = rng.randi_range(0, 2)  # Partir d'une note basse

	for i in range(length):
		if rng.randf() < 0.7:  # 70% : avancer
			scale += str(current_note)
			current_note = min(4, current_note + 1)
		else:  # 30% : point ou répéter
			scale += "." if rng.randf() < 0.5 else str(current_note)

	return scale


func _generate_rnb_scale_down(length: int) -> String:
	"""Génère une descente d'arpège."""
	var scale = ""
	var current_note = rng.randi_range(3, 4)  # Partir d'une note haute

	for i in range(length):
		if rng.randf() < 0.7:  # 70% : descendre
			scale += str(current_note)
			current_note = max(0, current_note - 1)
		else:  # 30% : point ou répéter
			scale += "." if rng.randf() < 0.5 else str(current_note)

	return scale


func _generate_rnb_motif(length: int) -> String:
	"""Génère un motif R'n B court."""
	var motif = ""
	var available_notes = [0, 1, 2, 3, 4]

	for i in range(length):
		var rand = rng.randf()

		if rand < 0.75:  # 75% : note
			var note = available_notes[rng.randi_range(0, available_notes.size() - 1)]
			motif += str(note)
		else:  # 25% : point
			motif += "."

	return motif


func _reverse_arpeggio_motif(motif: String) -> String:
	"""Inverse un motif d'arpège (4→0, 3→1, etc.)."""
	var reversed = ""

	for i in range(motif.length()):
		var c = motif[i]
		if c in ["0", "1", "2", "3", "4"]:
			var note_value = int(c)
			var inverted = 4 - note_value
			reversed += str(inverted)
		else:
			reversed += c

	return reversed


# ============================================================================
# HELPERS
# ============================================================================

func _pick_single_note() -> String:
	"""Retourne une note seule aléatoire (B, b, ou 0-4)."""
	var notes = ["B", "b", "0", "1", "2", "3", "4"]
	return notes[rng.randi_range(0, notes.size() - 1)]

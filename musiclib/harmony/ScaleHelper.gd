# ScaleHelper.gd — Godot 3.x
extends Reference
class_name ScaleHelper




const MAJOR_STEPS = [2, 2, 1, 2, 2, 2, 1]
const HARM_MINOR_STEPS = [2, 1, 2, 2, 1, 3, 1]
const MELOD_MINOR_STEPS = [2, 1, 2, 2, 2, 2, 1]
# --- Heptatoniques additionnelles (7 notes) ---

# Formules "step-by-step" (en demi-tons)
const HARMONIC_MAJOR_STEPS = [2, 2, 1, 2, 1, 3, 1]        # Harmonic major
const DOUBLE_HARMONIC_STEPS = [1, 3, 1, 2, 1, 3, 1]       # Double harmonic (a.k.a. Byzantine / Gypsy major)
const HUNGARIAN_MAJOR_STEPS = [3, 1, 2, 1, 2, 1, 2]       # Hungarian major
const HUNGARIAN_MINOR_STEPS = [2, 1, 3, 1, 1, 3, 1]       # Hungarian minor (Gypsy minor)
const NEAPOLITAN_MAJOR_STEPS = [1, 2, 2, 2, 2, 2, 1]      # Neapolitan major
const NEAPOLITAN_MINOR_STEPS = [1, 2, 2, 2, 1, 3, 1]      # Neapolitan minor
const ENIGMATIC_STEPS = [1, 3, 2, 2, 2, 1, 1]             # Enigmatic
const PERSIAN_STEPS = [1, 3, 1, 1, 2, 3, 1]               # Persian
const MAJOR_LOCRIAN_STEPS = [2, 2, 1, 1, 2, 2, 2]         # Major Locrian
const LEADING_WHOLE_TONE_STEPS = [2, 2, 2, 2, 2, 1, 1]    # Leading whole tone (mode II de Neapolitan major)
const ROMANIAN_MAJOR_STEPS = [1, 3, 2, 1, 2, 1, 2]        # Romanian major

var scale_steps: Dictionary = {}

func _init():
	_build_tables()

func get_scale_array(name) -> Array:
	_ensure_built()
	var key = _norm(name)
	if not scale_steps.has(key):
		push_error("Unknown scale: " + name)
		return []

	var result: Array = []
	var current = 0
	result.append(current)

	var steps = scale_steps[key]
	for s in steps:
		current += s
		result.append(current)

	return result

func list_scales() -> Array:
	_ensure_built()
	return scale_steps.keys()

# --- internals ---
func _ensure_built():
	if scale_steps.size() == 0:
		_build_tables()

func _build_tables():
	# Modes du majeur
	var major_names = ["ionian", "dorian", "phrygian", "lydian", "mixolydian", "aeolian", "locrian"]
	for i in range(major_names.size()):
		scale_steps[_norm(major_names[i])] = _rotate(MAJOR_STEPS, i)
	# alias majeurs
	scale_steps[_norm("major")] = scale_steps[_norm("ionian")]
	scale_steps[_norm("minor")] = scale_steps[_norm("aeolian")]
	
	# Mineure harmonique (modes)
	var hm_names = [
		"harmonic_minor",
		"locrian_n6",
		"ionian_#5",
		"ukrainian_dorian",
		"phrygian_dominant",
		"lydian_#2",
		"ultralocrian"
	]
	for i in range(hm_names.size()):
		scale_steps[_norm(hm_names[i])] = _rotate(HARM_MINOR_STEPS, i)


	# Mineure mélodique (modes)
	var mm_names = [
		"melodic_minor",
		"dorian_b2",
		"lydian_#5",
		"overtone",
		"hindu",
		"half_diminished",
		"altered"
	]
	for i in range(mm_names.size()):
		scale_steps[_norm(mm_names[i])] = _rotate(MELOD_MINOR_STEPS, i)

	
	scale_steps[_norm("harmonic_major")] = HARMONIC_MAJOR_STEPS

	scale_steps[_norm("double_harmonic")] = DOUBLE_HARMONIC_STEPS
	scale_steps[_norm("double_harmonic_major")] = DOUBLE_HARMONIC_STEPS
	scale_steps[_norm("byzantine")] = DOUBLE_HARMONIC_STEPS
	scale_steps[_norm("gypsy_major")] = DOUBLE_HARMONIC_STEPS

	scale_steps[_norm("hungarian_major")] = HUNGARIAN_MAJOR_STEPS
	scale_steps[_norm("hungarian_minor")] = HUNGARIAN_MINOR_STEPS
	scale_steps[_norm("gypsy_minor")] = HUNGARIAN_MINOR_STEPS

	scale_steps[_norm("neapolitan_major")] = NEAPOLITAN_MAJOR_STEPS
	scale_steps[_norm("neapolitan_minor")] = NEAPOLITAN_MINOR_STEPS

	scale_steps[_norm("enigmatic")] = ENIGMATIC_STEPS
	scale_steps[_norm("persian")] = PERSIAN_STEPS

	scale_steps[_norm("major_locrian")] = MAJOR_LOCRIAN_STEPS
	scale_steps[_norm("leading_whole_tone")] = LEADING_WHOLE_TONE_STEPS

	scale_steps[_norm("romanian_major")] = ROMANIAN_MAJOR_STEPS



	
func _rotate(a: Array, k: int) -> Array:
	var out: Array = []
	var n = a.size()
	if n == 0:
		return out
	var start = k % n
	for i in range(n):
		out.append(a[(start + i) % n])
	return out

func _norm(s: String) -> String:
	var t = s.to_lower()
	t = t.replace(" ", "")
	#t = t.replace("_", " ")
	t = t.replace("-", "")
	# strip accents FR courants
	t = t.replace("é", "e").replace("è", "e").replace("ê", "e").replace("ë", "e")
	t = t.replace("à", "a").replace("â", "a").replace("ä", "a")
	t = t.replace("î", "i").replace("ï", "i")
	t = t.replace("ô", "o").replace("ö", "o")
	t = t.replace("û", "u").replace("ü", "u")
	t = t.replace("ç", "c")
	return t
	
	
"""
# Exemples d'utilisation

var h = ScaleHelper.new()

print(h.get_scale_array("phrygian_dominant"))
# [0, 1, 4, 5, 7, 8, 10, 12]

print(h.get_scale_array("lydian_b7")) # (= overtone / lydian dominant)
# [0, 2, 4, 6, 7, 9, 10, 12]

print(h.get_scale_array("altered"))   # (= super locrian)
# [0, 1, 3, 4, 6, 8, 10, 12]

"""

	

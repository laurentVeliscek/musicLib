# HarmonicKey.gd — Godot 3.x (ajout: analyse + chiffres romains)
extends Reference
class_name HarmonicKey

const TAG = "HarmonicKey"
# Dépendances:
# - ScaleHelper (get_scale_array)
# - NoteParser  (midi_from_string)

var root_midi: int = 60 setget set_root_midi, get_root_midi
var scale_name: String = "major" setget set_scale_name, get_scale_name
var _degrees: Array = []
var _scale: ScaleHelper = null

# --- Dans HarmonicKey.gd (déclarations en haut du fichier) ---
var _root_token_hint: String = ""   # ce que l'utilisateur a tapé pour la tonique ("Db", "C#", "Do", "Réb3", etc.)
var _prefer_sharps_hint: int = -1   # -1 = inconnu, 0 = flats, 1 = sharps


func to_dict() -> Dictionary:
	return {
		"scale_name":scale_name, 
		"root_midi":root_midi
	}

func from_dict(data: Dictionary)-> HarmonicKey:
	var k:HarmonicKey = get_script().new()
	k.scale_name = str(data["scale_name"])
	k.root_midi = int(data["root_midi"])
	return k


func clone():
	var k:HarmonicKey = get_script().new()
	k.set_from_string(to_string())
	# … (autres scalaires)
	return k

func get_prefer_sharps_hint() -> int:
	return _prefer_sharps_hint

func get_root_token_hint() -> String:
	return _root_token_hint

func get_root_string() -> String:
	return to_string().split(" ")[0]
	
func get_scale_string() -> String:
	return scale_name

##### NEW  !
var root:int setget set_root,get_root

func get_root()->int:
	return root_midi % 12
func set_root(r:int):
	root_midi = 60 + (r % 12)

var scale:Array setget set_scale, get_scale

func get_scale()->Array:
	var s = []
	var t = get_scale_array()
	for i in range(0,7):
		s.append(t[i])
	return s 
	
func set_scale(s:Array):
	LogBus.error(TAG,"scale cannot be set. It is set by ScaleHelper")





func _init():
	_scale = ScaleHelper.new()
	_refresh_degrees()

func set_from_string(s: String) -> bool:
	var key = s.strip_edges()
	if key == "":
		key = "C major"
	var note_token = ""
	var scale_token = ""
	var p = key.find(" ")
	if p == -1:
		note_token = key
		scale_token = "major"
	else:
		note_token = key.substr(0, p)
		scale_token = key.substr(p + 1, key.length() - (p + 1))
	var midi = NoteParser.midi_from_string(note_token, 4)
	if midi < 0:
		LogBus.error("HarmonicKey:"," invalid root '" + note_token + "' in '" + s + "'")
		return false
	var arr = _scale.get_scale_array(scale_token)
	if arr.size() == 0:
		LogBus.error("HarmonicKey:","unknown scale '" + scale_token + "' in '" + s + "'")
		return false
	root_midi = midi
	scale_name = scale_token
	_degrees = arr
	
	# ... après avoir validé midi/arr et affecté root_midi / scale_name / _degrees :
	_root_token_hint = note_token

	# Normalise pour lire l'accidentel
	var t = note_token.to_lower()
	t = t.replace("♯", "#").replace("♭", "b")
	t = t.replace("é", "e").replace("è", "e").replace("ê", "e").replace("ë", "e")
	t = t.replace("à", "a").replace("â", "a").replace("ä", "a")
	t = t.replace("î", "i").replace("ï", "i")
	t = t.replace("ô", "o").replace("ö", "o")
	t = t.replace("û", "u").replace("ü", "u")
	t = t.replace("ç", "c")

	_prefer_sharps_hint = -1
	if t.find("#") != -1:
		_prefer_sharps_hint = 1
	elif t.find("b") != -1:
		_prefer_sharps_hint = 0

	#LogBus.info("HarmonicKey","key set to "+ to_string())
	return true



func set_root_midi(v: int):
	root_midi = v

func get_root_midi() -> int:
	return root_midi

func set_scale_name(name: String):
	if name == "":
		#LogBus.error("HarmonicKey:set_scale_name() -> ",' name  = ""')
		name = "major"
	var arr = _scale.get_scale_array(name)
	if arr.size() == 0:
		LogBus.error("HarmonicKey:"," unknown scale '" + name + "'")
		return
	scale_name = name
	_degrees = arr

func get_scale_name() -> String:
	return scale_name

# degré diatonique -> pitch MIDI (accepte négatifs et zéro)
func degree_midi(degree: int) -> int:
	if _degrees.size() == 0:
		_refresh_degrees()

	var k = degree - 1
	# index du degré dans [0..6]
	var idx = ((k % 7) + 7) % 7
	# nombre d'octaves à ajouter (division PLANCHER)
	var octs = int(floor(k / 7.0))

	var semis = _degrees[idx]
	return root_midi + semis + octs * 12

# offset en demi-tons par rapport à la tonique (même logique)
func degree_offset(degree: int) -> int:
	if _degrees.size() == 0:
		_refresh_degrees()

	var k = degree - 1
	var idx = ((k % 7) + 7) % 7
	var octs = int(floor(k / 7.0))

	return _degrees[idx] + octs * 12

func get_scale_array()-> Array:
	#LogBus.debug(TAG,"get_scale_array()"+str(_degrees))
	return _degrees

func triad(degree: int) -> Array:
	return _tertian_chord(degree, 3)

func seventh(degree: int) -> Array:
	return _tertian_chord(degree, 4)

func chord(degree: int, size: int) -> Array:
	return _tertian_chord(degree, size)

func invert(chord_notes: Array, times: int) -> Array:
	var n = chord_notes.size()
	if n == 0:
		return chord_notes
	if times < 0:
		times = 0
	var out: Array = []
	for i in range(n):
		out.append(chord_notes[i])
	for k in range(times):
		var first = out[0]
		out.remove(0)
		out.append(first + 12)
	return out

# ---------------------------
#        ANALYSE
# ---------------------------

## Renvoie la qualité de la triade au degré: "maj", "min", "dim", "aug" "maj_b5"
# --- triades / 7e: qualités (aucun blocage pour <1) ---
func triad_quality(degree: int) -> String:
	var iv = _triad_intervals(degree)	# [third, fifth] en demi-tons
	var t = iv[0]
	var f = iv[1]
	if t == 4 and f == 7:
		return "maj"
	if t == 3 and f == 7:
		return "min"
	if t == 3 and f == 6:
		return "dim"
	if t == 4 and f == 8:
		return "aug"
	# NEW: majeure avec quinte bémol (ex: degré V en double-harmonic)
	if t == 4 and f == 6:
		return "maj_b5"
	return "other"


## Chiffres romains (triade)
## majeur -> MAJ; mineur -> minuscule; diminué -> minuscule + "°"; augmenté -> MAJ + "+"
# --- chiffres romains: acceptent int quelconque (…, -2, -1, 0, 1, …) ---
func roman_triad(degree: int) -> String:
	var base = _roman_base(degree)	# wrap déjà géré
	var q = triad_quality(degree)
	if q == "maj":
		return base
	if q == "min":
		return base.to_lower()
	if q == "dim":
		return base.to_lower() + "°"
	if q == "aug":
		return base + "+"
	# NEW: triade maj b5
	if q == "maj_b5":
		return base + "b5"
	return base + "?"

func seventh_quality(degree: int) -> String:
	var tri_q = triad_quality(degree)
	var seventh_iv = _seventh_interval(degree)	# 9,10,11...
	
	# NEW: 9 demi-tons = double-bémol 7 (sauf dim où c'est le cas usuel "dim7")
	if seventh_iv == 9 and tri_q != "dim":
		return "bb7"
	
	if tri_q == "maj":
		if seventh_iv == 11:
			return "maj7"
		if seventh_iv == 10:
			return "7"
	elif tri_q == "min":
		if seventh_iv == 10:
			return "m7"
		if seventh_iv == 11:
			return "mMaj7"
	elif tri_q == "dim":
		if seventh_iv == 10:
			return "m7b5"
		if seventh_iv == 9:
			return "dim7"
	elif tri_q == "aug":
		if seventh_iv == 11:
			return "+maj7"
		if seventh_iv == 10:
			return "+7"
	# NEW: triade maj b5
	elif tri_q == "maj_b5":
		if seventh_iv == 11:
			return "maj7b5"
		if seventh_iv == 10:
			return "7b5"
	return "other"

# ---------------------------
#        internes
# ---------------------------

func _refresh_degrees():
	_degrees = _scale.get_scale_array(scale_name)

func _tertian_chord(degree: int, size: int) -> Array:
	if size < 1:
		return []
	if _degrees.size() == 0:
		_refresh_degrees()
	var notes: Array = []
	for k in range(size):
		var deg_k = degree + k * 2
		var m = degree_midi(deg_k)
		if m >= 0:
			notes.append(m)
	return notes

# Intervalles (en demi-tons) de la triade par rapport à la fondamentale du degré, pliés sur 12.
func _triad_intervals(degree: int) -> Array:
	var r = degree_midi(degree)
	var t = degree_midi(degree + 2)
	var f = degree_midi(degree + 4)
	var third = (t - r) % 12
	var fifth = (f - r) % 12
	return [third, fifth]

# Intervalle de 7e (en demi-tons) par rapport à la fondamentale du degré.
func _seventh_interval(degree: int) -> int:
	var r = degree_midi(degree)
	var s = degree_midi(degree + 6)
	return (s - r) % 12

# --- utils degré (wrap propre pour négatifs/0) ---
func _wrap_degree_index(degree: int) -> int:
	# convertit ...,-1,0,1.. -> index [0..6] (VII, VII, I, …)
	var k = degree - 1
	return ((k % 7) + 7) % 7

func _roman_base(degree: int) -> String:
	var romans = ["I","II","III","IV","V","VI","VII"]
	return romans[_wrap_degree_index(degree)]
	
	
# helpers d’affichage
func _upper_if_major(s: String) -> String:
	# si la triade était mineure (minuscule), repasse en majuscules (mais garde +/° si présents)
	var core = s.replace("°", "").replace("+", "")
	return core.to_upper() + _suffix_symbols(s)

func _lower_if_minor(s: String) -> String:
	var core = s.replace("°", "").replace("+", "")
	return core.to_lower() + _suffix_symbols(s)

func _ensure_dim_symbol(s: String) -> String:
	if s.find("°") == -1:
		return _lower_if_minor(s) + "°"
	return s

func _replace_dim_symbol(s: String, sym: String) -> String:
	var t = s
	t = t.replace("°", "")
	return t + sym

func _ensure_aug_symbol(s: String) -> String:
	if s.find("+") == -1:
		return s + "+"
	return s

func _suffix_symbols(s: String) -> String:
	var suf = ""
	if s.find("+") != -1:
		suf += "+"
	if s.find("°") != -1:
		suf += "°"
	return suf


# --- Public: nom lisible de la tonalité (anglais) ---
func to_string() -> String:
	# Tonique en notation EN, sans octave, avec préférence #/b issue de la tonalité
	var root_name = NoteParser.midipitch2StringInKey(root_midi, self, "en", false, false)
	#var scale_label = _english_scale_label(scale_name)
	return root_name + " " + scale_name

# --- Helpers d'affichage ---
func _english_scale_label(raw: String) -> String:
	var n = _norm_en(raw)

	# Canonicals / traductions FR → EN
	var map: Dictionary = {
		"ionian": "Major",
		"major": "Major",
		"aeolian": "Natural Minor",
		"naturalminor": "Natural Minor",
		"natminor": "Natural Minor",
		"minor": "Natural Minor",

		"harmonicminor": "Harmonic Minor",
		"melodicminor": "Melodic Minor",

		# modes courants
		"dorian": "Dorian",
		"phrygian": "Phrygian",
		"lydian": "Lydian",
		"mixolydian": "Mixolydian",
		"locrian": "Locrian",


	}

	if map.has(n):
		return map[n]

	# Fallback générique: "lydian_b7" -> "Lydian b7", "locrian_#2" -> "Locrian #2"
	var s = String(raw).strip_edges()
	s = s.replace("_", " ").replace("-", " ")
	var parts = s.split(" ")
	var out: Array = []
	for i in range(parts.size()):
		var p = parts[i]
		if p.length() == 0:
			continue
		var c = p[0]
		# Capitalise les mots alphabétiques, laisse #/b/n* tel quel
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
			p = p.substr(0, 1).to_upper() + p.substr(1, p.length() - 1)
		out.append(p)
	return String(" ").join(out)

func _norm_en(s: String) -> String:
	var t = String(s).to_lower()
	t = t.replace(" ", "").replace("_", "").replace("-", "")
	# retire les accents (si le nom de gamme a été fourni en FR)
	t = t.replace("é", "e").replace("è", "e").replace("ê", "e").replace("ë", "e")
	t = t.replace("à", "a").replace("â", "a").replace("ä", "a")
	t = t.replace("î", "i").replace("ï", "i")
	t = t.replace("ô", "o").replace("ö", "o")
	t = t.replace("û", "u").replace("ü", "u")
	t = t.replace("ç", "c")
	return t




func roman_seventh(degree: int) -> String:
	var base_tri = roman_triad(degree)	# peut contenir "b5", "+", "°"
	var q7 = seventh_quality(degree)
	
	# NEW: double-bémol 7 (ex: degré III en double-harmonic)
	if q7 == "bb7":
		return base_tri.replace("?", "") + "bb7"
	
	# NEW: cas b5 avec 7e
	if q7 == "7b5":
		var core = base_tri.replace("b5", "").replace("?", "")
		return _upper_if_major(core) + "7b5"
	if q7 == "maj7b5":
		var core2 = base_tri.replace("b5", "").replace("?", "")
		return _upper_if_major(core2) + "maj7b5"
	
	if q7 == "maj7":
		return _upper_if_major(base_tri) + "maj7"
	if q7 == "7":
		return _upper_if_major(base_tri) + "7"
	if q7 == "m7":
		return _lower_if_minor(base_tri) + "7"
	if q7 == "m7b5":
		var b = _lower_if_minor(base_tri)
		return _replace_dim_symbol(b, "ø") + "7"
	if q7 == "dim7":
		var b2 = _ensure_dim_symbol(base_tri)
		return b2 + "7"
	if q7 == "mMaj7":
		return _lower_if_minor(base_tri) + "maj7"
	if q7 == "+maj7":
		return _ensure_aug_symbol(_upper_if_major(base_tri)) + "maj7"
	if q7 == "+7":
		return _ensure_aug_symbol(_upper_if_major(base_tri)) + "7"
	return base_tri + "?"

"""
# Exemples d'utilisation

var hk = HarmonicKey.new()
hk.set_from_string("Db natural_minor")

print(hk.degree_midi(1))   # 61  (Db4)
print(hk.degree_midi(5))   # 68  (quinte)
print(hk.degree_midi(9))   # 75  (2nde + 1 octave)

# Triades / 7e diatoniques
print(hk.triad(1))         # ex. [Db, F, Ab]
print(hk.seventh(2))       # degré II-7 (selon la gamme)

# Extensions : 9 / 11 / 13
print(hk.chord(1, 5))      # 9e (5 notes)
print(hk.chord(4, 6))      # 11e
print(hk.chord(5, 7))      # 13e

# Inversions
var cmaj = HarmonicKey.new()
cmaj.set_from_string("C major")
var g7 = cmaj.seventh(5)
print(g7)                  # G B D F
print(cmaj.invert(g7, 1))  # 1ère renversement : B D F G
print(cmaj.invert(g7, 2))  # 2e renversement : D F G B


---------------------------

var hk = HarmonicKey.new()
hk.set_from_string("C major")

print(hk.triad_quality(1))   # "maj"
print(hk.roman_triad(1))     # "I"

print(hk.triad_quality(2))   # "min"
print(hk.roman_triad(2))     # "ii"

print(hk.triad_quality(7))   # "dim"
print(hk.roman_triad(7))     # "vii°"

print(hk.seventh_quality(5)) # "7" (dominante en majeur)
print(hk.roman_seventh(5))   # "V7"

hk.set_from_string("A harmonic_minor")
print(hk.triad_quality(3))   # "aug" (III+)
print(hk.roman_triad(3))     # "III+"
print(hk.seventh_quality(3)) # "+maj7"
print(hk.roman_seventh(3))   # "III+maj7"

print(hk.seventh_quality(7)) # "dim7" (vii°7)
print(hk.roman_seventh(7))   # "vii°7"

hk.set_from_string("D melodic_minor")
print(hk.seventh_quality(4)) # "7" (Lydian b7 → dominante)
print(hk.roman_seventh(4))   # "IV7"

"""

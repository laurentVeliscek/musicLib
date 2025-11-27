# NoteParser.gd — Godot 3.x
extends Reference
class_name NoteParser


const ORDRE_DES_DIESES = "F C G D A E B"
const ORDRE_DES_BEMOLS = "B E A D G C F"



## Convert note string to MIDI number.
## Examples:
## - "C" -> 60 (C4 by default)
## - "C#4" / "Db4" -> 61
## - "Do" -> 60, "Réb3" / "Reb3" -> 49, "Sol#5" -> 80
static func midi_from_string(input: String, default_octave: int = 4) -> int:
	var s = _norm(input)
	if s.length() == 0:
		push_error("Empty note string")
		return -1

	# base name (english or french)
	var name = _match_name_prefix(s)
	if name == "":
		push_error("Unrecognized note name: " + input)
		return -1

	var i = name.length()
	var base = _base_offset(name)

	# accidentals: #, ## / x, b, bb
	var acc = 0
	while i < s.length():
		var ch = s[i]
		if ch == "#":
			acc += 1
			i += 1
			continue
		if ch == "x": # double sharp
			acc += 2
			i += 1
			continue
		if ch == "b":
			acc -= 1
			i += 1
			continue
		break

	# octave (optional)
	var octave = default_octave
	var rest = s.substr(i, s.length() - i)
	if rest != "":
		if rest.is_valid_integer():
			octave = int(rest)
		else:
			# parse leading +/-digits
			var parsed = ""
			for j in range(rest.length()):
				var cj = rest[j]
				if cj == "+" or cj == "-" or (cj >= "0" and cj <= "9"):
					parsed += cj
				else:
					break
			if parsed.is_valid_integer():
				octave = int(parsed)
			elif parsed != "":
				push_warning("Octave not valid in '" + input + "': '" + rest + "'")

	# fold accidentals across octave boundaries (e.g. B#3 -> C4)
	var total = base + acc
	var adj = 0
	while total >= 12:
		total -= 12
		adj += 1
	while total < 0:
		total += 12
		adj -= 1

	var midi = (octave + 1 + adj) * 12 + total
	return midi

# --- helpers ---

# map for english & french base names
static func _base_offset(name: String) -> int:
	if name == "c" or name == "do":
		return 0
	if name == "d" or name == "re":
		return 2
	if name == "e" or name == "mi":
		return 4
	if name == "f" or name == "fa":
		return 5
	if name == "g" or name == "sol":
		return 7
	if name == "a" or name == "la":
		return 9
	# b (english) == si (fr)
	return 11

# prefer longest matches first to disambiguate "sol" vs "si", etc.
static func _match_name_prefix(s: String) -> String:
	var candidates = ["sol", "do", "re", "mi", "fa", "la", "si", "c", "d", "e", "f", "g", "a", "b"]
	for n in candidates:
		if s.begins_with(n):
			return n
	return ""

# normalize: lowercase, replace ♯/♭ with #/b, strip french accents
static func _norm(s: String) -> String:
	var t = s.strip_edges().to_lower()
	t = t.replace("♯", "#")
	t = t.replace("♭", "b")
	# french accents
	t = t.replace("é", "e")
	t = t.replace("è", "e")
	t = t.replace("ê", "e")
	t = t.replace("ë", "e")
	t = t.replace("à", "a")
	t = t.replace("â", "a")
	t = t.replace("ä", "a")
	t = t.replace("î", "i")
	t = t.replace("ï", "i")
	t = t.replace("ô", "o")
	t = t.replace("ö", "o")
	t = t.replace("û", "u")
	t = t.replace("ü", "u")
	t = t.replace("ç", "c")
	return t

# Ajoute ceci dans NoteParser.gd (ou un utilitaire)
static func midipitch2StringFR(midi: int, include_octave: bool = true, prefer_sharps: bool = true, use_unicode_accidentals: bool = false, ascii: bool = false) -> String:
	var pc = midi % 12
	if pc < 0:
		pc += 12

	var names_sharp = ["do", "do#", "ré", "ré#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si"]
	var names_flat  = ["do", "réb", "ré", "mib", "mi", "fa", "solb", "sol", "lab", "la", "sib", "si"]

	var name = ""
	if prefer_sharps:
		name = names_sharp[pc]
	else:
		name = names_flat[pc]

	if use_unicode_accidentals:
		name = name.replace("#", "♯")
		name = name.replace("b", "♭")

	if ascii:
		name = _strip_accents(name)  # cf. helper ci-dessous

	if include_octave:
		var octave = int(midi / 12) - 1
		return name + String(octave)
	else:
		return name

# helper optionnel (si tu veux l’ASCII sans accents)
static func _strip_accents(s: String) -> String:
	var t = s
	t = t.replace("é", "e").replace("è", "e").replace("ê", "e").replace("ë", "e")
	t = t.replace("à", "a").replace("â", "a").replace("ä", "a")
	t = t.replace("î", "i").replace("ï", "i")
	t = t.replace("ô", "o").replace("ö", "o")
	t = t.replace("û", "u").replace("ü", "u")
	return t

static func midipitch2String(midi: int, include_octave: bool = true, prefer_sharps: bool = true, use_unicode_accidentals: bool = false) -> String:
	var pc = midi % 12
	if pc < 0:
		pc += 12

	var names_sharp = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var names_flat  = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

	var name = ""
	if prefer_sharps:
		name = names_sharp[pc]
	else:
		name = names_flat[pc]

	if use_unicode_accidentals:
		name = name.replace("#", "♯")
		name = name.replace("b", "♭")

	if include_octave:
		var octave = int(midi / 12) - 1
		return name + String(octave)
	else:
		return name


# Devine la préférence dièses/bémols depuis la tonalité.
# 1 = dièses, 0 = bémols.
static func guess_prefer_sharps_from_key(hk) -> int:
	# si l'utilisateur a explicitement mis # ou b dans la tonique, on respecte
	if hk != null and hk.get_prefer_sharps_hint() != -1:
		return hk.get_prefer_sharps_hint()

	# fallback : préférence "signature" basique selon la classe de hauteur de la tonique
	# keys "naturellement bémol" : F (5), Db (1), Eb (3), Gb (6), Ab (8), Bb (10)
	# sinon → dièses
	var pc = hk.get_root_midi() % 12
	if pc < 0:
		pc += 12

	if pc == 5 or pc == 1 or pc == 3 or pc == 6 or pc == 8 or pc == 10:
		return 0
	return 1

# Convertit un midi pitch en nom de note selon la tonalité (anglais ou français).
# locale: "en" ou "fr"
static func midipitch2StringInKey(midi: int, hk, locale: String = "en", include_octave: bool = true, use_unicode_accidentals: bool = false) -> String:
	var pref = guess_prefer_sharps_from_key(hk) == 1
	if locale == "fr":
		# midipitch2StringFR(midi, include_octave, prefer_sharps, use_unicode_accidentals, ascii=false)
		return midipitch2StringFR(midi, include_octave, pref, use_unicode_accidentals, false)
	else:
		# midipitch2String(midi, include_octave, prefer_sharps, use_unicode_accidentals)
		return midipitch2String(midi, include_octave, pref, use_unicode_accidentals)



################################################################# 
# NoteParser.gd — orthographe stricte dans une tonalité (EN/FR)
#################################################################
# NoteParser.gd — orthographe stricte dans une tonalité (EN/FR)

# API principale
static func midipitch2StringStrictInKey(midi: int, hk, locale: String = "en", include_octave: bool = true, use_unicode_accidentals: bool = false) -> String:
	var root_letter = _root_letter_index_from_hk(hk)
	var cand = _spell_candidate_for_midi(midi, hk, root_letter)
	var name = _format_spelled(cand["letter_index"], cand["acc"], locale, use_unicode_accidentals)
	if include_octave:
		var octave = int(midi / 12) - 1
		return name + String(octave)
	return name

# Liste les 7 degrés orthographiés dans la tonalité (utile pour debug/UI)
static func spelling_table_in_key(hk, locale: String = "en", use_unicode_accidentals: bool = false) -> Array:
	var out: Array = []
	if hk == null:
		return out

	var root_letter = _root_letter_index_from_hk(hk)
	for i in range(7):
		var degree_midi = hk.degree_midi(1 + i)
		var target_pc = degree_midi % 12
		if target_pc < 0:
			target_pc += 12

		var letter_index = (root_letter + i) % 7
		var letter_pc = _letter_pc_from_c_major(letter_index)  # C,D,E,F,G,A,B -> 0,2,4,5,7,9,11
		var acc = _signed_mod12(target_pc - letter_pc)         # accidentel relatif à la lettre naturelle

		var label = _format_spelled(letter_index, acc, locale, use_unicode_accidentals)
		out.append(label)
	return out

# Choisit la meilleure lettre (degré) + altération pour atteindre 'midi'
# -> on privilégie d'abord les notes QUI SONT sur un degré de la gamme (pitch class égal au degré),
#    puis le moins d'altérations, puis la préférence #/b, puis la proximité de degré.
static func _spell_candidate_for_midi(midi: int, hk, root_letter: int) -> Dictionary:
	var target_pc = midi % 12
	if target_pc < 0:
		target_pc += 12

	var root_pc = 0
	if hk != null:
		root_pc = hk.get_root_midi() % 12
		if root_pc < 0:
			root_pc += 12

	var best = null
	var best_score = 999999
	var prefer = -1
	if hk != null:
		prefer = hk.get_prefer_sharps_hint()  # 1 = dièses, 0 = bémols, -1 = neutre

	for k in range(-7, 8):
		var letter_index = (root_letter + ((k % 7) + 7) % 7) % 7
		var letter_pc = _letter_pc_from_c_major(letter_index)
		var acc = _signed_mod12(target_pc - letter_pc)

		# degré diatonique associé à cette lettre
		var deg_index = (letter_index - root_letter + 7) % 7
		var scale_pc = -1
		if hk != null:
			var off = hk.degree_offset(deg_index + 1) # 0..11 typiquement
			scale_pc = (root_pc + (off % 12)) % 12

		var on_scale_penalty = 0
		if scale_pc != -1:
			if target_pc != scale_pc:
				on_scale_penalty = 1

		var acc_cost = abs(acc)                      # 0,1,2…
		var pref_cost = 0
		if prefer == 1 and acc < 0:
			pref_cost = 1
		elif prefer == 0 and acc > 0:
			pref_cost = 1

		var degree_distance = abs(k)

		var score = on_scale_penalty * 1000 + acc_cost * 100 + pref_cost * 10 + degree_distance
		if best == null or score < best_score:
			best_score = score
			best = {"letter_index": letter_index, "acc": acc, "k": k}

	return best


# Déduit la lettre (C..B) de la tonique depuis HarmonicKey
static func _root_letter_index_from_hk(hk) -> int:
	# 0=C,1=D,2=E,3=F,4=G,5=A,6=B
	if hk == null:
		return 0
	var tok = hk.get_root_token_hint()
	if tok == null or String(tok) == "":
		# fallback depuis la classe de hauteur + préférence #/b
		var pc = hk.get_root_midi() % 12
		if pc < 0:
			pc += 12
		var prefer = hk.get_prefer_sharps_hint()
		return _fallback_letter_from_pc(pc, prefer)
	# parse le token utilisateur (EN/FR, avec accents)
	var p = _parse_letter_token(tok)
	if p.has("letter_index"):
		return p["letter_index"]
	# fallback
	var pc2 = hk.get_root_midi() % 12
	if pc2 < 0:
		pc2 += 12
	return _fallback_letter_from_pc(pc2, hk.get_prefer_sharps_hint())

# Fallback “clé raisonnable” (C#, F#, G♭, etc.)
static func _fallback_letter_from_pc(pc: int, prefer: int) -> int:
	# mapping simple qui colle aux armures usuelles
	# pc: 0 C,1 C#/Db,2 D,3 D#/Eb,4 E,5 F,6 F#/Gb,7 G,8 G#/Ab,9 A,10 A#/Bb,11 B
	# renvoie juste la lettre (pas l'altération) pour poser la grille des degrés
	if pc == 0:
		return 0 # C
	if pc == 2:
		return 1 # D
	if pc == 4:
		return 2 # E
	if pc == 5:
		return 3 # F
	if pc == 7:
		return 4 # G
	if pc == 9:
		return 5 # A
	if pc == 11:
		return 6 # B
	# altérés:
	if pc == 1:
		return 0 if prefer == 1 else 1  # C# ou Db -> lettre C ou D
	if pc == 3:
		return 1 if prefer == 1 else 2  # D# ou Eb -> D ou E
	if pc == 6:
		return 3 if prefer == 1 else 4  # F# ou Gb -> F ou G
	if pc == 8:
		return 4 if prefer == 1 else 5  # G# ou Ab -> G ou A
	if pc == 10:
		return 5 if prefer == 1 else 6  # A# ou Bb -> A ou B
	return 0

# Formate une lettre + altération vers EN/FR
static func _format_spelled(letter_index: int, acc: int, locale: String, use_unicode: bool) -> String:
	var base = ""
	if locale == "fr":
		base = _fr_letter_name(letter_index)
	else:
		base = _en_letter_name(letter_index)

	var acc_str = ""
	if acc > 0:
		if acc == 1:
			acc_str = "#"
		elif acc == 2:
			acc_str = "x" # double dièse; pour Unicode: 𝄪
		else:
			acc_str = String("#").repeat(acc)
	elif acc < 0:
		if acc == -1:
			acc_str = "b"
		elif acc == -2:
			acc_str = "bb" # double bémol; pour Unicode: 𝄫
		else:
			acc_str = String("b").repeat(-acc)

	if use_unicode:
		acc_str = acc_str.replace("x", "𝄪").replace("#", "♯").replace("bb", "♭♭").replace("b", "♭")

	return base + acc_str

# Noms de lettres
static func _en_letter_name(i: int) -> String:
	var names = ["C","D","E","F","G","A","B"]
	return names[i % 7]

static func _fr_letter_name(i: int) -> String:
	var names = ["do","ré","mi","fa","sol","la","si"]
	return names[i % 7]

# Parse une tonique saisie par l'utilisateur pour extraire la lettre (EN/FR)
static func _parse_letter_token(s: String) -> Dictionary:
	var t = _norm_simple(s)
	var candidates = ["sol","do","re","mi","fa","la","si","c","d","e","f","g","a","b"]
	for n in candidates:
		if t.begins_with(n):
			var idx = -1
			if n == "c" or n == "do":
				idx = 0
			elif n == "d" or n == "re":
				idx = 1
			elif n == "e" or n == "mi":
				idx = 2
			elif n == "f" or n == "fa":
				idx = 3
			elif n == "g" or n == "sol":
				idx = 4
			elif n == "a" or n == "la":
				idx = 5
			elif n == "b" or n == "si":
				idx = 6
			return {"letter_index": idx}
	return {}

# PC naturel (en demi-tons) d'une lettre dans C majeur (C=0,D=2,E=4,F=5,G=7,A=9,B=11)
static func _letter_pc_from_c_major(letter_index: int) -> int:
	var tbl = [0,2,4,5,7,9,11]
	return tbl[letter_index % 7]

# diff signé modulo 12 dans [-6..+5]
static func _signed_mod12(x: int) -> int:
	var r = x % 12
	if r < 0:
		r += 12
	if r > 6:
		r -= 12
	return r

# normalisation basique (minuscule, remplace ♯/♭, retire accents FR)
static func _norm_simple(s: String) -> String:
	var t = s.strip_edges().to_lower()
	t = t.replace("♯", "#").replace("♭", "b")
	t = t.replace("é", "e").replace("è", "e").replace("ê", "e").replace("ë", "e")
	t = t.replace("à", "a").replace("â", "a").replace("ä", "a")
	t = t.replace("î", "i").replace("ï", "i")
	t = t.replace("ô", "o").replace("ö", "o")
	t = t.replace("û", "u").replace("ü", "u")
	t = t.replace("ç", "c")
	return t






"""
# Exemples d'utilisation

print(NoteParser.midi_from_string("C"))       # 60
print(NoteParser.midi_from_string("C#"))      # 61
print(NoteParser.midi_from_string("Db"))      # 61
print(NoteParser.midi_from_string("Do"))      # 60
print(NoteParser.midi_from_string("Réb3"))    # 49 (or "Reb3")
print(NoteParser.midi_from_string("Sol#5"))   # 80
print(NoteParser.midi_from_string("B#3"))     # 60 (C4)
print(NoteParser.midi_from_string("Cb4"))     # 59 (B3)

print(NoteParser.midipitch2StringFR(60))                           # "do4"
print(NoteParser.midipitch2StringFR(60, false))                    # "do"
print(NoteParser.midipitch2StringFR(61, true, false))              # "réb4"
print(NoteParser.midipitch2StringFR(61, true, true, true))         # "ré♯4"
print(NoteParser.midipitch2StringFR(61, true, false, true, true))  # "reb4" (ASCII)

print(NoteParser.midipitch2String(60))                         # "C4"
print(NoteParser.midipitch2String(61))                         # "C#4"
print(NoteParser.midipitch2String(61, true, false))            # "Db4"
print(NoteParser.midipitch2String(73, true, false, true))      # "C♯5" (si prefer_sharps=true) / "D♭5" (si false)
print(NoteParser.midipitch2String(59, false))                  # "B"


## midipitch2StringInKey ! ###########

hk.set_from_string("Db major") # bémols préférés
print(NoteParser.midipitch2StringInKey(61, hk, "en")) # "Eb4" (pas "D#4")
print(NoteParser.midipitch2StringInKey(61, hk, "fr")) # "réb4" ou "ré♭4" selon use_unicode_accidentals

hk.set_from_string("C# minor") # dièses préférés
print(NoteParser.midipitch2StringInKey(61, hk, "en")) # "C#4"
print(NoteParser.midipitch2StringInKey(70, hk, "en")) # "A#4" (pas "Bb4")

hk.set_from_string("C major")  # naturel → fallback (dièses par défaut pour les altérations)
print(NoteParser.midipitch2StringInKey(66, hk, "en")) # "F#4"
print(NoteParser.midipitch2StringInKey(70, hk, "en")) # "A#4"


######################################################################
# NoteParser.gd — orthographe stricte dans une tonalité (EN/FR)
######################################################################

var hk = HarmonicKey.new()

hk.set_from_string("C# major")
print(NoteParser.midipitch2StringStrictInKey(65, hk, "en")) # "F#4" (pas "Gb4")
print(NoteParser.midipitch2StringStrictInKey(64, hk, "en")) # "E#4" (pas "F4")
print(NoteParser.spelling_table_in_key(hk, "en"))            # ["C#","D#","E#","F#","G#","A#","B#"]

hk.set_from_string("Gb major")
print(NoteParser.midipitch2StringStrictInKey(66, hk, "en")) # "Gb4" (pas "F#4")
print(NoteParser.spelling_table_in_key(hk, "en"))           # ["Gb","Ab","Bb","Cb","Db","Eb","F"]

hk.set_from_string("Ré mineur harmonique") # "D harmonic_minor"
print(NoteParser.midipitch2StringStrictInKey(62, hk, "fr")) # "ré4"
print(NoteParser.midipitch2StringStrictInKey(61, hk, "fr")) # "dod4" (C#) — dièse en contexte
print(NoteParser.midipitch2StringStrictInKey(70, hk, "fr")) # "la#4" (pas "sib4")


"""





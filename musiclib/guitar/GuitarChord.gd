extends Resource
class_name GuitarChord

const TAG = "GuitarChord"

const SELF_SCRIPT_PATH = "res://addons/musiclib/guitar/GuitarChord.gd"

# --- Données principales
export(String) var chord_name = ""					# ex: "Am", "G7", "F#m7b5"
export(int) var base_fret = 1						# 1 = sillet; >1 => on affiche "5fr" etc.
export(PoolIntArray) var frets = PoolIntArray()		# 6 valeurs (corde 6 -> 1). -1=muette, 0=à vide, n=frette relative à base_fret
export(PoolIntArray) var fingers = PoolIntArray()	# 6 valeurs (0=aucun, 1..4 = doigt)
export(Array) var barres = []						# [{ "fret": n, "from_string": 6, "to_string": 1 }, ...]
export(int) var root_pc = -1  # 0..11 ; si -1 => on tente de déduire


var time:float = 0 setget set_time,get_time
var beat_length:float = 1 setget set_beat_length, get_beat_length
var midiNotes:PoolIntArray = ([]) setget set_midiNotes, get_midiNotes
var notes:Array = [] setget set_notes,get_notes



# Accordage (MIDI) E2 A2 D3 G3 B3 E4 => [40,45,50,55,59,64]
export(PoolIntArray) var tuning = PoolIntArray([40, 45, 50, 55, 59, 64])

func to_dict() -> Dictionary:
	var d = {}
	d["chord_name"] = chord_name
	d["base_fret"] = base_fret
	d["frets"] = frets
	d["fingers"] = fingers
	d["barres"] = barres
	d["root_pc"] = root_pc
	
	return d
	


func set_time(t:float):
	time = t

func get_time()->float:
	return time

func set_beat_length(t:float):
	beat_length = t

func get_beat_length()->float:
	return beat_length
	
func set_midiNotes(p:PoolIntArray):
	LogBus.error(TAG,"midiNotes cannot be set !")

func get_midiNotes()->PoolIntArray:
	return midiNotes()
	
func set_notes(p:Array):
	LogBus.error(TAG,"GuitarChord notes cannot be set !")

func get_notes()->Array:
	var a = []
	for n in midiNotes():
		a.append(n)	
	return a


# --- Fabrique: depuis un dict tombatossals (1 position)

# Remplace ta fabrique par ceci (note: pas de type de retour explicite) :
static func from_tombatossals_position(chord_name: String, pos: Dictionary):
	# var gc = GuitarChord.new()	# <- PROVOQUE une cyclic reference dans ce fichier
	var gc = load(SELF_SCRIPT_PATH).new()	# <- OK: on n’emploie pas le nom de la classe
	gc.chord_name = chord_name
	
	if pos.has("baseFret"):
		gc.base_fret = int(pos["baseFret"])

	var f = []
	if pos.has("frets"):
		var arr = pos["frets"]
		for i in range(arr.size()):
			var v = arr[i]
			if typeof(v) == TYPE_STRING:
				if String(v).to_lower() == "x":
					f.append(-1)
				else:
					f.append(int(v))
			else:
				f.append(int(v))
	gc.frets = PoolIntArray(f)

	var fing = []
	if pos.has("fingers"):
		var arr2 = pos["fingers"]
		for i in range(arr2.size()):
			fing.append(int(arr2[i]))
	else:
		for i in range(6):
			fing.append(0)
	gc.fingers = PoolIntArray(fing)

	gc.barres = []
	if pos.has("barres"):
		var b = pos["barres"]
		if typeof(b) == TYPE_ARRAY:
			for bb in b:
				if typeof(bb) == TYPE_DICTIONARY:
					var d = { "fret": int(bb.get("fret", 0)), "from_string": int(bb.get("fromString", 6)), "to_string": int(bb.get("toString", 1)) }
					gc.barres.append(d)

	return gc

# --- Utilitaires
func is_valid() -> bool:
	return frets.size() == 6 and fingers.size() == 6
	
# "x02210" si toutes <10 ; sinon "x 10 12 12 10 10"
func tab_string_compact() -> String:
	if not is_valid():
		return ""
	var tokens = []
	for i in range(6):
		var v = int(frets[i])
		if v < 0:
			tokens.append("x")
		elif v == 0:
			tokens.append("0")
		else:
			tokens.append(str(v))
	# si toutes sur un seul caractère -> concat sans espaces
	var single = true
	for t in tokens:
		if String(t).length() > 1:
			single = false
			break
	if single:
		return "".join(tokens)
	return String(" ").join(tokens)

# --- Conversion en notes MIDI (toutes les cordes non muettes)
func midiNotes() -> PoolIntArray:
	var out = []
	if not is_valid():
		return PoolIntArray(out)
	for s in range(6):	# 0..5 correspond corde 6..1
		var fret_rel = int(frets[s])
		if fret_rel < 0:
			continue
		var open_midi = int(tuning[s])
		if fret_rel == 0:
			out.append(open_midi)
		else:
			# fret absolue = (base_fret - 1) + fret_rel
			var add = (base_fret - 1) + fret_rel
			out.append(open_midi + add)
	return PoolIntArray(out)



# --- Conversion en notes MIDI (toutes les cordes non muettes)
func midiNotes_with_string() -> Array:
	var out = []
	if not is_valid():
		return []
	for s in range(6):	# 0..5 correspond corde 6..1
		var fret_rel = int(frets[s])
		if fret_rel < 0:
			continue
		var open_midi = int(tuning[s])
		if fret_rel == 0:
			var n = {"string":s, "midi":open_midi}
			out.append(n)
			#out.append(open_midi)
		else:
			# fret absolue = (base_fret - 1) + fret_rel
			var add = (base_fret - 1) + fret_rel
			var n = {"string":s, "midi":open_midi + add}
			out.append(n)
	return out



# Pitch-class de la fondamentale (0=C, 1=C#/Db, ..., 11=B)
func root_pitch_class() -> int:
	if root_pc >= 0:
		return root_pc

	var name = String(chord_name).strip_edges()
	# coupe la basse éventuelle: "F#maj7/A" -> "F#maj7"
	var slash = name.find("/")
	if slash >= 0:
		name = name.substr(0, slash)

	if name.length() == 0:
		return -1

	# Lettre initiale
	var tonic = name.substr(0, 1).to_upper()

	# Accidentel juste APRÈS la lettre: "#", "b", "♯", "♭", ou mots "sharp"/"flat"
	if name.length() > 1:
		var rest = name.substr(1, name.length() - 1)
		var rl = rest.to_lower()
		if rest.begins_with("#") or rest.begins_with("♯"):
			tonic += "#"
		elif rest.begins_with("b") or rest.begins_with("♭"):
			tonic += "b"
		elif rl.begins_with("sharp"):
			tonic += "#"
		elif rl.begins_with("flat"):
			tonic += "b"

	root_pc = _pc_from_note_name_local(tonic)
	return root_pc
	

# Indices (corde) où la fondamentale est jouée (pour colorer en rouge)
func strings_with_root() -> PoolIntArray:
	var pcs = []
	var roots = []
	var root_pc = root_pitch_class()
	if root_pc < 0:
		return PoolIntArray(roots)
	var notes = midiNotes()
	# notes est dans l'ordre corde 6..1 mais avec muettes retirées; on veut repérer sur les 6 cordes.
	# On recalcule par corde.
	for s in range(6):
		var fret_rel = int(frets[s])
		if fret_rel < 0:
			continue
		var midi_val = 0
		if fret_rel == 0:
			midi_val = int(tuning[s])
		else:
			var add = (base_fret - 1) + fret_rel
			midi_val = int(tuning[s]) + add
		var pc = midi_val % 12
		if pc == root_pc:
			roots.append(s)	# s=0 (corde6) ... 5 (corde1)
	return PoolIntArray(roots)
# Clé canonique pour comparer 2 voicings (absolutise les frettes)
# ignore_fingers=true si tu veux ignorer les doigtés et ne dédupliquer que les positions.
# Remplace TOUTE la fonction par ceci
func canonical_key(ignore_fingers = false):
	var abs_frets = []
	for s in range(frets.size()):
		var fr = int(frets[s])
		if fr < 0:
			abs_frets.append("x")
		elif fr == 0:
			abs_frets.append("0")
		else:
			# frette absolue sur le manche
			abs_frets.append(str((base_fret - 1) + fr))

	var k = "F:" + String(",".join(abs_frets))

	if (not ignore_fingers) and fingers.size() == 6:
		var fing = []
		for i in range(6):
			fing.append(str(int(fingers[i])))
		k += "|D:" + String(",".join(fing))

	# Barres (normalisées)
	if barres != null and barres.size() > 0:
		var bparts = []
		for b in barres:
			if typeof(b) == TYPE_DICTIONARY:
				var fret_rel = int(b.get("fret", 0))
				var fret_abs = 0
				if fret_rel > 0:
					fret_abs = (base_fret - 1) + fret_rel
				var s1 = int(b.get("from_string", 6))
				var s2 = int(b.get("to_string", 1))
				var smin = s1
				var smax = s2
				if smin > smax:
					var tmp = smin
					smin = smax
					smax = tmp
				bparts.append(str(fret_abs) + ":" + str(smin) + "-" + str(smax))
		if bparts.size() > 0:
			k += "|B:" + String(",".join(bparts))

	return k

func clone():
	var c = get_script().new()
	c.chord_name = chord_name
	c.base_fret = base_fret

	# PoolIntArray -> copie par construction
	c.frets = PoolIntArray(frets)
	c.fingers = PoolIntArray(fingers)
	c.tuning = PoolIntArray(tuning)

	# barres = Array de Dictionary -> deep copy simple
	var b = []
	for v in barres:
		if typeof(v) == TYPE_DICTIONARY:
			var d = {
				"fret": int(v.get("fret", 0)),
				"from_string": int(v.get("from_string", 6)),
				"to_string": int(v.get("to_string", 1))
			}
			b.append(d)
	c.barres = b
	return c

func to_string() -> String:
	return "GuitarChord{" + chord_name + ", bf=" + str(base_fret) + ", frets=" + str(frets) + ", fingers=" + str(fingers) + "}"

# --- Helpers nom→pitch class (0..11)
func _pc_from_note_name_local(s: String) -> int:
	var t = String(s).strip_edges()
	if t == "":
		return -1
	# normalise
	t = t.replace("♯", "#").replace("♭", "b")
	var tl = t.to_lower()

	# accepte ...sharp / ...flat
	if tl.length() >= 6 and tl.ends_with("sharp"):
		t = String(t.substr(0, 1)).to_upper() + "#"
	elif tl.length() >= 4 and tl.ends_with("flat"):
		t = String(t.substr(0, 1)).to_upper() + "b"
	else:
		var head = t.substr(0, 1).to_upper()
		var tail = ""
		if t.length() > 1:
			tail = t.substr(1, t.length() - 1)
		t = head + tail

	var map = {
		"C":0, "B#":0,
		"C#":1, "Db":1,
		"D":2,
		"D#":3, "Eb":3,
		"E":4, "Fb":4,
		"F":5, "E#":5,
		"F#":6, "Gb":6,
		"G":7,
		"G#":8, "Ab":8,
		"A":9,
		"A#":10, "Bb":10,
		"B":11, "Cb":11
	}
	if map.has(t):
		return int(map[t])
	return -1

# --- Représentation ASCII tab (EADGBE) + nom d'accord + barres
func get_ascii_tab() -> String:
	if not is_valid():
		return ""
	
	var lines = []
	var string_names = ["E", "A", "D", "G", "B", "e"]
	
	# Construire les lignes corde par corde (6 -> 1)
	for i in range(6):
		var fret_val = int(frets[i])
		var sname = string_names[i]
		var fret_txt = ""
		
		if fret_val < 0:
			fret_txt = "x"
		elif fret_val == 0:
			fret_txt = "0"
		else:
			# Frette absolue = (base_fret - 1) + fret_rel
			fret_txt = str((base_fret - 1) + fret_val)
			# Frette relative =  fret_rel
			#fret_txt = str(fret_val)
		
		var line = sname + "|---" + fret_txt + "---"
		lines.append(line)
	
	# Inverser pour affichage guitare (E aiguë en haut)
	lines.invert()
	
	# Ajouter infos de barres si présentes
	var bar_lines = []
	if barres.size() > 0:
		for b in barres:
			if typeof(b) == TYPE_DICTIONARY:
				var fret_abs = (base_fret - 1) + int(b.get("fret", 0))
				
				var from_s = int(b.get("from_string", 6))
				var to_s = int(b.get("to_string", 1))
				bar_lines.append("Barre " + str(fret_abs) + "fr: " + str(from_s) + "→" + str(to_s))
	
	# Nom de l'accord en en-tête
	var out = ""
	if chord_name != "":
		out += chord_name + "\n\n"
	
	out += "\n".join(lines)
	
	if bar_lines.size() > 0:
		out += "\n".join(bar_lines)
	
	#if base_fret > 1:
	#	out+= "\n\nFret: " + str(base_fret)
	
	return out


func is_string_muted(i):
	return false
	#return (frets[i] == -1)


# retourne 2 notes de basse [b1,b2] b1 est la fondamentale (en principe)
# si accord de 4 notes on renvoie [b1,b1]
func get_bass_notes()->Array:
	var notes = []
	var root = root_pitch_class()
	var chord_notes = []
	for m in midiNotes():
		chord_notes.append(m)
	
	if chord_notes.size() < 5:
		var b1 = chord_notes[0]
		return [b1,b1]
	else :
		var b1 = chord_notes[0]
		var b2 = chord_notes[1]
		if b1 % 12  == root % 12:
			return [b1,b2]
		else :
			return [b2,b1]

# retourne 2 notes de basse [b1,b2] b1 est la fondamentale (en principe)
# si accord de 4 notes on renvoie [b1,b1]
func get_bass_notes_with_string()->Array:
	var notes = []
	var root = root_pitch_class()
	var chord_notes = []
	for e in midiNotes_with_string():
		chord_notes.append(e)
	
	if chord_notes.size() < 5:
		var b1 = chord_notes[0]
		return [b1,b1]
	else :
		var b1 = chord_notes[0]
		var b2 = chord_notes[1]
		if b1["midi"] % 12  == root % 12:
			return [b1,b2]
		else :
			return [b2,b1]

func get_arp_note(idx:int)-> int:
	var notes = midiNotes()
	var size = midiNotes().size()
	match idx:
			4: return notes[-1]
			3: return notes[-(2 % size)]
			2: return notes[-(3 % size)]
			1: return notes[-(4 % size)]
			0:
				if notes.size() > 4:
					return notes[-5]
				else:
					return notes[-4]
			_:
				return notes[idx % size]
		
		
func get_arp_note_with_string(idx:int)-> Dictionary:
	var notes = midiNotes_with_string()
	match idx:
			4: return notes[-1]
			3: return notes[-2]
			2: return notes[-3]
			1: return notes[-4]
			0: 
				if notes.size() > 4:
					return notes[-5]
				else:
					return notes[-4]
			_:
				return notes[idx % notes.size()]

func get_tab_absolute_as_array()->Array:
	var tab = []
	for s in range(0,6):
		if frets[s] == -1:
			tab.append("x")
		else :
			tab.append(str(- 1 + frets[s] + base_fret))
			
	return tab
	

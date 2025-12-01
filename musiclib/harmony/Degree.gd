extends Reference
class_name Degree

# Objet Degree 

const DEFAULT_MIDI_CHANNEL = 0	# canal 0
const DEFAULT_MIDI_VELOCITY = 120	# vélocité 100
const TAG = "Degree"


# dictionnaire des realizations possibles avecles extensions
const EXTENSIONS_ARRAY:Dictionary = {
	"":[1,3,5], 
	"add6":[1,5,6,8],
	"7":[1,3,5,7],
	"9":[1,3,7,9]	,	
	"11":[1,5,7,11],
	"#9":[1,3,7,9], # alteration accord 2#
	"b9":[1,3,7,9], # alteration accord b2
	"b7#9":[1,5,7,9] # alteration accord b7 et #2
	}
				


#	Major scales par classe de hauteur MIDI (0=C ... 11=B)
const MIDI_ROOT_TO_NOTES_OF_MAJOR_SCALE = {
	0: ["C", "D", "E", "F", "G", "A", "B"],						# C major
	1: ["Db", "Eb", "F", "Gb", "Ab", "Bb", "C"],					# Db major
	2: ["D", "E", "F#", "G", "A", "B", "C#"],						# D major
	3: ["Eb", "F", "G", "Ab", "Bb", "C", "D"],						# Eb major
	4: ["E", "F#", "G#", "A", "B", "C#", "D#"],						# E major
	5: ["F", "G", "A", "Bb", "C", "D", "E"],						# F major
	6: ["Gb", "Ab", "Bb", "Cb", "Db", "Eb", "F"],					# Gb major
	7: ["G", "A", "B", "C", "D", "E", "F#"],						# G major
	8: ["Ab", "Bb", "C", "Db", "Eb", "F", "G"],						# Ab major
	9: ["A", "B", "C#", "D", "E", "F#", "G#"],						# A major
	10: ["Bb", "C", "D", "Eb", "F", "G", "A"],						# Bb major
	11: ["B", "C#", "D#", "E", "F#", "G#", "A"]						# B major
}



var key:HarmonicKey = HarmonicKey.new() setget set_key,get_key
# indice du degré dans la tonalité ex: Tonique -> 1
var degree_number:int = 1 setget set_degree_number, get_degree_number
# _realization du degré -> tableau contenant les degrés exprimés
#var _realization:Array = [1,3,5]

var realization:Array = [1,3,5] setget set_realization, get_realization
# kind -> définit le type de l'accord (diatonic, secondary, N6, etc...)
var kind:String = "diatonic" setget set_kind , get_kind
# Altérations de l'accord -> Dictionnaire degré:alteration 
# Par ex: {3:-1} -> les altérations sont celles de la tonalité
# elles sont appliquées après la réalization de l'accord
# elles peuvent être définies par set_chord_alteration ou set_key_altération
# mais jamais accessibles directement
# l'interface est _set_chord_altération(degre
var _alterations:Dictionary = {} setget _set_alterations, _get_alterations
# Altérations dans la tonalité -> Dictionnaire degré:alteration 
# par ex, pour la sensible de la gamme mineure, ou peut avoir {7:1}

var inversion:int = 0 setget set_inversion, get_inversion
# extension : 9eme ou 11eme ou 13eme UNE SEULE POSSIBLE A LA FOIS

var length_beats:float = 4 setget set_length_beats, get_length_beats
# func -> fonction harmonique "T" "PD" "D" "?"
var harmonic_function:String ="T" setget set_harmonic_function, get_harmonic_function
# plan_data pour stocker les infos du générateur
#var plan_data:Dictionary  = {} setget set_plan_data, get_plan_data

# adaptateur progressionGenerators
#jazz_chord
var override_jazz_chord:String = "" setget set_override_jazz_chord, get_override_jazz_chord

# chord_midi
var override_chord_midi:Array = [] setget set_override_chord_midi, get_chord_midi
# octave
var _octave:int = 0 setget set_octave, get_octave

# booleen pour l'affichage degree secondaire (ajoute une barre "/" après roman numeral
var _is_secondary:bool = false 

# si kind "sus2" ou kind "sus4" -> sus = "sus2" ou "sus4"
#var sus:String = ""

var _secondary_roman_spelling = ""

# right click current satb 
var satb:Array= [] 

# index du current satb > debug
var satb_index:int = 0 

# tableau des tableaux satb > debug
var satb_objects:Array= [] 

var enharmonic_string:String = ""

# dictionnaire retour de satb_progression -> charges les satb possibles
var satb_dictionary:Dictionary = {}


var comment:String = ""

var chord_voicing_index:int = 0

########### CLONE ET TO STRING ##############

func clone()-> Degree:

	var d:Degree = get_script().new()
	d.key = key
	d.degree_number = degree_number
	d.realization = realization
	d.kind = kind
	d._alterations = _alterations
	d.inversion = inversion
	d.length_beats = length_beats
	d.harmonic_function = harmonic_function
	#d.plan_data = plan_data
	d._secondary_roman_spelling = _secondary_roman_spelling
	d.override_jazz_chord = override_jazz_chord
	d.override_chord_midi = override_chord_midi
	d._octave = _octave
	d._is_secondary = _is_secondary
	d.enharmonic_string = enharmonic_string
	
	# SATB
	d.satb = satb
	d.satb_objects = satb_objects
	d.satb_dictionary = satb_dictionary
	d.satb_index = satb_index
	
	# String comment
	d.comment = comment
	d.chord_voicing_index = chord_voicing_index
	
	return d
	
	
func to_dict() -> Dictionary:
	var d:Dictionary = {}
	
	# --- Key (HarmonicKey) ---
	var key_dict:Dictionary = {}
	if key != null and typeof(key) == TYPE_OBJECT:
		if key.has_method("to_dict"):
			# on laisse HarmonicKey décider de sa propre sérialisation
			key_dict = key.to_dict()
		else:
			key_dict["scale_name"] = key.scale_name
			key_dict["root_midi"] = key.root_midi
	d["key"] = key_dict
	
	# --- Propriétés de base du Degree ---
	d["degree_number"] = degree_number
	d["realization"] = realization.duplicate()
	d["kind"] = kind
	d["enharmonic_string"] = enharmonic_string
	# Altérations accord
	d["alterations"] = _alterations.duplicate()
	d["inversion"] = inversion
	
	# Durée + fonction harmonique
	d["length_beats"] = length_beats
	d["harmonic_function"] = harmonic_function
	
	# Données du générateur / plan
	# Si tu es sûr que plan_data ne contient que des types simples,
	# tu peux décommenter la ligne suivante.
	# d["plan_data"] = plan_data.duplicate()
	
	# Overrides éventuels
	d["override_jazz_chord"] = override_jazz_chord
	d["override_chord_midi"] = override_chord_midi.duplicate()
	
	# Contexte de hauteur / secondaire
	d["octave"] = _octave
	d["is_secondary"] = _is_secondary
	d["secondary_roman_spelling"] = _secondary_roman_spelling
	
	# SATB + structures associées
	d["satb"] = satb.duplicate(true)
	d["satb_index"] = satb_index
	d["satb_objects"] = satb_objects.duplicate(true)
	d["satb_dictionary"] = satb_dictionary.duplicate(true)
	
	# Commentaire texte
	d["comment"] = comment
	d["chord_voicing_index"] = chord_voicing_index
	
	return d


func from_dict(data:Dictionary) -> Degree:
	var d:Degree = get_script().new()
	
	# --- Key (HarmonicKey) ---
	if data.has("key"):
		var kdata = data["key"]
		if typeof(kdata) == TYPE_DICTIONARY:
			var hk:HarmonicKey = HarmonicKey.new()
			if hk.has_method("from_dict"):
				hk = hk.from_dict(kdata)
			else:
				hk.scale_name = str(kdata.get("scale_name", hk.scale_name))
				hk.root_midi = int(kdata.get("root_midi", hk.root_midi))
			d.set_key(hk)
	
	# --- Propriétés de base du Degree ---
	if data.has("degree_number"):
		d.set_degree_number(int(data["degree_number"]))
	
	if data.has("realization"):
		var r = data["realization"]
		if typeof(r) == TYPE_ARRAY:
			var arr = []
			for i in r:
				arr.append(int(i))
			d.realization = arr
	
	if data.has("kind"):
		d.set_kind(str(data["kind"]))
	
	# Altérations accord
	if data.has("alterations"):
		var alt = data["alterations"]
		if typeof(alt) == TYPE_DICTIONARY:
			d._set_alterations(alt.duplicate())
	
	if data.has("inversion"):
		d.set_inversion(int(data["inversion"]))
	
	# Durée + fonction harmonique
	if data.has("length_beats"):
		d.set_length_beats(float(data["length_beats"]))
	
	if data.has("harmonic_function"):
		d.set_harmonic_function(str(data["harmonic_function"]))

	if data.has("enharmonic_string"):
		d.enharmonic_string = str(data["enharmonic_string"])
	
	# Données du générateur / plan (optionnel)
	if data.has("plan_data"):
		var pd = data["plan_data"]
		if typeof(pd) == TYPE_DICTIONARY:
			d.set_plan_data(pd.duplicate())
	
	# Overrides éventuels
	if data.has("override_jazz_chord"):
		d.set_override_jazz_chord(str(data["override_jazz_chord"]))
	
	if data.has("override_chord_midi"):
		var ocm = data["override_chord_midi"]
		if typeof(ocm) == TYPE_ARRAY:
			d.set_override_chord_midi(ocm.duplicate())
	
	# Contexte de hauteur / secondaire
	if data.has("octave"):
		d.set_octave(int(data["octave"]))
	
	if data.has("is_secondary"):
		d._is_secondary = bool(data["is_secondary"])
	
	if data.has("secondary_roman_spelling"):
		d._secondary_roman_spelling = str(data["secondary_roman_spelling"])
	
	# SATB + structures associées
	if data.has("satb"):
		var s = data["satb"]
		if typeof(s) == TYPE_ARRAY:
			d.satb = s.duplicate(true)
	
	if data.has("satb_index"):
		d.satb_index = int(data["satb_index"])
	
	if data.has("satb_objects"):
		var so = data["satb_objects"]
		if typeof(so) == TYPE_ARRAY:
			d.satb_objects = so.duplicate(true)
	
	if data.has("satb_dictionary"):
		var sd = data["satb_dictionary"]
		if typeof(sd) == TYPE_DICTIONARY:
			d.satb_dictionary = sd.duplicate(true)
	
	# Commentaire texte
	if data.has("comment"):
		d.comment = str(data["comment"])
		
	# Commentaire texte
	if data.has("chord_voicing_index"):
		d.chord_voicing_index = int(data["chord_voicing_index"])
	
	return d

func _set_alterations(d:Dictionary = {}):
	_alterations = d

func _get_alterations():
	return _alterations

func get_degree_note_names(chord_degre_number) :
	if key.scale_name == "major":
		var root_midi_norm = key.root_midi % 12
		var key_notes_string = MIDI_ROOT_TO_NOTES_OF_MAJOR_SCALE[root_midi_norm]
		return key_notes_string[(chord_degre_number - 1) % 7]
		



func to_string() -> String:
	var degree_roman = key.roman_triad(degree_number)
	var txt = "Degree: " + degree_roman + " of key: " + key.to_string() + "(" + str(key.root_midi) + ")"
	txt += ", Duration: "+str(length_beats)+ " beats"
	txt += ", harmonic function: "+harmonic_function + "\n"
	
	var kind_txt = kind
	if _is_secondary:
		kind_txt += " (secondary chord)"
	
	var _inversion = -1
	if inversion > -1:
		_inversion = inversion
	
	txt += "kind: "+ kind_txt + ", realization: "	+ str(realization)
	
	if enharmonic_string != "":
		txt += ", enharmonic: "+ enharmonic_string

	txt += ", inversion: "+ str(_inversion)
	if _octave != 0:
		txt += ", octave: "+ str(_octave)
	if _alterations.empty() == false :
		txt += ", alterations: "+ str(_alterations) 
	txt += "\nRoman Numeral: "+get_roman_numeral()
	txt += ", jazz chord: " + get_jazz_chord()
	var midis = get_chord_midi()
	txt += ", midi: "+ str(midis)
	
		
	# on traduit le midi en notes
	var notes_txt = []
	
	for m in midis:
		notes_txt.append(NoteParser.midipitch2String(m))
	txt += " -> "+str(notes_txt)
	
	# SATB
	if satb.size() > 0:
		var satb_arr = []
		for m in satb:
			satb_arr.append(NoteParser.midipitch2StringStrictInKey(m,key,"en"))
		txt += ", SATB: " + str(satb_arr)
		
		
	# comment
	if comment != "":
		txt += "\n\n-> "+ comment
	
	return txt


########### GETTERS SETTERS ##############
func set_override_jazz_chord(s:String):
	override_jazz_chord = s

func get_override_jazz_chord():
	return override_jazz_chord


func set_override_chord_midi(arr:Array):
	override_chord_midi = arr

func get_override_chord_midi() -> Array:
	return override_chord_midi

func set_octave(oct = 0):
	_octave = oct

func get_octave():
	return _octave

func set_key(k:HarmonicKey):
	key = k.clone()

func get_key() -> HarmonicKey:
	return key

func set_degree_number(d=1):
	if d < 1 :
		LogBus.error("Degree","set_degree_number with a value of " + str(d) + " !")
		d = 1
	# harmonic_function
	if kind == "diatonic" :
		if d == 1 or d == 6 or d == 3:
			harmonic_function = "T"
		elif d == 5 or d == 7 :
			harmonic_function = "D"
		else:
			harmonic_function = "PD"
	degree_number = d
	

func get_degree_number():
	return degree_number




func set_realization(arr:Array):
	if arr.empty() or arr == null:
		LogBus.error("Degree","set_realization with an empty or null array !")
	elif (1 in arr) == false :
		LogBus.error("Degree","set_realization is missing 1 !")
		print(str(arr))
		
	else :
		if arr.size() == 3 or arr.size() == 4:
			realization = arr
			return
		else: LogBus.error(TAG,"set_realization -> bad length, arr = " + str(arr))	
	

func get_realization():
	return realization

func set_kind(k:String):
	# bérifie que le kind existe bien
	var kinds = ["melodic","diatonic","secondary","It+6","Fr+6","Ger+6", "It+6inv","Fr+6inv","Ger+6inv", "N6","chrom.","cad64","sus2","sus4","add9","add11"]
	if kinds.has(k):
		kind = k
		match kind:
			"it+6": set_aug6_It()
			"Fr+6": set_aug6_Fr()
			"Ger+6": set_aug6_Ger()			
			"it+6Inv": set_aug6_It_inv()
			"Fr+6Inv": set_aug6_Fr_inv()
			"Ger+6Inv": set_aug6_Ger_inv()
			
			
	else:
		LogBus.error("Degree","set_kind of unknown kind ! -> "+ k)
	
func get_kind() -> String:
	return kind	



func set_chord_alteration(degree:int, alter:int):
	var deg_key = 1 + (degree + degree_number -2) % 7
	set_key_alteration(deg_key,alter)
		
			
		
	
func get_chord_alteration(degree:int) -> int:
	var deg_key = 1 + ( (degree + degree_number - 2) %7)
	if _alterations.has(deg_key):
			return _alterations[deg_key]
	else :
		return 0

func set_key_alteration(degree,alter):
	_alterations[degree] = alter

func get_key_alteration(degree) -> int:

	var d = 1 + ((degree + 6) % 7)
	if _alterations.has(d):
		return _alterations[d]
	else:
		return 0
		
func set_inversion(inv:int):
	if inv == -1:
		inversion = -1
		return
	
	if realization.size() > 0 :
		inversion = inv % realization.size()
	else:
		inversion = inv	
func get_inversion() -> int:
	return inversion


func set_length_beats(l:float = 1.0):
	length_beats = max(0,l)
	
func get_length_beats():
	return length_beats

func set_harmonic_function(f:String = "?"):
	if ["T","PD","D"].has(f):
		harmonic_function = f 
	else:
		harmonic_function = "?"

func get_harmonic_function() -> String:
	return harmonic_function
	
#func set_plan_data(pd:Dictionary) :
#	plan_data = pd
#
#func get_plan_data():
#	return plan_data
#
## Convertit plan_data en texte
#func get_plan_data_JSON() -> String:
#	var PDText = JSON.print(plan_data, "\t")
#	return PDText
	
####################### Methodes #################



func reset():
	kind = "diatonic"
	realization = [1,3,5]
	_alterations = {}
	_octave = 0
	inversion = 0
	degree_number = 1
	_is_secondary = false
	harmonic_function = "T"
	enharmonic_string = ""
	comment = ""


# C'est le premier degré de la tonalité majeure un 1/2 ton au dessus	
func set_N6():
	#_octave = -1
	var oct = _octave
	var old_key = key
	reset()
	# on restaure key
	_octave = oct
	key = old_key
	kind = "N6"
	degree_number = 2
	set_key_alteration(2,-1)
	if key.scale_name == "major" or key.scale_name == "melodic_minor":
		set_key_alteration(6,-1)
	realization = [1,3,5]
	inversion = 1
	harmonic_function = "PD"

func set_add9():
	var n = degree_number
	reset()
	kind = "add9"
	realization = [1,3,7,9]
	degree_number = n
	
func set_add11():
	var n = degree_number
	reset()
	kind = "add11"
	realization = [1,5,7,11]
	degree_number = n

func set_melodic():
	realization = [1]
	kind = "melodic"

# C'est le premier degré de la tonalité majeure un 1/2 ton au dessus	
func set_cad64():
	reset()
	kind = "cad64"
	degree_number = 1
	inversion = 2
	#_octave = -1
	harmonic_function = "PD"



# pour les Sixtes augmentées, 
# on évite les altérations Meme méthode que pour N6, 
# on se décale sur la tonalité un demi-ton au dessous
func set_aug6_It():
#	if ["minor", "harmonic_minor","melodic_minor","major"].has( key.get_scale_name()) == false:
#		LogBus.error(TAG,"It+6 is only available in minor/major")
#		return
	var oct = _octave
	var old_key = key
	reset()
	_octave = oct
	key = old_key
	kind = "It+6"
	degree_number = 4
	realization = [1,3,5]
	inversion = 1
	var scale_name = key.scale_name
	set_key_alteration(4,1)
	# si minor on ne touche pas à la sixte de la tonalité
	if scale_name == "major" or scale_name == "melodic_minor" :
		set_key_alteration(6,-1)
	harmonic_function = "PD"


func set_aug6_Fr():
#	if ["minor", "harmonic_minor","melodic_minor","major"].has( key.get_scale_name()) == false:
#		LogBus.error(TAG,"It+6 is only available in minor/major")
#		return
	var oct = _octave
	var old_key = key
	reset()
	_octave = oct
	key = old_key
	kind = "Fr+6"
	degree_number = 4
	realization = [1,3,5,6]
	inversion = 1
	var scale_name = key.scale_name
	set_key_alteration(4,1)
	# si minor on ne touche pas à la sixte de la tonalité
	if scale_name == "major" or scale_name == "melodic_minor" :
		set_key_alteration(6,-1)
	harmonic_function = "PD"

func set_aug6_Ger():
#	if ["minor", "harmonic_minor","melodic_minor","major"].has( key.get_scale_name()) == false:
#		LogBus.error(TAG,"It+6 is only available in minor/major")
#		return
	var oct = _octave
	var old_key = key
	reset()
	_octave = oct
	key = old_key
	kind = "Ger+6"
	degree_number = 4
	realization = [1,3,5,7]
	inversion = 1
	var scale_name = key.scale_name
	# Dans tous le cas
	set_key_alteration(4,1)
	if scale_name == "major":
		set_key_alteration(3,-1)

	# si minor on ne touche pas à la sixte de la tonalité
	if scale_name == "major" or scale_name == "melodic_minor" :
		set_key_alteration(6,-1)
	harmonic_function = "PD"


func set_aug6_It_inv():
#	if ["minor", "harmonic_minor","melodic_minor","major"].has( key.get_scale_name()) == false:
#		LogBus.error(TAG,"It+6 is only available in minor/major")
#		return
	var oct = _octave
	var old_key = key
	reset()
	_octave = oct
	key = old_key
	kind = "It+6inv"
	degree_number = 4
	realization = [1,3,5]
	inversion = 0
	var scale_name = key.scale_name
	set_key_alteration(4,1)
	# si minor on ne touche pas à la sixte de la tonalité
	if scale_name == "major" or scale_name == "melodic_minor" :
		set_key_alteration(6,-1)
	harmonic_function = "PD"


func set_aug6_Fr_inv():
#	if ["minor", "harmonic_minor","melodic_minor","major"].has( key.get_scale_name()) == false:
#		LogBus.error(TAG,"It+6 is only available in minor/major")
#		return
	var oct = _octave
	var old_key = key
	reset()
	_octave = oct
	key = old_key
	kind = "Fr+6inv"
	degree_number = 4
	realization = [1,3,5,6]
	inversion = 0
	var scale_name = key.scale_name
	# Dans tous le cas
	set_key_alteration(4,1)
	# si minor on ne touche pas à la sixte de la tonalité
	if scale_name == "major" or scale_name == "melodic_minor" :
		set_key_alteration(6,-1)
	harmonic_function = "PD"

func set_aug6_Ger_inv():
#	if ["minor", "harmonic_minor","melodic_minor","major"].has( key.get_scale_name()) == false:
#		LogBus.error(TAG,"It+6 is only available in minor/major")
#		return
	var oct = _octave
	var old_key = key
	reset()
	_octave = oct
	key = old_key
	kind = "Ger+6inv"
	degree_number = 4
	realization = [1,3,5,7]
	inversion = 0
	var scale_name = key.scale_name
	# Dans tous le cas
	set_key_alteration(4,1)
	if scale_name == "major":
		set_key_alteration(3,-1)

	# si minor on ne touche pas à la sixte de la tonalité
	if scale_name == "major" or scale_name == "melodic_minor" :
		set_key_alteration(6,-1)
	harmonic_function = "PD"


func set_sus2():

	var n = degree_number
	reset()
	kind = "sus2"
	degree_number = n
	realization[1] = 2
	# on check seconde mineure sur 2
	var degre_dans_l_accord = 2

	var midi_degre_1 = key.degree_midi(degree_number) + get_key_alteration(1)
	var midi_degre_2 = key.degree_midi(degree_number + 1) + get_key_alteration(2)
	if midi_degre_2 - midi_degre_1 == 1:
		set_chord_alteration(2,1)

func set_sus4():
	var n = degree_number
	reset()
	kind = "sus4"
	degree_number = n
	realization[1] = 4



func has_seventh() -> bool:
	return realization.has(7)
	
####################### Conversions ##############

func get_jazz_chord() -> String :
	var basePitch =  NoteParser.midipitch2StringStrictInKey(int(get_chord_midi()[0])%12,key,"en",false)
	var res = get_chord_and_scale(get_chord_midi(), (key.root_midi) % 12  )
	if ["It+6","Fr+6","Ger+6" ].has(kind):
		
		match kind:
			"It+6":
				return basePitch+"7"
			"Fr+6":
				return basePitch+"7b5"
			_:
				return basePitch+"7"
	if ["It+6inv","Fr+6inv","Ger+6inv" ].has(kind):
		var invbassPitch =  NoteParser.midipitch2StringStrictInKey(int(get_chord_midi()[1])%12,key,"en",false)
		match kind:
			"It+6inv":
				return invbassPitch+"7no5/" + basePitch
			"Fr+6inv":
				return invbassPitch+"7b5/" + basePitch
			_:
				return invbassPitch+"7/" + basePitch
	
	if kind == "add9":
		if third_distance() == 3 :		
			return basePitch+"m9"
		else:
			return basePitch+"9"
	if kind == "add11":
		if third_distance() == 3 :		
			return basePitch+"m11"
		else:
			return basePitch+"11"
	
	#"It+6inv","Fr+6inv","Ger+6inv"
	if res != null :
		return str(res["string"])
	else:
		# rattrapage pour le faire à la main...
		var root_txt

		#static func midipitch2StringStrictInKey(midi: int, hk, locale: String = "en", include_octave: bool = true, use_unicode_accidentals: bool = false) -> String:
		root_txt = NoteParser.midipitch2StringStrictInKey(int(get_chord_midi()[0])%12,key,"en",false)
		
		# triades funky...
		if realization.size()  == 3 :
			if third_distance() == 4 and fifth_distance() == 6:
				return root_txt+" b5"
				
		
		
		
		
		var q = triad_quality()
		var quality_txt = ""
		
		if kind == "sus2":
			quality_txt = "sus2"
		elif kind == "sus4":
			quality_txt = "sus4"
		match q:
			"dim":
				quality_txt = "dim"
			"min":
				quality_txt = "m"
			"maj":
				quality_txt = ""
			"aug":
				quality_txt = "aug"
		
		
		if realization == [1,3,7,9] : 			
			# Neuvieme
			return root_txt + quality_txt + "9"	
		elif realization == [1,5,7,11] : 		
			# onzieme	
			return root_txt + quality_txt + "11"
		else :
			return "?"	
		


func get_chord_midi_root_normalised() -> int:
	return get_chord_midi()[0]%12


#	# accords Slash
#
#	if inversion == 6 or inversion  == 65 :
#		#basse tierce si pas sus2 ou sus4
#		if ["sus2","sus4"].has(kind) == false:
#			jc +="/"+
#	elif inversion == 64 or inversion  == 43 :
#		jc +="/"+spelledKeyScale[(degree_number+3)%7]
#	elif inversion == 42:
#		jc +="/"+spelledKeyScale[(degree_number+5)%7]
#
#	return jc
	


func get_roman_numeral() -> String:

	# On precise l'inversion pour le roman_numeral (pratique pour SATB)
	var chiffrage: String
	#if [1,7,6,64,65,42,43].has(inv) :
	if inversion == -1:
		chiffrage = "?"
	elif realization == [1,3,5] :
		match (inversion + realization.size()) % realization.size():
			0:
				chiffrage = ""
			1:
				chiffrage = "6"
			2:
				chiffrage = "64"

	elif realization == [1,3,5,7] or realization == [1,4,5,7] or realization == [1,2,5,7]:
		match inversion:
			0:
				chiffrage = ""
			1:
				chiffrage = "(65)"
			2:
				chiffrage = "(43)"
			3:
				chiffrage = "(42)"	

	elif realization == [1,3,7,9] :
		# neuvieme
		chiffrage = "9"
	elif realization == [1,5,7,11] :
		# onzieme
		chiffrage = "11"
	

	if chiffrage == null:
		LogBus.error(TAG,"get_roman_numeral -> inversion non valide: "+ str(inversion))

	var suffixe_secondary = ""
	
	if _is_secondary:
		suffixe_secondary = "/"
	

				
	if kind == "N6" or kind == "It+6" or kind == "Fr+6" or kind == "Ger+6" or kind == "It+6inv" or kind == "Fr+6inv" or kind == "Ger+6inv" or kind == "cad64":
		return kind  + suffixe_secondary

	elif  kind == "diatonic" or kind == "sus2" or kind == "sus4" :
		
		var sus = ""
		if kind =="sus2":
			sus = "sus2"
		elif kind =="sus4":
			sus = "sus4"
		

		
		if realization.size() == 3 :

			return triad_string_with_alter() + chiffrage + sus + suffixe_secondary
		elif realization.size() == 4 :
			
			if third_distance() == 3 and fifth_distance() == 6:

				var roman_triad_dim = triad_string_with_alter() 
		
				if seventh_distance() == 11:
					return triad_string_with_alter()  + "maj7"+ chiffrage + sus + suffixe_secondary
				elif seventh_distance() == 10:
					
					roman_triad_dim = roman_triad_dim.replace("°","ø")
					return roman_triad_dim +seventh_string_with_alter()+ chiffrage + sus + suffixe_secondary
				elif seventh_distance() == 9:
					return triad_string_with_alter() +seventh_string_with_alter() + chiffrage + sus + suffixe_secondary
				else :
					LogBus.error(TAG,'elif  kind == "diatonic" and dim -> _seventh_interval is not 9 10 11 ')
			else:
				return triad_string_with_alter() + seventh_string_with_alter() + chiffrage  + sus + suffixe_secondary
				
	elif kind == "add9" :
		# return key.roman_triad(degree_number) + kind
		return triad_string_with_alter() + "9"
	elif kind == "add11" :
		return triad_string_with_alter() + "11"
	else:
		LogBus.error("Degree","get_roman_numeral not set for kind: "+ kind + "!")
		return "unknown"
	return "?"

func degre_dans_la_tonalite(degre_dans_l_accord):
	return ((degree_number+degre_dans_l_accord-2)%7) + 1


################# CONVERSION MIDI #############################
# On convertit les degrés en midi
# -> midi des réalizations
# -> application des altérations
# -> application de l'inversion
func get_chord_midi() -> Array:
	
	#if override_chord_midi != [] :
	#	return override_chord_midi
	
	if kind == "N6":
		var midi_pitches = [] 
		for n in realization:
		# n est le degre dans l'accord 
			var degre_dans_l_accord = n
			var degre_dans_la_tonalite = 1 + (degree_number + degre_dans_l_accord -2) 
			var m = key.degree_midi(degre_dans_la_tonalite)
			m += get_key_alteration(1 + ((degre_dans_la_tonalite + 6) % 7))
			m += _octave*12
			midi_pitches.append(m)
		# on gere les inversions
		for i in range(0,inversion) :
			midi_pitches = _renverse_midi_chord_array(midi_pitches,1)
			
		return midi_pitches
	

		if realization.size() == 0 :
				LogBus.warn("Degree","get_chord_midi: empty realization")
				return []
	var midi_pitches = []
	
	for n in realization:
		# n est le degre dans l'accord 
		var degre_dans_l_accord = n
		var degre_dans_la_tonalite = degree_number + degre_dans_l_accord -1
		var m = key.degree_midi(degre_dans_la_tonalite)
		m += get_key_alteration(degre_dans_la_tonalite % 7)
		m += _octave*12
		
		midi_pitches.append(m)

	# on gere les inversions
	var _inversion # <= pour effecturer les inversions sans perdre inversopn = -1  -> aléatoire
	
	if inversion == -1:
		_inversion = 0
	else :
		_inversion = inversion
	
	for i in range(0,_inversion) :
		midi_pitches = _renverse_midi_chord_array(midi_pitches,1)
		
	return midi_pitches
		

func to_chord() -> Array:
	var midis = get_chord_midi()
	var arr = []
	for i in range(midis.size()):
		var n = Note.new()
		var m = midis[i]
		if m < 0:
			m = 0
		if m > 127:
			m = 127
		n.midi = m
		# par défaut, velocity = 100		
		n.velocity = DEFAULT_MIDI_VELOCITY
		n.set_length_beats (max(0.0, get_length_beats()))
		# par défaut, canal midi = 0
		n.channel = DEFAULT_MIDI_CHANNEL
		arr.append(n)
	return arr

	
## Helper de get_chord_midi
func _renverse_midi_chord_array(arr:Array, times:int) -> Array:
	if arr.size() < 2: 
		return arr
	for i in range(0,times) :			
		var f = arr.pop_front()
		f += 12
		arr.append(f)
	return arr 


func renverse_up():
	if kind == "diatonic":
		# par de second renversement pour les traides diatoniques
		if realization.size() == 3  and inversion == 1:
			inversion = (inversion + 2) % realization.size()
		else: 
			inversion = (inversion + 1) % realization.size()
		if inversion == 0 and _octave < 4:
			_octave +=1
	else:
		LogBus.info(TAG, kind + " chords cannot be reversed !")


		
func renverse_down():
	if kind == "diatonic":	
		if realization.size() == 3  and inversion == 0 :
			inversion = (inversion + realization.size() - 2) % realization.size()
			if _octave > -4 :
				_octave += -1
		else: 
			inversion = (inversion + realization.size() - 1) % realization.size()
			if inversion == realization.size()- 1 and _octave > -4 :
				_octave += -1
				

	else:
		LogBus.info(TAG, kind + " chords cannot be reversed !")	

		
	



########### VIEWS ##############

# --- Vue MIDI compacte d'un Degree ---
# Retourne un Control de 128 px de haut, largeur = d.get_length_beats() * 12
# Fond coloré selon le degré normalisé (dégradé tétradique 1..7)
# Largeur = get_length_beats() * 12 * scale ; hauteur = 128 px
func get_midi_view(scale:float = 1.0) -> Control:
	var beats = length_beats


	var sc = max(0.1, float(scale))
	var w = int(max(.5, beats) * 12.0 * sc)
	var h = 128
	
	var root = Control.new()
	root.rect_min_size = Vector2(w, h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.minimum_size_changed()
	
	# Fond coloré selon le degré normalisé (dégradé tétradique 1..7)
	var bg = ColorRect.new()
	bg.rect_min_size = Vector2(w, h)
	bg.color = degree_bg_color_for()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	
	# Lignes noires = notes de l'accord
	var notes = get_chord_midi()

	for i in range(notes.size()):
		var m = int(notes[i])
		add_midi_hline(root, w, h, m, Color("#000000"))
	
	# Ligne rouge = basse

	var bm = notes[0]
	add_midi_hline(root, w, h, bm, Color("#FF0000"))
	# --- CADRE ARRONDI (fond transparent + bordure grise 1 px) ---
	var frame_panel = Panel.new()
	frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# plein cadre
	frame_panel.anchor_left = 0
	frame_panel.anchor_top = 0
	frame_panel.anchor_right = 1
	frame_panel.anchor_bottom = 1
	frame_panel.margin_left = 0
	frame_panel.margin_top = 0
	frame_panel.margin_right = 0
	frame_panel.margin_bottom = 0

	var frame_sb = StyleBoxFlat.new()
	# fond transparent pour ne pas masquer le clavier ; si tu veux un fond, mets backgroundColor à la place
	frame_sb.bg_color = Color(0, 0, 0, 0)	# transparent
	# bordure grise 1 px
	frame_sb.border_width_top = 1
	frame_sb.border_width_left = 1
	frame_sb.border_width_right = 1
	frame_sb.border_width_bottom = 1
	frame_sb.border_color = Color(0.78, 0.78, 0.78)
	# coins arrondis
	frame_sb.corner_radius_top_left = 4
	frame_sb.corner_radius_top_right = 4
	frame_sb.corner_radius_bottom_left = 4
	frame_sb.corner_radius_bottom_right = 4
	# un chouïa de padding pour éviter que le contenu touche la bordure
	frame_sb.set_default_margin(MARGIN_LEFT, 1)
	frame_sb.set_default_margin(MARGIN_RIGHT, 1)
	frame_sb.set_default_margin(MARGIN_TOP, 1)
	frame_sb.set_default_margin(MARGIN_BOTTOM, 1)

	frame_panel.set("custom_styles/panel", frame_sb)
	# IMPORTANT: l’ajouter AVANT les autres enfants → il restera en dessous
	root.add_child(frame_panel)

	
	return root


# Ajoute une ligne horizontale à la position Y correspondant au pitch MIDI
func add_midi_hline(parent: Control, w: int, h: int, midi_value: int, col: Color) -> void:
	var mv = clamp(int(midi_value), 0, 127)
	var y = (h - 1) - mv	# graves en bas, aigus en haut
	var line = ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = col
	line.rect_position = Vector2(0, y)
	line.rect_min_size = Vector2(w, 1)
	parent.add_child(line)


# Couleur de fond selon get_degree_normalized() ∈ [1..7]
# Palette tétradique: 1→EEFFCC, 3→CCFFF6, 5→DDCCFF, 7→FFCCD5 (interpolation pour 2,4,6)
func degree_bg_color_for() -> Color:
	
	var cD = Color("#FF7A61")
	var cPD = Color("#FFC861")
	var T = Color("#A3FFB3")
	
	if harmonic_function == "T":
		return Color("#A3FFB3")
	elif harmonic_function == "PD":
		return Color("#FFC861")
	elif harmonic_function == "D":
		return Color("#FF7A61")
	else:
		return Color.aliceblue
		


func get_keyboard_view(
	scale = 1,
	fontColor: Color = Color(0, 0, 0),	# couleur des traits (clavier)
	backgroundColor: Color = Color(1, 1, 1)
) -> Control:
	var beats = 1.0
	if has_method("get_length_beats"):
		beats = float(get_length_beats())
	
	var sc = 1.0
	if typeof(scale) == TYPE_REAL or typeof(scale) == TYPE_INT:
		sc = max(0.1, float(scale))
	
	var w = int(max(.5, beats) * 12.0 * sc)
	var h = 128
	
	# Récupère et normalise les notes
	var pcs_dict = {}
	
	var notes = get_chord_midi()
	for i in range(notes.size()):
		var pc = int(notes[i]) % 12
		if pc < 0:
			pc = (pc + 12) % 12
		pcs_dict[pc] = true
	
	var bass_pc = int(notes[0]) % 12

	
	# Racine (viewport)
	var root = Control.new()
	root.rect_min_size = Vector2(w, h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.minimum_size_changed()
	
	# Fond
	var bg = ColorRect.new()
	bg.color = backgroundColor
	bg.rect_min_size = Vector2(w, h)
	bg.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	root.add_child(bg)
	
	# Scroll si nécessaire
	var scroller = ScrollContainer.new()
	scroller.rect_min_size = Vector2(w, h)
	scroller.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	root.add_child(scroller)
	
	# Contenu scrollable = au moins la taille du clavier
	var content = Control.new()
	content.rect_min_size = Vector2(max(w, 44), max(h, 120))
	scroller.add_child(content)
	
	# Clavier calé à gauche (pas de centrage)
	var kbd = _KeyboardCanvas.new(pcs_dict, bass_pc, fontColor)
	kbd.rect_min_size = Vector2(44, 120)
	kbd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ancré en haut-gauche du "content"
	kbd.anchor_left = 0
	kbd.anchor_top = 0
	kbd.anchor_right = 0
	kbd.anchor_bottom = 0
	kbd.margin_left = 0
	kbd.margin_top = 0
	content.add_child(kbd)

	
	# --- CADRE ARRONDI (fond transparent + bordure grise 1 px) ---
	var frame_panel = Panel.new()
	frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# plein cadre
	frame_panel.anchor_left = 0
	frame_panel.anchor_top = 0
	frame_panel.anchor_right = 1
	frame_panel.anchor_bottom = 1
	frame_panel.margin_left = 0
	frame_panel.margin_top = 0
	frame_panel.margin_right = 0
	frame_panel.margin_bottom = 0

	var frame_sb = StyleBoxFlat.new()
	# fond transparent pour ne pas masquer le clavier ; si tu veux un fond, mets backgroundColor à la place
	frame_sb.bg_color = Color(0, 0, 0, 0)	# transparent
	# bordure grise 1 px
	frame_sb.border_width_top = 1
	frame_sb.border_width_left = 1
	frame_sb.border_width_right = 1
	frame_sb.border_width_bottom = 1
	frame_sb.border_color = Color(0.78, 0.78, 0.78)
	# coins arrondis
	frame_sb.corner_radius_top_left = 4
	frame_sb.corner_radius_top_right = 4
	frame_sb.corner_radius_bottom_left = 4
	frame_sb.corner_radius_bottom_right = 4
	# un chouïa de padding pour éviter que le contenu touche la bordure
	frame_sb.set_default_margin(MARGIN_LEFT, 1)
	frame_sb.set_default_margin(MARGIN_RIGHT, 1)
	frame_sb.set_default_margin(MARGIN_TOP, 1)
	frame_sb.set_default_margin(MARGIN_BOTTOM, 1)

	frame_panel.set("custom_styles/panel", frame_sb)
	# IMPORTANT: l’ajouter AVANT les autres enfants → il restera en dessous
	root.add_child(frame_panel)

	return root
	
# Helper get_keyboard_view
# --- Classe locale de dessin du clavier ---
class _KeyboardCanvas extends Control:
	var pcs_dict = {}
	var bass_pc = -1
	var stroke = Color(0, 0, 0)
	var blue = Color(0.15, 0.35, 1.0)
	var red = Color(1.0, 0.1, 0.1)
	
	func _init(p_pcs_dict, p_bass_pc, p_stroke):
		pcs_dict = p_pcs_dict
		bass_pc = p_bass_pc
		stroke = p_stroke
	
	func _ready():
		update()
	
	func _draw():
		var W = rect_size.x
		var H = rect_size.y
		var white_h = H / 7.0
		
		# Fond blanc + bordure
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1), true)
		draw_rect(Rect2(0, 0, W, H), stroke, false, 2)
		
		# Séparations des touches blanches
		for i in range(1, 7):
			var y = H - white_h * i
			draw_line(Vector2(0, y), Vector2(W, y), stroke, 1)
		
		# Touches noires (C#, D#, F#, G#, A#) comme rectangles plus courts
		var black_w = W * 0.65
		var black_h = white_h * 0.62
		var white_centers = []
		for i in range(7):
			white_centers.append(H - (i + 0.5) * white_h)	# C bas -> B haut
		
		# entre C-D, D-E, F-G, G-A, A-B
		var pairs = [[0,1],[1,2],[3,4],[4,5],[5,6]]
		for pi in range(pairs.size()):
			var a = pairs[pi][0]
			var b = pairs[pi][1]
			var cy = (white_centers[a] + white_centers[b]) * 0.5
			var rect = Rect2(0, cy - black_h * 0.5, black_w, black_h)
			draw_rect(rect, Color(0, 0, 0), true)
		
		# Positions Y des 12 demi-tons (0=C, ..., 11=B). C grave seulement.
		var pc_y = {}
		pc_y[0] = white_centers[0]	# C
		pc_y[2] = white_centers[1]	# D
		pc_y[4] = white_centers[2]	# E
		pc_y[5] = white_centers[3]	# F
		pc_y[7] = white_centers[4]	# G
		pc_y[9] = white_centers[5]	# A
		pc_y[11] = white_centers[6]	# B
		pc_y[1] = (white_centers[0] + white_centers[1]) * 0.5	# C#
		pc_y[3] = (white_centers[1] + white_centers[2]) * 0.5	# D#
		pc_y[6] = (white_centers[3] + white_centers[4]) * 0.5	# F#
		pc_y[8] = (white_centers[4] + white_centers[5]) * 0.5	# G#
		pc_y[10] = (white_centers[5] + white_centers[6]) * 0.5	# A#
		
		# X des pastilles : sur la zone logique (blanc à droite, noir à gauche)
		var x_white = W * 0.78
		var x_black = W * 0.40
		var r = 5.0
		
		# Pastilles bleues (accord)
		for k in pcs_dict.keys():
			var pc = int(k)
			var cy = 0.0
			if pc_y.has(pc):
				cy = float(pc_y[pc])
			else:
				continue
			var cx = x_white
			# touches noires
			if pc == 1 or pc == 3 or pc == 6 or pc == 8 or pc == 10:
				cx = x_black
			draw_circle(Vector2(cx, cy), r, blue)
		
		# Pastille rouge (basse)
		if bass_pc >= 0 and pc_y.has(bass_pc):
			var cyb = float(pc_y[bass_pc])
			var cxb = x_white
			if bass_pc == 1 or bass_pc == 3 or bass_pc == 6 or bass_pc == 8 or bass_pc == 10:
				cxb = x_black
			draw_circle(Vector2(cxb, cyb), r + 1.0, red)


# Affiche le symbole Romain (Degree.roman_numeral()) dans un Control scrollable
# w = get_length_beats() * 12 * scale ; h = 128
# font_path: chemin .ttf optionnel. Si "", on garde la police du thème courant.
# Affiche le symbole Romain sur une tuile dont la largeur = length_beats * 12 * scale.
# Signature alignée sur tes autres vues.
func get_roman_view(
	scale = 1,
	font_path: String = "",
	fontSize = 16,
	fontColor: Color = Color(0, 0, 0),
	backgroundColor: Color = Color(1, 1, 1),
	key_font_path: String = "",
	key_font_size = 12,
	key_font_color: Color = Color(0, 0, 0),
	scale_font_path: String = "",
	scale_font_size = 12,
	scale_font_color: Color = Color(0, 0, 0)
) -> Control:
	var beats = 1.0
	if has_method("get_length_beats"):
		beats = float(get_length_beats())

	# scale: même logique que get_keyboard_view / get_midi_view
	var sc = 2.0
	if typeof(scale) == TYPE_REAL or typeof(scale) == TYPE_INT:
		sc = max(0.1, float(scale))

	var w = int(max(.5, beats) * 12.0 * sc)
	var h = 128

	# Racine: Control (comme tes autres vues)
	var root = Control.new()
	root.rect_min_size = Vector2(w, h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.minimum_size_changed()

	# Couleur de fond selon la fonction (pastel léger)
	###########
	
	var dico_scale = {}
	dico_scale["locrian"] = 0
	dico_scale["phrygian"] = 1
	dico_scale["minor"] = 2
	dico_scale["harmonic_minor"] = 3
	dico_scale["melodic_minor"] = 4
	dico_scale["dorian"] = 5
	dico_scale["mixolydian"] = 6
	dico_scale["major"] = 7
	dico_scale["lydian"] = 8
	
	var idx_scale = null
	if dico_scale.has(key.get_scale_name()):
		idx_scale = 1.0 * dico_scale[key.get_scale_name()] / dico_scale.size()
	
	var bg = backgroundColor
	
	if idx_scale != null:
		var hh = lerp(0, .85, idx_scale)
		bg = Color.from_hsv(hh,.35,.9,1)
		#bg = get_interpolated_color(Color("#FFBAB8"), Color("#B8FDFF"),idx_scale)


	var panel = Panel.new()
	panel.anchor_left = 0
	panel.anchor_top = 0
	panel.anchor_right = 1
	panel.anchor_bottom = 1
	panel.margin_left = 0
	panel.margin_top = 0
	panel.margin_right = 0
	panel.margin_bottom = 0

	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	# Bordure grise 1 px tout autour
	sb.border_width_top = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.78, 0.78, 0.78)
	# Coins légèrement arrondis (discret)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	panel.set("custom_styles/panel", sb)

	root.add_child(panel)

	# Label centré plein cadre
	var label = Label.new()
	label.text = get_roman_numeral() 
	label.add_color_override("font_color", fontColor)

	# Police optionnelle (si tu donnes un .ttf/.otf)
	if String(font_path) != "":
		var df = DynamicFont.new()
		df.size = int(fontSize)
		df.font_data = load(font_path)
		label.add_font_override("font", df)
	else:
		label.set("custom_fonts/font", null)  # garde la police du thème

	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.autowrap = false
	label.clip_text = false

	# Ancrage plein cadre (comme tes autres vues)
	label.anchor_left = 0
	label.anchor_top = 0
	label.anchor_right = 1
	label.anchor_bottom = 1
	label.margin_left = 0
	label.margin_top = 0
	label.margin_right = 0
	label.margin_bottom = 0

#	panel.add_child(label)
#
#	return root
#
	panel.add_child(label)

	# --- Key root (top-right) ---
	var key_root_text = ""
	if key and key.has_method("get_root_string"):
		key_root_text = key.get_root_string()
	if key_root_text != "":
		var keyLabel = Label.new()
		keyLabel.text = key_root_text
		# couleur selon la root de la key
		var key_root = key.root_midi % 12
		
		var h_key_label = lerp(0, 1, float(key_root*7)/12)
		var h_key_label_color = Color.from_hsv(h_key_label,1,.7,1)		
		keyLabel.add_color_override("font_color", h_key_label_color)
		if key_font_path != "":
			var kdf = DynamicFont.new()
			kdf.size = int(key_font_size)
			kdf.font_data = load(key_font_path)
			keyLabel.add_font_override("font", kdf)
		keyLabel.anchor_left = 1
		keyLabel.anchor_top = 0
		keyLabel.anchor_right = 1
		keyLabel.anchor_bottom = 0
		keyLabel.margin_left = -64
		keyLabel.margin_top = 2
		keyLabel.margin_right = -2
		keyLabel.margin_bottom = 0
		keyLabel.align = Label.ALIGN_RIGHT
		panel.add_child(keyLabel)

	# --- Key scale name (vertical left) ---
	var scale_name_text = ""
	if key and key.has_method("get_scale_name"):
		scale_name_text = key.get_scale_name()
	if scale_name_text != "":
		var scaleLabel = Label.new()
		scaleLabel.text = scale_name_text
		scaleLabel.add_color_override("font_color", scale_font_color)
		if scale_font_path != "":
			var sdf = DynamicFont.new()
			sdf.size = int(scale_font_size)
			sdf.font_data = load(scale_font_path)
			scaleLabel.add_font_override("font", sdf)
		# Position left edge, rotated -90 so text reads bottom-to-top
		scaleLabel.rect_rotation = -90
		scaleLabel.anchor_left = 0
		scaleLabel.anchor_top = 1
		scaleLabel.anchor_right = 0
		scaleLabel.anchor_bottom = 1
		scaleLabel.margin_left = 2
		scaleLabel.margin_top = -4
		scaleLabel.margin_right = 0
		scaleLabel.margin_bottom = -2
		panel.add_child(scaleLabel)

	return root	
	

# --- vue "jazz chord" (même approche/params que roman_view) ---
func get_jazzchord_view(
	scale = 1,
	font_path: String = "",
	fontSize = 16,
	fontColor: Color = Color(0, 0, 0),
	backgroundColor: Color = Color(1, 1, 1)
) -> Control:
	var beats = 1.0
	if has_method("get_length_beats"):
		beats = float(get_length_beats())

	var sc = 2.0
	if typeof(scale) == TYPE_REAL or typeof(scale) == TYPE_INT:
		sc = max(0.1, float(scale))

	var w = int(max(.5, beats) * 12.0 * sc)
	var h = 128

	var root = Control.new()
	root.rect_min_size = Vector2(w, h)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.minimum_size_changed()

	# Fond pastel par fonction
	var func_str = harmonic_function
	var bg = backgroundColor
	if func_str == "T":
		bg = Color(0.88, 0.97, 0.90)  # vert pastel
	elif func_str == "PD":
		bg = Color(1.00, 0.94, 0.83)  # orange pastel
	elif func_str == "D":
		bg = Color(1.00, 0.90, 0.94)  # rose pastel
	else:
		bg = Color(0.94, 0.94, 0.94)  # neutre

	var panel = Panel.new()
	panel.anchor_left = 0
	panel.anchor_top = 0
	panel.anchor_right = 1
	panel.anchor_bottom = 1
	panel.margin_left = 0
	panel.margin_top = 0
	panel.margin_right = 0
	panel.margin_bottom = 0

	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_top = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.78, 0.78, 0.78)	# gris 1 px
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	panel.set("custom_styles/panel", sb)

	root.add_child(panel)

	var label = Label.new()
	var sym = get_jazz_chord()

	label.text = sym
	label.add_color_override("font_color", fontColor)

	if String(font_path) != "":
		var df = DynamicFont.new()
		df.size = int(fontSize)
		df.font_data = load(font_path)
		label.add_font_override("font", df)
	else:
		label.set("custom_fonts/font", null)

	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.autowrap = false
	label.clip_text = false
	label.anchor_left = 0
	label.anchor_top = 0
	label.anchor_right = 1
	label.anchor_bottom = 1
	label.margin_left = 0
	label.margin_top = 0
	label.margin_right = 0
	label.margin_bottom = 0

	panel.add_child(label)
	
	return root


func triad_quality() -> String:
	return key.triad_quality(degree_number)
	
# HELPER COLOR
func get_interpolated_color(color1: Color, color2: Color, index: float) -> Color:
	var r = lerp(color1.r, color2.r, index)
	var g = lerp(color1.g, color2.g, index)
	var b = lerp(color1.b, color2.b, index)
	var a = lerp(color1.a, color2.a, index)
	return Color(r, g, b, a)

func get_seventh_interval() -> int:
	return key._seventh_interval(degree_number)


static func get_chord_and_scale( notes:Array, music_chord:int = 0 ):
	#
	# 和音と調を解析する
	# @param	notes			MIDI note numbers
	# @param	music_chord		music chord (default C)
	# @return	if find: { root: _, chord: _, string: _ } not found: null
	#

	var chord_table:Array = []
	var octave:PoolIntArray = PoolIntArray( [0,0,0,0,0,0,0,0,0,0,0,0] )
	for note in notes: octave[int(note) % 12] = 1
	var sound_count:int = 0
	for i in octave: sound_count += i

	if sound_count == 5:
		chord_table = [
			{ "name": "7b9", "notes": [ 4, 7, 10, 13 ] },
			{ "name": "9", "notes": [ 4, 7, 10, 14 ] },
		]
	elif sound_count == 4:
		chord_table = [
			{ "name": "sus4(13)", "notes": [ 5, 7, 9 ] },
			{ "name": "augmaj7", "notes": [ 4, 8, 11 ] },
			{ "name": "dim7", "notes": [ 3, 6, 9 ] },
			{ "name": "7sus4", "notes": [ 5, 7, 10 ] },
			{ "name": "m7b5", "notes": [ 3, 6, 10 ] },
			{ "name": "mmaj7", "notes": [ 3, 7, 11 ] },
			{ "name": "m7", "notes": [ 3, 7, 10 ] },
			{ "name": "maj7", "notes": [ 4, 7, 11 ] },
			{ "name": "7", "notes": [ 4, 7, 10 ] },
			{ "name": "m6", "notes": [ 3, 7, 9 ] },
			{ "name": "6", "notes": [ 4, 7, 9 ] },
		]
	elif sound_count == 3:
		chord_table = [
			{ "name": "sus4", "notes": [ 5, 7 ] },
			{ "name": "sus2", "notes": [ 2, 7 ] },
			{ "name": "aug", "notes": [ 4, 8 ] },
			{ "name": "dim", "notes": [ 3, 6 ] },
			{ "name": "m", "notes": [ 3, 7 ] },
			{ "name": "", "notes": [ 4, 7 ] },
		]
	#elif sound_count == 2:
	#	chord_table = [
	#		{ "name": "power", "notes": [ 5 ] },
	#	]
	else:
		return null

	for i in range( 0, 12 ):
		var root_note:int = ( i + music_chord ) % 12
		if octave[root_note] == 0: continue

		for chord in chord_table:
			var found:bool = true
			for note in chord.notes:
				if octave[(root_note + note) % 12] == 0:
					found = false
					break
			if found:
				return {
					"root": root_note,
					"chord": chord.name,
					"string": "%s%s" % [
						["C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B"][root_note],
						chord.name
					]}

	return null


	
# musiclib/RomanNumeralHelper.gd
# Helper: convertir un RN ("V", "ii65", "I cad64", "V/V", "N6", "Ger6+", etc.)
# en { "degree": int(1..7), "inversion": int(0..3) }
# Tabs only. Pas de :=. Pas d'opérateur ternaire.

func quality_with_alter() -> String:

	var q = "?"
	var midi_root = key.degree_midi(degree_number) + get_chord_alteration(1)
	var midi_third = key.degree_midi(degree_number + 2) + get_chord_alteration(3)
	var midi_fifth = key.degree_midi(degree_number + 4) + get_chord_alteration(5)
	var midi_seventh = key.degree_midi(degree_number + 6) + get_chord_alteration(7) 
	

	
	
	if midi_third - midi_root == 3 and midi_fifth - midi_root == 6:
		q = "dim"
	elif midi_third - midi_root == 3 and midi_fifth - midi_root == 7:
		q = "min"
	elif midi_third - midi_root == 4 and midi_fifth - midi_root == 7:
		q = "maj"
	elif midi_third - midi_root == 4 and midi_fifth - midi_root == 8:
		q = "aug"	
	elif midi_third - midi_root == 4 and midi_fifth - midi_root == 6:
		q = "b5"	
	else : 
		#LogBus.error(TAG,"quality_with_alter() -> Unknown quality" )
		return "?"
	return q

func triad_string_with_alter() -> String:
	var roman_string = ""
	var base_roman_string =  key._roman_base(degree_number)
	var q = quality_with_alter() 
	if q  == "dim" :
		return base_roman_string.to_lower() + "°"
	elif q == "min" :
		return base_roman_string.to_lower() 
	elif q == "maj":
		return base_roman_string
	elif q == "aug":
		return base_roman_string + "+"
	elif q == "b5":
		return base_roman_string + "b5"
	else:
		#LogBus.error(TAG,"triad_string_with_alter() -> Unknown quality" )
		return base_roman_string + "?"
	return roman_string


func third_distance() -> int :
	var midi_root = key.degree_midi(degree_number) + get_chord_alteration(1) 
	var midi_third = key.degree_midi(degree_number + 2 ) + get_chord_alteration(3) 
	return midi_third - midi_root
	
func fifth_distance() -> int :
	var midi_root = key.degree_midi(degree_number) + get_chord_alteration(1) 
	var midi_fifth = key.degree_midi(degree_number + 4 ) + get_chord_alteration(5) 
	return midi_fifth - midi_root
	
func seventh_distance() -> int :
	var midi_root = key.degree_midi(degree_number) + get_chord_alteration(1) 
	var midi_seventh = key.degree_midi(degree_number + 6 ) + get_chord_alteration(7) 
	return midi_seventh - midi_root
	
func seventh_string_with_alter() -> String:
	var roman_seven_string = ""
	var midi_chord_seventh = key.degree_midi(degree_number + 6) + get_chord_alteration(7) 
	var midi_chord_root = key.degree_midi(degree_number ) + get_chord_alteration(1) 
	var distance = midi_chord_seventh - midi_chord_root

	
	if distance == 10 or distance == 9:
		roman_seven_string = "7"
	elif distance == 11:	
		roman_seven_string = "maj7"
	else:
		LogBus.error(TAG,"seventh_string_with_alter -> distance = "+ str(distance))
	return roman_seven_string
	

func enharmonize():
	#
	var from_key:HarmonicKey = key.clone()
	var old_key_root = from_key.get_root_midi() % 12
	var from_jazzchord = get_jazz_chord()
	var from_rn = get_roman_numeral()
	var midi_notes = get_chord_midi()
	
	#LogBus.clear_console()
	#LogBus.info(TAG,"Enharmony...")
	
	if (kind == "diatonic" or kind == "add9" or kind == "add11") and realization.size() > 3 and degree_number == 5:
		if key.scale_name == "major":
			if enharmonic_string == "Enharmony from major / minor V dominant":
				# on bascule sur Ger+6
				reset()
				key.root_midi = (old_key_root +11) % 12
				key.scale_name = from_key.scale_name
				set_aug6_Ger()
				comment = "Enharmonized from V dominant of "+from_key.to_string() 
				LogBus.info(TAG,comment)
				return
			# sinon...
			key.scale_name = "harmonic_minor"
			comment = "Enharmonized from V7 major to V7 harmonic minor"
			LogBus.info(TAG,comment)
			return
		elif key.scale_name == "harmonic_minor":
			key.scale_name = "major"
			comment = "Enharmonized from V7 harmonic minor to V7 major"
			LogBus.info(TAG,comment)
			enharmonic_string = "Enharmony from major / minor V dominant"
			return
	
	if kind == "Ger+6":
		reset()
		degree_number = 5
		key.scale_name = from_key.scale_name
		key.root_midi = (old_key_root +1) % 12
		realization = [1,3,5,7]
		comment = "Enharmonized from Ger+6 of key "+from_key.to_string() 
		LogBus.info(TAG,comment)
		enharmonic_string = "Enharmony: from Ger+6 to V dominant"
		return
	
	if enharmonic_string == "Enharmony: from Ger+6 to V dominant" :
		reset()
		key.root_midi = (old_key_root +11) % 12
		key.scale_name = from_key.scale_name
		set_aug6_Ger()
		comment = "Enharmonized from V dominant of "+from_key.to_string() 
		LogBus.info(TAG,comment)
		return
	
	if kind == "Diatonic" and key.scale_name == "major" and degree_number == 5:
		key.scale_name = "harmonic_minor"
		comment = "Enharmony from V major to V harmonic minor"
		LogBus.info(TAG,comment)
		return	

	if kind == "Diatonic" and key.scale_name == "harmonic_minor" and degree_number == 5:
		key.scale_name = "major"
		comment = "Enharmony from V harmonic minor to V major"
		LogBus.info(TAG,comment)	
		return
	
	# N6 -> 
	if kind == "N6":
		reset()
		key.root_midi = 60 + ((8 + old_key_root) % 12) 
		degree_number = 4
		inversion = 1
		realization = [1,3,5]
		comment =  "N6 enharmonized to IV in key " + key.to_string()
		LogBus.info(TAG,comment)
		return
	
	# test accord Dim7
	if midi_notes.size() == 4 and (midi_notes[1] - midi_notes[0] == 3) and  (midi_notes[2] - midi_notes[0] == 6) and (midi_notes[3] - midi_notes[0] == 9) :
		key.root_midi = 60 + ((3 + old_key_root) % 12)
		var log_str = "Enharmonization dim7 symmmetical chord:\nFrom: "+ from_rn + " in key " + from_key.to_string()
		log_str += "\nTo: " + get_roman_numeral() + " in key " + key.to_string()
		LogBus.info(TAG,log_str)
		return
	# accord dim triade
	if midi_notes.size() == 3 and (third_distance() == 3) and  (fifth_distance() == 6) :
		if key.scale_name == "major" and degree_number == 7:
			key.root_midi = 60 + ((9 + old_key_root) % 12)
			key.scale_name = "harmonic_minor"
			degree_number = 2
		elif (key.scale_name == "harmonic_minor" or key.scale_name == "minor")  and degree_number == 2:
			key.root_midi = 60 + ((3 + old_key_root) % 12)
			key.scale_name = "harmonic_minor"
			degree_number = 7
		elif key.scale_name == "harmonic_minor" and degree_number == 7:
			key.scale_name = "major"
			degree_number = 7
		else :
			var midi_root = (key.degree_midi(degree_number) + get_chord_alteration(1)) %12
			key.root_midi = (midi_root + 1) %12
			degree_number = 7
			key.scale_name = "harmonic_minor"

	# test accord augmenté 
	if midi_notes.size() == 3  and (midi_notes[1] - midi_notes[0] == 4) and  (midi_notes[2] - midi_notes[0] == 8): 
		key.root_midi = 60 + ((4 + old_key_root) % 12)
		var log_str = "Enharmonization symmetrical augmented chord:\nFrom: "+ from_rn + " in key " + from_key.to_string()
		log_str += "\nTo: " + get_roman_numeral() + " in key " + key.to_string()
		LogBus.info(TAG,log_str)
		return
	
	#Accord majeur
	if midi_notes.size() == 3 and (midi_notes[1] - midi_notes[0] == 4) and  (midi_notes[2] - midi_notes[0] == 7): 
		if key.scale_name == "major" and degree_number == 1:
			key.root_midi = 60 + ((9 + old_key_root) % 12)
			key.scale_name = "minor"
			degree_number = 3
		elif key.scale_name == "minor" and degree_number == 3:
			# 3 de La mineur
			key.root_midi = 60 + ((10 + old_key_root) % 12)
			key.scale_name = "major"
			degree_number = 4
		elif key.scale_name == "major" and degree_number == 4:
			#4 de sol majeur 
			key.root_midi = 60 + ((7 + old_key_root) % 12)
			key.scale_name = "minor"
			degree_number =  7
		elif  key.scale_name == "minor" and degree_number == 7:
			# 7 de ré mineur
			key.root_midi = 60 + ((3 + old_key_root) % 12)
			key.scale_name = "major"
			degree_number = 5
		elif  key.scale_name == "major" and degree_number == 5:
			# 5 de fa majeur
			key.root_midi = 60 + ((2 + old_key_root) % 12)
			key.scale_name = "melodic_minor"
			degree_number = 4
		elif  key.scale_name == "melodic_minor" and degree_number == 4:
			# 5 de fa majeur
			key.root_midi = 60 + ((5 + old_key_root) % 12)
			key.scale_name = "major"
			degree_number = 1
		else:
			# accord quelconque majeur
			var m = key.degree_midi(degree_number)
			key.scale_name = "major"
			key.root_midi = 60 + (m % 12)
			degree_number = 1 
			
		var log_str = "Enharmonization major triad:\nFrom: "+ from_rn + " in key " + from_key.to_string()
		log_str += "\nTo: " + get_roman_numeral() + " in key " + key.to_string()
		LogBus.info(TAG,log_str)
	
	
	#Accord mineur
	if midi_notes.size() == 3 and (midi_notes[1] - midi_notes[0] == 3) and  (midi_notes[2] - midi_notes[0] == 7): 
		if (key.scale_name == "minor" or key.scale_name == "harmonic_minor")  and degree_number == 1:
			key.root_midi = 60 + ((3 + old_key_root) % 12)
			key.scale_name = "major"
			degree_number = 6
		elif key.scale_name == "major" and degree_number == 6:
			#from C
			key.root_midi = 60 + ((4 + old_key_root) % 12)
			key.scale_name = "minor"
			degree_number = 4
		elif key.scale_name == "minor" and degree_number == 4:
			#from E minor
			key.root_midi = 60 + ((3 + old_key_root) % 12)
			key.scale_name = "major"
			degree_number = 2
		elif key.scale_name == "major" and degree_number == 2:
			#from G major
			key.root_midi = 60 + ((7 + old_key_root) % 12)
			key.scale_name = "minor"
			degree_number = 5
		elif key.scale_name == "minor" and degree_number == 5:
			#from D minor
			key.root_midi = 60 + ((3 + old_key_root) % 12)
			key.scale_name = "major"
			degree_number = 3		
		elif key.scale_name == "major" and degree_number == 3:
			#from F major  -> G melodic minor
			key.root_midi = 60 + ((2 + old_key_root) % 12)
			key.scale_name = "melodic_minor"
			degree_number = 2
		elif key.scale_name == "melodic_minor" and degree_number == 2:
			#G melodic minor
			key.root_midi = 60 + ((2 + old_key_root) % 12)
			key.scale_name = "harmonic_minor"
			degree_number = 1
		var log_str = "Enharmonization minor triad:\nFrom: "+ from_rn + " in key " + from_key.to_string()
		log_str += "\nTo: " + get_roman_numeral() + " in key " + key.to_string()
		LogBus.info(TAG,log_str)
#	# GAMME MAJEURE
#
#	# -> FROM ii
#	if enharmonic_string == "ii_N6":
#		# from key C to F#
#		reset()
#		var delta_key = 6
#		degree_number = 5
#		_set_alterations({})
#		var comment = "Degree ii becomes bII = V dominant chord in a new major key (resolves to I)\nTypical modulation from bII to V"
#		var new_scale = "major"
#		enharmonic_string = "ii_N6_V"
#		#
#		key.scale_name = new_scale
#		key.root_midi = 60 + ((old_key_root + delta_key) %12)
#		var txt_info = "Enharmonic exchange !\n\n"+ comment +"\n\n"
#		txt_info += "From: "+ from_jazzchord  + " (" + from_rn + " in key "+ from_key.to_string() +")"
#		txt_info += "\nTo: " + get_jazz_chord() + " (" + get_roman_numeral() +  " in key "+key.to_string()+") \n"
#		LogBus.info(TAG,txt_info)
#		return
#

func guitar_chords()-> Array :
	
	var keys = ["C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B"]
	var gc_array = []
	var basePitch =  key.degree_midi(degree_number) % 12
	var root_name = keys[basePitch]
	var triton_root_name = keys[(basePitch + 6) %12]
	var backdoor_root_name = keys[(basePitch + 3) %12]
	var chord_name = get_jazz_chord()
	var ggb = MusicLabGlobals.GuitarBase
	
	if kind == "diatonic" and realization == [1,3,5] and fifth_distance() == 7:
		if third_distance() == 3:
			chord_name = root_name+"minor"
		elif third_distance() == 4:
			chord_name = root_name+"major"
	elif kind == "It+6" or kind == "Fr+6" or kind == "Ger+6":
		chord_name = root_name+"7"
	elif kind == "It+6Inv" or kind == "Fr+6Inv" or kind == "Ger+6Inv":
		chord_name = root_name+"7"
	
	# search by name
	gc_array = ggb.search_by_name(chord_name)
	
	
					
	# on ajoute les sus2 et sus4
	if kind == "diatonic" and realization == [1,3,5] and fifth_distance() == 7 and degree_number !=1  and degree_number !=5:
		gc_array.append_array(ggb.search_by_name(root_name+"sus2"))
		gc_array.append_array(ggb.search_by_name(root_name+"sus4"))
		
	if kind == "diatonic" and realization == [1,3,5] and fifth_distance() == 7 :

	
		# et les 9emes et 11emes
		if key.scale_name == "major":
			if degree_number == 5:
				gc_array.append_array(ggb.search_by_name(root_name+"7"))
				gc_array.append_array(ggb.search_by_name(root_name+"9"))
				
			elif degree_number == 2 or degree_number == 6 or degree_number == 3 :
				gc_array.append_array(ggb.search_by_name(root_name+"m9"))
				if degree_number == 2 or degree_number == 6:
					gc_array.append_array(ggb.search_by_name(root_name+"m11"))
				elif degree_number == 5:
					gc_array.append_array(ggb.search_by_name(root_name+"11"))
		elif key.scale_name == "minor":	
			if degree_number == 4:
				gc_array.append_array(ggb.search_by_name(root_name+"m9"))	
				gc_array.append_array(ggb.search_by_name(root_name+"m11"))
			elif degree_number == 1:
				gc_array.append_array(ggb.search_by_name(root_name+"m11"))
		elif key.scale_name == "harmonic_minor":	
			if degree_number == 4:
				gc_array.append_array(ggb.search_by_name(root_name+"9"))	

	
	# on ajoute les 6/9
	if key.scale_name == "major":
		if (degree_number == 1 or degree_number == 4 or degree_number == 5):
			gc_array.append_array(ggb.search_by_name(root_name+"69"))
		elif degree_number == 2:
			gc_array.append_array(ggb.search_by_name(root_name+"m69"))
	elif key.scale_name == "minor":
		if (degree_number == 3 or degree_number == 6 or degree_number == 7):
			gc_array.append_array(ggb.search_by_name(root_name+"69"))
		elif degree_number == 4:
			gc_array.append_array(ggb.search_by_name(root_name+"m69"))
	elif  key.scale_name == "harmonic_minor":
		if degree_number == 4:
			gc_array.append_array(ggb.search_by_name(root_name+"m69"))
	elif key.scale_name == "melodic_minor":
		if degree_number == 4:
			gc_array.append_array(ggb.search_by_name(root_name+"69"))
				

	# Et les Dominantes altérées
	if kind == "diatonic" and realization == [1,3,5] and fifth_distance() == 7 and degree_number == 5:
		if key.scale_name == "major":
			gc_array.append_array(ggb.search_by_name(root_name+"7b9"))
			gc_array.append_array(ggb.search_by_name(root_name+"7#9"))
			gc_array.append_array(ggb.search_by_name(root_name+"7sus4"))
			gc_array.append_array(ggb.search_by_name(root_name+"alt"))
			# Substitutions tritoniques (♭II7 et cie)
			#gc_array.append_array(ggb.search_by_name(triton_root_name+"7"))
			#
			# ♭VII7 (B♭7) : « backdoor dominant »
			#gc_array.append_array(ggb.search_by_name(backdoor_root_name+"7"))
		elif key.scale_name == "harmonic_minor":	
			gc_array.append_array(ggb.search_by_name(root_name+"7b9"))
			gc_array.append_array(ggb.search_by_name(root_name+"7#9"))
			gc_array.append_array(ggb.search_by_name(root_name+"7sus4"))
			gc_array.append_array(ggb.search_by_name(root_name+"alt"))
		
	
	# search by notes
	var midi_notes =  PoolIntArray(get_chord_midi())
	var gc_by_pitch = ggb.search_by_pitches(midi_notes)
	#LogBus.debug(TAG,"gc_by_pitch.size()" + str(gc_by_pitch.size()))
	
	var gc_array_midiNotes = []
	for gc in gc_array:
		gc_array_midiNotes.append(gc.midiNotes)
	
	
	
	# on ajoute en dédoublonnant
	for gc in gc_by_pitch:
		if pool_int_array_in_array(gc.midiNotes , gc_array_midiNotes) == false:
			gc_array.append(gc)
				
	
	return gc_array
	
func same_pitch_class(p1:int,p2:int)->bool:
	return ((p1 % 12) ==  (p2 % 12))


func tonalize():
	if degree_number == 1 and ["major","minor"].has(key.scale_name):
		return
		
	if quality_with_alter() != "min" and  quality_with_alter() != "maj" :
		LogBus.info(TAG,"Cannot tonalize !\nYou must select 2 diatonic major or minor chords\nIt is better to use 2 Degree 1 of 2 different tonalities\n")
		return
		
	var k:HarmonicKey = HarmonicKey.new()
	k.root_midi = 60 +  (key.degree_midi(degree_number) % 12)
	if quality_with_alter() == "min" :
		k.scale_name = "minor"
	elif quality_with_alter() == "maj":
		k.scale_name = "major"
	kind = "diatonic"
	degree_number = 1
	key = k

		
func chromatize():
	if key.scale_name == "major":
		if degree_number == 2:
			# +6 -< ga#
			key.root_midi = 60 + ((key.root_midi + 6) %12)
			key.scale_name = "harmonic_minor"
			degree_number = 5
			inversion = 1
			LogBus.info(TAG,"Chromatization ii -> bII (enharmonic of V in minor scale)")
			comment = "chromatized chord"
			return
			
		elif degree_number == 3:
			# +6 -< ga#
			key.root_midi = 60 + ((key.root_midi + 11) %12)
			degree_number = 3
			key.scale_name = "minor"
			LogBus.info(TAG,"Chromatization iii -> bIII (enharmonic of III in minor scale)")
			comment = "chromatized chord"
			return
	LogBus.info(TAG,"Cannot chromatize this chord")
	return
	
# aug -> maj -> min -> dim7
func chromatizeDown():
	if quality_with_alter() == "aug":
		var midi_root = (key.degree_midi(degree_number) + get_chord_alteration(1)) %12
		reset()
		key.scale_name = "major"
		key.root_midi = midi_root
		LogBus.info(TAG,"Chord chromatized down to major tonic")
		LogBus.info(TAG,"You may use [E] to set the new chord function")
		comment = "chromatized chord"
	elif quality_with_alter() == "maj":
		var midi_root = key.degree_midi(degree_number) + get_chord_alteration(1)
		reset()
		key.scale_name = "harmonic_minor"
		key.root_midi = midi_root
		LogBus.info(TAG,"Chord chromatized down to harmonic minor tonic")
		LogBus.info(TAG,"You may use [E] to set the new chord function")
		comment = "chromatized chord"
	elif quality_with_alter() == "min":
		var midi_root = (key.degree_midi(degree_number) + get_chord_alteration(1))%12
		reset()
		key.scale_name = "harmonic_minor"
		key.root_midi = 60 + (midi_root+10) % 12
		degree_number = 7
		realization = [1,3,5,7]
		LogBus.info(TAG,"Chord chromatized down to diminished harmonic minor 7th")
		LogBus.info(TAG,"You may use [E] to set the new chord enharmonic key")
		comment = "chromatized chord"

	LogBus.info(TAG,"Cannot chromatize this chord")
	return
	
func chromatizeUp():
	if quality_with_alter() == "dim":
		var midi_root = key.degree_midi(degree_number) + get_chord_alteration(1)
		reset()
		key.scale_name = "harmonic_minor"
		key.root_midi = (midi_root +3) %12
		LogBus.info(TAG,"Chord chromatized up to minor tonic")
		LogBus.info(TAG,"You may use [E] to set the new chord function")
		comment = "chromatized chord"
	elif quality_with_alter() == "min":
		var midi_root = key.degree_midi(degree_number) + get_chord_alteration(1)
		reset()
		key.scale_name = "major"
		key.root_midi = midi_root
		LogBus.info(TAG,"Chord chromatized up to  major tonic")
		LogBus.info(TAG,"You may use [E] to set the new chord function")
		comment = "chromatized chord"
	elif quality_with_alter() == "maj":
		var midi_root = key.degree_midi(degree_number) + get_chord_alteration(1)

		reset()
		key.scale_name = "harmonic_minor"
		key.root_midi = 60 + (midi_root + 9 ) % 12
		degree_number = 3
		#realization = [1,3,5,7]
		LogBus.info(TAG,"Chord chromatized up to augmented harmonic minor 3rd")
		LogBus.info(TAG,"You may use [E] to set the new chord enharmonic key")
		comment = "chromatized chord"

	else :
		LogBus.info(TAG,"Cannot chromatize this chord")
		return	
		
	LogBus.info(TAG,"Cannot chromatize this chord")
	return
	
func pool_int_array_in_array(needle: PoolIntArray, haystack: Array) -> bool:
	for arr in haystack:
		if arr == needle:
			return true
	return false

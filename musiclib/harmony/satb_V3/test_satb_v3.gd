extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

const TAG = "test_SATB"
# Called when the node enters the scene tree for the first time.
onready var console:RichTextLabel = $console
var Harmony = Harmony_SATB.new()
func _ready():
	
	# Connection à LogBus
	var myTree = self.get_tree()
	LogBus.info("TPF","tree -> "+ str(myTree))
	
	#connection à la console 
	LogBus.connect("log_entry", self, "_on_log_entry")
	LogBus._verbose = true
	
	

	# Mini banc de test pour harmony.gd (RN + figures + accords spéciaux)
	var H = Harmony_SATB.new()
	_print_header("TEST HARMONY — Triades / 7e / N6 / Aug6 / cad64")

	# Clés de test
	var keys = [
		{"name":"C major", "key": H.key_make(0, "major")},
		{"name":"A minor", "key": H.key_make(9, "minor")}
	]

	# Figures d'inversion canoniques
	var triad_figs = ["1", "6", "64"]
	var seventh_figs = ["7", "65", "43", "42"]

	# RN triades typiques (on inclut vii° explicite)
	var rn_triads = ["I","ii","iii","IV","V","vi","vii°"]	# majeur
	var rn_triads_min = ["i","ii°","III","iv","V","VI","vii°"]	# mineur (harmonique géré)

	# RN susceptibles de 7e usuelles
	var rn_sevenths = ["V","ii","vii"]
	var rn_sevenths_min = ["V","ii","vii","i","iv","III","VI"]

	# Accords spéciaux à tester
	var specials = ["N6","cad64","It6","Fr6","Gr6"]

	for K in keys:
		var kname = K["name"]
		var key = K["key"]
		_print_header(kname)

		# ---- Triades (RN + 1/6/64)
		var set_triads = rn_triads if kname.find("major") != -1 else rn_triads_min
		for rn in set_triads:
			for fig in triad_figs:
				_test_build(H, {"key": key, "rn": rn, "fig": fig, "bass_oct": 2})

		# ---- Tétrades (RN + 7/65/43/42)
		var set_7 = rn_sevenths if kname.find("major") != -1 else rn_sevenths_min
		for rn7 in set_7:
			for fig7 in seventh_figs:
				_test_build(H, {"key": key, "rn": rn7, "fig": fig7, "bass_oct": 2})

		# ---- Spéciaux (N6, cad64, It6/Fr6/Gr6)
		for t in specials:
			_test_build(H, {"type": t, "key": key, "bass_oct": 2})

		# ---- Garde-fou bass_oct: extrêmes pour voir le repli
		_test_build(H, {"key": key, "rn": "I", "fig": "1", "bass_oct": 0})
		_test_build(H, {"key": key, "rn": "I", "fig": "1", "bass_oct": 6})

	_print_header("FIN TESTS")
	#get_tree().quit()

func _test_build(H, spec:Dictionary) -> void:
	var ch = H.build_chord(spec)
	if ch.empty():
		print(_fmt_spec(spec), " -> BUILD FAILED")
		return

	var pcs = ch.get("pitches", [])
	var bass = ch.get("bass", -1)
	var typ = ch.get("type", "RN")
	var q = ch.get("quality", "")
	var fn = ch.get("function", "")
	var rn_txt = spec.get("rn", typ)
	var fig_txt = str(spec.get("fig", ""))

	var pcs_txt = _pcs_to_names(pcs)
	var bass_txt = _midi_note_name(bass)
	var extra = ""
	if fn != "":
		extra = str(" fn=", fn)
	if q != "":
		extra += str(" q=", q)

	
	#print(_fmt_spec(spec), " -> type=", typ, " rn=", rn_txt, " fig=", fig_txt, " pcs=", pcs, " [", pcs_txt, "] ",
	#	"bass=", bass, " [", bass_txt, "]", extra)
	var logstr = _fmt_spec(spec) + " -> type=" +  typ + " rn=" + rn_txt + " fig=" + fig_txt+ " pcs=" + str(pcs) +  " [" + pcs_txt +  "] " 
	logstr += "bass=" + str(bass) + " [" +  bass_txt + "]"+ "  "+ extra
	LogBus.debug("> ",logstr)
func _fmt_spec(spec:Dictionary) -> String:
	var parts = []
	if spec.has("type"):
		parts.append(str("type:", spec["type"]))
	if spec.has("rn"):
		parts.append(str("rn:", spec["rn"]))
	if spec.has("fig"):
		parts.append(str("fig:", spec["fig"]))
	if spec.has("bass_oct"):
		parts.append(str("bass_oct:", spec["bass_oct"]))
	return str("{", _join(parts, ", "), "}")

func _pcs_to_names(pcs:Array) -> String:
	var out = []
	for p in pcs:
		out.append(_pc_name(p))
	return _join(out, "-")

func _pc_name(pc:int) -> String:
	var names = ["C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B"]
	var i = (pc % 12 + 12) % 12
	return names[i]

func _midi_note_name(m:int) -> String:
	if m < 0:
		return "?"
	var pc = m % 12
	var oct = int(m / 12) - 1
	return str(_pc_name(pc), oct)

func _print_header(s:String) -> void:
	LogBus.debug(TAG,"==================================================")
	LogBus.debug(TAG,s)
	LogBus.debug(TAG,"==================================================")

	
	
	
	
	
	
	


func _on_log_entry(entry):
	#entry = {time_str, msec, level, tag, message}
	var level = entry["level"]
	var tag = entry["tag"]
	var message = entry["message"]
	
	if level == "INFO":
		console.text += level + "|"  + tag + "|" + message + "\n"
	else :
		console.text += level + "|"  + tag + "|" + message + "\n"

func _join(arr:Array, sep:String) -> String:
	var s = ""
	for i in range(arr.size()):
		s += str(arr[i])
		if i < arr.size() - 1:
			s += sep
	return s

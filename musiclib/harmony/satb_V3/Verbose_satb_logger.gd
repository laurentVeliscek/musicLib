extends Reference
class_name Verbose_satb_logger
# Fichier: res://musiclib/verbose_logger.gd
# Logger "verbose" pour le solver SATB (Godot 3.x)

var step_index = -1
var chord_info = ""
var gen_total = 0
var gen_kept = 0
var gen_rejects = {}	# String -> int
var trans_total = 0
var trans_kept = 0
var trans_rejects = {}	# String -> int
var gen_cached = 0

func gen_cached_add(n:int) -> void: gen_cached += n


func _init():
	_reset_all()

func _reset_all() -> void:
	step_index = -1
	chord_info = ""
	gen_total = 0
	gen_kept = 0
	gen_rejects = {}
	trans_total = 0
	trans_kept = 0
	trans_rejects = {}

func start_step(index:int, chord:Dictionary) -> void:
	_reset_all()
	step_index = index
	var typ = chord.get("type", "RN")
	var pcs = chord.get("pitches", [])
	var bass = chord.get("bass", -1)
	chord_info = str("type=", typ, " pcs=", pcs, " bass=", bass)

# ---------- génération ----------
func gen_try() -> void:
	gen_total += 1

func gen_keep() -> void:
	gen_kept += 1

func gen_reject(reason:String) -> void:
	if not gen_rejects.has(reason):
		gen_rejects[reason] = 0
	gen_rejects[reason] += 1

# ---------- transitions ----------
func trans_try() -> void:
	trans_total += 1

func trans_keep() -> void:
	trans_kept += 1

func trans_reject(reason:String) -> void:
	#LogBus.debug("verbose_logger","reason -> "+reason)
	if not trans_rejects.has(reason):
		trans_rejects[reason] = 0
	trans_rejects[reason] += 1


func end_step() -> void:

	LogBus.debug("SATB Logger", "------------------------------------------")
	LogBus.debug("SATB Logger","[SATB verbose] Step " + str(step_index) + " | " + chord_info)

	LogBus.debug("SATB Logger","Generation: tried= " +  str(gen_total) + " kept= " + str(gen_kept) + " cached=" +  str(gen_cached))
	if gen_total > 0 and gen_total != gen_kept:
		LogBus.debug("SATB Logger","  Reject reasons (generation):")
		for k in gen_rejects.keys():
			LogBus.debug("SATB Logger","   - " + str(k) +  ": "+  str(gen_rejects[k]))
	LogBus.debug("SATB Logger","Transitions: tried=" + str(trans_total) + " kept=" +  str(trans_kept))
	if trans_total > 0 and trans_total != trans_kept:
		LogBus.debug("SATB Logger","  Reject reasons (transitions):")
		#LogBus.debug("trans_rejects ? -> ",str(trans_rejects))
		for k2 in trans_rejects.keys():
			LogBus.debug("SATB Logger","   - " +  str(k2) + ": " + str(trans_rejects[k2]))
	LogBus.debug("SATB Logger","\n")


# Song.gd — Godot 3.x
extends Reference
class_name Song


const TAG = "Song"

# ---- Métadonnées / tempo / métrique ----
var title: String = "Untitled Song"				# sera utilisé pour le nom du fichier
var ppq: int = 480                           # Pulses Per Quarter
var tempo_bpm: float = 120.0                 # Tempo initial (un seul pour l’instant)
var time_num: int = 4                      # Numérateur (4/4 → 4)
var time_den: int = 4                        # Dénominateur (4/4 → 4)

# --- Tempo map (en plus de tempo_bpm initial) ---
var tempo_changes: Array = []  # chaque item: { "beats": float, "bpm": float }
var satb_solutions_array:Array = []
var satb_solutions_index =  -1
#pour fractalizer
var satb_request_data:Dictionary = {}
# Patterns de strumming (Array de StrumPattern)
var strum_pattern_array:Array = []
# ---- Contenu : chaque entrée = { track: Track, offset_beats: float }
var _entries: Array = []
var guitar_player_scene_params:Dictionary = {}


const PROGRESSION_TRACK_NAME:String= "Chord Progression"
const SATB_TRACK_NAME:String= "SATB"
const SATB_SOPRANO:String= "SATB Soprano"
const SATB_ALTO:String= "SATB Alto"
const SATB_TENOR:String= "SATB Tenor"
const SATB_BASS:String= "SATB Bass"
const RYTHM_GUITAR_TRACK:String= "Rythm Guitar"
const FRACTAL_TRACK:String= "fractal SATB"
const MELODY_TRACK:String= "Melody"


func clone() -> Song:
	# ⚠️ factory locale pour éviter la self-référence en 3.x
	var s = get_script().new()
	
	# --- Métadonnées / métrique / tempo initial ---
	s.title = String(title)
	s.ppq = int(ppq)
	s.tempo_bpm = float(tempo_bpm)
	s.time_num = int(time_num)
	s.time_den = int(time_den)

	s.satb_solutions_array = satb_solutions_array
	s.satb_solutions_index =  satb_solutions_index
	# Pour fratcalizer
	s.satb_request_data = satb_request_data

	# Patterns de strumming
	s.strum_pattern_array = []
	if typeof(strum_pattern_array) == TYPE_ARRAY:
			for pat in strum_pattern_array:
					if pat != null and typeof(pat) == TYPE_OBJECT:
							if pat.has_method("clone"):
									s.strum_pattern_array.append(pat.clone())
							elif pat.has_method("duplicate"):
									s.strum_pattern_array.append(pat.duplicate(true))

	# Patterns de strumming
	s.strum_pattern_array = []
	if typeof(strum_pattern_array) == TYPE_ARRAY:
		for pat in strum_pattern_array:
			if pat != null and typeof(pat) == TYPE_OBJECT:
				if pat.has_method("clone"):
					s.strum_pattern_array.append(pat.clone())
				elif pat.has_method("duplicate"):
					s.strum_pattern_array.append(pat.duplicate(true))



	# --- Tempo map ---
	s.tempo_changes = []
	if typeof(tempo_changes) == TYPE_ARRAY:
		for ev in tempo_changes:
			if typeof(ev) == TYPE_DICTIONARY:
				var c: Dictionary = {}
				c["beats"] = float(ev.get("beats", 0.0))
				c["bpm"] = float(ev.get("bpm", tempo_bpm))
				s.tempo_changes.append(c)
	
	# --- Pistes + offsets (deep-clone si possible) ---
	if typeof(_entries) == TYPE_ARRAY:
		for e in _entries:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var off = float(e.get("offset_beats", 0.0))
			var tr = e.get("track", null)
			var tr_copy = tr
			if tr != null and typeof(tr) == TYPE_OBJECT:
				if tr.has_method("clone"):
					tr_copy = tr.clone()
				elif tr.has_method("duplicate"):
					# au cas où ce soit un Node et pas un Reference
					tr_copy = tr.duplicate(true)
			s._entries.append({"track": tr_copy, "offset_beats": off})
	
	s.guitar_player_scene_params = guitar_player_scene_params.duplicate()
	
	return s

func to_dict() -> Dictionary:
	var dic:Dictionary = {}
	
	# --- Métadonnées / tempo / métrique ---
	dic["title"] = title
	dic["ppq"] = ppq
	dic["tempo_bpm"] = tempo_bpm
	dic["time_num"] = time_num
	dic["time_den"] = time_den
	
	# --- Tempo map ---
	var tempos_array:Array = []
	for ev in tempo_changes:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var t_ev:Dictionary = {}
		t_ev["beats"] = float(ev.get("beats", 0.0))
		t_ev["bpm"] = float(ev.get("bpm", tempo_bpm))
		tempos_array.append(t_ev)
	dic["tempo_changes"] = tempos_array
	
	# --- SATB / Fractalizer ---
	# Solutions complètes (Array de solutions)
	dic["satb_solutions_array"] = satb_solutions_array.duplicate(true)
	# Index de la solution courante
	dic["satb_solutions_index"] = satb_solutions_index
	# Requête SATB (paramètres de génération)
	dic["satb_request_data"] = satb_request_data.duplicate(true)


	# --- Strum patterns ---
	var strums_array:Array = []
	for pat in strum_pattern_array:
		if pat != null and typeof(pat) == TYPE_OBJECT and pat.has_method("to_dict"):
			strums_array.append(pat.to_dict())
	dic["strum_pattern_array"] = strums_array

	# --- Entries / Tracks ---
	var entries_array:Array = []
	for entry in _entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		
		var off = float(entry.get("offset_beats", 0.0))
		var tr = entry.get("track", null)
		
		var e:Dictionary = {}
		e["offset_beats"] = off
		
		if tr != null and typeof(tr) == TYPE_OBJECT and tr.has_method("to_dict"):
			e["track"] = tr.to_dict()
		
		entries_array.append(e)
	
	dic["entries"] = entries_array
	dic["guitar_player_scene_params"] = guitar_player_scene_params.duplicate()
	
	
	#LogBus.debug(TAG, "Song.to_dict(): " + JSON.print(dic, "\t"))
	return dic


func from_dict(dic) -> Song:
	var s:Song = get_script().new()
	
	# --- Métadonnées / tempo / métrique ---
	s.title = dic.get("title", "Untitled Song")
	s.ppq = int(dic.get("ppq", 480))
	s.tempo_bpm = float(dic.get("tempo_bpm", 120.0))
	s.time_num = int(dic.get("time_num", 4))
	s.time_den = int(dic.get("time_den", 4))
	
	# --- Tempo map ---
	s.tempo_changes.clear()
	var tempos_array = dic.get("tempo_changes", [])
	if typeof(tempos_array) == TYPE_ARRAY:
		for ev in tempos_array:
			if typeof(ev) != TYPE_DICTIONARY:
				continue
			var t_ev:Dictionary = {}
			t_ev["beats"] = float(ev.get("beats", 0.0))
			t_ev["bpm"] = float(ev.get("bpm", s.tempo_bpm))
			s.tempo_changes.append(t_ev)
	
	# --- SATB / Fractalizer ---
	# Solutions
	var satb_array = dic.get("satb_solutions_array", [])
	if typeof(satb_array) == TYPE_ARRAY:
		s.satb_solutions_array = satb_array.duplicate(true)
	else:
		s.satb_solutions_array = []
	
	# Index courant (on peut le “clamp” pour éviter les débords)
	s.satb_solutions_index = int(dic.get("satb_solutions_index", -1))
	if s.satb_solutions_array.size() == 0:
		s.satb_solutions_index = -1
	elif s.satb_solutions_index < -1 or s.satb_solutions_index >= s.satb_solutions_array.size():
		s.satb_solutions_index = -1
	
	# Requête SATB
	var req = dic.get("satb_request_data", {})
	if typeof(req) == TYPE_DICTIONARY:
		s.satb_request_data = req.duplicate(true)
	else:
		s.satb_request_data = {}

	# --- Strum patterns ---
	s.strum_pattern_array.clear()
	var strums_array = dic.get("strum_pattern_array", [])
	if typeof(strums_array) == TYPE_ARRAY:
		for pat_data in strums_array:
			if typeof(pat_data) == TYPE_DICTIONARY:
				var dummy_sp = StrumPattern.new()
				s.strum_pattern_array.append(dummy_sp.from_dict(pat_data))

	# --- Entries / Tracks ---
	s._entries.clear()
	var entries_array = dic.get("entries", [])
	if typeof(entries_array) == TYPE_ARRAY:
		for e in entries_array:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			
			var off = float(e.get("offset_beats", 0.0))
			var tr_data = e.get("track", null)
			
			if typeof(tr_data) == TYPE_DICTIONARY:
				# factory locale pour éviter l’auto-référence en 3.x
				var dummy_tr = Track.new()
				var tr = dummy_tr.from_dict(tr_data)
				s._entries.append({
					"track": tr,
					"offset_beats": off
				})
	
	# Requête SATB
	var guitar_scene_params = dic.get("guitar_player_scene_params", {})
	if typeof(guitar_scene_params) == TYPE_DICTIONARY:
		s.guitar_player_scene_params = guitar_scene_params.duplicate(true)
	else:
		s.guitar_player_scene_params = {}
	
	#LogBus.debug(TAG, "Song.from_dict(): " + JSON.print(dic, "\t"))
	#LogBus.debug(TAG, "Song rebuilt: " + s.to_string())
	return s


#
func get_satb_request_data()-> Dictionary:
	if satb_request_data != {} :
		return satb_request_data
	else :
		LogBus.error(TAG,"satb_request_data = {}")
		return {}

func get_satb() -> Dictionary:
	if satb_solutions_array.size() > 0 :
		if satb_solutions_index > -1 and satb_solutions_index <= satb_solutions_array.size() -1 :
			var satb = satb_solutions_array[satb_solutions_index]	
			return satb
			#LogBus.debug(TAG,str(satb))
		else :
			LogBus.error(TAG,"satb_solutions_index = " + str(satb_solutions_index))
			return {}
	else :
		LogBus.error(TAG,"satb_solutions_array.size() = 0")
		return {}
		

# === API ===

# Ajoute une Track à une position (bar/beat). bar est 1-based (bar=1 → début du morceau).
# beat est relatif à la mesure (0..beatsPerBar). Si clone=true, on clone la Track à l’ajout.
func add_track_at(track, bar: int, beat: float, clone: bool = false) -> void:
	if track == null:
		return
	var use = track
	if clone and typeof(track) == TYPE_OBJECT and track.has_method("clone"):
		use = track.clone()
	var beats_per_bar = float(time_num)
	var bar_index = max(1, bar) - 1
	var offset_beats = float(bar_index) * beats_per_bar + float(beat)
	_entries.append({"track": use, "offset_beats": offset_beats})


# Retourne la Track à l'index donné, ou null si hors bornes / invalide.
func get_track(track_number: int = 0) -> Track:
	if typeof(_entries) != TYPE_ARRAY:
		return null

	var i = int(track_number)
	if i < 0:
		return null
	if i >= _entries.size():
		return null

	var entry = _entries[i]
	if typeof(entry) != TYPE_DICTIONARY:
		return null
	if not entry.has("track"):
		return null

	var tr = entry["track"]
	if tr == null:
		return null
	if typeof(tr) != TYPE_OBJECT:
		return null

	return tr

# Supprime la piste d'index 'track_number' si elle existe.
# - On enlève l'entrée correspondante de _entries (Array de {track, offset_beats}).
# - Ne modifie pas les autres entrées, ne touche pas aux offsets.
# - Hors bornes ou _entries invalide -> ne fait rien.
func remove_track(track_number: int = 0) -> void:
	if typeof(_entries) != TYPE_ARRAY:
		return

	var i = int(track_number)
	if i < 0:
		return
	if i >= _entries.size():
		return

	_entries.remove(i)

# Retourne la première Track dont le nom correspond exactement à 'name', ou null si introuvable.
func get_track_by_name(name: String) -> Track:
	if typeof(_entries) != TYPE_ARRAY:
		return null
	for entry in _entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not entry.has("track"):
			continue
		var tr = entry["track"]
		if tr == null or typeof(tr) != TYPE_OBJECT:
			continue
		var tr_name = str(tr.get("name"))
		if tr_name == name:
			return tr
	return null


# Supprime la première piste dont le nom correspond exactement à 'name'.
# Ne supprime qu'une seule occurrence (la première rencontrée). Hors-borne ou introuvable -> ne fait rien.
func remove_track_by_name(name: String) -> void:
	if typeof(_entries) != TYPE_ARRAY:
		return
	for i in range(_entries.size()):
		var entry = _entries[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not entry.has("track"):
			continue
		var tr = entry["track"]
		if tr == null or typeof(tr) != TYPE_OBJECT:
			continue
		var tr_name = str(tr.get("name"))
		if tr_name == name:
			_entries.remove(i)
			return


# Raccourci: débute à 1:1 (bar=1, beat=0)
func add_track(track, clone: bool = false) -> void:
	add_track_at(track, 1, 0.0, clone)

func clear() -> void:
	_entries.clear()

func track_count() -> int:
	return _entries.size()

# Durée en beats (fin la plus tardive de toutes les pistes)
func duration_beats() -> float:
	var end_b = 0.0
	for e in _entries:
		var tr = e.get("track", null)
		if tr == null:
			continue
		var off = float(e.get("offset_beats", 0.0))
		var cand = off + float(tr.duration_beats())
		if cand > end_b:
			end_b = cand
	return end_b

# Ajoute un changement de tempo à bar/beat (bar = 1-based)
func add_tempo_change(bar: int, beat: float, bpm: float) -> void:
	var beats_per_bar = float(time_num)
	var bar_index = max(1, bar) - 1
	var at_beats = float(bar_index) * beats_per_bar + float(beat)
	add_tempo_change_at_beats(at_beats, bpm)

# Ajoute un tempo à un offset absolu en beats depuis 1:1
func add_tempo_change_at_beats(beats: float, bpm: float) -> void:
	var ev: Dictionary = {}
	ev["beats"] = max(0.0, float(beats))
	ev["bpm"] = max(1.0, float(bpm))
	tempo_changes.append(ev)

func clear_tempo_changes() -> void:
	tempo_changes.clear()

func tempos_count() -> int:
	return tempo_changes.size()

func get_tempo_change(i: int) -> Dictionary:
	if i >= 0 and i < tempo_changes.size():
		return tempo_changes[i]
	return {}


# === Export MIDI ===

# Bytes SMF Type-1 (1 piste conductor + N pistes)
func get_midi_bytes_type1() -> PoolByteArray:
	var file_bytes: PoolByteArray = PoolByteArray()

	# 1) Construit les chunks piste
	var tracks_bytes: Array = []
	# 1.a) Conductor (tempo + métrique + éventuel nom)
	var conductor: PoolByteArray = _build_conductor_track()
	tracks_bytes.append(conductor)

	# 1.b) Une piste par Track
	for e in _entries:
		var tr = e.get("track", null)
		if tr == null:
			continue
		var off_beats = float(e.get("offset_beats", 0.0))
		var tb = _build_track_chunk_from_track(tr, off_beats)
		tracks_bytes.append(tb)

	# 2) Header MThd
	file_bytes = _append_ascii(file_bytes, "MThd")
	file_bytes = _append_u32be(file_bytes, 6)                 # header length
	file_bytes = _append_u16be(file_bytes, 1)                 # format 1
	file_bytes = _append_u16be(file_bytes, tracks_bytes.size())  # ntrks
	file_bytes = _append_u16be(file_bytes, clamp(int(ppq), 1, 32767))

	# 3) Chunks MTrk
	for tb2 in tracks_bytes:
		file_bytes = _append_ascii(file_bytes, "MTrk")
		file_bytes = _append_u32be(file_bytes, tb2.size())
		file_bytes.append_array(tb2)

	return file_bytes


static func save_midi_file_from_bytes(filename: String = "", bytes:PoolByteArray = []) -> bool:
	
	# Gestion du nom du fichier
	# si filename est "", on utilise Song.title
	var path:String = ""

	path = "user://"+filename+".mid"
		
	#var bytes = bytes
	var f = File.new()
	var err = f.open(path, File.WRITE)
	if err != OK:
		push_error("Song.save_midi_type1: can't open " + path + " (err " + String(err) + ")")
		return false
	f.store_buffer(bytes)
	f.close()
	return true


# Sauvegarde en .mid (Type-1)
func save_midi_type1(filename: String = "") -> bool:
	
	# Gestion du nom du fichier
	# si filename est "", on utilise Song.title
	var path:String = ""
	if filename == "" :
		path = "user://"+title+".mid"
	else: 
		path = "user://"+filename+".mid"
		
	var bytes = get_midi_bytes_type1()
	var f = File.new()
	var err = f.open(path, File.WRITE)
	if err != OK:
		push_error("Song.save_midi_type1: can't open " + path + " (err " + String(err) + ")")
		return false
	f.store_buffer(bytes)
	f.close()
	return true

# === Internes ===

func _build_conductor_track() -> PoolByteArray:
	var trk: PoolByteArray = PoolByteArray()

	# Track Name (delta 0)
	trk = _vlq_append(trk, 0)
	trk.append(0xFF); trk.append(0x03)  # Meta: Track Name
	var name_str = "Conductor"
	if title != "":
		name_str = title
	var name_bytes = _ascii_bytes(name_str)
	trk = _trk_append_text(trk, name_bytes)  # ⚠️ réassigner le retour

	# Time Signature (delta 0)
	# FF 58 04 nn dd cc bb
	var nn = clamp(int(time_num), 1, 64)
	var dd = _time_den_to_dd(time_den)
	var cc = 24
	var bb = 8
	trk = _vlq_append(trk, 0)
	trk.append(0xFF); trk.append(0x58); trk.append(0x04)
	trk.append(nn & 0xFF)
	trk.append(dd & 0xFF)
	trk.append(cc & 0xFF)
	trk.append(bb & 0xFF)

	# 2) Tempo events (FF 51 03 tt tt tt), triés par tick
	var q = max(1, int(ppq))

	# construit la liste des tempos incluant l'initial à 0 si rien n'est posé à 0
	var items: Array = []
	var has_zero = false

	for ev in tempo_changes:
		var beats = float(ev.get("beats", 0.0))
		var bpmv = float(ev.get("bpm", tempo_bpm))
		var tick = int(round(beats * q))
		if tick == 0:
			has_zero = true
		items.append({"tick": tick, "bpm": bpmv})

	if not has_zero:
		# tempo initial à 0 si aucun tempo à tick 0
		items.append({"tick": 0, "bpm": tempo_bpm})

	# tri par tick asc (comparateur bool pour Godot 3.x)
	items.sort_custom(self, "_less_tempo_event")

	# écriture avec deltas
	var last_tick = 0
	for it in items:
		var tick = int(it.get("tick", 0))
		var bpmv = float(it.get("bpm", 120.0))
		var mpq = int(round(60000000.0 / max(1.0, bpmv)))

		var dt = tick - last_tick
		last_tick = tick

		trk = _vlq_append(trk, dt)
		trk.append(0xFF); trk.append(0x51); trk.append(0x03)
		trk.append((mpq >> 16) & 0xFF)
		trk.append((mpq >> 8) & 0xFF)
		trk.append(mpq & 0xFF)

	# 3) End of Track (delta 0)
	trk = _vlq_append(trk, 0)
	trk.append(0xFF); trk.append(0x2F); trk.append(0x00)
	return trk

# comparateur pour les tempos (bool attendu par sort_custom en 3.x)
func _less_tempo_event(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("tick", 0)) < int(b.get("tick", 0))

func _build_track_chunk_from_track(tr, offset_beats: float) -> PoolByteArray:
	var trk: PoolByteArray = PoolByteArray()

	# Track Name (delta 0)
	var tname = ""
	if typeof(tr) == TYPE_OBJECT and tr != null and tr.has_method("get"):
		if "name" in tr:
			tname = String(tr.name)
	if tname == "":
		tname = "Track"
	trk = _vlq_append(trk, 0)
	trk.append(0xFF); trk.append(0x03)
	var nm = _ascii_bytes(tname)
	trk = _trk_append_text(trk, nm)  # ⚠️ réassigner le retour


	# Events de la Track → ticks absolus puis deltas stables
	var q = max(1, int(ppq))
	var offset_ticks = int(round(offset_beats * q))
	var evs = tr.to_midi_events(ppq, true, 1)

	var cursor = 0  # tick absolu déjà écrit

	for e in evs:
		var t_abs = int(e.get("tick", 0)) + offset_ticks
		if t_abs < 0:
			t_abs = 0
		var dt = t_abs - cursor
		cursor = t_abs

		trk = _vlq_append(trk, dt)

		var status = int(e.get("status", 0))

		# --- Meta events (Lyrics/Markers/etc.) ---
		if status == 0xFF:
			var meta_type = 0
			if e.has("meta"):
				meta_type = int(e["meta"])
			else:
				if e.has("data1"):
					meta_type = int(e["data1"])
			# FF <type> <VLQ len> <payload>
			trk.append(0xFF)
			trk.append(meta_type & 0x7F)
			# Payload: prefer 'text' (ASCII); else 'data' if provided; else empty
			if e.has("text"):
				var txt_bytes = _ascii_bytes(String(e["text"]))
				trk = _trk_append_text(trk, txt_bytes)
			elif e.has("data"):
				var payload = e["data"]
				# Suppose payload est déjà un PoolByteArray; sinon, fallback
				if typeof(payload) == TYPE_RAW_ARRAY:
					trk = _trk_append_text(trk, payload)
				else:
					var s = String(payload)
					trk = _trk_append_text(trk, _ascii_bytes(s))
			else:
				trk = _trk_append_text(trk, PoolByteArray())
			continue

		# --- Channel Voice/Mode events ---
		var hi = status & 0xF0
		var d1 = int(e.get("data1", 0))

		trk.append(status & 0xFF)
		trk.append(clamp(d1, 0, 127))

		# Program Change (0xC0) et Channel Pressure (0xD0) ont 1 seul data byte
		if not (hi == 0xC0 or hi == 0xD0):
			var d2 = int(e.get("data2", 0))
			trk.append(clamp(d2, 0, 127))

	# End of Track
	trk = _vlq_append(trk, 0)
	trk.append(0xFF); trk.append(0x2F); trk.append(0x00)
	return trk

# ---- Helpers MIDI ----

func _time_den_to_dd(den: int) -> int:
	# dd = log2(den); den ∈ {1,2,4,8,16,32}
	var d = max(1, den)
	var k = 0
	var v = 1
	while v < d and k < 7:
		v *= 2
		k += 1
	return k

func _append_ascii(arr: PoolByteArray, s: String) -> PoolByteArray:
	for i in range(s.length()):
		arr.append(int(s.ord_at(i)) & 0xFF)
	return arr

func _ascii_bytes(s: String) -> PoolByteArray:
#	var out: PoolByteArray = PoolByteArray()
#	for i in range(s.length()):
#		out.append(int(s.ord_at(i)) & 0xFF)
#	return out
	return s.to_utf8()

func _append_u16be(arr: PoolByteArray, v: int) -> PoolByteArray:
	arr.append((v >> 8) & 0xFF)
	arr.append(v & 0xFF)
	return arr

func _append_u32be(arr: PoolByteArray, v: int) -> PoolByteArray:
	arr.append((v >> 24) & 0xFF)
	arr.append((v >> 16) & 0xFF)
	arr.append((v >> 8) & 0xFF)
	arr.append(v & 0xFF)
	return arr

func _vlq_append(arr: PoolByteArray, value: int) -> PoolByteArray:
	var v = int(value)
	if v < 0:
		v = 0
	var buf: PoolByteArray = PoolByteArray()
	buf.append(v & 0x7F)
	v = v >> 7
	while v > 0:
		buf.insert(0, 0x80 | (v & 0x7F))
		v = v >> 7
	arr.append_array(buf)
	return arr

func _trk_append_text(arr: PoolByteArray, text_bytes: PoolByteArray) -> PoolByteArray:
	# écrit: <VLQ length> + <bytes>
	arr = _vlq_append(arr, text_bytes.size())
	arr.append_array(text_bytes)
	return arr

func to_string() -> String:
	var s = ""
	
	# En-tête global
	s += "Song(title=%s, ppq=%d, tempo_bpm=%s, time=%d/%d)\n" % [
		String(title),
		int(ppq),
		String(tempo_bpm),
		int(time_num),
		int(time_den)
	]
	
	# Tempo(s)
	s += "Tempos:\n"
	s += "\tinitial: %s bpm @ 0.0 beats\n" % [String(tempo_bpm)]
	if tempo_changes != null and tempo_changes.size() > 0:
		# afficher les changements triés par 'beats' (comme _build_conductor_track)
		var items = []
		for ev in tempo_changes:
			var beats = float(ev.get("beats", 0.0))
			var bpmv = float(ev.get("bpm", tempo_bpm))
			items.append({"beats": beats, "bpm": bpmv})
		# tri simple par beats
		items.sort_custom(self, "_less_tempo_event")
		for it in items:
			s += "\tchange: %s bpm @ %s beats\n" % [
				String(float(it.get("bpm", tempo_bpm))),
				String(float(it.get("beats", 0.0)))
			]
	else:
		s += "\t(no extra tempo changes)\n"
	
	# Récap des tracks (entries)
	var total_beats = duration_beats()
	var n_entries = 0
	if _entries != null:
		n_entries = _entries.size()
	s += "Tracks: %d (duration_beats=%s)\n" % [n_entries, String(total_beats)]
	
	if n_entries > 0:
		var idx = 0
		for e in _entries:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var tr = e.get("track", null)
			var off = float(e.get("offset_beats", 0.0))
			
			var tname = "Track"
			var ch = -1
			if tr != null and typeof(tr) == TYPE_OBJECT and tr.has_method("get"):
				if "name" in tr:
					tname = String(tr.name)
				if "channel" in tr:
					ch = int(tr.channel)
			
			var notes_count = 0
			var degrees_count = 0
			var lyrics_count = 0
			var tr_dur = 0.0
			
			if tr != null and typeof(tr) == TYPE_OBJECT:
				# durée de la track
				if tr.has_method("duration_beats"):
					tr_dur = float(tr.duration_beats())
				
				# compteur d'events
				var evs = null
				if "events" in tr:
					evs = tr.events
				if evs != null:
					for ev in evs:
						if typeof(ev) == TYPE_DICTIONARY:
							if ev.has("note"):
								notes_count += 1
							elif ev.has("degree"):
								degrees_count += 1
							elif ev.has("meta") and ev.has("text"):
								if int(ev["meta"]) == 0x05:
									lyrics_count += 1
			
			s += "\t[%d] %s (ch=%d, offset=%s)  notes=%d, degrees=%d, lyrics=%d, track_duration=%s\n" % [
				idx,
				tname,
				ch,
				String(off),
				notes_count,
				degrees_count,
				lyrics_count,
				String(tr_dur)
			]
			idx += 1
	
	return s




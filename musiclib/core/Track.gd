# Track.gd — Godot 3.x
extends Reference
class_name Track



const TAG = "Track"
# Nom facultatif de la piste
var name: String = "untitled Track"

# Canal MIDI commun (optionnel). Si adopt_channel=true, on l’applique aux notes qu’on ajoute.
var channel: int = 0 setget set_channel, get_channel
var adopt_channel: bool = true setget set_adopt_channel, get_adopt_channel


var program_change = null setget set_program_change, get_program_change
var adopt_program_channel: bool = true setget set_adopt_program_channel, get_adopt_program_channel

# Événements: chaque entrée = { "start": float (en temps/mesure/beat au choix), 
# "note": Note  OU "degree": degree}
var events: Array = []

var length_beats:float setget set_length_beats,get_length_beats


func clone() -> Track:
	var t = get_script().new()
	
	# Copie des attributs simples connus
	t.name = name
	t.channel = int(channel)
	t.adopt_channel = bool(adopt_channel)
	t.adopt_program_channel = bool(adopt_program_channel)
	
	# Program Change
	if program_change != null and typeof(program_change) == TYPE_OBJECT and program_change.has_method("clone"):
		t.program_change = program_change.clone()
	else:
		t.program_change = program_change
	
	# Events (deep-ish copy)
	t.events = []
	for e in events:
		var e2 = {}
		var pos:float = e["start"]
		if e.has("note"):
			var n:Note = e["note"].clone()
			t.add_note(pos,n)
		elif e.has("degree"):
			var d:Degree = e["degree"].clone()
			t.add_degree(pos,d)
#			e2["degree"] = e["degree"].clone()
#			e2["start"] = e["start"]
#			t.events.append(e2)
			
			
		elif e.has("meta"):
			pass
			# on ne fait 
#			e2["text"] = e["text"]
#			e2["length_beats"] = 0
#			e2["start"] = e["start"]
#			t.events.append(e2)
		elif e.has("MidiCC"): 
			e["start"] =e["start"]
			e["length_beats"] = 0
			t.add_midiCC(pos, e["MidiCC"].clone())
			
	return t
	
	
	
func to_dict() -> Dictionary:
	var dic:Dictionary = {}
	dic["name"] = name
	dic["channel"] = channel
	dic["adopt_channel"] = adopt_channel
	dic["adopt_program_channel"] = adopt_program_channel
	
	
	
	if program_change != null and typeof(program_change) == TYPE_OBJECT and program_change.has_method("to_dict"):
		dic["program_change"] = program_change.to_dict()
	
	# --- Events ---
	var ev_array:Array = []
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			# on ignore les trucs exotiques
			continue
		
		var e:Dictionary = {}
		e["start"] = float(ev.get("start", 0.0))
		
		# Note
		if ev.has("note") and ev["note"] != null and typeof(ev["note"]) == TYPE_OBJECT and ev["note"].has_method("to_dict"):
			e["kind"] = "note"
			e["data"] = ev["note"].to_dict()
		
		# Degree
		elif ev.has("degree") and ev["degree"] != null and typeof(ev["degree"]) == TYPE_OBJECT and ev["degree"].has_method("to_dict"):
			e["kind"] = "degree"
			e["data"] = ev["degree"].to_dict()
		
		# ProgramChange ponctuel
		elif ev.has("program_change") and ev["program_change"] != null and typeof(ev["program_change"]) == TYPE_OBJECT and ev["program_change"].has_method("to_dict"):
			e["kind"] = "program_change"
			e["data"] = ev["program_change"].to_dict()
		
		# MidiCC
		elif ev.has("MidiCC") and ev["MidiCC"] != null and typeof(ev["MidiCC"]) == TYPE_OBJECT and ev["MidiCC"].has_method("to_dict"):
			e["kind"] = "MidiCC"
			e["data"] = ev["MidiCC"].to_dict()
		
		# Event texte / meta déjà “plat”
		elif ev.has("meta"):
			e["kind"] = "meta"
			e["meta"] = ev.get("meta", 0)
			if ev.has("text"):
				e["text"] = String(ev["text"])
		
		# On ne stocke que les events qu’on sait interpréter
		if e.has("kind"):
			ev_array.append(e)
	
	dic["events"] = ev_array

	return dic


func from_dict(dic) -> Track:
	var t:Track = get_script().new()
	
	t.name = dic.get("name", "untitled Track")
	t.channel = int(dic.get("channel", 0))
	t.adopt_channel = bool(dic.get("adopt_channel", true))
	t.adopt_program_channel = bool(dic.get("adopt_program_channel", true))
	
	# ProgramChange de piste
	var pc_data = dic.get("program_change", null)
	if typeof(pc_data) == TYPE_DICTIONARY:
		var dummy_pc = ProgramChange.new()
		t.program_change = dummy_pc.from_dict(pc_data)
	else:
		t.program_change = null
	
	# --- Events ---
	t.events.clear()
	
	var ev_array = dic.get("events", [])

	if typeof(ev_array) == TYPE_ARRAY:
		for e in ev_array:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			
			var ev:Dictionary = {}
			ev["start"] = float(e.get("start", 0.0))
			
			var kind:String = String(e.get("kind", ""))
			
			# Note
			if kind == "note":
				var data_note = e.get("data", null)
				if typeof(data_note) == TYPE_DICTIONARY:
					var dummy_note = Note.new()
					ev["note"] = dummy_note.from_dict(data_note)
			
			# Degree
			elif kind == "degree":
				var data_deg = e.get("data", null)
				if typeof(data_deg) == TYPE_DICTIONARY:
					var dummy_deg = Degree.new()
					ev["degree"] = dummy_deg.from_dict(data_deg)
			
			# ProgramChange ponctuel
			elif kind == "program_change":
				var data_pc = e.get("data", null)
				if typeof(data_pc) == TYPE_DICTIONARY:
					var dummy_pc2 = ProgramChange.new()
					ev["program_change"] = dummy_pc2.from_dict(data_pc)
			
			# MidiCC
			elif kind == "MidiCC":
				var data_cc = e.get("data", null)
				if typeof(data_cc) == TYPE_DICTIONARY:
					var dummy_cc = MidiCC.new()
					ev["MidiCC"] = dummy_cc.from_dict(data_cc)
			
			# Meta / texte simple
			elif kind == "meta":
				ev["meta"] = e.get("meta", 0)
				if e.has("text"):
					ev["text"] = String(e["text"])
			
			t.events.append(ev)
#

	return t


func set_length_beats(_n):
	LogBus.error(TAG,"You cannot set Tracks.length_beats!")
	
func get_length_beats() -> float:
	var end_pos:float = 0
	if events == null or events == []:
		return end_pos
	for e in events:
		if e.has("start") and e["start"] >= end_pos :
			end_pos = e["start"]

		
		var lb:float = 0
		if e.has("note"):
			var n:Note = e["note"]
			lb = n.length_beats
		elif e.has("degree"):
			var d:Degree = e["degree"]
			lb = d.length_beats
			
		if lb != null  and lb > 0:
			if lb + e["start"] > end_pos:
				end_pos = lb + e["start"]
					
	return end_pos		
	



# ---------- API de base ----------
# ATTENTION, POUR UN TABLEAU DE Notes !
func add_notes(batch: Array) -> void:
	# batch: Array de Dictionaries { "start": float, "note": Note }
	for e in batch:
		if typeof(e) == TYPE_DICTIONARY and e.has("start") and e.has("note"):
			add_note(float(e["start"]), e["note"])

# Pour un objet Note
## add_note(start_beats: float, note) -> int:
func add_note(start_beats: float, note) -> int:
	var ev: Dictionary = {}
	var t = max(0.0, float(start_beats))
	ev["start"] = t

	if adopt_channel and typeof(note) == TYPE_OBJECT and note != null and note.has_method("set"):
		note.channel = clamp(channel, 0, 15)

	ev["note"] = note
	events.append(ev)
	return events.size() - 1



func add_midiCC(start_beats: float, midiCC:MidiCC) -> int:
	var ev: Dictionary = {}
	var t = max(0.0, float(start_beats))
	ev["start"] = t

	if adopt_channel and typeof(midiCC) == TYPE_OBJECT and midiCC != null and midiCC.has_method("set"):
		midiCC.channel = clamp(channel, 0, 15)

	ev["MidiCC"] = midiCC
	events.append(ev)
	return events.size() - 1



func remove_at(index: int) -> void:
	if index >= 0 and index < events.size():
		events.remove(index)

func clear() -> void:
	events.clear()




func size() -> int:
	return events.size()

func is_empty() -> bool:
	return events.size() == 0

func get_event(index: int) -> Dictionary:
	if index >= 0 and index < events.size():
		return events[index]
	return {}

func set_event(index: int, start_beats: float, note) -> void:
	if index >= 0 and index < events.size():
		events[index] = {"start": max(0.0, float(start_beats)), "note": note}

func set_program_change(pc):
	program_change = pc
	# éventuellement, on aligne le canal du PC sur celui de la piste
	if adopt_program_channel and program_change != null and typeof(program_change) == TYPE_OBJECT:
		if program_change.has_method("set_channel"):
			program_change.set_channel(channel)

func get_program_change():
	return program_change

func set_adopt_program_channel(v):
	adopt_program_channel = bool(v)

func get_adopt_program_channel() -> bool:
	return adopt_program_channel

# ---------- Outils temporels ----------
func sort_by_start() -> void:
	events.sort_custom(self, "_cmp_event_start")

func shift_time(delta_beats: float) -> void:
	for i in range(events.size()):
		var ev = events[i]
		ev["start"] = max(0.0, float(ev["start"]) + float(delta_beats))
		#events[i] = ev

func half_time() -> void:
	for i in range(events.size()):
		var e = events[i]
				# Note event
		if e.has("note"):
			var n = e["note"]
			if n != null and typeof(n) == TYPE_OBJECT:
				# Accès direct à la propriété
				n.length_beats = .5 * float(n.length_beats)
		elif e.has("degree"):
			var d= e["degree"]
			if d != null and typeof(d) == TYPE_OBJECT:
				# Accès direct à la propriété
				d.length_beats = .5 * float(d.length_beats)
		e["start"] = max(0.0, .5 * float(e["start"]))



func double_time() -> void:
	for i in range(events.size()):
		var e = events[i]
				# Note event
		if e.has("note"):
			var n = e["note"]
			if n != null and typeof(n) == TYPE_OBJECT:
				# Accès direct à la propriété
				n.length_beats = 2.0 * (n.length_beats)
		elif e.has("degree"):
			var d= e["degree"]
			if d != null and typeof(d) == TYPE_OBJECT:
				# Accès direct à la propriété
				d.length_beats = 2.0 * (d.length_beats)
		e["start"] = max(0.0, 2.0 * float(e["start"]))





func duration_beats() -> float:
	var max_end = 0.0
	if events == null or events.size() == 0:
		return 0.0
	
	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		
		var start_beats = 0.0
		if e.has("start"):
			start_beats = float(e["start"])
		
		var len_beats = 0.0
		
		# Note event
		if e.has("note"):
			var n = e["note"]
			if n != null and typeof(n) == TYPE_OBJECT:
				# Accès direct à la propriété
				len_beats = float(n.length_beats)
		
		# Degree event
		elif e.has("degree"):
			var d = e["degree"]
			if d != null and typeof(d) == TYPE_OBJECT:
				# ⚠️ pas de d.has(...) : utiliser get() ou l'accès direct
				var v = d.get("length_beats")
				if v != null:
					len_beats = float(v)
				# Variante simple (si sûr que la prop existe) :
				# len_beats = float(d.length_beats)
		
		# Meta/text : ignoré pour la durée
		
		var end_beats = start_beats + len_beats
		if end_beats > max_end:
			max_end = end_beats
	
	return max_end


# ---------- Outils musicaux ----------
# Ne transpose que les objets notes
func transpose_notes_semitones(semi: int) -> void:
	if events == null or events.size() == 0:
		return
	
	for i in range(events.size()):
		var e = events[i]
		if typeof(e) == TYPE_DICTIONARY and e.has("note"):
			var n = e["note"]
			if n != null and typeof(n) == TYPE_OBJECT:
				var m = int(n.midi) + int(semi)
				if m < 0:
					m = 0
				if m > 127:
					m = 127
				n.midi = m
		# Degree → pas de transposition ici (voulu)

# transpose en octaves les notes (Note) ET les degres (Degree)
func transpose_octave(transposition_octave: int) -> void:
	var oct = int(transposition_octave)
	if oct == 0:
		return
	
	# 1) Notes -> transpo chromatique
	var semi = oct * 12
	transpose_notes_semitones(semi)
	
	# 2) Degrees -> transpo diatonique (±7 par octave)
	if events == null or events.size() == 0:
		return
	
	var delta_deg = oct * 7
	for i in range(events.size()):
		var e = events[i]
		if typeof(e) == TYPE_DICTIONARY and e.has("degree"):
			var d = e["degree"]
			if d != null and typeof(d) == TYPE_OBJECT:
				d.degree = int(d.degree) + delta_deg


func constrain_channel(ch: int) -> void:
	channel = clamp(ch, 0, 15)
	for ev in events:
		var n = ev.get("note", null)
		if n != null and typeof(n) == TYPE_OBJECT:
			n.channel = channel

# ---------- Clone profond ----------

# ---------- internes ----------
func _cmp_event_start(a, b) -> int:
	var ta = float(a.get("start", 0.0))
	var tb = float(b.get("start", 0.0))
	if ta < tb:
		return -1
	if ta > tb:
		return 1
	return 0

func set_channel(c):
	channel = clamp(int(c), 0, 15)

func get_channel() -> int:
	return channel

func set_adopt_channel(v):
	adopt_channel = bool(v)

func get_adopt_channel() -> bool:
	return adopt_channel
	
# --- Track.gd : export MIDI ---------------------------------------------------

# Convertit la piste en événements MIDI triés (ticks depuis 0).
# Retour: Array de Dicts { "tick": int, "status": int, "data1": int, "data2": int }
#  - status: 0x90|ch (Note On), 0x80|ch (Note Off)
#  - data1: note (0..127), data2: velocity (0..127)
func to_midi_events(ppq: int = 480, sort: bool = true, min_length_ticks: int = 1) -> Array:
	var evs: Array = []
	var q = max(1, int(ppq))
	var min_ticks = max(0, int(min_length_ticks))
	
	# Program Change éventuel au tick 0
	if program_change != null and typeof(program_change) == TYPE_OBJECT:
		if program_change.has_method("to_midi_event_dict"):
			var pc_ev = program_change.to_midi_event_dict(0)
			if adopt_program_channel and program_change.has_method("set_channel"):
				program_change.set_channel(channel)
			evs.append(pc_ev)

	for e in events:
		var start_beats = float(e.get("start", 0.0))

		# ----- (A) Degree -> matérialiser en accords de Notes -----
		if typeof(e) == TYPE_DICTIONARY and e.has("degree"):
			var d = e["degree"]
			if d != null and typeof(d) == TYPE_OBJECT and d.has_method("to_chord"):
				var notes = d.to_chord()  # Array<Note>
				for i in range(notes.size()):
					var n = notes[i]
					if n == null or typeof(n) != TYPE_OBJECT:
						continue

					# Adopte le canal de la track si demandé
					var ch = int(n.channel)
					if adopt_channel:
						ch = channel

					var note_num = int(n.midi)
					var vel_on = int(n.velocity)
					if note_num < 0:
						note_num = 0
					if note_num > 127:
						note_num = 127
					vel_on = clamp(vel_on, 0, 127)
					ch = clamp(ch, 0, 15)

					var len_beats = float(n.length_beats)
					if len_beats < 0.0:
						len_beats = 0.0

					var t_on = int(round(start_beats * q))
					var dur_ticks = int(round(len_beats * q))
					if dur_ticks < min_ticks:
						dur_ticks = min_ticks
					var t_off = t_on + dur_ticks

					# Note On
					evs.append({
						"tick": t_on,
						"status": 0x90 | ch,
						"data1": note_num,
						"data2": vel_on
					})
					# Note Off (velocity fixe 64)
					evs.append({
						"tick": t_off,
						"status": 0x80 | ch,
						"data1": note_num,
						"data2": 64
					})
					# On ajoute le roman numeral en "lyric"
				evs.append({
					"tick": int(round(start_beats * q)),
					"status": 0xFF,
					"meta": 5,
					"text": e["degree"].get_roman_numeral() 
				})
			continue

		# ----- (B) Events MidiCC -----
		if typeof(e) == TYPE_DICTIONARY and e.has("MidiCC"):
			var cc = e["MidiCC"]
			if cc != null and typeof(cc) == TYPE_OBJECT:
				var t_cc = int(round(start_beats * q))
				if adopt_channel and cc.has_method("set_channel"):
					cc.set_channel(channel)
				if cc.has_method("to_midi_event_dict"):
					var cc_ev = cc.to_midi_event_dict(t_cc)
					if typeof(cc_ev) == TYPE_DICTIONARY:
						evs.append(cc_ev)
			continue


		# ----- (C) Events Note "classiques" {start, note} -----
		var n2 = e.get("note", null)
		if n2 == null or typeof(n2) != TYPE_OBJECT:
			continue

		var note_num2 = int(n2.midi)
		var vel_on2 = int(n2.velocity)
		var ch2 = int(n2.channel)
		if adopt_channel:
			ch2 = channel

		if note_num2 < 0:
			note_num2 = 0
		if note_num2 > 127:
			note_num2 = 127
		vel_on2 = clamp(vel_on2, 0, 127)
		ch2 = clamp(ch2, 0, 15)

		var len_beats2 = float(n2.length_beats)
		if len_beats2 < 0.0:
			len_beats2 = 0.0

		var t_on2 = int(round(start_beats * q))
		var dur_ticks2 = int(round(len_beats2 * q))
		if dur_ticks2 < min_ticks:
			dur_ticks2 = min_ticks
		var t_off2 = t_on2 + dur_ticks2

		evs.append({
			"tick": t_on2,
			"status": 0x90 | ch2,
			"data1": note_num2,
			"data2": vel_on2
		})
		evs.append({
			"tick": t_off2,
			"status": 0x80 | ch2,
			"data1": note_num2,
			"data2": 64
		})

	if sort:
		evs.sort_custom(self, "_less_midi_event")

	return evs

# Tri: tick asc; si égal: NoteOff (0x80) avant NoteOn (0x90); puis note; puis vélocité
func _less_midi_event(a, b) -> bool:
	var ta = int(a.get("tick", 0))
	var tb = int(b.get("tick", 0))
	if ta < tb:
		return true
	if ta > tb:
		return false

	var sa = int(a.get("status", 0))
	var sb = int(b.get("status", 0))

	# 1) À tick égal, meta (0xFF) avant tout le reste (lyrics visibles sur la note)
	if sa == 0xFF and sb != 0xFF:
		return true
	if sb == 0xFF and sa != 0xFF:
		return false

	# 2) NoteOff (0x80) avant NoteOn (0x90) pour un release propre
	var ha = sa & 0xF0
	var hb = sb & 0xF0
	if ha == 0x80 and hb == 0x90:
		return true
	if hb == 0x80 and ha == 0x90:
		return false

	# 3) Fallback stable sur data1 (note number / cc)
	var a1 = int(a.get("data1", 0))
	var b1 = int(b.get("data1", 0))
	return a1 < b1

#
# Écrit un fichier MIDI Type-0 minimal avec cette piste.
# - filename: le nom du fichier (= name par défaut)
# - ppq: pulses per quarter (division)
# - tempo_bpm: tempo initial (un seul tempo, si tu veux des changements, on peut étendre)
func save_midi_type0(filename: String ="", ppq: int = 480, tempo_bpm: float = 120.0) -> bool:
	var evs = to_midi_events(ppq, true, 1)
	
	var _path:String = ""
	# gestion du _path pour l"criture du fichier
	# si pas de filename, on utilise Track.name
	if filename == "":
		_path = "user://"+name+".mid"
	else:
		_path = "user://"+filename+".mid"
	
	
	
	# Construit le chunk piste
	var track_bytes: PoolByteArray = PoolByteArray()

	# 0) Meta: Set Tempo (delta 0)
	# FF 51 03 tt tt tt  (tttttt = microsec par noire)
	var mpq = int(round(60000000.0 / max(1.0, tempo_bpm)))
	# delta-time = 0
	track_bytes = _vlq_append(track_bytes, 0)
	track_bytes.append(0xFF)
	track_bytes.append(0x51)
	track_bytes.append(0x03)
	track_bytes.append((mpq >> 16) & 0xFF)
	track_bytes.append((mpq >> 8) & 0xFF)
	track_bytes.append(mpq & 0xFF)

	# 1) Événements Note On/Off
		# 1) Événements (Note/PC/Meta...)
	var last_tick = 0
	for e in evs:
		var t = int(e.get("tick", 0))
		var dt = t - last_tick
		last_tick = t
		track_bytes = _vlq_append(track_bytes, dt)

		# --- (X) Meta events (Lyrics / Marker / etc.) ---
		if int(e.get("status", 0)) == 0xFF and e.has("meta"):
			var meta_code = int(e.get("meta", 0))
			var txt_str = String(e.get("text", ""))
			var txt_bytes: PoolByteArray = txt_str.to_ascii()  # ASCII pour compat max

			track_bytes.append(0xFF)
			track_bytes.append(meta_code & 0x7F)
			track_bytes = _vlq_append(track_bytes, txt_bytes.size())
			track_bytes.append_array(txt_bytes)
			continue

		# --- (Y) Channel Voice/Mode events (Note On/Off, CC, PC, ...) ---
		var status = int(e.get("status", 0))
		var d1 = int(e.get("data1", 0))
		var hi = status & 0xF0

		track_bytes.append(status & 0xFF)
		track_bytes.append(clamp(d1, 0, 127))

		# Program Change (0xC0) / Channel Pressure (0xD0) n'ont qu'un data byte
		if not (hi == 0xC0 or hi == 0xD0):
			var d2 = int(e.get("data2", 0))
			track_bytes.append(clamp(d2, 0, 127))



	# 2) End of Track (delta 0)
	track_bytes = _vlq_append(track_bytes, 0)
	track_bytes.append(0xFF)
	track_bytes.append(0x2F)
	track_bytes.append(0x00)

	# Assemble le fichier SMF
	var file_bytes: PoolByteArray = PoolByteArray()

	# Header "MThd" + length=6, format=0, ntrks=1, division=ppq
	file_bytes = _append_ascii(file_bytes, "MThd")
	file_bytes = _append_u32be(file_bytes, 6)
	file_bytes = _append_u16be(file_bytes, 0)   # format 0
	file_bytes = _append_u16be(file_bytes, 1)   # 1 piste
	file_bytes = _append_u16be(file_bytes, clamp(int(ppq), 1, 32767))

	# Track "MTrk" + length
	file_bytes = _append_ascii(file_bytes, "MTrk")
	file_bytes = _append_u32be(file_bytes, track_bytes.size())
	file_bytes.append_array(track_bytes)

	# Écrit sur disque
	var f = File.new()
	var err = f.open(_path, File.WRITE)
	if err != OK:
		push_error("save_midi_type0: can't open " + _path + " (err " + String(err) + ")")
		return false
	f.store_buffer(file_bytes)
	f.close()
	return true

# --- Helpers binaires (SMF) ---------------------------------------------------

func _append_ascii(arr: PoolByteArray, s: String) -> PoolByteArray:
	for i in range(s.length()):
		arr.append(int(s.ord_at(i)) & 0xFF)
	return arr

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

# Variable-Length Quantity (VLQ) append
func _vlq_append(arr: PoolByteArray, value: int) -> PoolByteArray:
	var v = int(value)
	if v < 0:
		v = 0
	# construit en bytes, puis pose le bit 0x80 sauf sur le dernier
	var buf: PoolByteArray = PoolByteArray()
	buf.append(v & 0x7F)
	v = v >> 7
	while v > 0:
		buf.insert(0, 0x80 | (v & 0x7F))
		v = v >> 7
	arr.append_array(buf)
	return arr

# --- Meta types utiles (SMF) ---
const META_LYRIC = 0x05

# Ajoute un Degree à la track, avec son timing en beats.
# - start_beats : position en beats
# - d : objet Degree (utilisera d.roman_numeral())
# - clone : clone le Degree avant stockage pour éviter le partage d'instances
# - as_lyric : ajoute aussi un meta-event "Lyric" pour l'export MIDI
func add_degree(start_beats: float, d: Degree, clone: bool = true, as_lyric: bool = false) -> void:
	
	# le meta lyric est toujours ajouté pour les degrés
	# AU MOMENT DU MIDI
	as_lyric = false
	
	if d == null:
		return

	var d2 = d
	if clone and d is Object and d.has_method("clone"):
		d2 = d.clone()

	# Event "degree" interne (pour nos traitements MusicLib)
	var ev = {}
	ev["start"] = float(start_beats)
	ev["degree"] = d2
	events.append(ev)

	# Event texte pour l'export MIDI (lyrics)
	if as_lyric:
		var label = ""
		if d2 is Object and d2.has_method("get_roman_numeral"):
			label = String(d2.get_roman_numeral())
		else:
			# Fallback minimal si roman_numeral indispo
			label = "Degree " + str(int(d2.degree))

		var meta_ev = {}
		meta_ev["start"] = float(start_beats)
		meta_ev["meta"] = int(META_LYRIC)
		meta_ev["text"] = label
		meta_ev["length_beats"] = 0
		events.append(meta_ev)

	# Tri chrono pour ne rien casser derrière
	if events.size() > 1:
		events.sort_custom(self, "compare_events_by_time")


# --- Affichage (to_string) : ajouter le cas Degree ---
# Si tu utilises déjà une version de to_string(), insère le bloc 'degree' ci-dessous
# dans ta boucle 'for e in events:' AVANT les autres cas.
func to_string() -> String:
	var s = ""
	s += "Track(name=%s, channel=%d)\n" % [str(name), int(channel)]

	s += "Events: ("+ str(events.size()) +")\n"
	for e in events:
		if e == null:
			continue

		if typeof(e) == TYPE_DICTIONARY:
			# 1) Degree event
			if e.has("degree"):
				#s += "\t" + format_degree_event(e) + "\n"
				var d:Degree = e["degree"]
				s += "DEGREE start -> " + str(e["start"])
				s += " -> " + d.get_roman_numeral() + "\n"
			# 2) Meta text (lyrics)
			elif e.has("meta") and e.has("text"):
				var start_beats = 0.0
				if e.has("start"):
					start_beats = float(e["start"])
				var label = "Lyric"
				if int(e["meta"]) != META_LYRIC:
					label = "Meta"
				s += "\t%s(start_beats=%s, \"%s\")\n" % [label, str(start_beats), String(e["text"])]
			# 3) (optionnel) autres formats d'events que tu gères déjà (notes/MIDI bruts)
			elif e.has("note"):
				s += "\t" + format_note_event(e) + "\n"
			else:
				s += "\t" + str(e) + "\n"

		elif e is Object and e.has_method("to_string"):
			s += "\t" + e.to_string() + "\n"
		else:
			s += "\t" + str(e) + "\n"

	return s


func format_degree_event(e: Dictionary) -> String:
	var start_beats = 0.0
	if e.has("start"):
		start_beats = float(e["start"])

	var d = null
	if e.has("degree"):
		d = e["degree"]

	# Préfère Degree.to_string() (il inclut la key + roman_numeral), sinon affichage compact
	if d != null and d is Object:
		if d.has_method("to_string"):
			return "DegreeEvent(start_beats=%s, %s)" % [str(start_beats), d.to_string()]
		# compact si pas de to_string()
		var rn = ""
		if d.has_method("get_roman_numeral"):
			rn = String(d.get_roman_numeral())
		return "DegreeEvent(start_beats=%s, rn=%s)" % [str(start_beats), rn]

	return "DegreeEvent(start_beats=%s, degree=%s)" % [str(start_beats), str(d)]


func format_note_event(e: Dictionary) -> String:
	var start_beats = 0.0
	if e.has("start"):
		start_beats = float(e["start"])
	
	var n = e["note"]
	var note_str = ""
	if n != null and n is Object and n.has_method("to_string"):
		note_str = n.to_string()
	else:
		# Fallback si jamais "note" est un Dictionary ou objet sans to_string()
		var midi = -1
		var vel = 0
		var len_beats = 0.0
		var ch = 0
		if typeof(n) == TYPE_DICTIONARY:
			if n.has("midi"):
				midi = int(n["midi"])

			if n.has("velocity"):
				vel = int(n["velocity"])
			if n.has("length_beats"):
				len_beats = float(n["length_beats"])
			if n.has("channel"):
				ch = int(n["channel"])
			note_str = "Note(midi=%d, velocity=%d, length_beats=%s, channel=%d)" % [midi, vel, str(len_beats), ch]
		else:
			note_str = str(n)
	
	return "NoteEvent(start_beats=%s, %s)" % [str(start_beats), note_str]


func format_midi_event_dict(e: Dictionary) -> String:
	var tick = 0
	if e.has("tick"):
		tick = int(e["tick"])
	var status = -1
	if e.has("status"):
		status = int(e["status"])

	var data = []
	if e.has("data"):
		data = e["data"]
	
	# Décodage rapide pour les notes si possible
	var typ = status & 0xF0
	var ch = status & 0x0F
	
	if typ == 0x90 or typ == 0x80:
		var note = -1
		var vel = 0
		if data.size() > 0:
			note = int(data[0])
		if data.size() > 1:
			vel = int(data[1])
		var is_off = false
		if typ == 0x80:
			is_off = true
		else:
			if vel <= 0:
				is_off = true
		if is_off:
			return "NoteOff(tick=%d, ch=%d, note=%d)" % [tick, ch + 1, note]
		else:
			return "NoteOn(tick=%d, ch=%d, note=%d, vel=%d)" % [tick, ch + 1, note, vel]
	
	# Fallback générique
	return "Event(tick=%d, status=%d, data=%s)" % [tick, status, str(data)]



# Importe les events de 'tr' dans la track courante.
# - length_beats_offset: décalage (en beats) ajouté aux events qui ont "start".
# - clone: si true, on clone les Note (et on recopie les dictionaries) pour éviter tout partage indésirable.
## merge_track(tr: Track, length_beats_offset: float, clone: bool = true) -> void:
func merge_track(tr: Track, length_beats_offset: float = 0 , clone: bool = true) -> void:
	if tr == null:
		return
	if tr.events == null or tr.events.size() == 0:
		return

	# ⚠️ Snapshot pour supporter le self-merge (tr == self) sans planter.
	var src_events = tr.events.duplicate(false)  # copie superficielle du tableau

	for e in src_events:
		var e2 = null

		if typeof(e) == TYPE_DICTIONARY:
			e2 = copy_event_dict_for_merge(e, clone)
			# Décalage "start" en beats si présent
			if e2.has("start"):
				e2["start"] = float(e2["start"]) + float(length_beats_offset)

		elif e is Object:
			if clone and e.has_method("clone"):
				e2 = e.clone()
			else:
				e2 = e

		elif typeof(e) == TYPE_ARRAY:
			e2 = e.duplicate(true)

		else:
			e2 = e

		events.append(e2)

	# Tri chronologique pour rester cohérent avec les traitements en aval
	if events != null and events.size() > 1:
		events.sort_custom(self, "compare_events_by_time")


# Copie un event (Dictionary). Clone la Note si demandé.
func copy_event_dict_for_merge(src: Dictionary, clone_notes: bool) -> Dictionary:
	var d = {}
	for k in src.keys():
		d[k] = src[k]

	if d.has("note"):
		var n = d["note"]
		if clone_notes:
			if n != null and n is Object and n.has_method("clone"):
				d["note"] = n.clone()
			elif typeof(n) == TYPE_DICTIONARY:
				d["note"] = n.duplicate(true)
			else:
				# pas clonable → conservé tel quel
				pass
		else:
			# partage volontaire de l'instance
			pass

	return d


# Temps "primaire" de tri : 'start' (beats) si dispo, sinon 'tick'.
func event_time(e) -> float:
	var t = 0.0
	if typeof(e) == TYPE_DICTIONARY:
		if e.has("start"):
			t = float(e["start"])
		elif e.has("tick"):
			t = float(e["tick"])
	elif e is Object:
		if e.has_method("get_start"):
			t = float(e.get_start())
		elif e.has_method("get_tick"):
			t = float(e.get_tick())
	return t


# Comparateur pour sort_custom : true si 'a' doit venir avant 'b'.
func compare_events_by_time(a, b) -> bool:
	var ta = event_time(a)
	var tb = event_time(b)
	if ta < tb:
		return true
	if ta > tb:
		return false

	# Égalité sur 'start' → second critère: 'tick' si dispo
	var ta2 = 0.0
	var tb2 = 0.0
	if typeof(a) == TYPE_DICTIONARY and a.has("tick"):
		ta2 = float(a["tick"])
	if typeof(b) == TYPE_DICTIONARY and b.has("tick"):
		tb2 = float(b["tick"])
	if ta2 < tb2:
		return true
	return false


func get_notes_array() -> Array:
	var out = []
	if events == null or events.size() == 0:
		return out
	
	for e in events:
		if typeof(e) == TYPE_DICTIONARY and e.has("note"):
			var n = e["note"]
			if n != null and typeof(n) == TYPE_OBJECT:
				out.append(n)
	return out


func get_degrees_array() -> Array:
	var out = []
	if events == null or events.size() == 0:
		return out
	
	for e in events:
		if typeof(e) == TYPE_DICTIONARY and e.has("degree"):
			var d = e["degree"]
			if d != null and typeof(d) == TYPE_OBJECT:
				out.append(d)
	return out

###########################################################################
###########################################################################
###########################################################################
###########################################################################
# --- Import MIDI -> Array<Track> (notes uniquement) ---
const MIDI_IMPORT_DEFAULT_PPQ = 480
const MIDI_IMPORT_TRIPLE_CROCHE_BEATS = 0.125

func importMidiFile(path: String) -> Array:
	var file = File.new()
	if not file.file_exists(path):
		return []
	var err = file.open(path, File.READ)
	if err != OK:
		return []
	var bytes = file.get_buffer(file.get_len())
	file.close()
	return midi_parse_to_tracks(bytes)


# -------- Helpers (pas d'underscore "ninja") --------

static func midi_read_ascii(bytes: PoolByteArray, pos: int, count: int) -> String:
	var s = ""
	var end = pos + count
	var i = pos
	while i < end and i < bytes.size():
		s += char(bytes[i])
		i += 1
	return s

static func midi_read_u16_be(bytes: PoolByteArray, pos: int) -> int:
	return (int(bytes[pos]) << 8) | int(bytes[pos + 1])

static func midi_read_u32_be(bytes: PoolByteArray, pos: int) -> int:
	return (int(bytes[pos]) << 24) | (int(bytes[pos + 1]) << 16) | (int(bytes[pos + 2]) << 8) | int(bytes[pos + 3])

static func midi_read_vlq(bytes: PoolByteArray, pos: int) -> Dictionary:
	var value = 0
	var i = pos
	while true:
		var b = int(bytes[i])
		i += 1
		value = (value << 7) | (b & 0x7F)
		if (b & 0x80) == 0:
			break
	return {"value": value, "next": i}

func midi_parse_to_tracks(bytes: PoolByteArray) -> Array:
	var out_tracks = []

	# --- Header ---
	if bytes.size() < 14:
		return out_tracks
	var off = 0
	var cid = midi_read_ascii(bytes, off, 4); off += 4
	if cid != "MThd":
		return out_tracks
	var hdr_len = midi_read_u32_be(bytes, off); off += 4
	var fmt = midi_read_u16_be(bytes, off); off += 2
	var ntrks = midi_read_u16_be(bytes, off); off += 2
	var division = midi_read_u16_be(bytes, off); off += 2
	# Skip any extra header bytes
	off += max(0, hdr_len - 6)

	var is_ppq = (division & 0x8000) == 0
	var ppq = MIDI_IMPORT_DEFAULT_PPQ
	if is_ppq:
		ppq = max(1, int(division))

	# --- Parcours des tracks ---
	for t in range(ntrks):
		if off + 8 > bytes.size():
			break
		var tid = midi_read_ascii(bytes, off, 4); off += 4
		var tlen = midi_read_u32_be(bytes, off); off += 4
		if tid != "MTrk":
			off += tlen
			continue
		var tend = off + tlen
		var i = off

		# Agrégation par canal → Track par canal
		var tracks_by_ch = {}   # int ch -> Track
		var track_name = "Track " + str(t + 1)

		# Notes en cours (clé "ch:note") -> Array de {start_tick, vel}
		var pendings = {}

		var abs_ticks = 0
		var running_status = -1

		while i < tend:
			# Delta time
			var vlq = midi_read_vlq(bytes, i)
			var delta = int(vlq["value"])
			i = int(vlq["next"])
			abs_ticks += delta
			if i >= tend:
				break

			var status = int(bytes[i])
			if status >= 0x80:
				i += 1
				if status < 0xF0:
					running_status = status
				else:
					running_status = -1
			else:
				if running_status < 0:
					# statut invalide → on stoppe cette piste
					break
				status = running_status

			# Meta
			if status == 0xFF:
				if i >= tend:
					break
				var meta_type = int(bytes[i]); i += 1
				var vlq2 = midi_read_vlq(bytes, i)
				var length = int(vlq2["value"])
				i = int(vlq2["next"])
				# Track Name
				if meta_type == 0x03 and length > 0:
					var s = ""
					var endm = i + length
					var j = i
					while j < endm and j < tend:
						s += char(bytes[j])
						j += 1
					if s != "":
						track_name = s
				# skip payload
				i += length
				continue

			# SysEx (F0/F7)
			if status == 0xF0 or status == 0xF7:
				var vlq3 = midi_read_vlq(bytes, i)
				var sy_len = int(vlq3["value"])
				i = int(vlq3["next"]) + sy_len
				continue

			# Channel Voice/Mode
			var hi = status & 0xF0
			var ch = status & 0x0F

			# Data bytes
			var d1 = 0
			var d2 = 0
			if hi == 0xC0 or hi == 0xD0:
				d1 = int(bytes[i]); i += 1
			else:
				d1 = int(bytes[i])
				d2 = int(bytes[i + 1])
				i += 2

			# On ne s'intéresse qu'aux notes
			if hi == 0x90:
				if d2 > 0:
					# Note On
					var key = str(ch) + ":" + str(d1)
					if not pendings.has(key):
						pendings[key] = []
					pendings[key].append({"start_tick": abs_ticks, "vel": d2})
				else:
					# Note On vel=0 -> Note Off
					midi_close_note(pendings, tracks_by_ch, ch, d1, abs_ticks, ppq, track_name)
			elif hi == 0x80:
				# Note Off
				midi_close_note(pendings, tracks_by_ch, ch, d1, abs_ticks, ppq, track_name)
			else:
				# autres messages ignorés (CC, PC, PB, AT...)
				pass

		# Fin de piste : fermer ce qui reste ouvert avec une triple-croche
		for key in pendings.keys():
			var arr = pendings[key]
			for idx in range(arr.size()):
				var start_tick = int(arr[idx]["start_tick"])
				var vel = int(arr[idx]["vel"])
				var note_num = int(key.split(":")[1])
				var ch_str = key.split(":")[0]
				var ch2 = int(ch_str)
				var tr = midi_ensure_track_for_channel(tracks_by_ch, ch2, track_name)
				var start_beats = float(start_tick) / float(ppq)
				var n = Note.new()
				n.midi = note_num
				n.velocity = vel
				n.length_beats = MIDI_IMPORT_TRIPLE_CROCHE_BEATS
				n.channel = ch2
				var ev = {"start": start_beats, "note": n}
				tr.events.append(ev)

		# Collecter les tracks non vides
		for ch_key in tracks_by_ch.keys():
			var tr_out = tracks_by_ch[ch_key]
			if tr_out != null and tr_out.events != null and tr_out.events.size() > 0:
				out_tracks.append(tr_out)

		off = tend

	return out_tracks


func midi_ensure_track_for_channel(map_tracks: Dictionary, ch: int, base_name: String) -> Track:
	if map_tracks.has(ch):
		return map_tracks[ch]
	var tr = get_script().new()
	tr.channel = ch
	tr.name = base_name + "  ch" + str(ch + 1)
	tr.events = []
	map_tracks[ch] = tr
	return tr

func midi_close_note(pendings: Dictionary, map_tracks: Dictionary, ch: int, note_num: int, abs_ticks: int, ppq: int, base_name: String) -> void:
	var key = str(ch) + ":" + str(note_num)
	if not pendings.has(key):
		return
	var stack = pendings[key]
	if stack.size() == 0:
		return
	var item = stack.pop_back()
	var start_tick = int(item["start_tick"])
	var vel = int(item["vel"])
	var dur_ticks = abs_ticks - start_tick
	if dur_ticks <= 0:
		dur_ticks = int(round(float(ppq) * MIDI_IMPORT_TRIPLE_CROCHE_BEATS))
	var start_beats = float(start_tick) / float(ppq)
	var len_beats = float(dur_ticks) / float(ppq)

	var tr = midi_ensure_track_for_channel(map_tracks, ch, base_name)

	var n = Note.new()
	n.midi = note_num
	n.velocity = vel
	n.length_beats = max(len_beats, MIDI_IMPORT_TRIPLE_CROCHE_BEATS)
	n.channel = ch

	var ev = {"start": start_beats, "note": n}
	tr.events.append(ev)

# Génère une piste d'ancres mélodiques (un Degree par événement Degree de la piste source).
# - allow_seventh : autoriser le step 7
# - allow_second  : autoriser le step 2 seulement s’il s’agit d’une seconde MAJEURE dans le contexte
# - flexibility : si 0, on prend systématiquement le candidat le plus proche du pitch précédent,
#                     sinon pioche au hasard parmi les flexibility meilleurs candidats
# - out_track : si fourni, on la remplit ; sinon on instancie via get_script().new() (évite Track.new())
# - min_midi / max_midi : registre contraint de la ligne
# - rng_seed : 0 -> randomize()
func generate_anchor_track(allow_seventh: bool = true, allow_second: bool = false, flexibility: int = 0, out_track = null, min_midi: int = 48, max_midi: int = 76, rng_seed: int = 0):
	# Garde-fous simples
	var lo = int(min_midi)
	var hi = int(max_midi)
	if hi < lo:
		var tmp = hi
		hi = lo
		lo = tmp

	# Factory safe (pas de Track.new() dans Track.gd)
	var result
	if out_track == null:
		var cls = get_script()
		if cls != null and cls.has_method("new"):
			result = cls.new()
		else:
			return null
	else:
		result = out_track

	# Quelques méta-infos utiles
	result.name = str(name) + "_anchors"
	result.channel = int(channel)
	result.adopt_channel = true
	result.program_change = program_change
	result.adopt_program_channel = adopt_program_channel

	# RNG
	var rng = RandomNumberGenerator.new()
	if int(rng_seed) != 0:
		rng.seed = int(rng_seed)
	else:
		rng.randomize()

	# État contrepoint minimal
	var prev_step = 0					# 1/3/5/7/2 du précédent
	var thirds_run = 0					# nombre de 3 consécutives
	var prev_was_tension = false		# vrai si précédent = 7 ou 2
	var pitch_target = int(floor((lo + hi) * 0.5))	# centre de registre pour la première

	# On s'appuie sur l'API maison
	#var deg_events = get_degrees_array()

	for ev in events:
		# ev attendu: { "start": float, "degree": Degree }
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		if not ev.has("degree"):
			continue
		var d = ev["degree"]
		if d == null or typeof(d) != TYPE_OBJECT:
			continue

		# 1) Étapes candidates de base
		var steps = [1, 3, 5]
		if allow_seventh:
			steps.append(7)
		if allow_second:
			# seconde seulement si MAJEURE dans le contexte
			var hk = d.key
			if hk != null and hk.has_method("degree_midi"):
				var r = int(hk.degree_midi(int(d.degree)))
				var s = int(hk.degree_midi(int(d.degree) + 1))
				var diff = (s - r) % 12
				if diff < 0:
					diff += 12
				if diff == 2:
					steps.append(9)

		# 2) Règles simples
		var cand_steps = []
		for s in steps:
			cand_steps.append(int(s))

		# pas de fondamentales ni de quintes consécutives
		if prev_step == 1:
			cand_steps.erase(1)
		if prev_step == 5:
			cand_steps.erase(5)

		# pas plus de 3 tierces d'affilée
		if thirds_run >= 3:
			cand_steps.erase(3)

		# après 7 ou 2 -> restreindre à {1,3,5}
		if prev_was_tension:
			var only135 = []
			for s2 in cand_steps:
				if s2 == 1 or s2 == 3 or s2 == 5:
					only135.append(s2)
			cand_steps = only135

		# filet de sécurité minimal si vide
		if cand_steps.size() == 0:
			cand_steps = [1, 3, 5]
			if prev_step == 1:
				cand_steps.erase(1)
			if prev_step == 5:
				cand_steps.erase(5)
			if cand_steps.size() == 0:
				cand_steps = [3]

		# 3) Construire et évaluer les candidats (tous en vrais Degree clonés)
		var ranked = []	# Array de Dict { "step", "midi", "deg", "cost" }
		for s in cand_steps:
			# clone du DEGRÉ COURANT (pas d'objet fantaisie)
			var dc = d.clone()
			# mono = [s]
			if dc.has_method("set_realization"):
				dc.set_realization([int(s)])
			else:
				dc.realization = [int(s)]
			# inversion neutre puis meilleure octave vs pitch_target
			dc.chord_inversion = 0
			if dc.has_method("best_inversion"):
				dc.best_inversion(int(pitch_target))

			# midi courant
			var arr = dc.get_chord_midi()
			var m = 60
			if typeof(arr) == TYPE_ARRAY and arr.size() > 0:
				m = int(arr[0])

			# contraindre au registre [lo, hi] (par translation d'octave)
			while m < lo:
				dc.octave_offset = int(dc.octave_offset) + 1
				arr = dc.get_chord_midi()
				if arr.size() > 0:
					m = int(arr[0])
			while m > hi:
				dc.octave_offset = int(dc.octave_offset) - 1
				arr = dc.get_chord_midi()
				if arr.size() > 0:
					m = int(arr[0])

			var cost = abs(float(m) - float(pitch_target))
			ranked.append({
				"step": int(s),
				"midi": m,
				"deg": dc,
				"cost": cost
			})

		# 4) tri par coût puis pitch le plus grave (tie-break)
		ranked.sort_custom(self, "_cmp_anchor_candidates")

		# 5) choix final en fonction de 'flexibility'
		var picked
		var k = int(flexibility) + 1
		if k < 1:
			k = 1
		if k > ranked.size():
			k = ranked.size()
		if k == 1:
			picked = ranked[0]
		else:
			var idx = rng.randi_range(0, k - 1)
			picked = ranked[idx]

		# 6) émission : on clone le DEGRÉ COURANT, on impose la realization choisie,
		#    et on reporte l'octave optimisée du candidat retenu (pour coller au pitch)
		var step_chosen = int(picked["step"])
		var cand_deg = picked["deg"]

		var degreeAnchor = d.clone()
		if degreeAnchor.has_method("set_realization"):
			degreeAnchor.set_realization([step_chosen])
		else:
			degreeAnchor.realization = [step_chosen]
		degreeAnchor.chord_inversion = 0
		degreeAnchor.octave_offset = int(cand_deg.octave_offset)

		# copier quelques attributs d'interprétation
		degreeAnchor.velocity = int(d.velocity)
		degreeAnchor.length_beats = float(d.length_beats)
		degreeAnchor.channel = int(d.channel)

		# ajout
		var start_time = 0.0
		if ev.has("start"):
			start_time = float(ev["start"])
		result.add_degree(start_time, degreeAnchor, true, true)

		# 7) mise à jour de l'état
		var midi_chosen = int(picked["midi"])
		pitch_target = midi_chosen

		if step_chosen == 3:
			thirds_run += 1
		else:
			thirds_run = 0
		prev_was_tension = (step_chosen == 7 or step_chosen == 2)
		prev_step = step_chosen

	return result


# Comparateur pour le tri des candidats (coût croissant, puis pitch le plus grave)
func _cmp_anchor_candidates(a, b):
	var ca = float(a.get("cost", 0.0))
	var cb = float(b.get("cost", 0.0))
	if ca < cb:
		return true
	if ca > cb:
		return false
	var ma = int(a.get("midi", 0))
	var mb = int(b.get("midi", 0))
	#return randi() % 2 == 0
	return ma < mb




# --- Mono & legato des Notes ou des Degrees ---
# - highest: pour départager les collisions à la même position
# - toDegree: true -> opère sur les Degree, false -> sur les Note
# - extend_last: si true et end_limit_beats >= 0, étire le DERNIER jusqu'à end_limit
# - end_limit_beats: <0 désactivé ; sinon borne absolue de fin pour le type ciblé
# - strict_clip: si true, tout event ciblé qui DÉBUTE à/au-delà de end_limit a length=0
func legato(highest: bool = true, toDegree: bool = true, extend_last: bool = false, end_limit_beats: float = -1.0, strict_clip: bool = false) -> void:
	if events == null or events.size() == 0:
		return

	# 1) Choisir le type ciblé
	var type_key = "degree"
	if not toDegree:
		type_key = "note"

	# 2) Grouper par 'start' les events du type ciblé
	var groups = {}  # start(float) -> Array<Dictionary event>
	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if not e.has("start"):
			continue
		if not e.has(type_key):
			continue
		var obj = e[type_key]
		if obj == null or typeof(obj) != TYPE_OBJECT:
			continue
		var t = float(e["start"])
		if not groups.has(t):
			groups[t] = []
		groups[t].append(e)

	# 3) Sélectionner 1 event par start selon la règle 'highest'
	#    - Notes : compare midi
	#    - Degrees : compare degree, tie-break par alter
	var chosen_by_time = {}  # start -> chosen event (Dictionary)
	var selected_list = []   # Array des events choisis (pour tri/durée)
	for t in groups.keys():
		var arr = groups[t]
		if arr == null or arr.size() == 0:
			continue

		var best = arr[0]
		if toDegree:
			# Degree: comparer d.degree (int). Tie-break: d.alter
			for i in range(1, arr.size()):
				var ev = arr[i]
				var d_best = best[type_key]
				var d_cur = ev[type_key]
				var db = int(d_best.get("degree"))
				var dc = int(d_cur.get("degree"))
				if highest:
					if dc > db:
						best = ev
					elif dc == db:
						var alb = int(d_best.get("alter"))
						var alc = int(d_cur.get("alter"))
						if alc > alb:
							best = ev
				else:
					if dc < db:
						best = ev
					elif dc == db:
						var alb2 = int(d_best.get("alter"))
						var alc2 = int(d_cur.get("alter"))
						if alc2 < alb2:
							best = ev
		else:
			# Note: comparer n.midi
			for i in range(1, arr.size()):
				var evn = arr[i]
				var n_best = best[type_key]
				var n_cur = evn[type_key]
				var mb = int(n_best.get("midi"))
				var mc = int(n_cur.get("midi"))
				if highest:
					if mc > mb:
						best = evn
				else:
					if mc < mb:
						best = evn

		chosen_by_time[t] = best
		selected_list.append(best)

	# 4) Reconstruire events en ne gardant, au même 'start', que l'event choisi du type ciblé
	var rebuilt = []
	for e in events:
		if typeof(e) == TYPE_DICTIONARY and e.has("start") and e.has(type_key):
			var t = float(e["start"])
			var keep = false
			if chosen_by_time.has(t):
				# garder exactement l'event retenu
				if e == chosen_by_time[t]:
					keep = true
			# sinon, c'est un doublon du type ciblé -> on jette
			if keep:
				rebuilt.append(e)
		else:
			# autre type d'event (meta, autre clé...) -> conserver tel quel
			rebuilt.append(e)

	events = rebuilt

	# 5) Ajuster les durées pour un legato parfait sur la séquence sélectionnée
	if selected_list.size() == 0:
		return

	# trier par temps (utilise votre comparateur existant)
	if selected_list.size() > 1:
		selected_list.sort_custom(self, "compare_events_by_time")

	# utilitaires pour fin (limite active ?)
	var limit_active = end_limit_beats >= 0.0
	var limit = float(end_limit_beats)

	# étirer chaque event (sauf le dernier) jusqu'au 'start' du suivant, avec clamp optionnel
	if selected_list.size() > 1:
		for i in range(selected_list.size() - 1):
			var e_cur = selected_list[i]
			var e_next = selected_list[i + 1]
			var t0 = float(e_cur.get("start", 0.0))
			var t1 = float(e_next.get("start", t0))

			var end_target = t1
			if limit_active and limit < end_target:
				end_target = limit

			var dur = end_target - t0
			if dur < 0.0:
				dur = 0.0

			if toDegree:
				var d = e_cur[type_key]
				d.length_beats = float(dur)
			else:
				var n = e_cur[type_key]
				n.length_beats = float(dur)

	# dernier événement : étendre/clamper selon les options
	var last_e = selected_list[selected_list.size() - 1]
	var last_start = float(last_e.get("start", 0.0))

	if limit_active:
		if extend_last and last_start < limit:
			# étirer jusqu'à la limite
			var len_last = limit - last_start
			if len_last < 0.0:
				len_last = 0.0
			if toDegree:
				last_e[type_key].length_beats = float(len_last)
			else:
				last_e[type_key].length_beats = float(len_last)
		else:
			# conserver la durée d'origine mais la clamper si elle dépasse la limite
			var cur_len = 0.0
			if toDegree:
				cur_len = float(last_e[type_key].length_beats)
			else:
				cur_len = float(last_e[type_key].length_beats)
			var max_len = limit - last_start
			if max_len < 0.0:
				max_len = 0.0
			if cur_len > max_len:
				if toDegree:
					last_e[type_key].length_beats = float(max_len)
				else:
					last_e[type_key].length_beats = float(max_len)
	# sinon: pas de limite → on garde la durée d'origine du dernier

	# 6) strict_clip: tout event ciblé qui DÉBUTE à/au-delà de end_limit a length=0
	if limit_active and strict_clip:
		for e2 in events:
			if typeof(e2) != TYPE_DICTIONARY:
				continue
			if not e2.has("start"):
				continue
			if not e2.has(type_key):
				continue
			var st = float(e2["start"])
			if st >= limit:
				if toDegree:
					e2[type_key].length_beats = 0.0
				else:
					e2[type_key].length_beats = 0.0

	# Tri final chrono global (stabilise l'ordre dans events)
	if events != null and events.size() > 1:
		events.sort_custom(self, "compare_events_by_time")


# Cherche le Degree courant à une position en beats.
# - Exact match prioritaire (start == pos), sinon on prend le dernier avant pos.
# - Retourne null si aucun Degree n'est trouvé.
func get_degree_at_pos(length_beat_pos: float) -> Degree:
	if events == null or events.size() == 0:
		return null

	var pos = float(length_beat_pos)
	var best_start = -1.0e20
	var best_degree = null

	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if not e.has("degree"):
			continue
		if not e.has("start"):
			continue

		var st = float(e["start"])
		if st > pos:
			continue

		# On garde le degree le plus proche en arrière (start max <= pos)
		if best_degree == null or st > best_start:
			var d = e["degree"]
			if d != null and typeof(d) == TYPE_OBJECT:
				best_start = st
				best_degree = d

	return best_degree
	
	
# Convertit tous les Degree de la Track en Notes (stack d’accords)
# - Chaque Degree est converti via Degree.to_chord() (fallback chord_midi() si besoin)
# - Les nouveaux events {start, note} sont ajoutés
# - Les events {degree} sont supprimés après conversion
func realize_degrees_to_notes() -> void:
	if events == null or events.size() == 0:
		return

	var batch = []     # Array<Dictionary { "start": float, "note": Note }>
	var keep = []      # nouveaux 'events' sans les degrees

	# 1) Construire la fournée de notes à ajouter + filtrer les degrees
	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			keep.append(e)
			continue

		# Event Degree -> conversion
		if e.has("degree") and e["degree"] != null and typeof(e["degree"]) == TYPE_OBJECT:
			var d = e["degree"]
			var start_beats = 0.0
			if e.has("start"):
				start_beats = float(e["start"])

			# a) voie "normale" : Degree.to_chord() -> Array<Note>
			var notes_arr = []
			if d.has_method("to_chord"):
				notes_arr = d.to_chord()
			else:
				# b) fallback sûr si to_chord() absent : fabriquer les Notes depuis chord_midi()
				var mids = []
				if d.has_method("get_chord_midi"):
					mids = d.get_chord_midi()
				for i in range(mids.size()):
					var n = Note.new()
					var m = int(mids[i])
					if m < 0:
						m = 0
					if m > 127:
						m = 127
					n.midi = m
					# hérite des paramètres du Degree
					var vel = 100
					var lb = 1.0
					var ch = 0
					if d.has("velocity"):
						vel = int(d.velocity)
					if d.has("length_beats"):
						lb = float(d.length_beats)
					if d.has("channel"):
						ch = int(d.channel)
					n.velocity = clamp(vel, 0, 127)
					n.length_beats = max(0.0, lb)
					n.channel = clamp(ch, 0, 15)
					notes_arr.append(n)

			# empiler les nouvelles notes avec leur start
			for i in range(notes_arr.size()):
				var nn = notes_arr[i]
				batch.append({
					"start": start_beats,
					"note": nn
				})
			# ne PAS conserver cet event degree (on le supprime après conversion)
			continue

		# Pas un Degree : on garde tel quel (notes existantes, meta/lyrics, etc.)
		keep.append(e)

	# 2) Remplacer les events par ceux « sans Degree »
	events = keep

	# 3) Ajouter toutes les notes converties (adopte le channel si 'adopt_channel' actif)
	for i in range(batch.size()):
		var b = batch[i]
		add_note(float(b["start"]), b["note"])

	# 4) Tri chrono propre
	if events.size() > 1:
		events.sort_custom(self, "compare_events_by_time")



func extract(from:float,to:float,normalize:bool = false) -> Track:
	
	var tr = clone()
	tr.clear()

	
	for e in events:
		var start = e["start"]
		
		
		if start >= from and start < to :
			if e.has("note"):
				var n:Note = e["note"].clone()
				var end = start + n["length_beats"]
				end = min(to,end)
				var new_note_length = end - start
				if 	new_note_length > 0 :
					n.length_beats = new_note_length
					tr.add_note(start,n)	
					
			elif e.has("degree"):
				var d:Degree = e["degree"].clone()
				var end = start + d["length_beats"]
				end = min(to,end)
				var new_degree_length = end - start
				if 	new_degree_length > 0 :
					d.length_beats = new_degree_length
					var ev = {}
					ev["start"] = e["start"]
					ev["degree"] = e["degree"].clone()
					tr.events.append(ev)
					#tr.add_degree(start,d)	
				
			elif e.has("meta"):
				var m = {}
				m["meta"] = e["meta"]
				m["text"] = e["text"]
				m["start"]  = e["start"]
				m["length_beats"]  = 0
				tr.events.append(m)
			
			elif e.has("MidiCC"):
				var m = {}
				m["MidiCC"] = e["MidiCC"].clone()
				m["start"]  = e["start"] 
				m["length_beats"]  = 0
				tr.events.append(m)
			else :
				LogBus.error(TAG," -> " + str(e) )
				LogBus.error(TAG,'"extract() -> found a unknown element in track: ' + name + " !" )
				

			
	if normalize:
		tr.shift_time(-1.0 * from)
	return tr




# Fusionne les notes consécutives de même pitch en une seule note prolongée.
# - Deux notes sont considérées consécutives si elles se touchent (pas de silence entre elles).
# - La première note est étendue jusqu'à la fin de la dernière note consécutive de même pitch.
# - Les notes suivantes (fusionnées) sont supprimées.
func same_pitch_legato() -> void:
	if events == null or events.size() == 0:
		return
	
	# 1) Extraire uniquement les events Note avec leur index d'origine
	var note_items = []  # Array de { "index": int, "event": Dictionary, "note": Note, "start": float, "end": float }
	for i in range(events.size()):
		var e = events[i]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if not e.has("note"):
			continue
		var n = e["note"]
		if n == null or typeof(n) != TYPE_OBJECT:
			continue
		if not e.has("start"):
			continue
		
		var start = float(e["start"])
		var len_beats = float(n.length_beats)
		var end = start + len_beats
		
		note_items.append({
			"index": i,
			"event": e,
			"note": n,
			"start": start,
			"end": end,
			"midi": int(n.midi)
		})
	
	if note_items.size() == 0:
		return
	
	# 2) Trier par start (puis par midi pour stabilité)
	note_items.sort_custom(self, "_cmp_note_items_for_legato")
	
	# 3) Grouper par pitch et détecter les séquences consécutives (qui se touchent)
	var to_remove = []  # indices des events à supprimer
	
	var i = 0
	while i < note_items.size():
		var current = note_items[i]
		var midi_pitch = int(current["midi"])
		var chain_start = i
		var chain_end = i
		
		# Chercher toutes les notes consécutives de même pitch
		var j = i + 1
		while j < note_items.size():
			var next_item = note_items[j]
			if int(next_item["midi"]) != midi_pitch:
				# Pitch différent -> on arrête la chaîne
				break
			
			var prev_end = float(note_items[chain_end]["end"])
			var next_start = float(next_item["start"])
			
			# Tolérance pour erreurs d'arrondi (0.001 beat)
			if next_start <= prev_end + 0.001:
				# Notes qui se touchent ou se chevauchent -> on continue la chaîne
				chain_end = j
				j += 1
			else:
				# Il y a un silence -> on arrête la chaîne
				break
		
		# 4) Si on a trouvé au moins 2 notes consécutives de même pitch
		if chain_end > chain_start:
			# Étendre la première note jusqu'à la fin de la dernière
			var first_note = note_items[chain_start]["note"]
			var first_start = float(note_items[chain_start]["start"])
			var last_end = float(note_items[chain_end]["end"])
			
			first_note.length_beats = last_end - first_start
			
			# Marquer les notes suivantes pour suppression
			for k in range(chain_start + 1, chain_end + 1):
				to_remove.append(int(note_items[k]["index"]))
		
		# Passer à la prochaine note non traitée
		i = chain_end + 1
	
	# 5) Supprimer les events marqués (en ordre décroissant pour ne pas décaler les indices)
	if to_remove.size() > 0:
		to_remove.sort()
		to_remove.invert()
		for idx in to_remove:
			events.remove(idx)
	
	# 6) Re-trier les events pour maintenir la cohérence
	if events.size() > 1:
		events.sort_custom(self, "compare_events_by_time")


# Comparateur pour trier les note_items : start asc, puis midi asc
func _cmp_note_items_for_legato(a, b) -> bool:
	var sa = float(a.get("start", 0.0))
	var sb = float(b.get("start", 0.0))
	if sa < sb:
		return true
	if sa > sb:
		return false
	# Même start -> trier par pitch
	var ma = int(a.get("midi", 0))
	var mb = int(b.get("midi", 0))
	return ma < mb


# aligne les octaves des degrés par rapport au premier degree
func adjust_track_degree_octaves():

	var degrees = get_degrees_array()
	if degrees.size() < 2 :
		return
	
	var firstDegree = degrees[0]
	

	var moyenne =  _moyenne_tableau( firstDegree.get_chord_midi() )
	
	for d in degrees:
		var degree_moyenne = _moyenne_tableau( d.get_chord_midi() )
		var delta_octaves = int(round( 1 * ((moyenne - degree_moyenne) / 12)))
		d._octave += delta_octaves


func _moyenne_tableau(t:Array)-> float:
	var somme = 0
	for nombre in t:
		somme += nombre
	return somme / t.size()
	
func multiply(n:int, clone:bool = false):
	var actual_Track_length = self.get_length_beats()
	#LogBus.debug(TAG, "length_beats" + str(get_length_beats()))
	
	var new_events = []
	for e in events :
		for i in range(0,n):
			if e.has("degree") or e.has("note"):
				#LogBus.debug(TAG,"start: "  + str( e["start"]))
				var ev
				if clone == false :
					ev = e.duplicate()
				else :
					ev = {}
					if e.has("degree") :
						ev["degree"] = e["degree"].clone()
					elif e.has("note") :
						ev["note"] = e["note"].clone()
				
				ev["start"] = e["start"] + ((i + 1 )* actual_Track_length)
				#LogBus.debug(TAG,"start ev: "  + str( ev["start"]))
				new_events.append(ev)
	events.append_array(new_events)
	events.sort_custom(self, "compare_events_by_time")
			
				


# retourne tous les degrés de la Tarck avec leur start
func get_degrees_with_start()->Array:
	var arr = []
	for e in events:
		if e.has("degree"):
			var d_dic = {}
			d_dic["degree"] = e["degree"]
			d_dic["start"] = e["start"]
			arr.append(d_dic)
	return arr
						
#func add_note(start_beats: float, note) -> int:
#	var ev: Dictionary = {}
#	var t = max(0.0, float(start_beats))
#	ev["start"] = t
#
#	if adopt_channel and typeof(note) == TYPE_OBJECT and note != null and note.has_method("set"):
#		note.channel = clamp(channel, 0, 15)
#
#	ev["note"] = note
#	events.append(ev)
#	return events.size() - 1

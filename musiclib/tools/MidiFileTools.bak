# MidiFileTools.gd
extends Reference
class_name MidiFileTools

# Outils MIDI pour Godot 3.6
# Fonctions clés:
#  - same_pitch_legato(midi_bytes, track_number) -> PoolByteArray
#  - analyse_midi_file(midi_bytes) -> String

const CHUNK_HEADER_LEN = 8
const MTHD_MAGIC = "MThd"
const MTRK_MAGIC = "MTrk"

# Status de base
const META = 0xFF
const SYSEX_START = 0xF0
const SYSEX_CONT  = 0xF7

# Channel messages: longueur de données par statut (hors statut), -1 = variable/illégal ici
const CH_MSG_DATA_LEN = {
	0x80: 2,	# Note Off: key, vel
	0x90: 2,	# Note On: key, vel
	0xA0: 2,	# Poly AT
	0xB0: 2,	# CC
	0xC0: 1,	# Program
	0xD0: 1,	# Channel AT
	0xE0: 2		# Pitch Bend (LSB, MSB)
}

# Référence temporaire pour les comparateurs sort_custom
var _cmp_events_ref: Array = []

func same_pitch_legato(midi_bytes: PoolByteArray, track_number: int) -> PoolByteArray:
	# Parse header
	var rd = _Reader.new(midi_bytes)
	var header = _read_header(rd)
	if header == null:
		push_error("MIDI invalide: en-tête MThd manquant ou corrompu")
		return midi_bytes
	
	# Lire toutes les pistes en mémoire
	var tracks: Array = []
	for i in range(header.ntrks):
		var chunk = _read_chunk(rd)
		if chunk == null or chunk.id != MTRK_MAGIC:
			push_error("Chunk de piste manquant ou invalide à l'index %d" % i)
			return midi_bytes
		tracks.append(chunk)
	
	if track_number < 0 or track_number >= tracks.size():
		push_error("Numéro de piste hors limites")
		return midi_bytes
	
	# Parse la piste cible en événements à temps absolu
	var parsed: Array = _parse_track_events(tracks[track_number].data)
	if parsed.size() == 0:
		# Soit piste vide, soit erreur de parsing — on ne modifie pas
		return midi_bytes
	
	# Apparier note-on / note-off (par pitch & canal)
	_pair_notes(parsed)
	
	# Appliquer le legato: si deux notes (même pitch & canal) se touchent, fusionner
	_apply_same_pitch_legato(parsed)
	
	# Reconstituer la piste cible (tri temporel avant écriture)
	var new_track_bytes: PoolByteArray = _rebuild_track(parsed)
	
	# Reconstruire le fichier complet: en-tête original + pistes (remplace la cible)
	var out: PoolByteArray = PoolByteArray()
	out.append_array(_write_mthd(header))
	for i in range(tracks.size()):
		if i == track_number:
			out.append_array(_write_chunk(MTRK_MAGIC, new_track_bytes))
		else:
			out.append_array(_write_chunk(MTRK_MAGIC, tracks[i].data))
	return out


# ---------- Structures internes ----------

class _Header:
	var format = 1
	var ntrks = 0
	var division = 480

class _Chunk:
	var id = ""
	var data: PoolByteArray = PoolByteArray()

class _Event:
	# Événement générique avec temps absolu
	var abs_time = 0			# ticks absolus
	var kind = ""				# "ch","meta","sysex"
	var status = 0				# statut complet (incl. canal pour "ch")
	var data = PoolByteArray()	# données brutes
	var meta_type = -1			# si meta
	var delete = false			# marqué pour suppression
	
	# Pour notes
	var is_note_on = false
	var is_note_off = false
	var pitch = -1
	var velocity = 0
	var pair_index = -1			# index de l'autre borne (on <-> off)

class _Reader:
	var bytes: PoolByteArray
	var pos = 0
	func _init(b: PoolByteArray) -> void:
#<|diff_marker|> ADD A1020
		bytes = b
		pos = 0
	func left() -> int:
		return bytes.size() - pos
	func read_u8() -> int:
		if pos >= bytes.size():
			return -1
		var v = int(bytes[pos])
		pos += 1
		return v
	func read_u16() -> int:
		var a = read_u8()
		var b = read_u8()
		if a < 0 or b < 0:
			return -1
		return (a << 8) | b
	func read_u32be() -> int:
		var a = read_u8()
		var b = read_u8()
		var c = read_u8()
#<|diff_marker|> ADD A1040
		var d = read_u8()
		if a < 0 or b < 0 or c < 0 or d < 0:
			return -1
		return (a << 24) | (b << 16) | (c << 8) | d
	func read_str(n: int) -> String:
		if pos + n > bytes.size():
			return ""
		var s = ""
		for i in range(n):
			s += char(bytes[pos + i])
		pos += n
		return s
	func read_bytes(n: int) -> PoolByteArray:
		var out = PoolByteArray()
		if n <= 0 or pos + n > bytes.size():
			return out
		out.resize(n)
		for i in range(n):
			out[i] = bytes[pos + i]
		pos += n
#<|diff_marker|> ADD A1060
		return out

# ---------- Helpers VLQ / écriture ----------
func _read_vlq(r: _Reader) -> int:
	var value = 0
	while true:
		var b = r.read_u8()
		if b < 0:
			return -1
		value = (value << 7) | (b & 0x7F)
		if (b & 0x80) == 0:
			break
	return value

func _write_vlq(n: int) -> PoolByteArray:
	var stack = []
	stack.append(n & 0x7F)
	n = n >> 7
	while n > 0:
		stack.append((n & 0x7F) | 0x80)
#<|diff_marker|> ADD A1080
		n = n >> 7
	stack.invert()
	var out = PoolByteArray()
	out.resize(stack.size())
	for i in range(stack.size()):
		out[i] = int(stack[i])
	return out

func _u16be(n: int) -> PoolByteArray:
	var p = PoolByteArray()
	p.resize(2)
	p[0] = (n >> 8) & 0xFF
	p[1] = n & 0xFF
	return p

func _u32be(n: int) -> PoolByteArray:
	var p = PoolByteArray()
	p.resize(4)
	p[0] = (n >> 24) & 0xFF
	p[1] = (n >> 16) & 0xFF
#<|diff_marker|> ADD A1100
	p[2] = (n >> 8) & 0xFF
	p[3] = n & 0xFF
	return p

func _str_bytes(s: String) -> PoolByteArray:
	var p = PoolByteArray()
	p.resize(s.length())
	for i in range(s.length()):
		p[i] = int(s.ord_at(i))
	return p

# ---------- Lecture en-tête / chunks ----------
func _read_header(r: _Reader) -> _Header:
	var id = r.read_str(4)
	if id != MTHD_MAGIC:
		return null
	var length = r.read_u32be()
	if length != 6:
		return null
	var h = _Header.new()
#<|diff_marker|> ADD A1120
	h.format = r.read_u16()
	h.ntrks = r.read_u16()
	h.division = r.read_u16()
	return h

func _read_chunk(r: _Reader) -> _Chunk:
	var id = r.read_str(4)
	if id.length() != 4:
		return null
	var length = r.read_u32be()
	if length < 0 or r.left() < length:
		return null
	var data = r.read_bytes(length)
	var c = _Chunk.new()
	c.id = id
	c.data = data
	return c

# ---------- Parsing piste ----------
func _parse_track_events(track_bytes: PoolByteArray) -> Array:
#<|diff_marker|> ADD A1140
	var r = _Reader.new(track_bytes)
	var events: Array = []
	var cur_abs = 0
	var running_status = -1
	while r.left() > 0:
		var delta = _read_vlq(r)
		if delta < 0:
			return []	# # erreur VLQ
		cur_abs += delta
		
		var peek = r.read_u8()
		if peek < 0:
			return []	# # erreur lecture octet
		
		if peek == META:
			var ev = _Event.new()
			ev.abs_time = cur_abs
			ev.kind = "meta"
			ev.status = META
			ev.meta_type = r.read_u8()
#<|diff_marker|> ADD A1160
			var mlen = _read_vlq(r)
			if mlen < 0 or r.left() < mlen:
				return []	# # longueur meta invalide
			ev.data = r.read_bytes(mlen)
			events.append(ev)
			running_status = -1
		elif peek == SYSEX_START or peek == SYSEX_CONT:
			var evs = _Event.new()
			evs.abs_time = cur_abs
			evs.kind = "sysex"
			evs.status = peek
			var slen = _read_vlq(r)
			if slen < 0 or r.left() < slen:
				return []	# # longueur sysex invalide
			evs.data = r.read_bytes(slen)
			events.append(evs)
			running_status = -1
		else:
			var status_byte = peek
			if (status_byte & 0x80) == 0:
#<|diff_marker|> ADD A1180
				# Running status
				if running_status < 0:
					return []	# # running status absent
				var ev = _parse_channel_event_with_first_data(r, cur_abs, running_status, status_byte)
				if ev == null:
					return []
				events.append(ev)
			else:
				# Nouveau statut
				running_status = status_byte
				var ev2 = _parse_channel_event(r, cur_abs, running_status)
				if ev2 == null:
					return []
				events.append(ev2)
	return events

func _parse_channel_event_with_first_data(r: _Reader, cur_abs: int, status: int, first_data: int) -> _Event:
	var st_hi = status & 0xF0
	var need = CH_MSG_DATA_LEN.get(st_hi, -1)
	if need < 0:
#<|diff_marker|> ADD A1200
		return null
	var ev = _Event.new()
	ev.abs_time = cur_abs
	ev.kind = "ch"
	ev.status = status
	var arr = PoolByteArray()
	if need == 1:
		arr.resize(1)
		arr[0] = first_data
	elif need == 2:
		arr.resize(2)
		arr[0] = first_data
		var b1 = r.read_u8()
		if b1 < 0:
			return null
		arr[1] = b1
	else:
		return null
	ev.data = arr
	_mark_note_flags(ev)
#<|diff_marker|> ADD A1220
	return ev

func _parse_channel_event(r: _Reader, cur_abs: int, status: int) -> _Event:
	var st_hi = status & 0xF0
	var need = CH_MSG_DATA_LEN.get(st_hi, -1)
	if need < 0:
		return null
	var ev = _Event.new()
	ev.abs_time = cur_abs
	ev.kind = "ch"
	ev.status = status
	var arr = PoolByteArray()
	arr.resize(need)
	for i in range(need):
		var b = r.read_u8()
		if b < 0:
			return null
		arr[i] = b
	ev.data = arr
	_mark_note_flags(ev)
#<|diff_marker|> ADD A1240
	return ev

func _mark_note_flags(ev: _Event) -> void:
	var st_hi = ev.status & 0xF0
	if st_hi == 0x90:
		# Note-on si vel > 0, sinon note-off logique
		var vel = 0
		if ev.data.size() >= 2:
			vel = int(ev.data[1])
		if ev.data.size() >= 1:
			ev.pitch = int(ev.data[0])
		else:
			ev.pitch = -1
		ev.velocity = vel
		if vel > 0:
			ev.is_note_on = true
			ev.is_note_off = false
		else:
			ev.is_note_on = false
			ev.is_note_off = true
#<|diff_marker|> ADD A1260
	elif st_hi == 0x80:
		ev.is_note_off = true
		if ev.data.size() >= 1:
			ev.pitch = int(ev.data[0])
		if ev.data.size() >= 2:
			ev.velocity = int(ev.data[1])

# ---------- Appariement des notes (pitch & canal) ----------
func _pair_notes(events: Array) -> void:
	var stacks = {}	# clé: "pitch_chan" -> pile d'indices note-on
	for i in range(events.size()):
		var ev = events[i]
		if ev.kind != "ch":
			continue
		var chan = ev.status & 0x0F
		var key = str(ev.pitch) + "_" + str(chan)
		if ev.is_note_on:
			if not stacks.has(key):
				stacks[key] = []
			stacks[key].append(i)
#<|diff_marker|> ADD A1280
		elif ev.is_note_off:
			if stacks.has(key) and stacks[key].size() > 0:
				var on_idx = stacks[key].pop_back()
				var on_ev = events[on_idx]
				on_ev.pair_index = i
				ev.pair_index = on_idx

# ---------- Fusion legato (pitch & canal) ----------
func _apply_same_pitch_legato(events: Array) -> void:
	var notes_by_key = {}
	for i in range(events.size()):
		var ev = events[i]
		if ev.kind == "ch" and ev.is_note_on and ev.pair_index >= 0:
			var chan = ev.status & 0x0F
			var key = str(ev.pitch) + "_" + str(chan)
			if not notes_by_key.has(key):
				notes_by_key[key] = []
			notes_by_key[key].append(i)
	for key in notes_by_key.keys():
		var idxs = notes_by_key[key]
#<|diff_marker|> ADD A1300
		_cmp_events_ref = events
		idxs.sort_custom(self, "_cmp_ev_abs")
		var k = 0
		while k < idxs.size() - 1:
			var i_on_a = idxs[k]
			var i_off_a = events[i_on_a].pair_index
			var i_on_b = idxs[k + 1]
			var i_off_b = events[i_on_b].pair_index
			if i_off_a < 0 or i_off_b < 0:
				k += 1
				continue
			var ev_off_a = events[i_off_a]
			var ev_on_b  = events[i_on_b]
			# Legato si le off de A est exactement au on de B
			if ev_off_a.abs_time == ev_on_b.abs_time:
				var ev_off_b = events[i_off_b]
				# prolonger A jusqu'à la fin de B
				ev_off_a.abs_time = ev_off_b.abs_time
				# supprimer B (on/off)
				events[i_on_b].delete = true
#<|diff_marker|> ADD A1320
				ev_off_b.delete = true
				# retirer B de la chaîne
				idxs.remove(k + 1)
			else:
				k += 1

func _cmp_ev_abs(a_idx, b_idx) -> bool:
	var events = _cmp_events_ref
	var ea = events[int(a_idx)]
	var eb = events[int(b_idx)]
	if ea.abs_time == eb.abs_time:
		return int(a_idx) < int(b_idx)
	return ea.abs_time < eb.abs_time

func _cmp_idx_by_time_then_index(a_idx, b_idx) -> bool:
	var events = _cmp_events_ref
	var ea = events[int(a_idx)]
	var eb = events[int(b_idx)]
	if ea.abs_time == eb.abs_time:
		return int(a_idx) < int(b_idx)
#<|diff_marker|> ADD A1340
	return ea.abs_time < eb.abs_time

# ---------- Reconstruction de piste (tri temporel) ----------
func _rebuild_track(events: Array) -> PoolByteArray:
	# 1) collecter les indices des événements à garder
	var keep = []
	for i in range(events.size()):
		var ev = events[i]
		if not ev.delete:
			keep.append(i)
	# 2) trier par (abs_time, index d'origine) pour stabilité
	_cmp_events_ref = events
	keep.sort_custom(self, "_cmp_idx_by_time_then_index")
	# 3) écrire en VLQ avec deltas recalculés
	var out = PoolByteArray()
	var time_cursor = 0
	for j in range(keep.size()):
		var i = int(keep[j])
		var ev = events[i]
		var delta = ev.abs_time - time_cursor
#<|diff_marker|> ADD A1360
		if delta < 0:
			# ne devrait plus arriver après tri, garde-fou
			delta = 0
		out.append_array(_write_vlq(delta))
		time_cursor = ev.abs_time
		if ev.kind == "meta":
			out.append(META)
			out.append(ev.meta_type)
			out.append_array(_write_vlq(ev.data.size()))
			out.append_array(ev.data)
		elif ev.kind == "sysex":
			out.append(ev.status)	# F0 ou F7
			out.append_array(_write_vlq(ev.data.size()))
			out.append_array(ev.data)
		elif ev.kind == "ch":
			# statut complet (pas de running status)
			var st_hi = ev.status & 0xF0
			var ch = ev.status & 0x0F
			var status = st_hi | ch
			# Normaliser les note-off logiques en 0x80
#<|diff_marker|> ADD A1380
			if ev.is_note_off:
				status = 0x80 | ch
			out.append(status)
			for k in range(ev.data.size()):
				out.append(ev.data[k])
	# 4) s'assurer d'un EOT final
	var has_eot = false
	for j in range(keep.size()):
		var e = events[int(keep[j])]
		if e.kind == "meta" and e.meta_type == 0x2F:
			has_eot = true
			break
	if not has_eot:
		out.append_array(_write_vlq(0))
		out.append(META)
		out.append(0x2F)
		out.append(0x00)
	return out





# ---------- Écriture MThd / chunks ----------
func _write_mthd(h: _Header) -> PoolByteArray:
	var body = PoolByteArray()
	body.append_array(_u16be(h.format))
	body.append_array(_u16be(h.ntrks))
	body.append_array(_u16be(h.division))
	var out = PoolByteArray()
	out.append_array(_str_bytes(MTHD_MAGIC))
	out.append_array(_u32be(6))
	out.append_array(body)
	return out

func _write_chunk(id: String, data: PoolByteArray) -> PoolByteArray:
	var out = PoolByteArray()
	out.append_array(_str_bytes(id))
	out.append_array(_u32be(data.size()))
	out.append_array(data)
	return out



func analyse_midi_file(midi_bytes: PoolByteArray) -> String:
	var rd = _Reader.new(midi_bytes)
	var header = _read_header(rd)
	if header == null:
		return "Erreur: MIDI invalide (en-tête MThd manquant ou corrompu)"
	
	var rep = ""
	rep += "SMF format: " + str(header.format) + "\n"
	# Division: TPQN (ticks par noire) ou SMPTE
	var div_line = ""
	if (header.division & 0x8000) != 0:
		var fps_byte = (header.division >> 8) & 0xFF
		var fps = -int(fps_byte)	# signé dans le standard (ex: -24, -25, -29, -30)
		var tpf = header.division & 0xFF
		div_line = "SMPTE: " + str(fps) + " fps, " + str(tpf) + " ticks/frame"
	else:
		div_line = "TPQN: " + str(header.division) + " ticks/quarter"
	rep += div_line + "\n"
	rep += "Pistes: " + str(header.ntrks) + "\n\n"
	
	for ti in range(header.ntrks):
		var chunk = _read_chunk(rd)
		if chunk == null or chunk.id != MTRK_MAGIC:
			rep += "Piste " + str(ti) + ": erreur — chunk MTrk manquant ou invalide\n"
			continue
		
		var events = _parse_track_events(chunk.data)
		# Compat: selon ta version, _parse_track_events peut retourner [] ou null en cas d'erreur
		var parsed_ok = true
		if events == null:
			parsed_ok = false
		else:
			if typeof(events) == TYPE_ARRAY:
				parsed_ok = true
			else:
				parsed_ok = false
		if not parsed_ok:
			rep += "Piste " + str(ti) + ": erreur de parsing\n\n"
			continue
		
		# Appariement des notes pour compter les vraies "notes"
		_pair_notes(events)
		
		# Compteurs
		var total = events.size()
		var note_on_total = 0
		var note_off_total = 0
		var note_pairs = 0
		var orphan_ons = 0
		var orphan_offs = 0
		var poly_at = 0
		var ch_at = 0
		var cc = 0
		var prog = 0
		var pb = 0
		var sysex = 0
		var meta_total = 0
		var meta_tempo = 0
		var meta_timesig = 0
		var meta_keysig = 0
		var meta_text = 0
		var meta_eot = 0
		var track_name = ""
		var first_bpm = -1.0
		var ts_num = 0
		var ts_den = 0
		var keysig_sf = 0
		var keysig_mi = 0
		var have_keysig = false
		
		for i in range(events.size()):
			var ev = events[i]
			if ev.kind == "ch":
				var st_hi = ev.status & 0xF0
				# Compte notes via flags normalisés
				if ev.is_note_on:
					note_on_total += 1
					if ev.pair_index >= 0:
						note_pairs += 1
					else:
						orphan_ons += 1
				elif ev.is_note_off:
					note_off_total += 1
					if ev.pair_index < 0:
						orphan_offs += 1
				elif st_hi == 0xA0:
					poly_at += 1
				elif st_hi == 0xB0:
					cc += 1
				elif st_hi == 0xC0:
					prog += 1
				elif st_hi == 0xD0:
					ch_at += 1
				elif st_hi == 0xE0:
					pb += 1
			elif ev.kind == "meta":
				meta_total += 1
				var mt = ev.meta_type
				if mt == 0x03:
					if track_name == "":
						track_name = _bytes_to_string(ev.data)
				elif mt == 0x51:
					meta_tempo += 1
					if first_bpm < 0.0:
						first_bpm = _meta_tempo_to_bpm(ev.data)
				elif mt == 0x58:
					meta_timesig += 1
					if ts_num == 0 and ev.data.size() >= 2:
						ts_num = int(ev.data[0])
						var _pow = int(ev.data[1])
						var den = 1
						var k = 0
						while k < _pow:
							den *= 2
							k += 1
						ts_den = den
				elif mt == 0x59:
					meta_keysig += 1
					if not have_keysig and ev.data.size() >= 2:
						keysig_sf = int(ev.data[0])	# -7..+7 (0 = C)
						keysig_mi = int(ev.data[1])	# 0 = majeur, 1 = mineur
						have_keysig = true
				elif mt == 0x01:
					meta_text += 1

			elif ev.kind == "sysex":
				sysex += 1
		
		# Ligne de titre piste
		var title = "Piste " + str(ti)
		if track_name != "":
			title += " — \"" + track_name + "\""
		rep += title + "\n"
		
		# Résumé
		rep += "  Évènements: " + str(total) + "\n"
		rep += "  Notes (appariées): " + str(note_pairs) + " | on: " + str(note_on_total) + " | off: " + str(note_off_total) + "\n"
		if orphan_ons > 0 or orphan_offs > 0:
			rep += "  Orphelines: on=" + str(orphan_ons) + ", off=" + str(orphan_offs) + "\n"
		rep += "  CC: " + str(cc) + ", Program: " + str(prog) + ", PitchBend: " + str(pb) + ", PolyAT: " + str(poly_at) + ", ChanAT: " + str(ch_at) + "\n"
		rep += "  Meta: " + str(meta_total) + " (tempo: " + str(meta_tempo) + ", timesig: " + str(meta_timesig) + ", keysig: " + str(meta_keysig) + ", text: " + str(meta_text) + ", EOT: " + str(meta_eot) + ")\n"
		rep += "  SysEx: " + str(sysex) + "\n"
		# Quelques détails lisibles
		if first_bpm > 0.0:
			rep += "  Premier tempo: " + str(first_bpm) + " BPM\n"
		if ts_num > 0 and ts_den > 0:
			rep += "  Signature: " + str(ts_num) + "/" + str(ts_den) + "\n"
		if have_keysig:
			var mode_str = "majeur"
			if keysig_mi == 1:
				mode_str = "mineur"
			rep += "  Armure: sf=" + str(keysig_sf) + " (" + mode_str + ")\n"
		rep += "\n"
	
	return rep


# --- Helpers utilisés par analyse_midi_file ---

func _bytes_to_string(p: PoolByteArray) -> String:
	var s = ""
	for i in range(p.size()):
		s += char(int(p[i]))
	return s

func _meta_tempo_to_bpm(data: PoolByteArray) -> float:
	# data = 3 octets: microsecondes par noire (MPQN)
	if data.size() < 3:
		return -1.0
	var mpqn = (int(data[0]) << 16) | (int(data[1]) << 8) | int(data[2])
	if mpqn <= 0:
		return -1.0
	return 60000000.0 / float(mpqn)

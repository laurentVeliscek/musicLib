
extends Reference
class_name Harmony_SATB
# res://musiclib/harmony.gd  (extraits à ajouter/mettre à jour)

const BASS_MIDI_MIN = 40	# E2
const BASS_MIDI_MAX = 60	# C4

var want_seventh = false
var seventh_pc = -1


func _fit_bass_to_range(bass_midi:int, min_midi:int, max_midi:int) -> int:
	var b = bass_midi
	while b < min_midi:
		b += 12
	while b > max_midi:
		b -= 12
	return b

func parse_figure(fig_raw) -> Dictionary:
	# Retourne {"kind":"triad"|"seventh", "inv": int} ou {} si invalide
	var s = str(fig_raw).strip_edges()
	if s == "1" or s == "" or s == "53":
		return {"kind":"triad", "inv":0}
	if s == "6":
		return {"kind":"triad", "inv":1}
	if s == "64":
		return {"kind":"triad", "inv":2}
	if s == "7":
		return {"kind":"seventh", "inv":0}
	if s == "65":
		return {"kind":"seventh", "inv":1}
	if s == "43":
		return {"kind":"seventh", "inv":2}
	if s == "42":
		return {"kind":"seventh", "inv":3}
	else:
		LogBus.error("[Harmony_SATB]","parse_figure() -> figure: "+ fig_raw + "is not valid !")
		return {}

func roman_chord_pcs(key:Dictionary, rn:String, want_seventh:bool) -> Dictionary:
	# Déduit la triade (maj/min/dim/aug) comme avant, puis ajoute/choisit
	# la 7e selon tables usuelles (maj/min/harmonic minor).
	# Retourne {"pcs":Array, "quality":String, "root_pc":int, "function":String}
	var tri = roman_triads_pcs(key, rn)	# ta fonction existante (triade)
	if tri.empty():
		return {}
	if not want_seventh:
		return tri

	# Ajout de la 7e selon le degré et le mode
	var root_pc = tri["root_pc"]
	var third_pc = tri["pcs"][1]
	var fifth_pc = tri["pcs"][2]
	var seventh_pc = -1

	var mode = key["mode"]
	# Tables usuelles (fonctionnelles) :
	# MAJEUR: Imaj7, ii7, iii7, IVmaj7, V7, vi7, viiø7
	# MINEUR (harmonique): i7, iiø7, IIImaj7, iv7, V7, VImaj7, vii°7
	var deg_map = {"i":1,"ii":2,"iii":3,"iv":4,"v":5,"vi":6,"vii":7}
	var s = rn.strip_edges()
	var accidental = 0
	while s.begins_with("b") or s.begins_with("#"):
		if s[0] == "b":
			accidental -= 1
		else:
			accidental += 1
		s = s.substr(1, s.length() - 1)
	var base = s.to_lower()
	if not deg_map.has(base):
		return tri
	var deg = deg_map[base]

	if mode == "major":
		if deg == 1 or deg == 4 or deg == 6:
			# maj7 sur I/IV/VI
			seventh_pc = (root_pc + 11) % 12
		elif deg == 5:
			# dominant7
			seventh_pc = (root_pc + 10) % 12
		elif deg == 2 or deg == 3:
			# min7
			seventh_pc = (root_pc + 10) % 12
		elif deg == 7:
			# half-diminished 7 (ø7): 7e mineure au-dessus de la sensible diminuée
			seventh_pc = (root_pc + 10) % 12
	else:
		# MINOR (harmonique): sensible haussée disponible via key["pc_7_h"]
		if deg == 1 or deg == 4:
			seventh_pc = (root_pc + 10) % 12	# min7
		elif deg == 5:
			seventh_pc = (root_pc + 10) % 12	# dominant7
		elif deg == 3 or deg == 6:
			seventh_pc = (root_pc + 11) % 12	# maj7 sur III/VI
		elif deg == 2:
			seventh_pc = (root_pc + 10) % 12	# ø7
		elif deg == 7:
			# vii°7 (fully dim) en mineur harmonique
			seventh_pc = (root_pc + 9) % 12	# 7e diminuée

	var pcs4 = [tri["pcs"][0], third_pc, fifth_pc]
	if seventh_pc >= 0:
		pcs4.append(seventh_pc)
	# NB: l'ordre [root,3,5,7] est volontaire pour indexer les renversements
	return {
		"pcs": pcs4,
		"quality": tri.get("quality",""),
		"function": tri.get("function",""),
		"root_pc": tri["root_pc"]
	}




#
#func _roman_to_degree(rn:String) -> int:
#	var s = rn.strip_edges()
#	# enlever altérations initiales éventuelles (b, #)
#	while s.begins_with("b") or s.begins_with("#"):
#		s = s.substr(1, s.length() - 1)
#	s = s.to_lower()
#	var map = {"i":1,"ii":2,"iii":3,"iv":4,"v":5,"vi":6,"vii":7}
#	return map.get(s, -1)
#
#func roman_pcs(key:Dictionary, rn:String, want_seventh:bool=false) -> Dictionary:
#	# Base: triade normale
#	var tri = roman_triads_pcs(key, rn)
#	if tri.empty():
#		return {}
#	if not want_seventh:
#		return tri
#
#	# Déterminer la 7e "usuelle" selon le degré et le mode
#	var root_pc = int(tri["root_pc"])
#	var mode = str(key.get("mode", "major"))
#	var deg = _roman_to_degree(rn)
#	var seventh_pc = -1
#
#	if mode == "major":
#		# IΔ7, IVΔ7, V7, ii7, iii7, vi7, viiø7
#		if deg == 1 or deg == 4:
#			seventh_pc = wrap12(root_pc + 11)	# maj7
#		elif deg == 5:
#			seventh_pc = wrap12(root_pc + 10)	# dom7
#		elif deg == 2 or deg == 3 or deg == 6 or deg == 7:
#			seventh_pc = wrap12(root_pc + 10)	# min7 (vii: demi-dim + m7)
#	else:
#		# mineur harmonique: i7, iiø7, IIIΔ7, iv7, V7, VIΔ7, vii°7
#		if deg == 3 or deg == 6:
#			seventh_pc = wrap12(root_pc + 11)	# maj7
#		elif deg == 7:
#			seventh_pc = wrap12(root_pc + 9)	# dim7 (°7)
#		else:
#			seventh_pc = wrap12(root_pc + 10)	# min7 / dom7 (iiø7, i7, iv7, V7)
#
#	var out = tri.duplicate()
#	var pcs = out.get("pcs", out.get("pitches", []))
#	if pcs.size() == 3:
#		pcs = [int(pcs[0]), int(pcs[1]), int(pcs[2])]
#	pcs.append(seventh_pc)
#	out["pcs"] = pcs
#	out["pitches"] = pcs
#	out["ext_fig"] = "7"	# <- IMPORTANT : signale une tétrade
#	return out

func build_chord(spec:Dictionary) -> Dictionary:
	var key = spec["key"]
	var inv = spec.get("inv", 0)
	var bass_oct = spec.get("bass_oct", 2)
		
	var require_complete_triad = false	# R-3-5 exigés (free_triad resserré)
	# Bornes de basse configurables par accord (sinon défaut SATB)
	var min_b = int(spec.get("bass_min", BASS_MIDI_MIN))
	var max_b = int(spec.get("bass_max", BASS_MIDI_MAX))

	# Utilitaires locaux (au cas où key_make n'aurait pas fourni sh4/b3)
	var pc_4 = key["pc_4"]
	var sh4_pc = (pc_4 + 1) % 12
	#var b3_pc = key.has("pc_3_m") ? int(key["pc_3_m"]) : int((key["pc_3_M"] + 11) % 12)
	var b3_pc = 0
	if key.has("pc_3_m"):
		b3_pc = int(key["pc_3_m"])
	else:
		b3_pc = int((int(key["pc_3_M"]) + 11) % 12)	# équiv. à pc_3_M - 1 (wrap12)

	if spec.has("type"):
		var t = spec["type"]

		# ---------- Neapolitan 6 ----------
		if t == "N6":
			# {♭2, 4, ♭6}, basse = 4
			var pcs_n6 = [key["b2_pc"], key["pc_4"], key["b6_pc"]]
			var bass_pc = key["pc_4"]
			var bass_midi = midi_of_pc_in_oct(bass_pc, bass_oct)
			bass_midi = _fit_bass_to_range(bass_midi, min_b, max_b)
			return {"pitches": pcs_n6, "bass": bass_midi, "type": "N6", "function": "pred", "key": key}

		# ---------- Cadential 6-4 ----------
		if t == "cad64":
			# appoggiature sur V : {1, 3, 5}, basse = 5
			var third_pc = key["pc_3_M"]
			if key["mode"] == "minor":
				third_pc = key["pc_3_m"]
			var pcs_cad = [key["pc_1"], third_pc, key["pc_5"]]
			var bass_pc2 = key["pc_5"]
			var bass_midi2 = midi_of_pc_in_oct(bass_pc2, bass_oct)
			bass_midi2 = _fit_bass_to_range(bass_midi2, min_b, max_b)
			return {"pitches": pcs_cad, "bass": bass_midi2, "type": "cad64", "function": "V", "key": key}

		# ---------- Augmented Sixth: It6 / Fr6 / Gr6 ----------
		if t == "It6":
			# {♭6 (basse), 1, #4} — en SATB on double 1
			var pcs_it6 = [key["b6_pc"], key["pc_1"], sh4_pc]
			var bpc_it = key["b6_pc"]
			var bmid_it = midi_of_pc_in_oct(bpc_it, bass_oct)
			bmid_it = _fit_bass_to_range(bmid_it, min_b, max_b)
			return {"pitches": pcs_it6, "bass": bmid_it, "type": "It6", "function": "pred", "key": key}

		if t == "Fr6":
			# {♭6 (basse), 1, 2, #4}
			var pc2 = key["pc_2_m"]
			if key["mode"] == "major":
				pc2 = key["pc_2_M"]
			var pcs_fr6 = [key["b6_pc"], key["pc_1"], pc2, sh4_pc]
			var bpc_fr = key["b6_pc"]
			var bmid_fr = midi_of_pc_in_oct(bpc_fr, bass_oct)
			bmid_fr = _fit_bass_to_range(bmid_fr, min_b, max_b)
			return {"pitches": pcs_fr6, "bass": bmid_fr, "type": "Fr6", "function": "pred", "key": key}

		if t == "Gr6":
			# {♭6 (basse), 1, ♭3, #4}
			var pcs_gr6 = [key["b6_pc"], key["pc_1"], b3_pc, sh4_pc]
			var bpc_gr = key["b6_pc"]
			var bmid_gr = midi_of_pc_in_oct(bpc_gr, bass_oct)
			bmid_gr = _fit_bass_to_range(bmid_gr, min_b, max_b)
			return {"pitches": pcs_gr6, "bass": bmid_gr, "type": "Gr6", "function": "pred", "key": key}

	# ---------- RN triades (par défaut) ----------
	var data = roman_triads_pcs(key, spec["rn"])
	if data.empty():
		return {}

	var pcs = data["pcs"]
	
	# Forçage: si triade diminuée, imposer 1er renversement (figure "6")
	var inv_effective = inv
	if data.get("quality", "") == "dim":
		inv_effective = 1

	# Option: l'appelant peut donner une figure "6"/"64"/"53" pour override
	var want_fig = spec.has("fig")
	var inv_options = []
	var fig_is_extension = false
	var fig_ext_value = ""	
	
	
	if want_fig:
		var fig = str(spec["fig"]).strip_edges()
		if fig == "6":
			inv_effective = 1
		elif fig == "64":
			inv_effective = 2
		elif fig == "5-3" or fig == "53" or fig == "1":
			inv_effective = 0
		# -------- Nouvelles options “libres” --------
		elif fig == "free_triad":
			# autorise fondamentale et 1er renversement
			inv_options = [0, 1]
			# triade diminuée: restreindre à 1 uniquement
			if data.get("quality","") == "dim":
				inv_options = [1]
			# Triade libre, mais pas incomplète : on exigera R-3-5 (sauf exceptions)
			require_complete_triad = true
#		elif fig == "free_seventh":
#			# autorise 7 / 65 / 43 / 42 (si tétrade)
#			inv_options = [0, 1, 2, 3]
		elif fig == "free_seventh":
			# autorise fondamentale + tous renversements
			inv_options = [0, 1, 2, 3]
			# intention: tétrade avec 7e
			want_seventh = true
			# mapping simple (majeur par défaut, robuste et musical)
			var rn_str = str(spec.get("rn",""))
			var root_pc = int(data["root_pc"]) % 12
			if rn_str.begins_with("V"):
				# dominante: 7e mineure
				seventh_pc = (root_pc + 10) % 12
			elif rn_str.begins_with("I") or rn_str.begins_with("IV") or rn_str.begins_with("VI") or rn_str.begins_with("III"):
				# degrés majeurs tonique/sous-dominants: maj7
				seventh_pc = (root_pc + 11) % 12
			else:
				# autres degrés: min7 par défaut (ii, iii, vi…)
				seventh_pc = (root_pc + 10) % 12



		# -------- Extensions (tag seulement) --------
		elif fig == "9" or fig == "b9" or fig == "#9" or fig == "11" or fig == "#11" or fig == "13" or fig == "b13" or fig == "add6" or fig == "add9" or fig == "6/9":
			fig_is_extension = true
			fig_ext_value = fig

	var idx = clamp(inv_effective, 0, 2)
	var bass_pc3 = pcs[idx]
	var bass_midi3 = midi_of_pc_in_oct(bass_pc3, bass_oct)
	bass_midi3 = _fit_bass_to_range(bass_midi3, min_b, max_b)
	
	var chord = {
		"pitches": pcs,
		"bass": bass_midi3,
		"type": "RN",
		"function": data.get("function",""),
		"key": key,
		"root_pc": data["root_pc"],
		"quality": data.get("quality",""),
		
	}
	
	# intention "free_seventh": tétrade avec 7e
	if want_seventh and seventh_pc >= 0:
		chord["want_seventh"] = true
		chord["seventh_pc"] = seventh_pc
	
		# Exiger triade complète pour free_triad, sauf exceptions:
	# - vii° (dimin.) : la 5e est souvent omise (doublure de la 3e)
	# - cas spéciaux non-RN (N6, cad64) gérés ailleurs
	if require_complete_triad:
		var rn_str = spec.get("rn","")
		var is_dim = data.get("quality","") == "dim"
		var is_vii = rn_str.begins_with("vii")
		if not is_dim and not is_vii:
			chord["require_complete_triad"] = true
	
	
	# Si “free_*” a été demandé, taggue les inversions autorisées
	if inv_options.size() > 0:
		chord["inv_options"] = inv_options
		chord["bass_oct_hint"] = bass_oct
		
	# Si une extension a été demandée, tag minimal (rn requis pour la policy)
	if fig_is_extension:
		chord["ext_fig"] = fig_ext_value
		chord["rn"] = spec.get("rn","")		
		
		
	return chord





func roman_triads_pcs(key:Dictionary, rn:String) -> Dictionary:
	# Retourne {pcs:Array, quality:String, function:String, raise7:bool, root_pc:int}
	# Supporte:
	# - Accidentels sur le degré: "bII", "#iv", "bbVII", etc.
	# - Qualité explicite: "vii°", "vii o", "vii dim", "III+", "III aug"
	# - Chiffres collés (ignorés ici): "vii°6", "ii6", "I64" (la figure sera gérée ailleurs)
	#
	# Qualités renvoyées: "maj" | "min" | "dim" | "aug"

	if rn == null:
		return {}

	var s = str(rn).strip_edges()

	# 1) séparer la partie RN de tout suffixe figure (6, 64, 53)
	var core = s
	# enlève espaces internes superflus
	core = core.replace(" ", "")
	# on garde une copie au cas où tu veux extraire la figure ailleurs
	var core_len = core.length()

	# 2) extraire accidentels en tête ("b", "#", possibles en série)
	var accidental = 0
	var i = 0
	while i < core.length():
		var ch = core[i]
		if ch == "b":
			accidental -= 1
			i += 1
			continue
		if ch == "#":
			accidental += 1
			i += 1
			continue
		break

	# 3) extraire le bloc de lettres romaines (i, v, x) jusqu'à rencontrer un non-lettre
	var start_deg = i
	while i < core.length():
		var ch2 = core[i]
		var is_roman = (ch2 == "i" or ch2 == "v" or ch2 == "x" or ch2 == "I" or ch2 == "V" or ch2 == "X")
		if not is_roman:
			break
		i += 1
	if i <= start_deg:
		return {}
	var rn_letters = core.substr(start_deg, i - start_deg)

	# 4) ce qui reste peut contenir un marqueur de qualité (°, o, +, dim, aug) + éventuellement une figure (6/64/53)
	var tail = core.substr(i, core.length() - i)

	# 4a) détecter la qualité explicite dans tail
	var explicit_quality = ""
	# on tolère "°" (unicode), "o" (ascii), "dim" ; "+" et "aug" pour augmenté
	if tail.find("°") != -1 or tail.find("o") != -1 or tail.to_lower().find("dim") != -1:
		explicit_quality = "dim"
	elif tail.find("+") != -1 or tail.to_lower().find("aug") != -1:
		explicit_quality = "aug"

	# 5) calcul du degré numérique et de la casse (majuscules = MAJ, minuscules = min)
	var base = rn_letters.to_lower()
	var is_upper = rn_letters == rn_letters.to_upper()
	# map classique i..vii (on ignore "x", “ix” n'ayant pas de sens ici)
	var map_deg = {"i":1,"ii":2,"iii":3,"iv":4,"v":5,"vi":6,"vii":7}
	if not map_deg.has(base):
		return {}
	var deg = map_deg[base]

	# 6) qualité par défaut (si non explicitée)
	# - Majuscules → "maj", minuscules → "min"
	var qual = "maj" if is_upper else "min"
	# Exceptions usuelles:
	# - VII en MAJEUR (majuscule) = "maj" (accord sur 7e degré majeur, emprunt modal possible)
	# - vii en majeur (minuscule) = "dim" habituellement (sensible diminuée)
	if deg == 7 and not is_upper:
		qual = "dim"

	# 6b) override par qualité explicite (° / dim / + / aug)
	if explicit_quality == "dim":
		qual = "dim"
	elif explicit_quality == "aug":
		qual = "aug"

	# 7) échelle (pcs) selon le mode
	var scale_major = [key["pc_1"], key["pc_2_M"], key["pc_3_M"], key["pc_4"], key["pc_5"], key["pc_6_M"], key["pc_7_M"]]
	var scale_nmin = [key["pc_1"], key["pc_2_m"], key["pc_3_m"], key["pc_4"], key["pc_5"], key["pc_6_m"], key["pc_7_m"]]
	var scale = scale_major
	if key["mode"] == "minor":
		scale = scale_nmin

	# 8) racine avec accidentels
	var root_pc = wrap12(scale[deg - 1] + accidental)

	# 9) triade selon la qualité
	var third_pc = 0
	var fifth_pc = 0
	if qual == "maj":
		third_pc = wrap12(root_pc + 4)
		fifth_pc = wrap12(root_pc + 7)
	elif qual == "min":
		third_pc = wrap12(root_pc + 3)
		fifth_pc = wrap12(root_pc + 7)
	elif qual == "dim":
		third_pc = wrap12(root_pc + 3)
		fifth_pc = wrap12(root_pc + 6)
	elif qual == "aug":
		third_pc = wrap12(root_pc + 4)
		fifth_pc = wrap12(root_pc + 8)
	else:
		# fallback sûr
		third_pc = wrap12(root_pc + 4)
		fifth_pc = wrap12(root_pc + 7)

	# 10) cas V en mineur : tierce haussée (sensible)
	var raise7 = false
	if key["mode"] == "minor" and deg == 5:
		raise7 = true
		# force la tierce à être la sensible
		third_pc = key["pc_7_h"]

	# 11) fonction simplifiée
	var fn = ""
	if deg == 5:
		fn = "V"
	elif deg == 4:
		fn = "IV"
	elif deg == 1:
		fn = "I"

	return {
		"pcs": [root_pc, third_pc, fifth_pc],
		"quality": qual,
		"function": fn,
		"raise7": raise7,
		"root_pc": root_pc
	}

func midi_of_pc_in_oct(pc:int, oct:int) -> int:
	return 12 * (oct + 1) + wrap12(pc)

func wrap12(x:int) -> int:
	return (x % 12 + 12) % 12
func key_make(tonic_pc:int, mode:String) -> Dictionary:
	var k = {"tonic_pc": wrap12(tonic_pc), "mode": mode}
	k["pc_1"] = k["tonic_pc"]
	k["pc_2_M"] = wrap12(k["tonic_pc"] + 2)
	k["pc_3_M"] = wrap12(k["tonic_pc"] + 4)
	k["pc_4"] = wrap12(k["tonic_pc"] + 5)
	k["pc_5"] = wrap12(k["tonic_pc"] + 7)
	k["pc_6_M"] = wrap12(k["tonic_pc"] + 9)
	k["pc_7_M"] = wrap12(k["tonic_pc"] + 11)
	k["pc_2_m"] = wrap12(k["tonic_pc"] + 2)
	k["pc_3_m"] = wrap12(k["tonic_pc"] + 3)
	k["pc_6_m"] = wrap12(k["tonic_pc"] + 8)
	k["pc_7_m"] = wrap12(k["tonic_pc"] + 10)
	k["pc_7_h"] = k["pc_7_M"]
	k["lt_pc"] = k["pc_7_h"] if mode == "minor" else k["pc_7_M"]
	k["b2_pc"] = wrap12(k["tonic_pc"] + 1)
	k["b6_pc"] = k["pc_6_m"]
	# utiles pour Aug6
	k["sh4_pc"] = wrap12(k["pc_4"] + 1)	# #4
	k["b3_pc"] = k["pc_3_m"]				# ♭3 (emprunt en majeur, natif en mineur)
	return k

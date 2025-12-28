extends Reference
class_name Voicing_bank

# Fichier: res://musiclib/voicing_bank.gd
# Banque/caches de voicings avec instrumentation "verbose"

const INF_HUGE = 10000000	# garde-fou local pour ce fichier
var TAG = "[Voicing_bank]"


var RANGES = {
	"S": Vector2(60, 79),	# C4..G5
	"A": Vector2(55, 74),	# G3..D5
	"T": Vector2(48, 67),	# C3..G4
	"B": Vector2(40, 60)	# E2..C4
}

var _cache = {}	# key:String -> Array[Array[int]]  (voicing = [S,A,T,B])
var _ext_spec: Dictionary = {}
var _policy = "strict"
var _ext_loader = null		# loader d'extensions (facultatif)
var _ext_style = "classique"

func set_policy(p:String) -> void:
	_policy = p

func set_extensions_spec(spec:Dictionary) -> void:
	_ext_spec = spec

	
func set_extensions_loader(loader:Node, style:String="classique") -> void:
	_ext_loader = loader	# si tu préfères appeler loader.get_policy(...)
	_ext_style = style

	
func get_voicings(chord:Dictionary, policy:String="strict", logger = null) -> Array:
	var k = _key(chord, policy)
	if _cache.has(k):
		# pour “voir” les hits, sans reconstruire
		if logger != null:
			logger.gen_cached_add(_cache[k].size())  # compteur “cached”
		return _cache[k]
#	var vox = _build_voicings(chord, policy, logger)  # <- _is_dim_triad_pcs() se passe ici
	
	
	# Génération standard
	var vox = _build_voicings(chord, policy, logger)
	# Patch ciblé: V9 / V♭9 / V#9 / ii9 → exiger la 9e et omettre la 5e
# ----- PATCH: construction proactive pour V9 / V♭9 / V#9 / ii9 -----
	if _is_ext9_target(chord):
		var before = vox.size()
#		var exted = _augment_with_ext9(vox, chord, logger)
#		# Préférence soprano: voicings avec 9 au S en tête (tri stable)
#		exted = _sort_pref_soprano_ninth(exted, chord)
		var exted = _augment_with_ext9(vox, chord, logger)
		# Assurer la présence de la 7e (core) sans réintroduire la 5e et en gardant la 9e
		exted = _ensure_core7_for_ext9(exted, chord, logger)
		# Préférence soprano: voicings avec 9 au S en tête (tri stable)
		exted = _sort_pref_soprano_ninth(exted, chord)
		vox = exted
		if logger != null:
			LogBus.debug(TAG,str("ext9_augment: in=", before, " out=", vox.size()))
	
	# ----- PATCH: construction proactive pour V11 / V#11 (dominantes) -----
	if _is_ext11_dom_target(chord):
		var before11 = vox.size()
		var ext11 = _augment_with_ext11(vox, chord, logger)
		ext11 = _ensure_core7_for_ext11(ext11, chord, logger)
		ext11 = _sort_pref_soprano_eleven(ext11, chord)
		vox = ext11
		if logger != null:
			#logger.gen_info(str("ext11_augment: in=", before11, " out=", vox.size()))
			LogBus.debug(TAG,"ext11_augment: in=" + str(before11) + " out=" + str(vox.size()))
	
	# ----- PATCH: construction proactive pour V13 / V♭13 (dominantes) -----
	if _is_ext13_dom_target(chord):
		var before13 = vox.size()
		var ext13 = _augment_with_ext13(vox, chord, logger)
		ext13 = _ensure_core37_for_ext13(ext13, chord, logger)
#		# Promotion douce : si la 13e est en voix intérieure, tenter de la mettre au soprano
#		ext13 = _promote_thirteen_to_soprano(ext13, chord)
		# Promotion robuste : si la 13e est en voix intérieure, tenter de la monter à l’octave au soprano
		ext13 = _promote_thirteen_to_soprano(ext13, chord)
		ext13 = _sort_pref_soprano_thirteen(ext13, chord)
		vox = ext13
		if logger != null:

			#logger.gen_info(str("ext13_augment: in=", before13, " out=", vox.size()))
			LogBus.debug(TAG,"ext13_augment: in=" + str(before13) +  " out=" + str(vox.size()) )	


	# ----- FREE_SEVENTH : garantir la 7e présente dans chaque voicing -----
	if chord.get("want_seventh", false):
		var before7 = vox.size()
		vox = _ensure_wanted_seventh(vox, chord, logger)
		if logger != null:
			LogBus.debug(TAG,str("free_seventh_enforce7: in=", before7, " out=", vox.size()))
			#logger.gen_info()


	# ----- Filtre "free_triad resserré" : exiger R-3-5 pour RN sans extension -----
	if chord.get("type","") == "RN":
		var need_complete = chord.get("require_complete_triad", false)
		var has_ext = chord.has("ext_fig")
		if need_complete and not has_ext:
			var rn_str = chord.get("rn","")
			var pcs = chord.get("pitches", [])
			if pcs.size() == 3:
				var r_pc = int(pcs[0])
				var third_pc = int(pcs[1])
				var fifth_pc = int(pcs[2])
				var filtered = []
				for v in vox:
					var has_r = false
					var has_3 = false
					var has_5 = false
					for i in range(4):
						var pc = v[i] % 12
						if pc == r_pc: has_r = true
						if pc == third_pc: has_3 = true
						if pc == fifth_pc: has_5 = true
					# Exiger R,3,5 tous présents
					if has_r and has_3 and has_5:
						filtered.append(v)
				if not filtered.empty():
					if logger != null:
						LogBus.debug(TAG,str("free_triad tightened: kept=", filtered.size(), " / tried=", vox.size()))
						#logger.gen_info(str("free_triad tightened: kept=", filtered.size(), " / tried=", vox.size()))
					vox = filtered



	
	_cache[k] = vox
	return vox
	
	




# Filtre post-construction: supprime tout voicing qui contient la 5e
# et conserve uniquement ceux qui contiennent la 9e (au moins une voix).
func _filter_require9_omit5(vox:Array, chord:Dictionary) -> Array:
	if vox.empty():
		return vox
	var degs = _pc_9_and_5(chord)
	var pc9 = int(degs["pc9"])
	var pc5 = int(degs["pc5"])
	if pc9 < 0 or pc5 < 0:
		return vox
	var out = []
	for v in vox:
		var has9 = false
		var has5 = false
		for i in range(4):
			var pc = int(v[i]) % 12
			if pc == pc9:
				has9 = true
			if pc == pc5:
				has5 = true
		# garder uniquement: contient 9 ET ne contient PAS 5
		if has9 and not has5:
			out.append(v)
	return out

	
	
	

func preheat(prog:Array, policy:String="strict", logger =null) -> void:
	for ch in prog:
		get_voicings(ch, policy, logger)

# ---------- génération principale ----------

func _build_voicings(chord:Dictionary, policy:String, logger =null) -> Array:
	var out = []
	var B = chord["bass"]
	if not _in_range("B", B):
		if logger != null:
			logger.gen_reject("B_out_of_range")
		return out

	var pcs:Array = chord["pitches"]	# ex RN: [root, third, fifth]
	
	# >>> HARD pour triade diminuée : basse = tierce (1er renversement) <<<
	if _is_dim_triad_pcs(pcs):
		var third_pc = pcs[1]
		if (B % 12) != third_pc %12 :
			if logger != null:
				logger.gen_reject("dim_bass_not_third")
			return out
	
	var bass_pc = B % 12

	var triplets = _role_triplets(chord, policy)
	if triplets.empty():
		if logger != null:
			logger.gen_reject("no_role_triplets")
		return out

	# pré-calcul des intervalles relatifs
	var rel = []
	for i in range(pcs.size()):
		rel.append(wrap12(pcs[i] - bass_pc))

	for t in triplets:
		# on compte chaque "template" tenté
		if logger != null:
			logger.gen_try()

		var idxS = t[0]
		var idxA = t[1]
		var idxT = t[2]
		var rT = rel[idxT]
		var rA = rel[idxA]
		var rS = rel[idxS]
		if rT == 0:
			rT = 12
		if rA == 0:
			rA = 12
		if rS == 0:
			rS = 12

		var placed = _place_triplet(B, rS, rA, rT)
		if placed.empty():
			if logger != null:
				logger.gen_reject("placement_failed")
			continue

		for v in placed:
			if _hard_doubling_forbidden(v, chord):
				if logger != null:
					logger.gen_reject("bad_doubling")
				continue
			out.append(v)
			if logger != null:
				logger.gen_keep()

	return out

# Essaye de placer [rS,rA,rT] au-dessus de B (ranges, ordre, gaps)
func _place_triplet(B:int, rS:int, rA:int, rT:int) -> Array:
	var results = []

	var T = B + rT
	while T <= B or not _in_range("T", T):
		T += 12
	if T > int(RANGES["T"].y):
		return results

	var A = B + rA
	var triesA = 0
	while (A <= T or abs(A - T) > 12 or not _in_range("A", A)) and triesA < 3:
		A += 12
		triesA += 1
	if A <= T or abs(A - T) > 12 or not _in_range("A", A):
		return results

	var S = B + rS
	var triesS = 0
	while (S <= A or abs(S - A) > 12 or not _in_range("S", S)) and triesS < 4:
		S += 12
		triesS += 1
	if S <= A or abs(S - A) > 12 or not _in_range("S", S):
		return results

	results.append([S, A, T, B])

	var S2 = S + 12
	if _in_range("S", S2) and abs(S2 - A) <= 12:
		results.append([S2, A, T, B])

	var A2 = A + 12
	if _in_range("A", A2) and abs(S - A2) <= 12:
		results.append([S, A2, T, B])

	return results

# ---------- templates de rôles (triades & co) ----------

func _role_triplets(chord:Dictionary, policy:String) -> Array:
	var pcs:Array = chord["pitches"]
	var typ = chord.get("type", "RN")
	var bass_pc = chord["bass"] % 12
	var idx_bass = _index_of_pc(pcs, bass_pc)

	# Triades & N6 & cad64 (3 sons)
	if pcs.size() == 3:
		# toutes les permutations avec répétitions autorisées
		var triples = []
		for s in range(3):
			for a in range(3):
				for t in range(3):
					triples.append([s, a, t])

		var out = []
		for tr in triples:
			if policy == "strict":
				if typ == "N6":
					# double la basse (ici: 4e degré)
					if _count_role(tr, idx_bass) < 2:
						continue
				if typ == "RN":
					# interdit de doubler la sensible
					var lt = chord["key"]["lt_pc"]
					var idx_lt = _index_of_pc(pcs, lt)
					if idx_lt >= 0 and _count_role(tr, idx_lt) >= 2:
						continue
			else:
				var lt2 = chord["key"]["lt_pc"]
				var idx_lt2 = _index_of_pc(pcs, lt2)
				if idx_lt2 >= 0 and _count_role(tr, idx_lt2) >= 2:
					continue
			out.append(tr)
		return out


	# (dans _role_triplets)
	if pcs.size() == 4:
#		var bass_pc = chord["bass"] % 12
#		var idx_bass = _index_of_pc(pcs, bass_pc)
		var others = []
		for i in range(4):
			if i != idx_bass:
				others.append(i)
		return _permute3(others)	# 6 triplets S,A,T distincts



	# défaut: rien
	return []

# ---------- garde-fous ----------

func _hard_doubling_forbidden(vox:Array, chord:Dictionary) -> bool:
	# sensible doublée (hard)
	var lt = chord["key"]["lt_pc"]
	var cnt = 0
	for i in range(4):
		if vox[i] % 12 == lt:
			cnt += 1
	return cnt >= 2

# ---------- utilitaires ----------

# 2) res://musiclib/voicing_bank.gd (MINI PATCH)
func _key(chord:Dictionary, policy:String) -> String:
	# Clé de cache étendue pour éviter collisions quand une extension est active
	var ext_tag = ""
	if chord.has("ext_fig"):
		ext_tag = str("|ext:", chord["ext_fig"], "|rn:", chord.get("rn",""))
	return str(chord.get("type",""), "|",
		chord.get("pitches", []), "|",
		chord.get("bass", -1), "|",
		policy, ext_tag)

#func _key(chord:Dictionary, policy:String) -> String:
#	var pcs = PoolIntArray()
#	for p in chord["pitches"]:
#		pcs.append(int(p))
#	pcs.sort()
#	return str(chord.get("type","RN"), "|", pcs, "|", int(chord["bass"]), "|", chord["key"]["mode"], "|", policy)



func _index_of_pc(pcs:Array, pc:int) -> int:
	for i in range(pcs.size()):
		if pcs[i] == pc:
			return i
	return -1

func _count_role(triplet:Array, idx:int) -> int:
	var c = 0
	for v in triplet:
		if v == idx:
			c += 1
	return c

func _permute3(arr:Array) -> Array:
	return [
		[arr[0],arr[1],arr[2]],
		[arr[0],arr[2],arr[1]],
		[arr[1],arr[0],arr[2]],
		[arr[1],arr[2],arr[0]],
		[arr[2],arr[0],arr[1]],
		[arr[2],arr[1],arr[0]]
	]

func _in_range(voice:String, midi:int) -> bool:
	var r = RANGES[voice]
	return midi >= int(r.x) and midi <= int(r.y)

func wrap12(x:int) -> int:
	return (x % 12 + 12) % 12

# --- helper à placer dans voicing_bank.gd (en bas, à côté des utilitaires) ---
func _is_dim_triad_pcs(pcs:Array) -> bool:
	# pcs attendu = [root, third, fifth]
	if pcs.size() < 3:
		return false
	var r = pcs[0]
	var t = pcs[1]
	var f = pcs[2]
	# dim: r->t = +3, t->f = +3 (mod 12)
	var answer = ((t - r + 12) % 12) == 3 and ((f - t + 12) % 12) == 3
	return answer


# 7e mineure relative à la fondamentale (ii7 et V7) : root + 10
func _pc7_of_chord(chord:Dictionary) -> int:
	if not chord.has("root_pc"):
		return -1
	var root_pc = int(chord["root_pc"]) % 12
	return (root_pc + 10) % 12






# -------------------- EXT9 HELPERS --------------------
# Ciblage: V9 / V♭9 / V#9 (y compris V/deg) et ii9
func _is_ext9_target(chord:Dictionary) -> bool:
	if not chord.has("ext_fig") or not chord.has("rn"):
		return false
	var fig = str(chord["ext_fig"])
	if fig != "9" and fig != "b9" and fig != "#9":
		return false
	var rn = str(chord["rn"])
	if rn.begins_with("V"):
		return true
	if rn == "ii" and fig == "9":
		return true
	return false



# Dérive pc de 9 et de 5 depuis root_pc et fig (b9/#9 supportés)
func _pc_9_and_5(chord:Dictionary) -> Dictionary:
	var out = {"pc9": -1, "pc5": -1}
	if not chord.has("root_pc"):
		return out
	var root_pc = int(chord["root_pc"]) % 12
	out["pc5"] = (root_pc + 7) % 12
	var fig = str(chord.get("ext_fig",""))
	if fig == "b9":
		out["pc9"] = (root_pc + 1) % 12
	elif fig == "#9":
		out["pc9"] = (root_pc + 3) % 12
	else:
		out["pc9"] = (root_pc + 14) % 12
	return out

# Vérifs simples SATB (ranges, ordre, gaps S–A / A–T <= 12)
func _valid_satb(v:Array) -> bool:
	if v.size() != 4:
		return false
	# ordre S > A > T > B
	if not (v[0] > v[1] and v[1] > v[2] and v[2] > v[3]):
		return false
	# gaps <= 12 (S–A / A–T)
	if abs(v[0] - v[1]) > 12:
		return false
	if abs(v[1] - v[2]) > 12:
		return false
	# ranges
	if not _in_range("S", v[0]): return false
	if not _in_range("A", v[1]): return false
	if not _in_range("T", v[2]): return false
	if not _in_range("B", v[3]): return false
	return true

# Remplace (si possible) UNE occurrence de 5 par 9 dans un voicing, en gardant SATB valide
func _try_replace_5_with_9(v:Array, chord:Dictionary, pc5:int, pc9:int) -> Array:
	# On privilégie la transformation sur une voix intérieure (A puis T), sinon S
	var order = [1, 2, 0]	# indices A,T,S
	for idx in order:
		if v[idx] % 12 != pc5:
			continue
		# Cherche la 9 la plus proche de la note courante, dans le range de la voix
		var cand = v[idx]
		var tries = 0
		var best = -9999
		var best_d = 9999
		# on teste ±0,±12,±24 (3 tentatives) pour recaler la 9 à proximité
		for k in [-24, -12, 0, 12, 24]:
			var n = (cand - (cand % 12) + pc9) + k
			# garder proche
			var dist = abs(n - cand)
#			if not _in_range(idx == 0 ? "S" : (idx == 1 ? "A" : "T"), n):
			var voice = ""
			if idx == 0:
				voice = "S"
			elif idx == 1:
				voice = "A"
			else:
				voice = "T"

			if not _in_range(voice, n):
				continue


			# build candidat modifié
			var v2 = [v[0], v[1], v[2], v[3]]
			v2[idx] = n
			if _valid_satb(v2):
				if dist < best_d:
					best_d = dist
					best = n
		if best != -9999:
			var out = [v[0], v[1], v[2], v[3]]
			out[idx] = best
			return out
	return []

# Construit un set étendu: ajoute des voicings avec 9 et supprime 5 systématiquement
func _augment_with_ext9(vox:Array, chord:Dictionary, logger) -> Array:
	var degs = _pc_9_and_5(chord)
	var pc9 = int(degs["pc9"])
	var pc5 = int(degs["pc5"])
	if pc9 < 0 or pc5 < 0:
		return vox
	var out = []
	var seen = {}
	for v in vox:
		var has9 = false
		var has5 = false
		for i in range(4):
			var pc = v[i] % 12
			if pc == pc9: has9 = true
			if pc == pc5: has5 = true
		# Si déjà (has9 && !has5): garder tel quel
		if has9 and not has5:
			var k = str(v[0],"|",v[1],"|",v[2],"|",v[3])
			if not seen.has(k):
				seen[k] = true
				out.append(v)
			continue
		# Sinon, tenter de créer une variante où la 5 devient 9
		if not has9 and has5:
			var v2 = _try_replace_5_with_9(v, chord, pc5, pc9)
			if v2.size() == 4:
				var k2 = str(v2[0],"|",v2[1],"|",v2[2],"|",v2[3])
				if not seen.has(k2):
					seen[k2] = true
					out.append(v2)
		# Cas intermédiaire (contient 9 et 5) → on tente d’éliminer la 5
		if has9 and has5:
			var v3 = _try_replace_5_with_9(v, chord, pc5, pc9)
			if v3.size() == 4:
				var k3 = str(v3[0],"|",v3[1],"|",v3[2],"|",v3[3])
				if not seen.has(k3):
					seen[k3] = true
					out.append(v3)
	# Tri final: on **écarte** toute trace restante de 5 et on **impose** la présence de 9
	var final = []
	for v in out:
		var has9b = false
		var has5b = false
		for i in range(4):
			var pc = v[i] % 12
			if pc == pc9: has9b = true
			if pc == pc5: has5b = true
		if has9b and not has5b:
			final.append(v)
	return final



# Imposer la 7e si absente, sans perdre la 9e et sans réintroduire la 5e
func _ensure_core7_for_ext9(vox:Array, chord:Dictionary, logger) -> Array:
	if vox.empty():
		return vox
	var degs = _pc_9_and_5(chord)
	var pc9 = int(degs["pc9"])
	var pc5 = int(degs["pc5"])
	var pc7 = _pc7_of_chord(chord)
	if pc9 < 0 or pc5 < 0 or pc7 < 0:
		return vox
	var root_pc = int(chord.get("root_pc", -1)) % 12
	var out = []
	var seen = {}
	for v in vox:
		# audit du voicing
		var has9 = false
		var has5 = false
		var has7 = false
		var count_root = 0
		for i in range(4):
			var pc = v[i] % 12
			if pc == pc9: has9 = true
			if pc == pc5: has5 = true
			if pc == pc7: has7 = true
			if pc == root_pc: count_root += 1
		# invariant: déjà vérifié: has9 == true et has5 == false (par l'étape précédente)
		if has7:
			var k0 = str(v[0],"|",v[1],"|",v[2],"|",v[3])
			if not seen.has(k0):
				seen[k0] = true
				out.append(v)
			continue
		# sinon, tenter d'introduire UNE 7e en remplaçant une doublure (R prioritaire), sinon 3, sinon voix intérieure quelconque (hors B)
		var candidate = _try_impose_7(v, chord, pc7, pc9, pc5, root_pc)
		if candidate.size() == 4:
			var k1 = str(candidate[0],"|",candidate[1],"|",candidate[2],"|",candidate[3])
			if not seen.has(k1):
				seen[k1] = true
				out.append(candidate)
	# dernier filtre de sûreté
	var final = []
	for v2 in out:
		var ok9 = false
		var ok7 = false
		var bad5 = false
		for i in range(4):
			var pc = v2[i] % 12
			if pc == pc9: ok9 = true
			if pc == pc7: ok7 = true
			if pc == pc5: bad5 = true
		if ok9 and ok7 and not bad5:
			final.append(v2)
	return final

# Tente d'imposer la 7e en modifiant une seule voix (évite B, évite d'écraser la 9e), garde SATB valide
func _try_impose_7(v:Array, chord:Dictionary, pc7:int, pc9:int, pc5:int, root_pc:int) -> Array:
	# ordre de préférence des voix à modifier : A, T, S (on évite B)
	var order = [1, 2, 0]
	# cible de remplacement en priorité: doublure de R, sinon toute note != 9 (éviter d'écraser 9)
	for idx in order:
		var pc_here = v[idx] % 12
		if pc_here == pc9:
			continue
		if pc_here == pc5:
			continue
		# on autorise à remplacer une doublure de R en priorité, mais si ce n'est pas R on essaie quand même
		# recaler la 7e près de la note existante, dans le range de la voix
		var base = v[idx]
		var best = -9999
		var best_d = 9999
		for k in [-24, -12, 0, 12, 24]:
			var n = (base - (base % 12) + pc7) + k
			# vérifier tessiture de la voix
			var voice = ""
			if idx == 0:
				voice = "S"
			elif idx == 1:
				voice = "A"
			else:
				voice = "T"
			if not _in_range(voice, n):
				continue
			# construire le candidat et valider SATB + contraintes (pas de 5, garder 9)
			var v2 = [v[0], v[1], v[2], v[3]]
			v2[idx] = n
			if not _valid_satb(v2):
				continue
			var keep9 = false
			var has5 = false
			for j in range(4):
				var pc2 = v2[j] % 12
				if pc2 == pc9: keep9 = true
				if pc2 == pc5: has5 = true
			if has5 or not keep9:
				continue
			var dist = abs(n - base)
			if dist < best_d:
				best_d = dist
				best = n
		if best != -9999:
			var out = [v[0], v[1], v[2], v[3]]
			out[idx] = best
			return out
	return []


# Bias doux: voicings avec 9 au S en tête (tri stable)
func _sort_pref_soprano_ninth(vox:Array, chord:Dictionary) -> Array:
	var degs = _pc_9_and_5(chord)
	var pc9 = int(degs["pc9"])
	if pc9 < 0:
		return vox
	# partitionne: [S a 9] + [autres], puis concat (ordre relatif conservé)
	var with9 = []
	var other = []
	for v in vox:
		if v[0] % 12 == pc9:
			with9.append(v)
		else:
			other.append(v)
	for x in other:
		with9.append(x)
	return with9




# ==================== EXT11 HELPERS (dominantes) ====================
# Ciblage: V11 / V#11 (y compris V/deg). On ne traite pas ici les "minor 11" non-dominants.
func _is_ext11_dom_target(chord:Dictionary) -> bool:
	if not chord.has("ext_fig") or not chord.has("rn"):
		return false
	var fig = str(chord["ext_fig"])
	if fig != "11" and fig != "#11":
		return false
	var rn = str(chord["rn"])
	return rn.begins_with("V")

# PCs utiles : 11, (#11), 3, 5, 7 (mineure sur dominantes)
func _pc_11_3_5_7(chord:Dictionary) -> Dictionary:
	var out = {"pc11": -1, "pc3": -1, "pc5": -1, "pc7": -1}
	if not chord.has("root_pc"):
		return out
	var root_pc = int(chord["root_pc"]) % 12
	out["pc3"] = (root_pc + 4) % 12
	out["pc5"] = (root_pc + 7) % 12
	out["pc7"] = (root_pc + 10) % 12
	var fig = str(chord.get("ext_fig",""))
	if fig == "#11":
		out["pc11"] = (root_pc + 6) % 12	# #11 = +6 (triton au-dessus de la 3)
	else:
		out["pc11"] = (root_pc + 5) % 12	# 11 = +5
	return out

# SATB minimal déjà présent plus haut (_valid_satb), on le réutilise

# Tenter de supprimer 3 et 5 et d'introduire 11 en modifiant une voix à la fois (éviter Basse)
func _try_enforce_11_dom(v:Array, chord:Dictionary, pc11:int, pc3:int, pc5:int) -> Array:
	# ordre de remplacement: A, T, S (on évite B)
	var order = [1, 2, 0]
	for idx in order:
		var pc_here = v[idx] % 12
		# cibles prioritaires à remplacer: d'abord 3, puis 5, puis doublure de R/7 si besoin
		if pc_here != pc3 and pc_here != pc5:
			continue
		var base = v[idx]
		var best = -9999
		var best_d = 9999
		for k in [-24, -12, 0, 12, 24]:
			var n = (base - (base % 12) + pc11) + k
			var voice = ""
			if idx == 0:
				voice = "S"
			elif idx == 1:
				voice = "A"
			else:
				voice = "T"
			if not _in_range(voice, n):
				continue
			var v2 = [v[0], v[1], v[2], v[3]]
			v2[idx] = n
			if not _valid_satb(v2):
				continue
			# Interdits : 3 et (idéalement) 5 ; on tolère 5 si vraiment nécessaire ? → ici on l'exclut.
			var has3 = false
			var has5 = false
			var has11 = false
			for j in range(4):
				var pc2 = v2[j] % 12
				if pc2 == pc3: has3 = true
				if pc2 == pc5: has5 = true
				if pc2 == pc11: has11 = true
			if has3 or has5 or not has11:
				continue
			var dist = abs(n - base)
			if dist < best_d:
				best_d = dist
				best = n
		if best != -9999:
			var out = [v[0], v[1], v[2], v[3]]
			out[idx] = best
			return out
	return []

# Transformation d'un set : retirer 3/5 et garantir la présence de 11
func _augment_with_ext11(vox:Array, chord:Dictionary, logger) -> Array:
	if vox.empty():
		return vox
	var d = _pc_11_3_5_7(chord)
	var pc11 = int(d["pc11"])
	var pc3 = int(d["pc3"])
	var pc5 = int(d["pc5"])
	if pc11 < 0 or pc3 < 0 or pc5 < 0:
		return vox
	var out = []
	var seen = {}
	for v in vox:
		var has11 = false
		var has3 = false
		var has5 = false
		for i in range(4):
			var pc = v[i] % 12
			if pc == pc11: has11 = true
			if pc == pc3: has3 = true
			if pc == pc5: has5 = true
		# Si déjà correct (11 présente, pas de 3 ni 5) → garder
		if has11 and not has3 and not has5:
			var k0 = str(v[0],"|",v[1],"|",v[2],"|",v[3])
			if not seen.has(k0):
				seen[k0] = true
				out.append(v)
			continue
		# Sinon, tenter remplacement local pour imposer 11 et évincer 3/5
		var v2 = _try_enforce_11_dom(v, chord, pc11, pc3, pc5)
		if v2.size() == 4:
			var k1 = str(v2[0],"|",v2[1],"|",v2[2],"|",v2[3])
			if not seen.has(k1):
				seen[k1] = true
				out.append(v2)
	# Sûreté: filtre final (11 oui, 3/5 non)
	var final = []
	for v3 in out:
		var ok11 = false
		var bad3 = false
		var bad5 = false
		for i in range(4):
			var pc = v3[i] % 12
			if pc == pc11: ok11 = true
			if pc == pc3: bad3 = true
			if pc == pc5: bad5 = true
		if ok11 and not bad3 and not bad5:
			final.append(v3)
	return final

# Assurer la 7e (core) pour V11 / V#11 (comme pour la 9e)
func _ensure_core7_for_ext11(vox:Array, chord:Dictionary, logger) -> Array:
	if vox.empty():
		return vox
	var d = _pc_11_3_5_7(chord)
	var pc11 = int(d["pc11"])
	var pc7 = int(d["pc7"])
	var pc3 = int(d["pc3"])
	var pc5 = int(d["pc5"])
	var root_pc = int(chord.get("root_pc", -1)) % 12
	var out = []
	var seen = {}
	for v in vox:
		var has11 = false
		var has7 = false
		var has3 = false
		var has5 = false
		var count_root = 0
		for i in range(4):
			var pc = v[i] % 12
			if pc == pc11: has11 = true
			if pc == pc7: has7 = true
			if pc == pc3: has3 = true
			if pc == pc5: has5 = true
			if pc == root_pc: count_root += 1
		if has7 and has11 and not has3 and not has5:
			var k0 = str(v[0],"|",v[1],"|",v[2],"|",v[3])
			if not seen.has(k0):
				seen[k0] = true
				out.append(v)
			continue
		# introduire la 7e en remplaçant une doublure intérieure (éviter S si possible), ne pas perdre 11
		var candidate = _try_impose_7(v, chord, pc7, pc11, pc5, root_pc)
		if candidate.size() == 4:
			# s'assurer qu'on n'a pas réintroduit 3/5
			var bad = false
			var ok11 = false
			for j in range(4):
				var pc2 = candidate[j] % 12
				if pc2 == pc3 or pc2 == pc5:
					bad = true
				if pc2 == pc11:
					ok11 = true
			if not bad and ok11:
				var k1 = str(candidate[0],"|",candidate[1],"|",candidate[2],"|",candidate[3])
				if not seen.has(k1):
					seen[k1] = true
					out.append(candidate)
	# Sûreté finale
	var final = []
	for v2 in out:
		var ok7 = false
		var ok11b = false
		var bad3b = false
		var bad5b = false
		for i in range(4):
			var pc = v2[i] % 12
			if pc == pc7: ok7 = true
			if pc == pc11: ok11b = true
			if pc == pc3: bad3b = true
			if pc == pc5: bad5b = true
		if ok7 and ok11b and not bad3b and not bad5b:
			final.append(v2)
	return final

# Tri préférentiel: 11 au soprano
func _sort_pref_soprano_eleven(vox:Array, chord:Dictionary) -> Array:
	var d = _pc_11_3_5_7(chord)
	var pc11 = int(d["pc11"])
	if pc11 < 0:
		return vox
	var with11 = []
	var other = []
	for v in vox:
		if v[0] % 12 == pc11:
			with11.append(v)
		else:
			other.append(v)
	for x in other:
		with11.append(x)
	return with11



# ==================== EXT13 HELPERS (dominantes) ====================
# Ciblage: V13 / V♭13 (y compris V/deg)
func _is_ext13_dom_target(chord:Dictionary) -> bool:
	if not chord.has("ext_fig") or not chord.has("rn"):
		return false
	var fig = str(chord["ext_fig"])
	if fig != "13" and fig != "b13":
		return false
	var rn = str(chord["rn"])
	return rn.begins_with("V")

# PCs utiles pour V13 : 3, 5, 7, 11, 13 (13 alt si b13)
func _pc_13_11_5_7_3(chord:Dictionary) -> Dictionary:
	var out = {"pc13": -1, "pc11": -1, "pc5": -1, "pc7": -1, "pc3": -1}
	if not chord.has("root_pc"):
		return out
	var root_pc = int(chord["root_pc"]) % 12
	out["pc3"] = (root_pc + 4) % 12
	out["pc5"] = (root_pc + 7) % 12
	out["pc7"] = (root_pc + 10) % 12
	out["pc11"] = (root_pc + 5) % 12
	var fig = str(chord.get("ext_fig",""))
	if fig == "b13":
		out["pc13"] = (root_pc + 20) % 12	# 13♭ = +20
	else:
		out["pc13"] = (root_pc + 21) % 12	# 13 = +21
	return out

# Remplacer 5 ou 11 par 13 (éviter B), garder SATB valide et sans 11/5
func _try_enforce_13_dom(v:Array, chord:Dictionary, pc13:int, pc5:int, pc11:int) -> Array:
	var order = [1, 2, 0]	# A, T, S
	for idx in order:
		var pc_here = v[idx] % 12
		if pc_here != pc5 and pc_here != pc11:
			continue
		var base = v[idx]
		var best = -9999
		var best_d = 9999
		for k in [-24, -12, 0, 12, 24]:
			var n = (base - (base % 12) + pc13) + k
			var voice = ""
			if idx == 0:
				voice = "S"
			elif idx == 1:
				voice = "A"
			else:
				voice = "T"
			if not _in_range(voice, n):
				continue
			var v2 = [v[0], v[1], v[2], v[3]]
			v2[idx] = n
			if not _valid_satb(v2):
				continue
			# Vérifier absence 11/5 et présence 13
			var has13 = false
			var has11 = false
			var has5 = false
			for j in range(4):
				var pc2 = v2[j] % 12
				if pc2 == pc13: has13 = true
				if pc2 == pc11: has11 = true
				if pc2 == pc5: has5 = true
			if has13 and not has11 and not has5:
				var dist = abs(n - base)
				if dist < best_d:
					best_d = dist
					best = n
		if best != -9999:
			var out = [v[0], v[1], v[2], v[3]]
			out[idx] = best
			return out
	return []

# Étape 1 : imposer 13, supprimer 11/5
func _augment_with_ext13(vox:Array, chord:Dictionary, logger) -> Array:
	if vox.empty():
		return vox
	var d = _pc_13_11_5_7_3(chord)
	var pc13 = int(d["pc13"])
	var pc11 = int(d["pc11"])
	var pc5 = int(d["pc5"])
	if pc13 < 0 or pc11 < 0 or pc5 < 0:
		return vox
	var out = []
	var seen = {}
	for v in vox:
		var has13 = false
		var has11 = false
		var has5 = false
		for i in range(4):
			var pc = v[i] % 12
			if pc == pc13: has13 = true
			if pc == pc11: has11 = true
			if pc == pc5: has5 = true
		if has13 and not has11 and not has5:
			var k0 = str(v[0],"|",v[1],"|",v[2],"|",v[3])
			if not seen.has(k0):
				seen[k0] = true
				out.append(v)
			continue
		var v2 = _try_enforce_13_dom(v, chord, pc13, pc5, pc11)
		if v2.size() == 4:
			var k1 = str(v2[0],"|",v2[1],"|",v2[2],"|",v2[3])
			if not seen.has(k1):
				seen[k1] = true
				out.append(v2)
	# Filtre sûreté (13 oui, 11/5 non)
	var final = []
	for v3 in out:
		var ok13 = false
		var bad11 = false
		var bad5 = false
		for i in range(4):
			var pc = v3[i] % 12
			if pc == pc13: ok13 = true
			if pc == pc11: bad11 = true
			if pc == pc5: bad5 = true
		if ok13 and not bad11 and not bad5:
			final.append(v3)
	return final

# Étape 2 : garantir 3 ET 7 présentes (core)
func _ensure_core37_for_ext13(vox:Array, chord:Dictionary, logger) -> Array:
	if vox.empty():
		return vox
	var d = _pc_13_11_5_7_3(chord)
	var pc13 = int(d["pc13"])
	var pc11 = int(d["pc11"])
	var pc5 = int(d["pc5"])
	var pc7 = int(d["pc7"])
	var pc3 = int(d["pc3"])
	if pc13 < 0 or pc7 < 0 or pc3 < 0:
		return vox
	var out = []
	var seen = {}
	for v in vox:
		var has13 = false
		var has7 = false
		var has3 = false
		var has11 = false
		var has5 = false
		for i in range(4):
			var pc = v[i] % 12
			if pc == pc13: has13 = true
			if pc == pc7: has7 = true
			if pc == pc3: has3 = true
			if pc == pc11: has11 = true
			if pc == pc5: has5 = true
		if has13 and has7 and has3 and not has11 and not has5:
			var k0 = str(v[0],"|",v[1],"|",v[2],"|",v[3])
			if not seen.has(k0):
				seen[k0] = true
				out.append(v)
			continue
		# introduire 7 puis 3 (sans perdre 13, sans réintroduire 11/5)
		var v2 = v
		if not has7:
			v2 = _try_impose_7(v2, chord, pc7, pc13, pc5, int(chord.get("root_pc", 0)) % 12)
		if v2.size() == 4 and not _has_pc(v2, pc3):
			v2 = _try_impose_3(v2, chord, pc3, pc13, pc5, pc11)
		if v2.size() == 4:
			# sûreté : 13,3,7 présents; 11/5 absents
			var ok = _has_pc(v2, pc13) and _has_pc(v2, pc7) and _has_pc(v2, pc3) and not _has_pc(v2, pc11) and not _has_pc(v2, pc5)
			if ok:
				var k1 = str(v2[0],"|",v2[1],"|",v2[2],"|",v2[3])
				if not seen.has(k1):
					seen[k1] = true
					out.append(v2)
	return out

func _has_pc(v:Array, pc:int) -> bool:
	for i in range(4):
		if v[i] % 12 == pc:
			return true
	return false

# Imposer 3 en modifiant une voix intérieure, sans casser 13, sans 11/5
func _try_impose_3(v:Array, chord:Dictionary, pc3:int, pc13:int, pc5:int, pc11:int) -> Array:
	var order = [1, 2, 0]	# A, T, S
	for idx in order:
		var pc_here = v[idx] % 12
		if pc_here == pc13 or pc_here == pc5 or pc_here == pc11:
			continue
		var base = v[idx]
		var best = -9999
		var best_d = 9999
		for k in [-24, -12, 0, 12, 24]:
			var n = (base - (base % 12) + pc3) + k
			var voice = ""
			if idx == 0:
				voice = "S"
			elif idx == 1:
				voice = "A"
			else:
				voice = "T"
			if not _in_range(voice, n):
				continue
			var v2 = [v[0], v[1], v[2], v[3]]
			v2[idx] = n
			if not _valid_satb(v2):
				continue
			# garder 13, éviter 11/5
			var keep13 = false
			var bad = false
			for j in range(4):
				var pc2 = v2[j] % 12
				if pc2 == pc13: keep13 = true
				if pc2 == pc11 or pc2 == pc5: bad = true
			if not keep13 or bad:
				continue
			var dist = abs(n - base)
			if dist < best_d:
				best_d = dist
				best = n
		if best != -9999:
			var out = [v[0], v[1], v[2], v[3]]
			out[idx] = best
			return out
	return []

# Tri préférentiel: 13 au soprano
func _sort_pref_soprano_thirteen(vox:Array, chord:Dictionary) -> Array:
	var d = _pc_13_11_5_7_3(chord)
	var pc13 = int(d["pc13"])
	if pc13 < 0:
		return vox
	var with13 = []
	var other = []
	for v in vox:
		if v[0] % 12 == pc13:
			with13.append(v)
		else:
			other.append(v)
	for x in other:
		with13.append(x)
	return with13


# Promotion de la 13e au soprano (sans casser SATB)
func _promote_thirteen_to_soprano(vox:Array, chord:Dictionary) -> Array:
	if vox.empty():
		return vox
	var d = _pc_13_11_5_7_3(chord)
	var pc13 = int(d["pc13"])
	if pc13 < 0:
		return vox
	var out = []
	for v in vox:
		# si déjà 13 au S, garder
		if v[0] % 12 == pc13:
			out.append(v)
			continue
		# chercher la 13e en A ou T
		var promoted = false
		for idx in [1, 2]:
			if v[idx] % 12 != pc13:
				continue
			# 1) calculer la meilleure octave pour mettre la 13e au soprano (> Alto, gaps ≤ 12, tessiture S)
			var A = v[1]
			var base13 = v[idx] - (v[idx] % 12) + pc13
			var s_candidate = base13
			# remonter par pas de 12 tant que nécessaire
			while s_candidate <= A:
				s_candidate += 12
			# tenter quelques variantes autour
			var s_try = [s_candidate - 12, s_candidate, s_candidate + 12]
			for t in s_try:
				if t <= A:
					continue
				# tessiture soprano et gap S–A ≤ 12
				if not _in_range("S", t):
					continue
				if abs(t - A) > 12:
					continue
				# 2) replacer l’ancienne note de S dans la voix idx (A ou T), en ajustant d’une octave si besoin
				var v2 = [v[0], v[1], v[2], v[3]]
				var oldS = v2[0]
				v2[0] = t
				# injecter oldS dans la voix idx puis corriger par ±12 pour garder l’ordre
				v2[idx] = oldS
				# corriger si A ≤ T ou S ≤ A, etc. On tente ±12 sur la voix idx pour rétablir l’ordre
				for shift in [-24, -12, 0, 12, 24]:
					var v3 = [v2[0], v2[1], v2[2], v2[3]]
					v3[idx] = v2[idx] + shift
					if _valid_satb(v3):
						out.append(v3)
						promoted = true
						break
				if promoted:
					break
			if promoted:
				break
		if not promoted:
			out.append(v)
	return out		
#
#	var out = []
#	for v in vox:
#		# si déjà 13 au S, garder
#		if v[0] % 12 == pc13:
#			out.append(v)
#			continue
#		# chercher 13 en A ou T, tenter swap S<->(A|T) si valide
#		var swapped = false
#		for idx in [1, 2]:
#			if v[idx] % 12 != pc13:
#				continue
#			var v2 = [v[0], v[1], v[2], v[3]]
#			var tmp = v2[0]
#			v2[0] = v2[idx]
#			v2[idx] = tmp
#			# Vérifier ordre/gaps/tessitures après échange
#			if _valid_satb(v2):
#				out.append(v2)
#				swapped = true
#				break
#		if not swapped:
#			out.append(v)
#	return out
# Assure qu'un set de voicings contient bien la 7e demandée ; si absente, tente de l'imposer en remplaçant une doublure.
func _ensure_wanted_seventh(vox:Array, chord:Dictionary, logger) -> Array:
	if vox.empty():
		return vox
	var pc7 = int(chord.get("seventh_pc", -1))
	if pc7 < 0:
		return vox
	var pcs = chord.get("pitches", [])
	if pcs.size() < 3:
		return vox
	var root_pc = int(pcs[0])
	var third_pc = int(pcs[1])
	var fifth_pc = int(pcs[2])
	var out = []
	var seen = {}
	for v in vox:
		var has7 = false
		for i in range(4):
			if v[i] % 12 == pc7:
				has7 = true
				break
		if has7:
			var k0 = str(v[0],"|",v[1],"|",v[2],"|",v[3])
			if not seen.has(k0):
				seen[k0] = true
				out.append(v)
			continue
		# Tenter d'introduire la 7e: remplacer une doublure de R prioritaire, sinon doublure de 3e, sinon n'importe quelle doublure intérieure
		var cand = _try_impose_7_generic(v, pc7, root_pc, third_pc, fifth_pc)
		if cand.size() == 4:
			var k1 = str(cand[0],"|",cand[1],"|",cand[2],"|",cand[3])
			if not seen.has(k1):
				seen[k1] = true
				out.append(cand)
	# sûreté: garder seulement ceux qui ont bien la 7e
	var final = []
	for v2 in out:
		var ok7 = false
		for i in range(4):
			if v2[i] % 12 == pc7:
				ok7 = true
				break
		if ok7:
			final.append(v2)
	return final

# Variante générique: impose pc7 en modifiant UNE voix intérieure (A puis T, sinon S), garde l'ordre SATB.
func _try_impose_7_generic(v:Array, pc7:int, root_pc:int, third_pc:int, fifth_pc:int) -> Array:
	var order = [1, 2, 0]	# A, T, S (éviter la Basse)
	for idx in order:
		# éviter d'écraser la 7e (même si absente a priori), et viser en priorité une doublure de R, puis de 3e
		var pc_here = v[idx] % 12
		var priority = 0
		if pc_here == root_pc:
			priority = 2
		elif pc_here == third_pc:
			priority = 1
		elif pc_here == fifth_pc:
			priority = 0
		else:
			priority = 0
		# On tente quand même, mais on choisira la 1re solution valide trouvée en balayant A>T>S
		var base = v[idx]
		for k in [-24, -12, 0, 12, 24]:
			var n = (base - (base % 12) + pc7) + k
			var voice = ""
			if idx == 0:
				voice = "S"
			elif idx == 1:
				voice = "A"
			else:
				voice = "T"
			if not _in_range(voice, n):
				continue
			var v2 = [v[0], v[1], v[2], v[3]]
			v2[idx] = n
			if not _valid_satb(v2):
				continue
			return v2
	return []

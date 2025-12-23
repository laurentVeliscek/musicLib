extends Node
class_name SATB_solver
# Fichier: res://musiclib/satb_solver.gd
# Solver SATB (beam) avec instrumentation et garde-fous

const _INF = 10000000
# satb_solver.gd (en haut du fichier, avec RANGES)
const BASS_MIN = 40	# E2
const BASS_MAX = 60	# C4
const TAG = "[SATB_solver]"

var Harmony = Harmony_SATB.new()
var VoicingBank = Voicing_bank.new()
var VerboseLogger = Verbose_satb_logger.new()

var _bank = null
var _logger = null
var _ext_loader = null
var _ext_style = "classique"


var RANGES = {
	"S": Vector2(60, 79),
	"A": Vector2(55, 74),
	"T": Vector2(48, 67),
	"B": Vector2(40, 60)
}

var DEFAULT_WEIGHTS = {
	"hidden_5_8": 40,
	"wide_gap_hard": 18,
	"wide_gap_soft": 6,
	"bad_doubling": 12,
	"bad_resolution": 8,
	"break_common": 10,
	"step_reward": -4,
	"common_tone_reward": -3,
	"contrary_ext_reward": -2,
	"motion_cost_per_semitone": 1,
	# --- accord dim -> basse : tierce doublée dans l'accord
	"dim_third_double_bonus": -12,	# ajuste l’intensité à ton goût (négatif = mieux)
	# --- nouveau ---
	"missing_third_penalty": 36,	# ajuste à ton goût (30–60)
	# ---- nouveaux réglages (très légers) ----
	"bass_conj_bonus_on_inv_change": -6,	# bonus si la basse est conjointe ET renversement change
	"v42_penalty": 6,						# légère pénalité pour V42
	"fundamental_pos_bonus": -3,			# très léger bonus en position fondamentale
	"inversion_change_penalty": 4,	
	"ninth_descend_bonus": -5,
	"eleventh_descend_bonus": -4,
	"v11_with_third_hard": 10000000,
	"v11_no_resolution_penalty": 18,
	# --- 13ths ---
	"v13_missing_seventh_hard": 10000000,
	"v13_missing_third_hard": 10000000,
	"v13_with_11_hard": 10000000,
	"v13_with_5_hard": 10000000,
	"thirteenth_to_five_bonus": -5,
	"thirteenth_step_down_bonus": -3,			# petit coût quand l’inversion change
	# ---- free_triad resserré ----
	"missing_fifth_soft": 18,
	"distinctiveness_penalty": 12,
	# --- free_seventh ---
	"missing_seventh_hard": 10000000,
	"missing_seventh_soft": 36

	}	



func set_bank(b):
	_bank = b

func set_logger(l):
	_logger = l


func set_extensions_loader(ext_loader, style:String="classique") -> void:
	_ext_loader = ext_loader
	_ext_style = style
	if _bank != null and _ext_loader != null:
		_bank.set_extensions_loader(_ext_loader, _ext_style)


 
#
# ------------------------------------------------------------
# Helper: certaines extensions interdisent la tierce (ex: V11/#11),
# et (plus tard) sus2/sus4. Ce helper dit si la tierce est FORBIDDEN.
# Policy-aware si _ext_loader est dispo ; sinon heuristique.
# ------------------------------------------------------------
func _third_forbidden(ch:Dictionary) -> bool:
	if ch.empty():
		return false
	if not ch.has("ext_fig") or not ch.has("rn"):
		return false
	var fig = str(ch["ext_fig"])
	var rn = str(ch["rn"])
	# 1) Policy si loader disponible
	if _ext_loader != null:
		var pol = _ext_loader.get_policy(fig, rn, _ext_style)
		if pol.has("must_absent"):
			var ma = pol["must_absent"]
			if typeof(ma) == TYPE_ARRAY:
				for i in range(ma.size()):
					if str(ma[i]) == "3":
						return true
	# 2) Heuristique fallback: V11 / V#11 (dominantes)
	if rn.begins_with("V"):
		if fig == "11" or fig == "#11":
			return true
	# 3) Préparation sus2/sus4 (si activés plus tard)
	if fig == "sus2" or fig == "sus4":
		return true
	return false



# ---- helpers inversion ----
func _inv_index_of_chord(ch:Dictionary) -> int:
	# Renvoie l'index d'inversion (0..2 triade, 0..3 tétrade) pour un accord RN.
	# -1 si non-RN ou si la basse ne correspond pas à une note des pcs (ne devrait pas arriver).
	if ch.get("type","") != "RN":
		return -1
	if not ch.has("pitches"):
		return -1
	var pcs = ch["pitches"]
	if pcs.size() < 3:
		return -1
	var bass_pc = ch["bass"] % 12
	for i in range(pcs.size()):
		if pcs[i] == bass_pc:
			return i
	return -1


# -------- Helpers pour variantes de renversement “free_*” --------
func _fit_bass_to_range_local(bass_midi:int, min_midi:int, max_midi:int) -> int:
	var b = bass_midi
	while b < min_midi:
		b += 12
	while b > max_midi:
		b -= 12
	return b

func _midi_of_pc_in_oct(pc:int, oct:int) -> int:
	return 12 * (oct + 1) + ((pc % 12 + 12) % 12)

func _expand_chord_variants(ch:Dictionary) -> Array:
	var out = []
	if not ch.has("inv_options"):
		out.append(ch)
		return out
	var pcs = ch["pitches"]
	var invs = ch["inv_options"]
	var bass = int(ch["bass"])
	var oct_hint = int(ch.get("bass_oct_hint", int(bass / 12) - 1))
	for inv in invs:
		var inv_i = clamp(int(inv), 0, pcs.size() - 1)
		var bass_pc = pcs[inv_i]
		var b = _midi_of_pc_in_oct(bass_pc, oct_hint)
		b = _fit_bass_to_range_local(b, BASS_MIN, BASS_MAX)
		var c = ch.duplicate()
		c.erase("inv_options")
		c.erase("bass_oct_hint")
		c["bass"] = b
		out.append(c)
	return out

func _union_voicings(arrays:Array) -> Array:
	var seen = {}
	var out = []
	for A in arrays:
		for v in A:
			var key = str(v[0], "|", v[1], "|", v[2], "|", v[3])
			if not seen.has(key):
				seen[key] = true
				out.append(v)
	return out







# ---------- solve (PATCH AVEC SONDES) ----------

func solve(prog:Array, params:Dictionary) -> Dictionary:
	# Params
	var beam = params.get("beam", 12)
	var top_m = params.get("top_m", 3)
	var restarts = params.get("restarts", 20)
	var W = params.get("weights", DEFAULT_WEIGHTS)
	#var verbose = params.get("verbose", false)
	
	var verbose = params.get("verbose", false)
	# Style/loader d’extensions (optionnels)
	if params.has("ext_loader"):
		_ext_loader = params["ext_loader"]
	if params.has("style"):
		_ext_style = str(params["style"])
	# Propager à la bank si dispo
	if _bank != null and _ext_loader != null:
		_bank.set_extensions_loader(_ext_loader, _ext_style)	
	
	var hard_require_third = params.get("hard_require_third", true)
	var rescue_first = params.get("rescue_first_chord", true)
	#var enforce_first_third = params.get("enforce_first_third", true)
	var enforce_first_third = params.get("enforce_first_third", true)
	var enforce_first_complete_triad = params.get("enforce_first_complete_triad", true)	
	
	# Logger
	if verbose:
		if params.has("logger"):
			LogBus.debug("solver",'params.has("logger"')
			_logger = params["logger"]
		else:
			LogBus.debug("solver",'_logger = VerboseLogger.new()')
			_logger = VerboseLogger.new()
	else:
		_logger = null

	# Bank + préchauffage
	if _bank == null:
		_bank = Voicing_bank.new()
	_bank.preheat(prog, "strict", _logger)

	# Sanity (pour attraper les pièges courants)
	if verbose:
		print("[SANITY] _INF=", _INF)
		print("[SANITY] has _less_score=", has_method("_less_score"), " has _less_delta=", has_method("_less_delta"))

	randomize()
	var best = {"score": _INF, "voices": []}

	for r in range(restarts):
		
		#yield(get_tree(), "physics_frame")
		
		# 1) Voicings du premier accord

		# ----- Premier accord : expansion des variantes “free_*” -----
		var first = prog[0]
		# (log facultatif) si extension taggée sur l’accord
		if verbose and first.has("ext_fig"):
			LogBus.debug(TAG,"[EXT] step=0 fig=" + first["ext_fig"] +  " rn=" + first.get("rn","") + " style=" +  _ext_style)



		var first_set = _expand_chord_variants(first)
		var bank_sets = []
		for chv in first_set:
			bank_sets.append(_bank.get_voicings(chv, "strict", _logger))
		var start_voicings = _union_voicings(bank_sets)
		if verbose:
			print("[GEN SRC] step=0 variants=", first_set.size(), " union_size=", start_voicings.size())
		if start_voicings.empty():
			# fallback exhaustive sur chaque variante
			var ex_sets = []
			
			
			# Filtre optionnel: tierce requise au départ (sauf si interdite)
			if enforce_first_third and not _third_forbidden(first):
				if first.get("type","") == "RN":
					var pcs0 = first.get("pitches", [])
					if pcs0.size() == 3:
						var third_pc0 = pcs0[1]
						var filtered = []
						for v in start_voicings:
							var has_third0 = false
							for i4 in range(4):
								if v[i4] % 12 == third_pc0:
									has_third0 = true
									break
							if has_third0:
								filtered.append(v)
						if not filtered.empty():
							if verbose:
								LogBus.debug(TAG,"[INIT FILTER] kept_with_third=" + str(filtered.size()) + " / total=" + str(start_voicings.size()))
							start_voicings = filtered			
				
				
			

			# Filtre optionnel: triade complète R-3-5 au départ (free_triad resserré)
			if enforce_first_complete_triad:
				if first.get("type","") == "RN" and not first.has("ext_fig"):
					var need_complete = first.get("require_complete_triad", false)
					if need_complete:
						var rn0 = first.get("rn","")
						var pcs0b = first.get("pitches", [])
						if pcs0b.size() == 3:
							var r_pc0 = pcs0b[0]
							var t_pc0 = pcs0b[1]
							var f_pc0 = pcs0b[2]
							var filtered2 = []
							for v in start_voicings:
								var hr = false
								var h3 = false
								var h5 = false
								for i5 in range(4):
									var pc = v[i5] % 12
									if pc == r_pc0: hr = true
									if pc == t_pc0: h3 = true
									if pc == f_pc0: h5 = true
								if hr and h3 and h5:
									filtered2.append(v)
							if not filtered2.empty():
								if verbose:
									LogBus.debug(TAG,"[INIT FILTER] kept_complete_triad=" + str(filtered2.size()) + " / total=" + str(start_voicings.size()))
								start_voicings = filtered2			
				
			
			
			
			
			
			for chv2 in first_set:
				ex_sets.append(generate_voicings(chv2, _logger))
			start_voicings = _union_voicings(ex_sets)
			if verbose:
				print("[GEN SRC] step=0 exhaustive_union_size=", start_voicings.size())
			# ----- Filtre opt-in: exiger la tierce au départ (RN triade) -----
			if enforce_first_third and first.get("type","") == "RN":
				var pcs0 = first.get("pitches", [])
				if pcs0.size() == 3:
					var third_pc0 = pcs0[1]
					var filtered = []
					for v in start_voicings:
						var has_third0 = false
						for i4 in range(4):
							if v[i4] % 12 == third_pc0:
								has_third0 = true
								break
						if has_third0:
							filtered.append(v)
					if not filtered.empty():
						if verbose:
							#print("[INIT FILTER] kept_with_third=", filtered.size(), " / total=", start_voicings.size())
							LogBus.debug(TAG,"[INIT FILTER] kept_with_third=" + str(filtered.size()) + " / total=" + str(start_voicings.size()))
						start_voicings = filtered		
		if start_voicings.empty():
			if verbose:
				#print("[verbose] No voicings for first chord (after variants/filter)")
				LogBus.debug(TAG,"No voicings for first chord (after variants/filter)")
			continue
	
		
#		start_voicings.shuffle()
#		var init = start_voicings[0]
#		var beam_states = [ {"seq":[init], "score": static_cost(init, prog[0], W)} ]
		start_voicings.shuffle()
		var init = start_voicings[0]
		var beam_states = [ {"seq":[init], "score": static_cost(init, first, W, hard_require_third)} ]



		# 2) Itération sur la progression
		for i in range(prog.size() - 1):
			
			var next_chord = prog[i + 1]
			# --- LOG: début d'étape ---

			if _logger != null:
				_logger.start_step(i + 1, next_chord)

			# ----- Expansion des variantes “free_*” -----
			var variants = _expand_chord_variants(next_chord)
			var bank_batches = []
			for chv in variants:
				bank_batches.append(_bank.get_voicings(chv, "strict", _logger))
			var next_vox = _union_voicings(bank_batches)
			if verbose:
				#print("[GEN SRC] step=", i + 1, " variants=", variants.size(), " union_size=", next_vox.size())
				LogBus.debug(TAG,"[GEN SRC] step=" + str( i + 1) + " variants=" + str(variants.size()) + " union_size=" + str(next_vox.size() ))
			if next_vox.empty():
				# fallback exhaustive
				var ex2 = []
				for chv2 in variants:
					ex2.append(generate_voicings(chv2, _logger))
				next_vox = _union_voicings(ex2)
				if verbose:
					#print("[GEN SRC] step=", i + 1, " exhaustive_union_size=", next_vox.size())
					LogBus.debug(TAG,"[GEN SRC] step=" + str(i+1) + " exhaustive_union_size=" + str(next_vox.size())  )
			if next_vox.empty():
				beam_states = []
				if verbose:
					#print("[verbose] No voicings for chord index ", i + 1, " (after variants)")
					LogBus.debug(TAG,"[verbose] No voicings for chord index " + str(i + 1) + " (after variants)")
				if _logger != null:
					_logger.end_step()
				break





			if _logger != null and verbose:
				LogBus.debug("[SATB verbose]", "beam_size_in=" + str(beam_states.size()) +  " candidates=" + str(next_vox.size()))

			var new_states = []
			var hard_rejects = 0

			# Évalue transitions depuis chaque état du beam
			for state in beam_states:
				var prev = state["seq"][state["seq"].size() - 1]
				var scored = []
				
				#LogBus.debug("solver -> evalue transition","next_vox.size() = " + str(next_vox.size()))
				
				for cand in next_vox:
					if _logger != null:
						_logger.trans_try()
					var tscore = transition_cost(prev, cand, prog[i], next_chord, W, _logger)
					if tscore >= _INF:
						hard_rejects += 1
						continue
					if _logger != null:
						_logger.trans_keep()
					scored.append({"cand": cand, "delta": tscore})

				# trie croissant par delta
				#LogBus.debug("solver -> trie croissant par delta","scored.size() = " + str(scored.size()))
				scored.sort_custom(self, "_less_delta")

				# diversification top_m
				var take = min(top_m, scored.size())
				for j in range(take):
					var sel = scored[j]
					var new_seq = state["seq"].duplicate()
					new_seq.append(sel["cand"])
					var new_score = state["score"] + sel["delta"]

					# garde-fou contre fuite d'INF
					if new_score >= _INF:
						if _logger != null:
							_logger.trans_reject("HARD_LEAK_score_ge_INF")
						continue

					new_states.append({"seq": new_seq, "score": new_score})

			# hard rejects récapitulatif
			if verbose:
				var tried_total = next_vox.size() * beam_states.size()
				LogBus.debug("[HARD REJECTS]", "step=" + str(i + 1) +  " count="+ str(hard_rejects) + " / tried=" + str(tried_total))

			# coupe au beam
			new_states.sort_custom(self, "_less_score")
			if new_states.size() > beam:
				new_states = new_states.slice(0, beam)

			if _logger != null and verbose:
				LogBus.debug("[SATB verbose]", " beam_size_out=" +str(new_states.size()))

			beam_states = new_states

			# --- LOG: fin d'étape ---
			if _logger != null:
				_logger.end_step()

			if beam_states.empty():
				break

		# 3) Mise à jour du meilleur résultat
		if not beam_states.empty():
			var cand_best = beam_states[0]
			var norm_score = cand_best["score"] / float(prog.size())
			if norm_score < best["score"]:
				best["score"] = norm_score
				best["voices"] = cand_best["seq"]

	return best

# ---------- comparateurs pour sort_custom ----------

func _less_score(a, b) -> bool:
	return a["score"] < b["score"]

func _less_delta(a, b) -> bool:
	return a["delta"] < b["delta"]

# ---------- coûts / règles ----------

func static_cost(vox:Array, chord:Dictionary, W:Dictionary, hard_require_third=false) -> int:
	var cost = 0
	var _skip_third_checks = _third_forbidden(chord)
	
	# ---------- FREE_SEVENTH : 7e obligatoire (statique) ----------
	if chord.get("want_seventh", false):
		var pc7s = int(chord.get("seventh_pc", -1))
		if pc7s >= 0:
			var has7s = false
			for i7 in range(4):
				if vox[i7] % 12 == pc7s:
					has7s = true
					break
			if not has7s:
				return W.get("missing_seventh_hard", _INF)	
	
	
	
	
	
	# Accord RN triade: exiger la présence de la tierce (comme en transition_cost)
	if chord.get("type","") == "RN" and not _skip_third_checks:
		var pcs = chord.get("pitches", [])
		if pcs.size() == 3:
			var third_pc = pcs[1]
			var has_third = false
			for i in range(4):
				if vox[i] % 12 == third_pc:
					has_third = true
					break
			if not has_third:
				if hard_require_third:
					return _INF
				var penalty = W.get("missing_third_penalty", 36)
				if chord.get("function","") == "V":
					penalty += 12
				cost += penalty
				
				







	# ---------- RÈGLE: ACCORD RN SANS QUINTE (free_triad resserré) ----------
	# S'applique aux triades RN sans extension, quand require_complete_triad est activé.
	if chord.get("type","") == "RN" and not chord.has("ext_fig"):
		var need_complete = chord.get("require_complete_triad", false)
		if need_complete:
			var pcs5 = chord.get("pitches", [])
			if pcs5.size() == 3:
				var fifth_pc = int(pcs5[2])
				var has5 = false
				for i6 in range(4):
					if vox[i6] % 12 == fifth_pc:
						has5 = true
						break
				if not has5:
					cost += W.get("missing_fifth_soft", 18)



				
				
	return cost


func transition_cost(prev:Array, next:Array, prev_ch:Dictionary, next_ch:Dictionary, W:Dictionary, logger=null, hard_require_third=false) -> int:
	# ---------- HARD CHECKS ----------
	# croisements
	if _has_crossing(next):
		if logger != null:
			logger.trans_reject("crossing")
		return _INF

	# parallèles 5/8
	var pw = _parallel_which(prev, next)
	if pw != null:
		if logger != null:
			logger.trans_reject(str("parallels_", pw["int"], "_pair_", pw["pair"]))
		return _INF

	# résolutions obligatoires (sensible, N6→, cad64→V, Aug6→…)
	if _bad_resolutions(prev, next, prev_ch, next_ch):
		if logger != null:
			logger.trans_reject("bad_resolution")
		return _INF

	# ---------- COST (SOFT) ----------
	var cost = 0
	var _skip_third_next = _third_forbidden(next_ch)
	
	# ---------- FREE_SEVENTH : 7e obligatoire (sur l'accord cible) ----------
	if next_ch.get("want_seventh", false):
		var pc7n = int(next_ch.get("seventh_pc", -1))
		if pc7n >= 0:
			var has7n = false
			for j7 in range(4):
				if next[j7] % 12 == pc7n:
					has7n = true
					break
			if not has7n:
				return W.get("missing_seventh_hard", _INF)	
	
	
	
	
	# espacements trop larges (S–A / A–T)
	var gapSA = abs(next[0] - next[1])
	var gapAT = abs(next[1] - next[2])
	if gapSA > 12 or gapAT > 12:
		cost += W.get("wide_gap_hard", 18)
	elif gapSA >= 9:
		cost += W.get("wide_gap_soft", 6)
	elif gapAT >= 9:
		cost += W.get("wide_gap_soft", 6)

	# mouvement total (lissage)
	for i in range(4):
		cost += W.get("motion_cost_per_semitone", 1) * abs(next[i] - prev[i])

	# pas conjoints (petit bonus négatif)
	for i in range(4):
		if abs(next[i] - prev[i]) == 1:
			cost += W.get("step_reward", -4)

	# tons communs
	var common = 0
	for i in range(4):
		for j in range(4):
			if prev[i] % 12 == next[j] % 12:
				common += 1
	if common > 0:
		cost += W.get("common_tone_reward", -3)

	# mouvement contraire extérieurs
	var ext_dir = sign(next[0] - prev[0]) * sign(next[3] - prev[3])
	if ext_dir == -1:
		cost += W.get("contrary_ext_reward", -2)

	# quintes/octaves cachées vers soprano
	if _hidden_5_8(prev, next):
		cost += W.get("hidden_5_8", 40)

	# doublures discutables (soft)
	if _doubtful_doubling(next, next_ch):
		cost += W.get("bad_doubling", 12)

	# résolutions discutables (soft)
	if _soft_resolution_issues(prev, next, prev_ch, next_ch):
		cost += W.get("bad_resolution", 8)
		
		
 
	# ---------- EXTENSIONS: bonus 9e qui descend conjointement ----------
	# On regarde si l'accord PRECEDENT est un accord "9" (V9 / Vb9 / V#9 / ii9)
	if prev_ch.has("ext_fig") and prev_ch.has("rn"):
		var f9 = str(prev_ch["ext_fig"])
		var rn9 = str(prev_ch["rn"])
		if f9 == "9" or f9 == "b9" or f9 == "#9":
			if rn9.begins_with("V") or (rn9 == "ii" and f9 == "9"):
				# calcul pc9 du précédent
				if prev_ch.has("root_pc"):
					var root_pc9 = int(prev_ch["root_pc"]) % 12
					var pc9 = -1
					if f9 == "b9":
						pc9 = (root_pc9 + 1) % 12
					elif f9 == "#9":
						pc9 = (root_pc9 + 3) % 12
					else:
						pc9 = (root_pc9 + 14) % 12
					# bonus si une VOIX qui portait la 9e descend d'1 demi-ton
					for i in range(4):
						if prev[i] % 12 == pc9 and next[i] == prev[i] - 1:
							cost += W.get("ninth_descend_bonus", -5)
							break


	# ---------- RÈGLE: ACCORD RN SANS QUINTE (cible) ----------
	if next_ch.get("type","") == "RN" and not next_ch.has("ext_fig"):
		var need_complete2 = next_ch.get("require_complete_triad", false)
		if need_complete2:
			var pcsn2 = next_ch.get("pitches", [])
			if pcsn2.size() == 3:
				var fifth_pc2 = int(pcsn2[2])
				var has5n = false
				for i7 in range(4):
					if next[i7] % 12 == fifth_pc2:
						has5n = true
						break
				if not has5n:
					cost += W.get("missing_fifth_soft", 18)

	# ---------- EXTENSIONS (dominantes): V11 / V#11 ----------
	# Hard: interdire la 3e dans la V11 ; Soft: bonus si 11 descend (→ 10 ou 9)
	if next_ch.has("ext_fig") and next_ch.has("rn"):
		var f11 = str(next_ch["ext_fig"])
		var rn11 = str(next_ch["rn"])
		if (f11 == "11" or f11 == "#11") and rn11.begins_with("V"):
			if next_ch.has("root_pc"):
				var root_pc = int(next_ch["root_pc"]) % 12
				var pc3 = (root_pc + 4) % 12
				# Hard reject si la 3e est présente
				for i in range(4):
					if next[i] % 12 == pc3:
						if logger != null:
							logger.trans_reject("v11_with_third")
						return W.get("v11_with_third_hard", _INF)
				# Bonus de résolution si la 11e du PRECEDENT descend d'1 ou 2
				if prev_ch.has("ext_fig") and (str(prev_ch["ext_fig"]) == f11) and prev_ch.has("root_pc"):
					var root_pc_prev = int(prev_ch["root_pc"]) % 12
					#var pc11_prev = (str(prev_ch["ext_fig"]) == "#11") ? ((root_pc_prev + 6) % 12) : ((root_pc_prev + 5) % 12)
					var pc11_prev = -1
					if str(prev_ch["ext_fig"]) == "#11":
						pc11_prev = (root_pc_prev + 6) % 12
					else:
						pc11_prev = (root_pc_prev + 5) % 12
					for i in range(4):
						var step = prev[i] - next[i]
						if prev[i] % 12 == pc11_prev and (step == 1 or step == 2):
							cost += W.get("eleventh_descend_bonus", -4)
							break
				# Mode "classique": si V11 ne résout pas immédiatement, pénaliser
				if _ext_style == "classique":
					# très simple: si on reste avec une 11e (même voix) non résolue
					if prev_ch.has("root_pc"):
						#var pc11_prev2 = (str(prev_ch.get("ext_fig","")) == "#11") ? ((int(prev_ch["root_pc"]) + 6) % 12) : ((int(prev_ch.get("root_pc",0)) + 5) % 12)
						var pc11_prev2 = -1
						if str(prev_ch.get("ext_fig","")) == "#11":
							pc11_prev2 = (int(prev_ch["root_pc"]) + 6) % 12
						else:
							pc11_prev2 = (int(prev_ch.get("root_pc", 0)) + 5) % 12
						var still11 = false
						for i in range(4):
							if prev[i] % 12 == pc11_prev2 and next[i] % 12 == pc11_prev2:
								still11 = true
								break
						if still11:
							cost += W.get("v11_no_resolution_penalty", 18)




	# ---------- EXTENSIONS (dominantes): V13 / V♭13 ----------
	if next_ch.has("ext_fig") and next_ch.has("root_pc") and next_ch.has("rn"):
		var f13 = str(next_ch["ext_fig"])
		var rn13 = str(next_ch["rn"])
		if (f13 == "13" or f13 == "b13") and rn13.begins_with("V"):
			var root_pc = int(next_ch["root_pc"]) % 12
			var pc3 = (root_pc + 4) % 12
			var pc7 = (root_pc + 10) % 12
			var pc11 = (root_pc + 5) % 12
			var pc5 = (root_pc + 7) % 12
			
			#TERNAIRE
			#var pc13 = (f13 == "b13") ? ((root_pc + 20) % 12) : ((root_pc + 21) % 12)
			var pc13 = 0
			if f13 == "b13":
				pc13 = (root_pc + 20) % 12
			else:
				pc13 = (root_pc + 21) % 12
			
			# Hard: exiger 3 et 7, interdire 11 et 5
			var has3 = false
			var has7 = false
			var has11 = false
			var has5 = false
			var has13 = false
			for i in range(4):
				var pc = next[i] % 12
				if pc == pc3: has3 = true
				if pc == pc7: has7 = true
				if pc == pc11: has11 = true
				if pc == pc5: has5 = true
				if pc == pc13: has13 = true
			if not has7:
				if logger != null: logger.trans_reject("v13_missing_7")
				return W.get("v13_missing_seventh_hard", _INF)
			if not has3:
				if logger != null: logger.trans_reject("v13_missing_3")
				return W.get("v13_missing_third_hard", _INF)
			if has11:
				if logger != null: logger.trans_reject("v13_with_11")
				return W.get("v13_with_11_hard", _INF)
			if has5:
				if logger != null: logger.trans_reject("v13_with_5")
				return W.get("v13_with_5_hard", _INF)
			
			if prev_ch.has("ext_fig") and prev_ch.has("root_pc"):
				var f13_prev = str(prev_ch["ext_fig"])
				var root_pc_prev = int(prev_ch["root_pc"]) % 12

				var pc13_prev = 0
				if f13_prev == "b13":
					pc13_prev = (root_pc_prev + 20) % 12
				else:
					pc13_prev = (root_pc_prev + 21) % 12

				for i in range(4):
					if prev[i] % 12 == pc13_prev:
						# vers la quinte : bonus
						if next[i] % 12 == ((int(next_ch["root_pc"]) % 12 + 7) % 12):
							cost += W.get("thirteenth_to_five_bonus", -5)
							break
						# descente conjointe d'1 demi-ton : bonus
						if next[i] == prev[i] - 1:
							cost += W.get("thirteenth_step_down_bonus", -3)
							break
			
	# ---------- GUIDAGE D'INVERSION & BASSE ----------
	# S'applique uniquement aux accords RN (triades/tétrades)
	if next_ch.get("type","") == "RN":
		var next_inv = _inv_index_of_chord(next_ch)
		if next_inv >= 0:
			# (1) légère pénalité pour V42
			if next_ch.get("function","") == "V" and next_inv == 3:
				cost += W.get("v42_penalty", 6)
			# (2) très léger bonus en position fondamentale
			if next_inv == 0:
				cost += W.get("fundamental_pos_bonus", -3)
			# (3) léger coût si l'inversion change par rapport à l'accord RN précédent
			var prev_inv = _inv_index_of_chord(prev_ch)
			if prev_inv >= 0 and prev_inv != next_inv:
				cost += W.get("inversion_change_penalty", 4)
				# (4) bonus si ce changement d’inversion rend la basse conjointe (1 ou 2 demi-tons)
				var bass_step = abs(next[3] - prev[3])
				if bass_step == 1 or bass_step == 2:
					cost += W.get("bass_conj_bonus_on_inv_change", -6)



	# ---------- RÈGLE: ACCORD RN SANS TIERCE ----------
	# s'applique uniquement aux triades "RN"
	if next_ch.get("type", "") == "RN":
		var pcs = next_ch.get("pitches", [])
		if pcs.size() >= 2:
			var third_pc = pcs[1]	# convention: pitches[1] = tierce
			var has_third = false
			for i in range(4):
				if next[i] % 12 == third_pc:
					has_third = true
					break
			if not has_third:
				# mode hard: on élimine le voicing
				if hard_require_third:
					if logger != null:
						logger.trans_reject("missing_third_hard")
					return _INF
				# mode soft: on pénalise (plus fort sur V)
				var penalty = W.get("missing_third_penalty", 36)
				if next_ch.get("function", "") == "V":
					penalty += 12	# sensible (tierce de V en mineur) particulièrement cruciale
				cost += penalty
				if logger != null:
					# info seulement; pas un rejet
					logger.trans_reject("missing_third_soft")





	# Pas de plafond ici (tu as retiré le cap), on renvoie le coût tel quel
	return cost

# ---------- utilitaires règles (tu peux remplacer par tes versions avancées) ----------

func _has_crossing(v:Array) -> bool:
	return not (v[0] > v[1] and v[1] > v[2] and v[2] > v[3])

func _parallel_which(a:Array, b:Array):
	var pairs = [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]
	for p in pairs:
		var ia = abs(a[p[0]] - a[p[1]])
		ia = int(ia) % 12
		var ib = abs(b[p[0]] - b[p[1]])
		ib = int(ib) % 12
		var dir1 = sign(b[p[0]] - a[p[0]])
		var dir2 = sign(b[p[1]] - a[p[1]])
		if (ia == 0 or ia == 7) and ia == ib and dir1 == dir2 and dir1 != 0:
			return {"pair": p, "int": ia}
	return null

func _hidden_5_8(a:Array, b:Array) -> bool:
	var ia = abs(a[0] - a[3]) 
	ia  = int(ia) % 12
	var ib = abs(b[0] - b[3]) 
	ib = int(ib) %12
	var dirS = sign(b[0] - a[0])
	var dirB = sign(b[3] - a[3])
	if (ib == 0 or ib == 7) and dirS == dirB and dirS != 0:
		if abs(b[0] - a[0]) >= 3:
			return true
	return false

func _bad_resolutions(prev:Array, next:Array, prev_ch:Dictionary, next_ch:Dictionary) -> bool:
	# Place tes règles "hard" ici (sensible, N6, cad64, Aug6, 7e descend…)
	return false

func _soft_resolution_issues(prev:Array, next:Array, prev_ch:Dictionary, next_ch:Dictionary) -> bool:
	return false

func _doubtful_doubling(vox:Array, chord:Dictionary) -> bool:
	return false

# ---------- génération exhaustive de secours (fallback instrumenté) ----------

func generate_voicings(chord:Dictionary, logger = null) -> Array:
	var out = []
	var B = chord["bass"]

	# auto-lift local de la basse pour éviter blocage hors tessiture
	var lifted = false
	while not _in_range("B", B) and B <= int(RANGES["B"].y):
		B += 12
		lifted = true
	if not _in_range("B", B):
		if logger != null:
			logger.gen_reject("B_out_of_range_exhaustive")
		return out

	if lifted:
		var chord_fixed = chord.duplicate()
		chord_fixed["bass"] = B
		chord = chord_fixed

	var pcs = chord["pitches"]
	var banks = _note_banks_above_bass(B, pcs)

	for s in banks["S"]:
		for a in banks["A"]:
			for t in banks["T"]:
				if logger != null:
					logger.gen_try()

				if not _in_range("S", s):
					if logger != null:
						logger.gen_reject("S_out_of_range")
					continue
				if not _in_range("A", a):
					if logger != null:
						logger.gen_reject("A_out_of_range")
					continue
				if not _in_range("T", t):
					if logger != null:
						logger.gen_reject("T_out_of_range")
					continue
				if not (s > a and a > t and t > B):
					if logger != null:
						logger.gen_reject("order_violation")
					continue
				if abs(s - a) > 12:
					if logger != null:
						logger.gen_reject("gap_SA_gt12")
					continue
				if abs(a - t) > 12:
					if logger != null:
						logger.gen_reject("gap_AT_gt12")
					continue

				var vox = [s, a, t, B]
				if logger != null:
					logger.gen_keep()
				out.append(vox)

	return out

func _note_banks_above_bass(B:int, pcs:Array) -> Dictionary:
	var banks = {"S": [], "A": [], "T": []}
	for v in ["T", "A", "S"]:
		var low = RANGES[v].x
		var hi = RANGES[v].y
		var arr = []
		for m in range(low, hi + 1):
			if m > B and pcs.has(m % 12):
				arr.append(m)
		banks[v] = arr
	return banks

func _in_range(voice:String, midi:int) -> bool:
	var r = RANGES[voice]
	return midi >= int(r.x) and midi <= int(r.y)


func convert_Array_to_logbus (arr:Array):
	var txt = ""
	for el in arr:
		txt += str(el)+ " "
	LogBus.debug(str(arr[0]),txt)
	
func _is_dim_triad_pcs(pcs:Array) -> bool:
	if pcs.size() < 3:
		return false
	var r = pcs[0]
	var t = pcs[1]
	var f = pcs[2]
	return ((t - r + 12) % 12) == 3 and ((f - t + 12) % 12) == 3

func _rescue_first_chord(ch:Dictionary, logger=null) -> Dictionary:
	# Ne modifie PAS l'entrée : renvoie une copie possiblement corrigée
	var B = int(ch.get("bass", -1))
	if B < 0:
		return ch
	var B0 = B
	var B1 = _fit_bass_to_range_local(B, BASS_MIN, BASS_MAX)
	if B1 == B0:
		return ch
	var fixed = ch.duplicate()
	fixed["bass"] = B1
	if logger != null:
		print("[RESCUE] first chord bass ", B0, " -> ", B1, " (E2..C4)")
	return fixed

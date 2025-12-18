extends Reference
class_name Key_Guess


const TONAL_MODES = {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"harmonic_minor": [0, 2, 3, 5, 7, 8, 11]
}


const ALL_MODES = {
	"ionian": [0, 2, 4, 5, 7, 9, 11],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"lydian": [0, 2, 4, 6, 7, 9, 11],
	"mixolydian": [0, 2, 4, 5, 7, 9, 10],
	"aeolian": [0, 2, 3, 5, 7, 8, 10],
	"locrian": [0, 1, 3, 5, 6, 8, 10],
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"harmonic_minor": [0, 2, 3, 5, 7, 8, 11],
	"locrian_n6": [0, 1, 3, 5, 6, 9, 10],
	"ionian_#5": [0, 2, 4, 5, 8, 9, 11],
	"ukrainian_dorian": [0, 2, 3, 6, 7, 9, 10],
	"phrygian_dominant": [0, 1, 4, 5, 7, 8, 10],
	"lydian_#2": [0, 3, 4, 6, 7, 9, 11],
	"ultralocrian": [0, 1, 3, 4, 6, 8, 9],
	"melodic_minor": [0, 2, 3, 5, 7, 9, 11],
	"dorian_b2": [0, 1, 3, 5, 7, 9, 10],
	"lydian_#5": [0, 2, 4, 6, 8, 9, 11],
	"overtone": [0, 2, 4, 6, 7, 9, 10],
	"hindu": [0, 2, 4, 5, 7, 8, 10],
	"half_diminished": [0, 2, 3, 5, 6, 8, 10],
	"altered": [0, 1, 3, 4, 6, 8, 10],
	"harmonic_major": [0, 2, 4, 5, 7, 8, 11],
	"gypsy_major": [0, 1, 4, 5, 7, 8, 11],
	"hungarian_major": [0, 3, 4, 6, 7, 9, 10],
	"gypsy_minor": [0, 2, 3, 6, 7, 8, 11],
	"neapolitan_major": [0, 1, 3, 5, 7, 9, 11],
	"neapolitan_minor": [0, 1, 3, 5, 7, 8, 11],
	"enigmatic": [0, 1, 4, 6, 8, 10, 11],
	"persian": [0, 1, 4, 5, 6, 8, 11],
	"major_locrian": [0, 2, 4, 5, 6, 8, 10],
	"leading_whole_tone": [0, 2, 4, 6, 8, 10, 11],
	"romanian_major": [0, 1, 4, 6, 7, 9, 10]
}


func guess_keys(notes: Array, tonal_only: bool = true, max_results: int = 10) -> Array:
	var results = []
	
	if notes.empty():
		return results
	
	var modes = TONAL_MODES
	if not tonal_only:
		modes = ALL_MODES
	
	var note_weights = _compute_note_weights(notes)
	var total_weight = 0.0
	
	for w in note_weights.values():
		total_weight += w
	
	if total_weight == 0.0:
		return results
	
	var first_pc = int(notes[0]["pitch"]) % 12
	
	for mode_name in modes.keys():
		var intervals = modes[mode_name]
		
		for root in range(12):
			var score = _score_key(note_weights, total_weight, root, intervals)
			
			if first_pc == root:
				score += 0.05
			
			results.append({
				"mode": mode_name,
				"root": root,
				"score": score
			})
	
	results.sort_custom(self, "_sort_by_score_desc")
	
	if results.size() > max_results:
		results.resize(max_results)
	
	return results


func _compute_note_weights(notes: Array) -> Dictionary:
	var weights = {}
	
	for n in notes:
		if not n.has("pitch"):
			continue
		if not n.has("duration"):
			continue
		
		var pc = int(n["pitch"]) % 12
		var duration = float(n["duration"])
		
		if duration <= 0.0:
			continue
		
		if not weights.has(pc):
			weights[pc] = 0.0
		
		weights[pc] += duration
	
	return weights


func _score_key(note_weights: Dictionary, total_weight: float, root: int, intervals: Array) -> float:
	var scale_pcs = {}
	
	for i in intervals:
		scale_pcs[(root + i) % 12] = true
	
	var hits = 0.0
	
	for pc in note_weights.keys():
		if scale_pcs.has(pc):
			hits += note_weights[pc]
	
	return hits / total_weight


func _sort_by_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return a["score"] > b["score"]

func guess_keys_windowed(notes: Array, window_size: float, step: float = 0.0, tonal_only: bool = true, max_results: int = 5, first_note_bonus: float = 0.05, verbose: bool = false) -> Array:
	var windows = []
	
	if notes.empty():
		return windows
	
	if window_size <= 0.0:
		if verbose:
			print_debug("Key_Guess.guess_keys_windowed: window_size <= 0, abort")
		return windows
	
	if step <= 0.0:
		step = window_size * 0.5
		if verbose:
			print_debug("Key_Guess.guess_keys_windowed: step <= 0, fallback step=", step)
	
	var sorted_notes = notes.duplicate()
	sorted_notes.sort_custom(self, "_sort_notes_by_time")
	
	var t_min = _get_notes_time_min(sorted_notes)
	var t_max = _get_notes_time_max(sorted_notes)
	
	var t = t_min
	while t < t_max:
		var t0 = t
		var t1 = t + window_size
		
		var first_pc = _first_pitch_class_in_window(sorted_notes, t0, t1)
		var note_weights = _compute_note_weights_in_window(sorted_notes, t0, t1)
		var total_weight = 0.0
		for w in note_weights.values():
			total_weight += w
		
		var top = []
		if total_weight > 0.0:
			top = _score_all_keys(note_weights, total_weight, tonal_only, first_pc, first_note_bonus)
			top.sort_custom(self, "_sort_by_score_desc")
			if top.size() > max_results:
				top.resize(max_results)
		
		var confidence = 0.0
		if top.size() >= 2:
			confidence = float(top[0]["score"]) - float(top[1]["score"])
		elif top.size() == 1:
			confidence = float(top[0]["score"])
		
		windows.append({
			"t0": t0,
			"t1": t1,
			"top": top,
			"confidence": confidence
		})
		
		t += step
	
	return windows


func detect_modulations(notes: Array, window_size: float, step: float = 0.0, tonal_only: bool = true, min_confidence: float = 0.08, min_hold_windows: int = 2, verbose: bool = false) -> Array:
	var segments = []
	
	var windows = guess_keys_windowed(notes, window_size, step, tonal_only, 3, 0.05, verbose)
	if windows.empty():
		return segments
	
	var current_key = null
	var current_start = float(windows[0]["t0"])
	var acc_score = 0.0
	var acc_count = 0
	
	var pending_key = null
	var pending_count = 0
	var pending_start = 0.0
	
	for w in windows:
		var top = w["top"]
		if top.empty():
			continue
		
		var conf = float(w["confidence"])
		if conf < min_confidence:
			continue
		
		var best = top[0]
		var key_id = str(best["mode"]) + ":" + str(best["root"])
		
		if current_key == null:
			current_key = best
			current_start = float(w["t0"])
			acc_score = float(best["score"])
			acc_count = 1
			continue
		
		var current_id = str(current_key["mode"]) + ":" + str(current_key["root"])
		if key_id == current_id:
			acc_score += float(best["score"])
			acc_count += 1
			pending_key = null
			pending_count = 0
			continue
		
		# Changement possible -> on exige que ça "tienne" min_hold_windows
		if pending_key == null:
			pending_key = best
			pending_count = 1
			pending_start = float(w["t0"])
		else:
			var pending_id = str(pending_key["mode"]) + ":" + str(pending_key["root"])
			if key_id == pending_id:
				pending_count += 1
			else:
				pending_key = best
				pending_count = 1
				pending_start = float(w["t0"])
		
		if pending_count >= min_hold_windows:
			# On ferme le segment courant
			var end_time = pending_start
			var avg_score = 0.0
			if acc_count > 0:
				avg_score = acc_score / float(acc_count)
			
			segments.append({
				"t0": current_start,
				"t1": end_time,
				"mode": current_key["mode"],
				"root": current_key["root"],
				"avg_score": avg_score
			})
			
			# On ouvre le nouveau segment
			current_key = pending_key
			current_start = pending_start
			acc_score = float(pending_key["score"])
			acc_count = 1
			pending_key = null
			pending_count = 0
	
	# Dernier segment
	var last_t1 = float(windows[windows.size() - 1]["t1"])
	if current_key != null:
		var avg_score2 = 0.0
		if acc_count > 0:
			avg_score2 = acc_score / float(acc_count)
		segments.append({
			"t0": current_start,
			"t1": last_t1,
			"mode": current_key["mode"],
			"root": current_key["root"],
			"avg_score": avg_score2
		})
	
	return segments


func _score_all_keys(note_weights: Dictionary, total_weight: float, tonal_only: bool, first_pc: int, first_note_bonus: float) -> Array:
	var results = []
	var modes = TONAL_MODES
	if not tonal_only:
		modes = ALL_MODES
	
	for mode_name in modes.keys():
		var intervals = modes[mode_name]
		for root in range(12):
			var score = _score_key(note_weights, total_weight, root, intervals)
			if first_pc >= 0 and first_pc == root:
				score += first_note_bonus
			results.append({
				"mode": mode_name,
				"root": root,
				"score": score
			})
	
	return results


func _compute_note_weights_in_window(notes: Array, t0: float, t1: float) -> Dictionary:
	var weights = {}
	
	for n in notes:
		if not n.has("pitch"):
			continue
		if not n.has("duration"):
			continue
		if not n.has("time"):
			continue
		
		var start = float(n["time"])
		var dur = float(n["duration"])
		if dur <= 0.0:
			continue
		
		var endt = start + dur
		
		var overlap_start = start
		if overlap_start < t0:
			overlap_start = t0
		
		var overlap_end = endt
		if overlap_end > t1:
			overlap_end = t1
		
		var overlap = overlap_end - overlap_start
		if overlap <= 0.0:
			continue
		
		var pc = int(n["pitch"]) % 12
		if not weights.has(pc):
			weights[pc] = 0.0
		weights[pc] += overlap
	
	return weights


func _first_pitch_class_in_window(notes: Array, t0: float, t1: float) -> int:
	for n in notes:
		if not n.has("pitch"):
			continue
		if not n.has("time"):
			continue
		if not n.has("duration"):
			continue
		
		var start = float(n["time"])
		var dur = float(n["duration"])
		if dur <= 0.0:
			continue
		
		var endt = start + dur
		if endt <= t0:
			continue
		if start >= t1:
			continue
		
		return int(n["pitch"]) % 12
	
	return -1


func _get_notes_time_min(notes: Array) -> float:
	var tmin = 0.0
	var first = true
	
	for n in notes:
		if not n.has("time"):
			continue
		var t = float(n["time"])
		if first:
			tmin = t
			first = false
		else:
			if t < tmin:
				tmin = t
	
	return tmin


func _get_notes_time_max(notes: Array) -> float:
	var tmax = 0.0
	var first = true
	
	for n in notes:
		if not n.has("time"):
			continue
		if not n.has("duration"):
			continue
		var t = float(n["time"]) + float(n["duration"])
		if first:
			tmax = t
			first = false
		else:
			if t > tmax:
				tmax = t
	
	return tmax


func _sort_notes_by_time(a: Dictionary, b: Dictionary) -> bool:
	if not a.has("time"):
		return true
	if not b.has("time"):
		return false
	return float(a["time"]) < float(b["time"])

extends Node

class_name Planner
const TAG = "Planner"
const Constants = preload("res://addons/musiclib/satb_fractalizer/core/Constants.gd")

var ProgressionAdapter = load("res://addons/musiclib/satb_fractalizer/core/ProgressionAdapter.gd")
var PassingTone = load("res://addons/musiclib/satb_fractalizer/techniques/PassingTone.gd")
var ChromaticPassingTone = load("res://addons/musiclib/satb_fractalizer/techniques/ChromaticPassingTone.gd")
var ChromaticNeighborTone = load("res://addons/musiclib/satb_fractalizer/techniques/ChromaticNeighborTone.gd")
var NeighborTone = load("res://addons/musiclib/satb_fractalizer/techniques/NeighborTone.gd")
var NeighborToneForced = load("res://addons/musiclib/satb_fractalizer/techniques/NeighborToneForced.gd")
var DoubleNeighbor = load("res://addons/musiclib/satb_fractalizer/techniques/DoubleNeighbor.gd")
var Appoggiatura = load("res://addons/musiclib/satb_fractalizer/techniques/Appoggiatura.gd")
var EscapeTone = load("res://addons/musiclib/satb_fractalizer/techniques/EscapeTone.gd")
var Anticipation = load("res://addons/musiclib/satb_fractalizer/techniques/Anticipation.gd")
var Suspension = load("res://addons/musiclib/satb_fractalizer/techniques/Suspension.gd")
var Retardation = load("res://addons/musiclib/satb_fractalizer/techniques/Retardation.gd")
var Pedal = load("res://addons/musiclib/satb_fractalizer/techniques/Pedal.gd")
var ExtendedPassingTones = load("res://addons/musiclib/satb_fractalizer/techniques/ExtendedPassingTones.gd")

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

func apply(chords_array, params):
	LogBus.info(TAG, "=== SATB Fractalizer: Starting ===")

	# Extract global params
	var time_num = params.get("time_num", Constants.DEFAULT_TIME_NUM)
	var time_den = params.get("time_den", Constants.DEFAULT_TIME_DEN)
	var grid_unit = params.get("grid_unit", Constants.DEFAULT_GRID_UNIT)
	var time_windows = params.get("time_windows", [])
	var voice_pattern = params.get("voice_window_pattern", Constants.DEFAULT_VOICE_PATTERN)
	var allowed_techniques = params.get("allowed_techniques", [
		Constants.TECHNIQUE_PASSING_TONE,
		Constants.TECHNIQUE_NEIGHBOR_TONE,
		Constants.TECHNIQUE_APPOGGIATURA
	])
	var triplet_allowed = params.get("triplet_allowed", Constants.DEFAULT_TRIPLET_ALLOWED)
	var pair_strategy = params.get("pair_selection_strategy", Constants.STRATEGY_EARLIEST)
	var technique_weights = params.get("technique_weights", {})  # Empty dict = uniform weights

	# Initialize RNG with seed (for reproducibility)
	var rng_seed = params.get("rng_seed", null)
	if rng_seed == null:
		rng_seed = OS.get_ticks_msec()
	randomize()
	seed(rng_seed)
	LogBus.info(TAG, "RNG seed: " + str(rng_seed) + " (for reproducibility)")

	# 1. Convert JSON Array to Progression
	var adapter = ProgressionAdapter.new()
	var progression = adapter.from_json_array(chords_array, time_num, time_den, grid_unit)

	if not progression:
		LogBus.error(TAG, "Failed to convert JSON to Progression")
		return chords_array

	# Initialize metadata with global parameters (stored once, not repeated per window)
	var current_depth = progression.metadata.get("generation_depth", 0)
	progression.metadata["generation_depth"] = current_depth
	progression.metadata["rng_seed"] = rng_seed
	progression.metadata["global_params"] = {
		"time_num": time_num,
		"time_den": time_den,
		"grid_unit": grid_unit,
		"voice_window_pattern": voice_pattern,
		"triplet_allowed": triplet_allowed,
		"pair_selection_strategy": pair_strategy,
		"allowed_techniques": allowed_techniques.duplicate()
	}

	# Store initial progression (only on first pass)
	if not progression.metadata.has("initial_progression"):
		progression.metadata["initial_progression"] = adapter.to_json_array(progression)

	LogBus.info(TAG, "Converted to Progression: " + str(progression.get_chord_count()) + " chords")

	# 2. Process each time window
	for w in range(time_windows.size()):
		var window = time_windows[w]

		# Get iteration count for this window (default = 1)
		var iterations = window.get("iteration", 1)

		if iterations < 1:
			LogBus.warn(TAG, "Window " + str(w) + " has invalid iteration count " + str(iterations) + ", skipping")
			continue

		LogBus.info(TAG, "Processing window " + str(w) + ": [" + str(window.start) + ", " + str(window.end) + "] (" + str(iterations) + " iteration(s))")

		# Process window multiple times if iterations > 1
		for iter in range(iterations):
			if iterations > 1:
				LogBus.debug(TAG, "Window " + str(w) + ", iteration " + str(iter + 1) + "/" + str(iterations))

			# Get pattern voice for this window
			var pattern_voice = _get_pattern_voice(w, voice_pattern)
			LogBus.debug(TAG, "Pattern voice for window " + str(w) + " iter " + str(iter) + ": " + pattern_voice)

			# For iterations after the first, exclude decorative pairs to avoid re-processing
			# This prevents overlaps and gaps when applying multiple techniques
			var exclude_decorative = (iter > 0)

			# Create technique params with iteration-specific settings
			var technique_params = params.duplicate()
			technique_params["exclude_decorative_pairs"] = exclude_decorative

			# Process window
			progression = _process_window(
				progression,
				window,
				w,  # window_index
				pattern_voice,
				allowed_techniques,
				triplet_allowed,
				pair_strategy,
				technique_weights,
				technique_params
			)

	# 3. Convert Progression back to JSON Array
	var result_chords = adapter.to_json_array(progression)

	if not result_chords:
		LogBus.error(TAG, "Failed to convert Progression to JSON")
		return chords_array

	# 4. Build result object with chords and metadata
	var result = {
		"chords": result_chords,
		"metadata": progression.metadata.duplicate(true)
	}

	LogBus.info(TAG, "=== SATB Fractalizer: Complete ===")
	return result

# =============================================================================
# GET PATTERN VOICE
# =============================================================================

func _get_pattern_voice(window_index, pattern):
	# pattern = "SA" → window 0: S, window 1: A, window 2: S, etc.
	var pattern_length = pattern.length()
	if pattern_length == 0:
		LogBus.warn(TAG, "_get_pattern_voice: empty pattern, using default S")
		return Constants.VOICE_SOPRANO

	var idx = window_index % pattern_length
	var voice_char = pattern[idx]

	# Map character to voice ID
	if voice_char == "S":
		return Constants.VOICE_SOPRANO
	elif voice_char == "A":
		return Constants.VOICE_ALTO
	elif voice_char == "T":
		return Constants.VOICE_TENOR
	elif voice_char == "B":
		return Constants.VOICE_BASS
	else:
		LogBus.warn(TAG, "_get_pattern_voice: unknown voice char '" + voice_char + "', using S")
		return Constants.VOICE_SOPRANO

# =============================================================================
# PROCESS WINDOW
# =============================================================================

func _process_window(progression, window, window_index, voice_id, allowed_techniques, triplet_allowed, pair_strategy, technique_weights, global_params):
	# Select and apply one technique for this window

	# Initialize window report
	var window_report = {
		"start": window.start,
		"end": window.end,
		"window_index": window_index,
		"pattern_voice": voice_id,
		"candidate_techniques": allowed_techniques.duplicate(),
		"candidate_voices": [voice_id],
		"chosen_technique": null,
		"chosen_span": null,
		"applied": false,
		"reason_if_skipped": null
	}

	# Check if voice is modifiable
	if not _is_voice_modifiable(progression, voice_id):
		LogBus.warn(TAG, "Voice " + voice_id + " is not modifiable, skipping window")
		window_report.reason_if_skipped = "pattern_voice_not_modifiable"
		progression.metadata.technique_report.time_windows.append(window_report)
		return progression

	# Select a technique
	var chosen_technique = _select_technique(allowed_techniques, technique_weights)
	if not chosen_technique:
		LogBus.warn(TAG, "No technique selected, skipping window")
		window_report.reason_if_skipped = "no_technique_selected"
		progression.metadata.technique_report.time_windows.append(window_report)
		return progression

	window_report.chosen_technique = chosen_technique
	LogBus.info(TAG, "Applying technique: " + chosen_technique + " on voice " + voice_id)

	# Create technique instance
	var technique = _create_technique_instance(chosen_technique)
	if not technique:
		LogBus.error(TAG, "Failed to create technique instance for " + chosen_technique)
		window_report.reason_if_skipped = "technique_instantiation_failed"
		progression.metadata.technique_report.time_windows.append(window_report)
		return progression

	# Prepare params for technique
	var technique_params = {
		"time_window": window,
		"voice": voice_id,
		"triplet_allowed": triplet_allowed,
		"pair_selection_strategy": pair_strategy
	}

	# Merge with global params (for technique-specific overrides)
	for key in global_params:
		if not technique_params.has(key):
			technique_params[key] = global_params[key]

	# Record in history (before applying) - only window-specific data
	var history_entry = {
		"op": "apply_" + chosen_technique,
		"window_index": window_index,
		"window_start": window.start,
		"window_end": window.end,
		"voice": voice_id,
		"status": "pending"
	}

	# Apply technique
	var chord_count_before = progression.get_chord_count()
	var new_progression = technique.apply(progression, technique_params)
	var chord_count_after = new_progression.get_chord_count()

	# Check if technique was actually applied
	if chord_count_after > chord_count_before:
		window_report.applied = true
		history_entry.status = "success"
		history_entry.chords_added = chord_count_after - chord_count_before
		LogBus.info(TAG, "Technique applied successfully: " + str(chord_count_after - chord_count_before) + " chords added")
	else:
		window_report.applied = false
		window_report.reason_if_skipped = "technique_conditions_not_met"
		history_entry.status = "skipped"
		LogBus.warn(TAG, "Technique was not applied (conditions not met)")

	# Record in progression metadata
	new_progression.metadata.history.append(history_entry)
	new_progression.metadata.technique_report.time_windows.append(window_report)

	return new_progression

# =============================================================================
# VOICE MODIFIABILITY CHECK
# =============================================================================

func _is_voice_modifiable(progression, voice_id):
	# Check voice_policy if it exists
	if progression.voice_policy.has(voice_id):
		var policy = progression.voice_policy[voice_id]
		if policy.has("modifiable"):
			return policy.modifiable

	# Default: allow modification
	return true

# =============================================================================
# TECHNIQUE SELECTION
# =============================================================================

func _select_technique(allowed_techniques, technique_weights):
	# Weighted probabilistic technique selection
	# If technique_weights is provided, uses weighted random selection
	# Otherwise, uses uniform random selection

	if allowed_techniques.empty():
		return null

	# If no weights provided or weights empty, use uniform random
	if not technique_weights or technique_weights.empty():
		var idx = randi() % allowed_techniques.size()
		return allowed_techniques[idx]

	# Build weighted list
	var total_weight = 0.0
	var cumulative_weights = []

	for technique in allowed_techniques:
		var weight = technique_weights.get(technique, 1.0)  # Default weight = 1.0
		total_weight += weight
		cumulative_weights.append(total_weight)

	if total_weight <= 0.0:
		# All weights are zero or negative, fallback to uniform
		var idx = randi() % allowed_techniques.size()
		return allowed_techniques[idx]

	# Select using weighted random
	var random_value = randf() * total_weight

	for i in range(cumulative_weights.size()):
		if random_value <= cumulative_weights[i]:
			return allowed_techniques[i]

	# Fallback (should not reach here)
	return allowed_techniques[allowed_techniques.size() - 1]

# =============================================================================
# TECHNIQUE INSTANTIATION
# =============================================================================

func _create_technique_instance(technique_id):
	if technique_id == Constants.TECHNIQUE_PASSING_TONE:
		return PassingTone.new()
	elif technique_id == Constants.TECHNIQUE_CHROMATIC_PASSING_TONE:
		return ChromaticPassingTone.new()
	elif technique_id == Constants.TECHNIQUE_CHROMATIC_NEIGHBOR_TONE:
		return ChromaticNeighborTone.new()
	elif technique_id == Constants.TECHNIQUE_NEIGHBOR_TONE:
		return NeighborTone.new()
	elif technique_id == Constants.TECHNIQUE_NEIGHBOR_TONE_FORCED:
		return NeighborToneForced.new()
	elif technique_id == Constants.TECHNIQUE_DOUBLE_NEIGHBOR:
		return DoubleNeighbor.new()
	elif technique_id == Constants.TECHNIQUE_APPOGGIATURA:
		return Appoggiatura.new()
	elif technique_id == Constants.TECHNIQUE_ESCAPE_TONE:
		return EscapeTone.new()
	elif technique_id == Constants.TECHNIQUE_ANTICIPATION:
		return Anticipation.new()
	elif technique_id == Constants.TECHNIQUE_SUSPENSION:
		return Suspension.new()
	elif technique_id == Constants.TECHNIQUE_RETARDATION:
		return Retardation.new()
	elif technique_id == Constants.TECHNIQUE_PEDAL:
		return Pedal.new()
	elif technique_id == Constants.TECHNIQUE_EXTENDED_PASSING_TONES:
		return ExtendedPassingTones.new()
	else:
		LogBus.error(TAG, "_create_technique_instance: unknown technique " + technique_id)
		return null

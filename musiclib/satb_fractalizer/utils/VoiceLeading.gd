extends Node

const TAG = "VoiceLeading"
const Constants = preload("res://addons/musiclib/satb_fractalizer/core/Constants.gd")

# =============================================================================
# RANGE VALIDATION (±1 octave from original, no crossing)
# =============================================================================

static func validate_range(voice_id, new_pitch, original_pitch, adjacent_voices):
	# adjacent_voices: {"upper": pitch or null, "lower": pitch or null}
	# Returns: {valid: bool, reason: String}

	# Check ±1 octave from original
	var distance = abs(new_pitch - original_pitch)
	if distance > Constants.MAX_VOICE_RANGE:
		return {
			"valid": false,
			"reason": "pitch " + str(new_pitch) + " exceeds ±1 octave from original " + str(original_pitch)
		}

	# Check no crossing with upper voice
	if adjacent_voices.has("upper") and adjacent_voices.upper != null:
		if new_pitch > adjacent_voices.upper:
			return {
				"valid": false,
				"reason": "pitch " + str(new_pitch) + " crosses upper voice " + str(adjacent_voices.upper)
			}

	# Check no crossing with lower voice
	if adjacent_voices.has("lower") and adjacent_voices.lower != null:
		if new_pitch < adjacent_voices.lower:
			return {
				"valid": false,
				"reason": "pitch " + str(new_pitch) + " crosses lower voice " + str(adjacent_voices.lower)
			}

	return {"valid": true, "reason": ""}

# =============================================================================
# VOICE CROSSING CHECK
# =============================================================================

static func check_voice_crossing(soprano_pitch, alto_pitch, tenor_pitch, bass_pitch):
	# Returns: {valid: bool, reason: String}

	if soprano_pitch < alto_pitch:
		return {
			"valid": false,
			"reason": "soprano " + str(soprano_pitch) + " < alto " + str(alto_pitch)
		}

	if alto_pitch < tenor_pitch:
		return {
			"valid": false,
			"reason": "alto " + str(alto_pitch) + " < tenor " + str(tenor_pitch)
		}

	if tenor_pitch < bass_pitch:
		return {
			"valid": false,
			"reason": "tenor " + str(tenor_pitch) + " < bass " + str(bass_pitch)
		}

	return {"valid": true, "reason": ""}

# =============================================================================
# CONJOINT MOTION CHECK
# =============================================================================

static func is_conjoint_motion(pitch1, pitch2):
	# Conjoint = interval of 1 or 2 semitones (minor or major second)
	var interval = abs(pitch2 - pitch1)
	return interval == 1 or interval == 2

# =============================================================================
# BEAT STRENGTH VALIDATION
# =============================================================================

static func validate_beat_strength(technique_id, beat_strength):
	# Returns: {valid: bool, reason: String}
	# Based on spec §5

	if technique_id == Constants.TECHNIQUE_PASSING_TONE:
		if beat_strength != Constants.BEAT_WEAK:
			return {
				"valid": false,
				"reason": "passing_tone requires weak beat, got " + beat_strength
			}

	elif technique_id == Constants.TECHNIQUE_NEIGHBOR_TONE:
		if beat_strength != Constants.BEAT_WEAK:
			return {
				"valid": false,
				"reason": "neighbor_tone requires weak beat, got " + beat_strength
			}

	elif technique_id == Constants.TECHNIQUE_APPOGGIATURA:
		if beat_strength != Constants.BEAT_STRONG:
			return {
				"valid": false,
				"reason": "appoggiatura requires strong beat, got " + beat_strength
			}

	elif technique_id == Constants.TECHNIQUE_ESCAPE_TONE:
		if beat_strength != Constants.BEAT_WEAK:
			return {
				"valid": false,
				"reason": "escape_tone requires weak beat, got " + beat_strength
			}

	elif technique_id == Constants.TECHNIQUE_ANTICIPATION:
		if beat_strength != Constants.BEAT_WEAK:
			return {
				"valid": false,
				"reason": "anticipation requires weak beat, got " + beat_strength
			}

	# Suspension/retardation have more complex rules (prepared on previous chord)
	# Pedal doesn't have beat strength requirements

	return {"valid": true, "reason": ""}

# =============================================================================
# SIMULTANEITY CHECK
# =============================================================================

static func check_simultaneity(nct_pitch, anchor_pitch, voice_distance):
	# Check if NCT can sound simultaneously with its anchor/resolution note
	# voice_distance: number of voices apart (1=adjacent, 2=one voice between, etc.)
	# Returns: {valid: bool, reason: String}

	var interval = abs(nct_pitch - anchor_pitch)

	# Adjacent voices (S-A, A-T, T-B)
	if voice_distance == 1:
		# Prefer to avoid simultaneity in adjacent voices
		# If unavoidable, ensure consonant interval or large distance
		if interval < 3:
			return {
				"valid": false,
				"reason": "too close interval " + str(interval) + " between adjacent voices"
			}

	# Non-adjacent voices: more permissive
	# (no strict rule for now)

	return {"valid": true, "reason": ""}

# =============================================================================
# GENERAL VALIDATION
# =============================================================================

static func validate_nct_insertion(chord, voice_id, new_pitch, technique_id, time_grid):
	# Comprehensive validation for NCT insertion
	# Returns: {valid: bool, reason: String}

	var original_pitch = chord.voices[voice_id].pitch

	# 1. Range validation
	var adjacent_voices = _get_adjacent_voices(chord, voice_id)
	var range_check = validate_range(voice_id, new_pitch, original_pitch, adjacent_voices)
	if not range_check.valid:
		return range_check

	# 2. Beat strength validation
	var beat_strength = time_grid.get_beat_strength(chord.start_time)
	var beat_check = validate_beat_strength(technique_id, beat_strength)
	if not beat_check.valid:
		return beat_check

	# 3. Conjoint motion (if required by technique)
	if _requires_conjoint_motion(technique_id):
		# This check is done in the technique itself (comparing with target pitch)
		pass

	return {"valid": true, "reason": ""}

static func _get_adjacent_voices(chord, voice_id):
	var adjacent = {"upper": null, "lower": null}

	if voice_id == Constants.VOICE_SOPRANO:
		adjacent.lower = chord.voices[Constants.VOICE_ALTO].pitch
	elif voice_id == Constants.VOICE_ALTO:
		adjacent.upper = chord.voices[Constants.VOICE_SOPRANO].pitch
		adjacent.lower = chord.voices[Constants.VOICE_TENOR].pitch
	elif voice_id == Constants.VOICE_TENOR:
		adjacent.upper = chord.voices[Constants.VOICE_ALTO].pitch
		adjacent.lower = chord.voices[Constants.VOICE_BASS].pitch
	elif voice_id == Constants.VOICE_BASS:
		adjacent.upper = chord.voices[Constants.VOICE_TENOR].pitch

	return adjacent

static func _requires_conjoint_motion(technique_id):
	return technique_id in [
		Constants.TECHNIQUE_PASSING_TONE,
		Constants.TECHNIQUE_NEIGHBOR_TONE,
		Constants.TECHNIQUE_APPOGGIATURA,
		Constants.TECHNIQUE_ANTICIPATION
	]

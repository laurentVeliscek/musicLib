extends Node

const TAG = "Constants"

# =============================================================================
# TECHNIQUE IDs
# =============================================================================

const TECHNIQUE_PASSING_TONE = "passing_tone"
const TECHNIQUE_NEIGHBOR_TONE = "neighbor_tone"
const TECHNIQUE_NEIGHBOR_TONE_FORCED = "neighbor_tone_forced"
const TECHNIQUE_APPOGGIATURA = "appoggiatura"
const TECHNIQUE_CHROMATIC_PASSING_TONE = "chromatic_passing_tone"
const TECHNIQUE_CHROMATIC_NEIGHBOR_TONE = "chromatic_neighbor_tone"
const TECHNIQUE_DOUBLE_NEIGHBOR = "double_neighbor"
const TECHNIQUE_ESCAPE_TONE = "escape_tone"
const TECHNIQUE_ANTICIPATION = "anticipation"
const TECHNIQUE_SUSPENSION = "suspension"
const TECHNIQUE_RETARDATION = "retardation"
const TECHNIQUE_PEDAL = "pedal"
const TECHNIQUE_EXTENDED_PASSING_TONES = "extended_passing_tones"

# =============================================================================
# VOICE NAMES
# =============================================================================

const VOICE_SOPRANO = "S"
const VOICE_ALTO = "A"
const VOICE_TENOR = "T"
const VOICE_BASS = "B"

const VOICES = [VOICE_SOPRANO, VOICE_ALTO, VOICE_TENOR, VOICE_BASS]

# Mapping vers format JSON (avec majuscules)
const VOICE_TO_JSON = {
	"S": "Soprano",
	"A": "Alto",
	"T": "Tenor",
	"B": "Bass"
}

const JSON_TO_VOICE = {
	"Soprano": "S",
	"Alto": "A",
	"Tenor": "T",
	"Bass": "B"
}

# =============================================================================
# VOICE ROLES
# =============================================================================

const ROLE_CHORD_TONE = "chord_tone"
const ROLE_PASSING_TONE = "passing_tone"
const ROLE_CHROMATIC_PASSING_TONE = "chromatic_passing_tone"
const ROLE_NEIGHBOR_TONE = "neighbor_tone"
const ROLE_DOUBLE_NEIGHBOR = "double_neighbor"
const ROLE_APPOGGIATURA = "appoggiatura"
const ROLE_ESCAPE_TONE = "escape_tone"
const ROLE_ANTICIPATION = "anticipation"
const ROLE_SUSPENSION = "suspension"
const ROLE_RETARDATION = "retardation"
const ROLE_PEDAL = "pedal"
const ROLE_OTHER_NCT = "other_nct"

# =============================================================================
# BEAT STRENGTH
# =============================================================================

const BEAT_STRONG = "strong"
const BEAT_MEDIUM = "medium"
const BEAT_WEAK = "weak"

# =============================================================================
# DIRECTION
# =============================================================================

const DIRECTION_ASCENDING = "ascending"
const DIRECTION_DESCENDING = "descending"
const DIRECTION_STATIC = "static"

# =============================================================================
# SCALE NAMES (recognized tonal scales)
# =============================================================================

const SCALE_MAJOR = "major"
const SCALE_MINOR = "minor"
const SCALE_HARMONIC_MINOR = "harmonic_minor"
const SCALE_MELODIC_MINOR = "melodic_minor"

# =============================================================================
# PAIR SELECTION STRATEGIES
# =============================================================================

const STRATEGY_EARLIEST = "earliest"
const STRATEGY_LONGEST = "longest"

# =============================================================================
# DEFAULTS
# =============================================================================

const DEFAULT_GRID_UNIT = 0.25
const DEFAULT_TIME_NUM = 4
const DEFAULT_TIME_DEN = 4
const DEFAULT_MIN_NOTE_DURATION = 0.25
const DEFAULT_WINDOW_SIZE = 2.0
const DEFAULT_VOICE_PATTERN = "SA"
const DEFAULT_TRIPLET_ALLOWED = false

# =============================================================================
# TESSITURA (±1 octave from original pitch)
# =============================================================================

const MAX_VOICE_RANGE = 12  # semitones (1 octave)

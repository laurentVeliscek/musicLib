extends Reference
class_name PartimentoRules

const TAG = "PartimentoRules"

# ==============================================================================
# PARTIMENTO RULES
# Règles d'harmonisation basées sur la tradition napolitaine du 18ème siècle
# ==============================================================================

# ------------------------------------------------------------------------------
# RÈGLE D'OCTAVE (Rule of the Octave)
# Harmonisation standard de chaque degré de la gamme à la basse
# Format: degree_number -> { chord_info }
# ------------------------------------------------------------------------------

const RULE_OF_OCTAVE_MAJOR_ASCENDING = {
	1: { "degree": 1, "label": "I", "inversion": 0, "realization": [1, 3, 5], "function": "T" },
	2: { "degree": 5, "label": "V", "inversion": 1, "realization": [1, 3, 5, 7], "function": "D" },  # V65
	3: { "degree": 1, "label": "I", "inversion": 1, "realization": [1, 3, 5], "function": "T" },      # I6
	4: { "degree": 2, "label": "ii", "inversion": 1, "realization": [1, 3, 5], "function": "PD" },    # ii6 ou IV
	5: { "degree": 5, "label": "V", "inversion": 0, "realization": [1, 3, 5], "function": "D" },
	6: { "degree": 5, "label": "V", "inversion": 1, "realization": [1, 3, 5, 7], "function": "D" },   # V65/vi ou vi
	7: { "degree": 5, "label": "V", "inversion": 2, "realization": [1, 3, 5, 7], "function": "D" }    # V43
}

const RULE_OF_OCTAVE_MAJOR_DESCENDING = {
	1: { "degree": 1, "label": "I", "inversion": 0, "realization": [1, 3, 5], "function": "T" },
	7: { "degree": 5, "label": "V", "inversion": 2, "realization": [1, 3, 5, 7], "function": "D" },   # V43
	6: { "degree": 4, "label": "IV", "inversion": 0, "realization": [1, 3, 5], "function": "PD" },
	5: { "degree": 5, "label": "V", "inversion": 0, "realization": [1, 3, 5], "function": "D" },
	4: { "degree": 5, "label": "V", "inversion": 3, "realization": [1, 3, 5, 7], "function": "D" },   # V42
	3: { "degree": 1, "label": "I", "inversion": 1, "realization": [1, 3, 5], "function": "T" },      # I6
	2: { "degree": 5, "label": "V", "inversion": 1, "realization": [1, 3, 5, 7], "function": "D" }    # V65
}

const RULE_OF_OCTAVE_MINOR_ASCENDING = {
	1: { "degree": 1, "label": "i", "inversion": 0, "realization": [1, 3, 5], "function": "T" },
	2: { "degree": 5, "label": "V", "inversion": 1, "realization": [1, 3, 5, 7], "function": "D" },   # V65
	3: { "degree": 1, "label": "i", "inversion": 1, "realization": [1, 3, 5], "function": "T" },      # i6
	4: { "degree": 2, "label": "iio", "inversion": 1, "realization": [1, 3, 5], "function": "PD" },   # iio6 ou iv
	5: { "degree": 5, "label": "V", "inversion": 0, "realization": [1, 3, 5], "function": "D" },
	6: { "degree": 4, "label": "iv", "inversion": 1, "realization": [1, 3, 5], "function": "PD" },    # iv6
	7: { "degree": 5, "label": "V", "inversion": 2, "realization": [1, 3, 5, 7], "function": "D" }    # V43 (sensible)
}

const RULE_OF_OCTAVE_MINOR_DESCENDING = {
	1: { "degree": 1, "label": "i", "inversion": 0, "realization": [1, 3, 5], "function": "T" },
	7: { "degree": 7, "label": "VII", "inversion": 0, "realization": [1, 3, 5], "function": "T" },    # VII naturel
	6: { "degree": 4, "label": "iv", "inversion": 0, "realization": [1, 3, 5], "function": "PD" },
	5: { "degree": 5, "label": "V", "inversion": 0, "realization": [1, 3, 5], "function": "D" },
	4: { "degree": 5, "label": "V", "inversion": 3, "realization": [1, 3, 5, 7], "function": "D" },   # V42
	3: { "degree": 1, "label": "i", "inversion": 1, "realization": [1, 3, 5], "function": "T" },      # i6
	2: { "degree": 5, "label": "V", "inversion": 1, "realization": [1, 3, 5, 7], "function": "D" }    # V65
}

# ------------------------------------------------------------------------------
# SCHÉMAS PARTIMENTO (Schemata)
# Patterns harmoniques récurrents de la tradition galante
# ------------------------------------------------------------------------------

# Romanesca: I - VII - I - V (basse: 1 - 7 - 1 - 5)
const SCHEMA_ROMANESCA = {
	"name": "Romanesca",
	"pattern": [
		{ "degree": 1, "inversion": 0, "function": "T" },
		{ "degree": 7, "inversion": 0, "function": "D" },   # ou viio6
		{ "degree": 1, "inversion": 1, "function": "T" },
		{ "degree": 5, "inversion": 0, "function": "D" }
	],
	"bass_line": [1, 7, 1, 5],
	"typical_soprano": [3, 2, 1, 7]  # ou [5, 4, 3, 2]
}

# Prinner: IV - I - ii - V (basse: 4 - 3 - 2 - 1 ou 5)
const SCHEMA_PRINNER = {
	"name": "Prinner",
	"pattern": [
		{ "degree": 4, "inversion": 0, "function": "PD" },
		{ "degree": 1, "inversion": 1, "function": "T" },
		{ "degree": 2, "inversion": 0, "function": "PD" },
		{ "degree": 5, "inversion": 0, "function": "D" }
	],
	"bass_line": [4, 3, 2, 1],
	"typical_soprano": [6, 5, 4, 3]
}

# Monte: Séquence ascendante par tons (ii - V - iii - vi...)
const SCHEMA_MONTE = {
	"name": "Monte",
	"pattern": [
		{ "degree": 2, "inversion": 0, "function": "PD" },
		{ "degree": 5, "inversion": 0, "function": "D" },
		{ "degree": 3, "inversion": 0, "function": "T" },
		{ "degree": 6, "inversion": 0, "function": "T" }
	],
	"bass_line": [2, 5, 3, 6],
	"typical_soprano": [4, 5, 5, 6]
}

# Fonte: Séquence descendante (vi - ii - V - I)
const SCHEMA_FONTE = {
	"name": "Fonte",
	"pattern": [
		{ "degree": 6, "inversion": 0, "function": "T" },
		{ "degree": 2, "inversion": 0, "function": "PD" },
		{ "degree": 5, "inversion": 0, "function": "D" },
		{ "degree": 1, "inversion": 0, "function": "T" }
	],
	"bass_line": [6, 2, 5, 1],
	"typical_soprano": [1, 7, 2, 1]
}

# Folia: i - V - i - VII - III - VII - i - V
const SCHEMA_FOLIA = {
	"name": "Folia",
	"pattern": [
		{ "degree": 1, "inversion": 0, "function": "T" },
		{ "degree": 5, "inversion": 0, "function": "D" },
		{ "degree": 1, "inversion": 0, "function": "T" },
		{ "degree": 7, "inversion": 0, "function": "D" },
		{ "degree": 3, "inversion": 0, "function": "T" },
		{ "degree": 7, "inversion": 0, "function": "D" },
		{ "degree": 1, "inversion": 0, "function": "T" },
		{ "degree": 5, "inversion": 0, "function": "D" }
	],
	"bass_line": [1, 5, 1, 7, 3, 7, 1, 5],
	"typical_soprano": [5, 5, 5, 4, 3, 4, 5, 5]
}

# Pachelbel / Canon: I - V - vi - iii - IV - I - IV - V
const SCHEMA_PACHELBEL = {
	"name": "Pachelbel",
	"pattern": [
		{ "degree": 1, "inversion": 0, "function": "T" },
		{ "degree": 5, "inversion": 0, "function": "D" },
		{ "degree": 6, "inversion": 0, "function": "T" },
		{ "degree": 3, "inversion": 0, "function": "T" },
		{ "degree": 4, "inversion": 0, "function": "PD" },
		{ "degree": 1, "inversion": 0, "function": "T" },
		{ "degree": 4, "inversion": 0, "function": "PD" },
		{ "degree": 5, "inversion": 0, "function": "D" }
	],
	"bass_line": [1, 5, 6, 3, 4, 1, 4, 5],
	"typical_soprano": [3, 2, 1, 7, 1, 1, 1, 2]
}

# Cadence parfaite: ii - V - I
const SCHEMA_CADENCE_PARFAITE = {
	"name": "Cadence Parfaite",
	"pattern": [
		{ "degree": 2, "inversion": 0, "function": "PD" },
		{ "degree": 5, "inversion": 0, "function": "D" },
		{ "degree": 1, "inversion": 0, "function": "T" }
	],
	"bass_line": [2, 5, 1],
	"typical_soprano": [2, 2, 1]
}

# Cadence avec quarte et sixte: I64 - V - I
const SCHEMA_CADENCE_64 = {
	"name": "Cadence 6/4",
	"pattern": [
		{ "degree": 1, "inversion": 2, "function": "T", "kind": "cad64" },
		{ "degree": 5, "inversion": 0, "function": "D" },
		{ "degree": 1, "inversion": 0, "function": "T" }
	],
	"bass_line": [5, 5, 1],
	"typical_soprano": [1, 7, 1]
}

# Liste de tous les schémas
const ALL_SCHEMAS = ["romanesca", "prinner", "monte", "fonte", "folia", "pachelbel", "cadence_parfaite", "cadence_64"]

# ------------------------------------------------------------------------------
# MAPPING NOTE MÉLODIQUE -> ACCORDS POSSIBLES
# Pour chaque degré de la gamme au soprano, quels accords peuvent l'accompagner
# ------------------------------------------------------------------------------

# En majeur: note (degré 1-7) -> liste d'accords possibles
const MELODY_TO_CHORDS_MAJOR = {
	1: [  # Do en Do majeur
		{ "degree": 1, "label": "I", "position": "root", "weight": 4, "function": "T" },
		{ "degree": 4, "label": "IV", "position": "fifth", "weight": 3, "function": "PD" },
		{ "degree": 6, "label": "vi", "position": "third", "weight": 2, "function": "T" }
	],
	2: [  # Ré
		{ "degree": 2, "label": "ii", "position": "root", "weight": 3, "function": "PD" },
		{ "degree": 5, "label": "V", "position": "fifth", "weight": 4, "function": "D" },
		{ "degree": 7, "label": "viio", "position": "third", "weight": 2, "function": "D" }
	],
	3: [  # Mi
		{ "degree": 1, "label": "I", "position": "third", "weight": 4, "function": "T" },
		{ "degree": 3, "label": "iii", "position": "root", "weight": 2, "function": "T" },
		{ "degree": 6, "label": "vi", "position": "fifth", "weight": 2, "function": "T" }
	],
	4: [  # Fa
		{ "degree": 2, "label": "ii", "position": "third", "weight": 3, "function": "PD" },
		{ "degree": 4, "label": "IV", "position": "root", "weight": 4, "function": "PD" },
		{ "degree": 7, "label": "viio", "position": "fifth", "weight": 2, "function": "D" }
	],
	5: [  # Sol
		{ "degree": 1, "label": "I", "position": "fifth", "weight": 4, "function": "T" },
		{ "degree": 3, "label": "iii", "position": "third", "weight": 1, "function": "T" },
		{ "degree": 5, "label": "V", "position": "root", "weight": 4, "function": "D" }
	],
	6: [  # La
		{ "degree": 2, "label": "ii", "position": "fifth", "weight": 3, "function": "PD" },
		{ "degree": 4, "label": "IV", "position": "third", "weight": 3, "function": "PD" },
		{ "degree": 6, "label": "vi", "position": "root", "weight": 3, "function": "T" }
	],
	7: [  # Si (sensible)
		{ "degree": 3, "label": "iii", "position": "fifth", "weight": 1, "function": "T" },
		{ "degree": 5, "label": "V", "position": "third", "weight": 5, "function": "D" },
		{ "degree": 7, "label": "viio", "position": "root", "weight": 3, "function": "D" }
	]
}

# En mineur: note (degré 1-7) -> liste d'accords possibles
const MELODY_TO_CHORDS_MINOR = {
	1: [  # Do en La mineur
		{ "degree": 1, "label": "i", "position": "root", "weight": 4, "function": "T" },
		{ "degree": 4, "label": "iv", "position": "fifth", "weight": 3, "function": "PD" },
		{ "degree": 6, "label": "VI", "position": "third", "weight": 2, "function": "T" }
	],
	2: [  # Ré
		{ "degree": 2, "label": "iio", "position": "root", "weight": 3, "function": "PD" },
		{ "degree": 5, "label": "V", "position": "fifth", "weight": 4, "function": "D" },
		{ "degree": 7, "label": "viio", "position": "third", "weight": 2, "function": "D" }
	],
	3: [  # Mi bémol (tierce mineure)
		{ "degree": 1, "label": "i", "position": "third", "weight": 4, "function": "T" },
		{ "degree": 3, "label": "III", "position": "root", "weight": 3, "function": "T" },
		{ "degree": 6, "label": "VI", "position": "fifth", "weight": 2, "function": "T" }
	],
	4: [  # Fa
		{ "degree": 2, "label": "iio", "position": "third", "weight": 2, "function": "PD" },
		{ "degree": 4, "label": "iv", "position": "root", "weight": 4, "function": "PD" },
		{ "degree": 7, "label": "VII", "position": "fifth", "weight": 2, "function": "T" }  # VII naturel
	],
	5: [  # Sol
		{ "degree": 1, "label": "i", "position": "fifth", "weight": 4, "function": "T" },
		{ "degree": 3, "label": "III", "position": "third", "weight": 2, "function": "T" },
		{ "degree": 5, "label": "V", "position": "root", "weight": 4, "function": "D" }
	],
	6: [  # La bémol (sixte mineure)
		{ "degree": 2, "label": "iio", "position": "fifth", "weight": 2, "function": "PD" },
		{ "degree": 4, "label": "iv", "position": "third", "weight": 3, "function": "PD" },
		{ "degree": 6, "label": "VI", "position": "root", "weight": 4, "function": "T" }
	],
	7: [  # Sol# (sensible harmonique)
		{ "degree": 3, "label": "III+", "position": "fifth", "weight": 1, "function": "T" },
		{ "degree": 5, "label": "V", "position": "third", "weight": 5, "function": "D" },
		{ "degree": 7, "label": "viio", "position": "root", "weight": 3, "function": "D" }
	]
}

# ------------------------------------------------------------------------------
# TRANSITIONS VALIDES ENTRE FONCTIONS HARMONIQUES
# Utilisées pour scorer les enchaînements
# ------------------------------------------------------------------------------

const VALID_TRANSITIONS = {
	"T": { "T": 2, "PD": 4, "D": 3 },      # Tonique peut aller partout
	"PD": { "T": 1, "PD": 2, "D": 5 },     # Pré-dominante préfère aller vers D
	"D": { "T": 5, "PD": 1, "D": 2 }       # Dominante préfère résoudre sur T
}

# Pénalités pour enchaînements faibles
const WEAK_PROGRESSIONS = {
	"V_to_IV": -3,      # Rétrograde
	"iii_to_I": -1,     # Faible
	"viio_to_IV": -2    # Inhabituel
}

# Bonus pour enchaînements idiomatiques
const STRONG_PROGRESSIONS = {
	"ii_to_V": 3,
	"V_to_I": 4,
	"IV_to_V": 2,
	"vi_to_ii": 2,
	"I_to_IV": 2,
	"I_to_V": 2
}

# ------------------------------------------------------------------------------
# NOTES ALTÉRÉES -> ACCORDS SUGGÉRÉS
# Quand une note est chromatique, elle suggère certains accords
# ------------------------------------------------------------------------------

# Format: alteration_type -> { conditions, suggested_chords }
const CHROMATIC_SUGGESTIONS_MAJOR = {
	# Do# en Do majeur -> V/ii (dominante secondaire de Ré mineur)
	"raised_1": { "suggests": [{ "degree": 5, "secondary_of": 2, "weight": 5 }] },
	# Ré# en Do majeur -> V/iii ou passage
	"raised_2": { "suggests": [{ "degree": 5, "secondary_of": 3, "weight": 4 }] },
	# Fa# en Do majeur -> V/V (dominante de Sol)
	"raised_4": { "suggests": [{ "degree": 5, "secondary_of": 5, "weight": 5 }] },
	# Sol# en Do majeur -> V/vi
	"raised_5": { "suggests": [{ "degree": 5, "secondary_of": 6, "weight": 5 }] },
	# La# en Do majeur -> V/V (7ème de V/V) ou viio/V
	"raised_6": { "suggests": [{ "degree": 7, "secondary_of": 5, "weight": 4 }] },
	# Sib en Do majeur -> IV/IV ou emprunt
	"lowered_7": { "suggests": [{ "degree": 4, "borrowed": true, "weight": 3 }] },
	# Mib en Do majeur -> emprunt mineur
	"lowered_3": { "suggests": [{ "degree": 1, "borrowed": true, "minor": true, "weight": 3 }] },
	# Lab en Do majeur -> emprunt mineur (iv ou bVI)
	"lowered_6": { "suggests": [{ "degree": 6, "borrowed": true, "weight": 4 }] }
}

# ------------------------------------------------------------------------------
# MÉTHODES UTILITAIRES
# ------------------------------------------------------------------------------

static func get_schema(name: String) -> Dictionary:
	match name.to_lower():
		"romanesca":
			return SCHEMA_ROMANESCA
		"prinner":
			return SCHEMA_PRINNER
		"monte":
			return SCHEMA_MONTE
		"fonte":
			return SCHEMA_FONTE
		"folia":
			return SCHEMA_FOLIA
		"pachelbel":
			return SCHEMA_PACHELBEL
		"cadence_parfaite", "perfect_cadence":
			return SCHEMA_CADENCE_PARFAITE
		"cadence_64", "cadential_64":
			return SCHEMA_CADENCE_64
		_:
			return {}

static func get_chords_for_melody_note(scale_degree: int, is_minor: bool = false) -> Array:
	var table = MELODY_TO_CHORDS_MINOR if is_minor else MELODY_TO_CHORDS_MAJOR
	if table.has(scale_degree):
		return table[scale_degree]
	return []

static func get_rule_of_octave(scale_degree: int, is_minor: bool = false, ascending: bool = true) -> Dictionary:
	var table
	if is_minor:
		table = RULE_OF_OCTAVE_MINOR_ASCENDING if ascending else RULE_OF_OCTAVE_MINOR_DESCENDING
	else:
		table = RULE_OF_OCTAVE_MAJOR_ASCENDING if ascending else RULE_OF_OCTAVE_MAJOR_DESCENDING

	if table.has(scale_degree):
		return table[scale_degree]
	return {}

static func get_transition_score(from_function: String, to_function: String) -> int:
	if VALID_TRANSITIONS.has(from_function):
		var trans = VALID_TRANSITIONS[from_function]
		if trans.has(to_function):
			return trans[to_function]
	return 1

static func get_progression_bonus(from_degree: int, to_degree: int, from_label: String, to_label: String) -> int:
	var key = from_label + "_to_" + to_label
	if STRONG_PROGRESSIONS.has(key):
		return STRONG_PROGRESSIONS[key]
	if WEAK_PROGRESSIONS.has(key):
		return WEAK_PROGRESSIONS[key]
	return 0

static func list_schemas() -> Array:
	return ALL_SCHEMAS.duplicate()

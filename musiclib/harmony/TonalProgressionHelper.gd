extends Reference
class_name TonalProgressionHelper

const TAG = "TonalProgressionHelper"

var rng: RandomNumberGenerator = null

#-------------------------------------------------------------------------------
# Graphe MAJEUR : structure proche du JSON donné précédemment
#-------------------------------------------------------------------------------

const GRAPH_MAJOR = {
	"I": {
		"harmonic_function": "T",
		"scale": "major",
		"suggested_inversions": ["5", "6"],
		"next": [
			{ "degree": "I",   "preferred_inversions": ["5", "6"],                       "weight": 2 },
			{ "degree": "IV",  "preferred_inversions": ["5", "6"],                       "weight": 3 },
			{ "degree": "ii",  "preferred_inversions": ["6", "5"],                       "weight": 3 },
			{ "degree": "V",   "preferred_inversions": ["5", "7", "65", "43"],          "weight": 3 },
			{ "degree": "vi",  "preferred_inversions": ["5", "6"],                       "weight": 2 },
			{ "degree": "iii", "preferred_inversions": ["5"],                            "weight": 1 },
			{ "degree": "N6",  "preferred_inversions": ["6"],                            "weight": 1 }
		]
	},

	"ii": {
		"harmonic_function": "PD",
		"scale": "major",
		"suggested_inversions": ["5", "6", "65"],
		"next": [
			{ "degree": "V",    "preferred_inversions": ["5", "7", "65", "43"],         "weight": 4 },
			{ "degree": "viio", "preferred_inversions": ["6", "65"],                    "weight": 2 },
			{ "degree": "IV",   "preferred_inversions": ["5", "6"],                     "weight": 1 },
			{ "degree": "N6",   "preferred_inversions": ["6"],                          "weight": 1 },
			{ "degree": "It+6", "preferred_inversions": [],                             "weight": 1 },
			{ "degree": "Fr+6", "preferred_inversions": [],                             "weight": 1 },
			{ "degree": "Ger+6","preferred_inversions": [],                             "weight": 1 }
		]
	},

	"iii": {
		"harmonic_function": "T",
		"scale": "major",
		"suggested_inversions": ["5"],
		"next": [
			{ "degree": "vi",  "preferred_inversions": ["5", "6"],                      "weight": 3 },
			{ "degree": "IV",  "preferred_inversions": ["5", "6"],                      "weight": 2 },
			{ "degree": "ii",  "preferred_inversions": ["6", "5"],                      "weight": 2 },
			{ "degree": "V",   "preferred_inversions": ["5", "7", "65"],               "weight": 1 }
		]
	},

	"IV": {
		"harmonic_function": "PD",
		"scale": "major",
		"suggested_inversions": ["5", "6"],
		"next": [
			{ "degree": "ii",   "preferred_inversions": ["6", "5"],                     "weight": 2 },
			{ "degree": "V",    "preferred_inversions": ["5", "7", "65", "43"],        "weight": 4 },
			{ "degree": "viio", "preferred_inversions": ["6", "65"],                   "weight": 1 },
			{ "degree": "I",    "preferred_inversions": ["5", "6"],                    "weight": 4 },
			{ "degree": "N6",   "preferred_inversions": ["6"],                         "weight": 2 },
			{ "degree": "It+6", "preferred_inversions": [],                            "weight": 1 },
			{ "degree": "Fr+6", "preferred_inversions": [],                            "weight": 1 },
			{ "degree": "Ger+6","preferred_inversions": [],                            "weight": 1 }
		]
	},

	"V": {
		"harmonic_function": "D",
		"scale": "major",
		"suggested_inversions": ["5", "7", "65", "43"],
		"next": [
			{ "degree": "I",    "preferred_inversions": ["5", "6"],                    "weight": 4 },
			{ "degree": "I64",  "preferred_inversions": ["64"],                        "weight": 1 },
			{ "degree": "vi",   "preferred_inversions": ["5", "6"],                    "weight": 2 },  # cadence rompue
			{ "degree": "iii",  "preferred_inversions": ["5"],                         "weight": 1 },
			{ "degree": "IV",   "preferred_inversions": ["6"],                         "weight": 1 }
		]
	},

	"vi": {
		"harmonic_function": "T",
		"scale": "major",
		"suggested_inversions": ["5", "6"],
		"next": [
			{ "degree": "ii",   "preferred_inversions": ["6", "5"],                    "weight": 2 },
			{ "degree": "IV",   "preferred_inversions": ["5", "6"],                    "weight": 2 },
			{ "degree": "V",    "preferred_inversions": ["5", "7", "65"],             "weight": 3 },
			{ "degree": "N6",   "preferred_inversions": ["6"],                         "weight": 1 },
			{ "degree": "iii",  "preferred_inversions": ["5"],                         "weight": 1 }
		]
	},

	"viio": {
		"harmonic_function": "D",
		"scale": "major",
		"suggested_inversions": ["6", "65", "7"],
		"next": [
			{ "degree": "I",   "preferred_inversions": ["5", "6"],                     "weight": 4 },
			{ "degree": "iii", "preferred_inversions": ["5"],                         "weight": 1 },
			{ "degree": "vi",  "preferred_inversions": ["5", "6"],                    "weight": 1 },
			{ "degree": "V",   "preferred_inversions": ["5", "7"],                    "weight": 1 }
		]
	},

	"I64": {
		"harmonic_function": "T",
		"scale": "major",
		"suggested_inversions": ["64"],
		"next": [
			{ "degree": "V",    "preferred_inversions": ["5", "7", "65", "43"],       "weight": 4 },
			{ "degree": "viio", "preferred_inversions": ["6", "65"],                  "weight": 1 }
		]
	},

	"N6": {
		"harmonic_function": "PD",
		"scale": "major",
		"suggested_inversions": ["6"],
		"next": [
			{ "degree": "V",   "preferred_inversions": ["5", "7", "65", "43"],        "weight": 4 },
			{ "degree": "I64", "preferred_inversions": ["64"],                        "weight": 2 }
		]
	},

	"It+6": {
		"harmonic_function": "PD",
		"scale": "major",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V",   "preferred_inversions": ["5", "7", "65"],              "weight": 4 },
			{ "degree": "I64", "preferred_inversions": ["64"],                        "weight": 1 },
			{ "degree": "It+6inv", "preferred_inversions": [],                         "weight": 1 }
		]
	},

	"Fr+6": {
		"harmonic_function": "PD",
		"scale": "major",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V",   "preferred_inversions": ["7", "65"],                   "weight": 4 },
			{ "degree": "I64", "preferred_inversions": ["64"],                        "weight": 1 },
			{ "degree": "Fr+6inv", "preferred_inversions": [],                         "weight": 1 }
		]
	},

	"Ger+6": {
		"harmonic_function": "PD",
		"scale": "major",
		"suggested_inversions": [],
		"next": [
			{ "degree": "I64", "preferred_inversions": ["64"],                        "weight": 3 },
			{ "degree": "V",   "preferred_inversions": ["5", "7"],                    "weight": 2 },
			{ "degree": "Ger+6inv", "preferred_inversions": [],                        "weight": 1 }
		]
	},

	# Sixtes augmentées "inversées" (#4 à la basse)
	"It+6inv": {
		"harmonic_function": "PD",
		"scale": "major",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V", "preferred_inversions": ["5", "7", "65"],                "weight": 4 }
		]
	},

	"Fr+6inv": {
		"harmonic_function": "PD",
		"scale": "major",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V", "preferred_inversions": ["7", "65"],                     "weight": 4 }
		]
	},

	"Ger+6inv": {
		"harmonic_function": "PD",
		"scale": "major",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V", "preferred_inversions": ["5", "7"],                      "weight": 4 }
		]
	}
}

#-------------------------------------------------------------------------------
# Graphe MINEUR (éolien + mineur harmonique), basé sur le JSON précédent
#-------------------------------------------------------------------------------

const GRAPH_MINOR = {
	"i": {
		"harmonic_function": "T",
		"scale": "minor",
		"suggested_inversions": ["5", "6"],
		"next": [
			{ "degree": "i",   "preferred_inversions": ["5", "6"],                      "weight": 2 },
			{ "degree": "iv",  "preferred_inversions": ["5", "6"],                      "weight": 3 },
			{ "degree": "iio", "preferred_inversions": ["6", "5"],                      "weight": 3 },
			{ "degree": "V",   "preferred_inversions": ["5", "7", "65", "43"],         "weight": 3 },
			{ "degree": "VI",  "preferred_inversions": ["5", "6"],                      "weight": 2 },
			{ "degree": "III", "preferred_inversions": ["5"],                           "weight": 1 },
			{ "degree": "N6",  "preferred_inversions": ["6"],                           "weight": 1 }
		]
	},

	"iio": {
		"harmonic_function": "PD",
		"scale": "minor",
		"suggested_inversions": ["5", "6"],
		"next": [
			{ "degree": "V",    "preferred_inversions": ["5", "7", "65", "43"],        "weight": 4 },
			{ "degree": "viio", "preferred_inversions": ["6", "65"],                   "weight": 2 },
			{ "degree": "iv",   "preferred_inversions": ["5", "6"],                    "weight": 1 },
			{ "degree": "N6",   "preferred_inversions": ["6"],                         "weight": 1 },
			{ "degree": "It+6", "preferred_inversions": [],                            "weight": 1 },
			{ "degree": "Fr+6", "preferred_inversions": [],                            "weight": 1 },
			{ "degree": "Ger+6","preferred_inversions": [],                            "weight": 1 }
		]
	},

	"III": {
		"harmonic_function": "T",
		"scale": "minor",
		"suggested_inversions": ["5"],
		"next": [
			{ "degree": "VI",  "preferred_inversions": ["5", "6"],                     "weight": 3 },
			{ "degree": "iv",  "preferred_inversions": ["5", "6"],                     "weight": 2 },
			{ "degree": "iio", "preferred_inversions": ["6", "5"],                     "weight": 2 },
			{ "degree": "V",   "preferred_inversions": ["5", "7", "65"],              "weight": 1 }
		]
	},

	"iv": {
		"harmonic_function": "PD",
		"scale": "minor",
		"suggested_inversions": ["5", "6"],
		"next": [
			{ "degree": "iio",  "preferred_inversions": ["6", "5"],                   "weight": 2 },
			{ "degree": "V",    "preferred_inversions": ["5", "7", "65", "43"],      "weight": 4 },
			{ "degree": "viio", "preferred_inversions": ["6", "65"],                 "weight": 1 },
			{ "degree": "i",    "preferred_inversions": ["5", "6"],                  "weight": 2 },
			{ "degree": "N6",   "preferred_inversions": ["6"],                       "weight": 2 },
			{ "degree": "It+6", "preferred_inversions": [],                          "weight": 1 },
			{ "degree": "Fr+6", "preferred_inversions": [],                          "weight": 1 },
			{ "degree": "Ger+6","preferred_inversions": [],                          "weight": 1 }
		]
	},

	"V": {
		"harmonic_function": "D",
		"scale": "harmonic_minor",
		"suggested_inversions": ["5", "7", "65", "43"],
		"next": [
			{ "degree": "i",   "preferred_inversions": ["5", "6"],                    "weight": 4 },
			{ "degree": "i64", "preferred_inversions": ["64"],                        "weight": 1 },
			{ "degree": "VI",  "preferred_inversions": ["5", "6"],                    "weight": 2 },  # cadence rompue
			{ "degree": "iv",  "preferred_inversions": ["6"],                         "weight": 1 },
			{ "degree": "III", "preferred_inversions": ["5"],                         "weight": 1 }
		]
	},

	"VI": {
		"harmonic_function": "T",
		"scale": "minor",
		"suggested_inversions": ["5", "6"],
		"next": [
			{ "degree": "iio", "preferred_inversions": ["6", "5"],                    "weight": 2 },
			{ "degree": "iv",  "preferred_inversions": ["5", "6"],                    "weight": 2 },
			{ "degree": "V",   "preferred_inversions": ["5", "7", "65"],             "weight": 3 },
			{ "degree": "N6",  "preferred_inversions": ["6"],                         "weight": 1 },
			{ "degree": "III", "preferred_inversions": ["5"],                         "weight": 1 }
		]
	},

	"VII": {
		"harmonic_function": "T",
		"scale": "minor",
		"suggested_inversions": ["5"],
		"next": [
			{ "degree": "III", "preferred_inversions": ["5"],                         "weight": 3 },
			{ "degree": "i",   "preferred_inversions": ["5", "6"],                    "weight": 2 },
			{ "degree": "VI",  "preferred_inversions": ["5", "6"],                    "weight": 1 },
			{ "degree": "V",   "preferred_inversions": ["5", "7"],                    "weight": 1 }
		]
	},

	"viio": {
		"harmonic_function": "D",
		"scale": "harmonic_minor",
		"suggested_inversions": ["6", "65", "7"],
		"next": [
			{ "degree": "i",   "preferred_inversions": ["5", "6"],                    "weight": 4 },
			{ "degree": "III", "preferred_inversions": ["5"],                         "weight": 1 },
			{ "degree": "VI",  "preferred_inversions": ["5", "6"],                    "weight": 1 },
			{ "degree": "V",   "preferred_inversions": ["5", "7"],                    "weight": 1 }
		]
	},

	"i64": {
		"harmonic_function": "T",
		"scale": "minor",
		"suggested_inversions": ["64"],
		"next": [
			{ "degree": "V",    "preferred_inversions": ["5", "7", "65", "43"],      "weight": 4 },
			{ "degree": "viio", "preferred_inversions": ["6", "65"],                 "weight": 1 }
		]
	},

	"N6": {
		"harmonic_function": "PD",
		"scale": "harmonic_minor",
		"suggested_inversions": ["6"],
		"next": [
			{ "degree": "V",   "preferred_inversions": ["5", "7", "65", "43"],       "weight": 4 },
			{ "degree": "i64", "preferred_inversions": ["64"],                       "weight": 2 }
		]
	},

	"It+6": {
		"harmonic_function": "PD",
		"scale": "harmonic_minor",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V",   "preferred_inversions": ["5", "7", "65"],             "weight": 4 },
			{ "degree": "i64", "preferred_inversions": ["64"],                       "weight": 1 },
			{ "degree": "It+6inv", "preferred_inversions": [],                        "weight": 1 }
		]
	},

	"Fr+6": {
		"harmonic_function": "PD",
		"scale": "harmonic_minor",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V",   "preferred_inversions": ["7", "65"],                  "weight": 4 },
			{ "degree": "i64", "preferred_inversions": ["64"],                       "weight": 1 },
			{ "degree": "Fr+6inv", "preferred_inversions": [],                        "weight": 1 }
		]
	},

	"Ger+6": {
		"harmonic_function": "PD",
		"scale": "harmonic_minor",
		"suggested_inversions": [],
		"next": [
			{ "degree": "i64", "preferred_inversions": ["64"],                       "weight": 3 },
			{ "degree": "V",   "preferred_inversions": ["5", "7"],                   "weight": 2 },
			{ "degree": "Ger+6inv", "preferred_inversions": [],                       "weight": 1 }
		]
	},

	"It+6inv": {
		"harmonic_function": "PD",
		"scale": "harmonic_minor",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V", "preferred_inversions": ["5", "7", "65"],               "weight": 4 }
		]
	},

	"Fr+6inv": {
		"harmonic_function": "PD",
		"scale": "harmonic_minor",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V", "preferred_inversions": ["7", "65"],                    "weight": 4 }
		]
	},

	"Ger+6inv": {
		"harmonic_function": "PD",
		"scale": "harmonic_minor",
		"suggested_inversions": [],
		"next": [
			{ "degree": "V", "preferred_inversions": ["5", "7"],                     "weight": 4 }
		]
	}
}

func _init():
	pass

func _randi(max_val: int) -> int:
	if rng != null:
		return rng.randi() % max_val
	return randi() % max_val

#-------------------------------------------------------------------------------
# API principale
#-------------------------------------------------------------------------------


func get_next_degree(d:Degree, deceptive = false) -> Degree:

	var realization = [1, 3, 5]
	if d.realization.size() > 3:
		realization = [1, 3, 5, 7]

	var state = {
		"degree_number": d.degree_number,
		"scale_name": d.key.scale_name,
		"inversion": d.inversion,
		"realization": realization,
		"kind": d.kind,
		"deceptive": deceptive,
		"root_midi": d.key.root_midi
	}

	var state_retour = get_next_chord(state)


	#LogBus.debug(TAG,JSON.print(state_retour))

	var next_degree:Degree = Degree.new()
	var new_key:HarmonicKey = d.key.clone()
	new_key.scale_name = state_retour["scale_name"]
	next_degree.key = new_key
	next_degree.degree_number = state_retour["degree_number"]
	next_degree.inversion = state_retour["inversion"]
	next_degree.kind = state_retour["kind"]
	next_degree.realization = state_retour["realization"]
	next_degree.length_beats = d.length_beats
	next_degree.set_harmonic_function(state_retour["harmonic_function"])

	return next_degree
	

func get_next_chord(current_state: Dictionary) -> Dictionary:
	var degree_key = _state_to_degree_key(current_state)
	var graph = _select_graph_for_state(current_state)

	if not graph.has(degree_key):
		# fallback : repartir de la tonique si label inconnu
		var scale_name = String(current_state.get("scale_name", "major"))
		if scale_name == "major":
			degree_key = "I"
		else:
			degree_key = "i"

	var node = graph.get(degree_key, {})
	var next_list = node.get("next", [])
	
	# Filtrage en fonction du renversement et du type de l'accord d'entrée (sixte napolitaine / augmentée)
	next_list = _filter_next_for_aug_sixths(next_list, node, current_state)
	# Filtrage éventuel pour forcer une cadence rompue si l'occasion se présente
	next_list = _filter_next_for_deceptive(next_list, node, current_state)
	
	if next_list.empty():
		return current_state
	
	var edge = _pick_weighted_edge(next_list)
	var target_key = String(edge.get("degree", degree_key))
	
	if not graph.has(target_key):
		target_key = degree_key
	
	var target_node = graph.get(target_key, node)
	var new_state = _degree_key_to_state(target_key, target_node, edge, current_state)
	
	# Propager le flag "deceptive" si présent
	if current_state.has("deceptive"):
		new_state["deceptive"] = current_state["deceptive"]
	
	return new_state

func generate_progression(start_state: Dictionary, length: int) -> Array:
	var result = []
	var state = start_state.duplicate()
	var i = 0
	while i < length:
		result.append(state)
		state = get_next_chord(state)
		i += 1
	return result

#-------------------------------------------------------------------------------
# Sélection du graphe
#-------------------------------------------------------------------------------

func _select_graph_for_state(state: Dictionary) -> Dictionary:
	var scale_name = String(state.get("scale_name", "major"))
	if scale_name == "major":
		return GRAPH_MAJOR
	if scale_name == "minor" or scale_name == "harmonic_minor" or scale_name == "melodic_minor":
		return GRAPH_MINOR
	return GRAPH_MAJOR

#-------------------------------------------------------------------------------
# Filtrages contextuels
#-------------------------------------------------------------------------------

func _filter_next_for_aug_sixths(next_list: Array, current_node: Dictionary, current_state: Dictionary) -> Array:
	var result = []
	var current_harmonic_function = String(current_node.get("harmonic_function", "T"))
	var current_inversion = int(current_state.get("inversion", 0))
	
	for edge in next_list:
		var deg = String(edge.get("degree", ""))
		var is_aug_or_nap = deg == "N6" or deg == "It+6" or deg == "Fr+6" or deg == "Ger+6" or deg == "It+6inv" or deg == "Fr+6inv" or deg == "Ger+6inv"
		
		if is_aug_or_nap:
			# Règle simple : ces accords sont pris surtout après une fonction PD
			# et plutôt pas depuis des 2èmes renversements bizarres.
			if current_harmonic_function != "PD" and current_harmonic_function != "T":
				continue
			if current_inversion > 1:
				continue
		
		result.append(edge)
	
	if result.empty():
		return next_list
	
	return result

func _filter_next_for_deceptive(next_list: Array, current_node: Dictionary, current_state: Dictionary) -> Array:
	var deceptive = current_state.get("deceptive", false)
	var current_harmonic_function = String(current_node.get("harmonic_function", ""))

	# Seulement applicable quand on est sur une fonction dominante
	if current_harmonic_function != "D":
		return next_list

	if deceptive:
		# deceptive = true: éviter I/i en position fondamentale (inversion 0)
		# mais permettre I/i en premier renversement (inversion 1)
		var filtered = []
		for edge in next_list:
			var deg = String(edge.get("degree", ""))
			if deg == "I" or deg == "i":
				# Créer une copie avec preferred_inversions filtré (exclure "5")
				var new_preferred = []
				var orig_preferred = edge.get("preferred_inversions", [])
				for inv in orig_preferred:
					if String(inv) != "5":
						new_preferred.append(inv)
				if new_preferred.size() > 0:
					var new_edge = edge.duplicate()
					new_edge["preferred_inversions"] = new_preferred
					filtered.append(new_edge)
				# Si pas d'inversions restantes, on exclut l'edge
			else:
				filtered.append(edge)
		if filtered.empty():
			return next_list
		return filtered
	else:
		# deceptive = false: forcer I/i en position fondamentale si possible
		var tonic_edges = []
		for edge in next_list:
			var deg = String(edge.get("degree", ""))
			if deg == "I" or deg == "i":
				var orig_preferred = edge.get("preferred_inversions", [])
				# Vérifier si "5" est dans les preferred_inversions
				var has_root_pos = false
				for inv in orig_preferred:
					if String(inv) == "5":
						has_root_pos = true
						break
				if has_root_pos:
					# Créer une copie avec seulement "5" comme preferred_inversion
					var new_edge = edge.duplicate()
					new_edge["preferred_inversions"] = ["5"]
					tonic_edges.append(new_edge)
		if tonic_edges.size() > 0:
			return tonic_edges
		return next_list

#-------------------------------------------------------------------------------
# Tirage pondéré
#-------------------------------------------------------------------------------

func _pick_weighted_edge(next_list: Array) -> Dictionary:
	var total_weight = 0
	for edge in next_list:
		total_weight += int(edge.get("weight", 1))
	
	if total_weight <= 0:
		return next_list[0]
	
	var r = _randi(total_weight)
	var acc = 0
	for edge in next_list:
		acc += int(edge.get("weight", 1))
		if r < acc:
			return edge
	
	return next_list[0]

#-------------------------------------------------------------------------------
# Mapping state <-> clé de degré
#-------------------------------------------------------------------------------

func _state_to_degree_key(state: Dictionary) -> String:
	var kind = String(state.get("kind", "diatonic"))
	var degree_number = int(state.get("degree_number", 1))
	var inv = int(state.get("inversion", 0))
	var realization = state.get("realization", [1, 3, 5])
	var scale_name = String(state.get("scale_name", "major"))

	# Types spéciaux d'abord
	if kind == "cad64":
		if scale_name == "major":
			return "I64"
		else:
			return "i64"

	if kind == "N6":
		return "N6"
	if kind == "It+6":
		return "It+6"
	if kind == "Fr+6":
		return "Fr+6"
	if kind == "Ger+6":
		return "Ger+6"
	if kind == "It+6inv":
		return "It+6inv"
	if kind == "Fr+6inv":
		return "Fr+6inv"
	if kind == "Ger+6inv":
		return "Ger+6inv"

	var deg_label = ""

	if scale_name == "major":
		if degree_number == 1:
			deg_label = "I"
		elif degree_number == 2:
			deg_label = "ii"
		elif degree_number == 3:
			deg_label = "iii"
		elif degree_number == 4:
			deg_label = "IV"
		elif degree_number == 5:
			deg_label = "V"
		elif degree_number == 6:
			deg_label = "vi"
		elif degree_number == 7:
			deg_label = "viio"
	else:
		if degree_number == 1:
			deg_label = "i"
		elif degree_number == 2:
			deg_label = "iio"
		elif degree_number == 3:
			deg_label = "III"
		elif degree_number == 4:
			deg_label = "iv"
		elif degree_number == 5:
			deg_label = "V"
		elif degree_number == 6:
			deg_label = "VI"
		elif degree_number == 7:
			deg_label = "VII"

	# La 7e est gérée par le code d'inversion, pas dans la clé de graphe
	# On encode seulement les renversements les plus "typiques" si besoin.
	# Ici, on garde le label de base ("V", "I", etc.).
	return deg_label

func _degree_key_to_state(degree_key: String, node: Dictionary, edge: Dictionary, from_state: Dictionary) -> Dictionary:
	var result_scale_name = ""
	if node.has("scale"):
		result_scale_name = String(node.get("scale"))
	else:
		result_scale_name = String(from_state.get("scale_name", "major"))

	var harmonic_function = String(node.get("harmonic_function", "T"))

	var state = {
		"degree_number": 1,
		"scale_name": result_scale_name,
		"inversion": 0,
		"realization": [1, 3, 5],
		"kind": "diatonic",
		"root_midi": from_state.get("root_midi", 0),
		"harmonic_function": harmonic_function
	}

	# Types spéciaux (N6, +6, cad64)
	if degree_key == "I64" or degree_key == "i64":
		state["kind"] = "cad64"
		state["degree_number"] = 1
		state["inversion"] = 2
		state["realization"] = [1, 3, 5]
		return state

	if degree_key == "N6":
		state["kind"] = "N6"
		state["degree_number"] = 2
		state["inversion"] = 1
		state["realization"] = [1, 3, 5]
		return state

	if degree_key.begins_with("It+6"):
		state["degree_number"] = 4
		state["realization"] = [1, 3, 5]
		if degree_key == "It+6inv":
			state["kind"] = "It+6inv"
			state["inversion"] = 1
		else:
			state["kind"] = "It+6"
			state["inversion"] = 0
		return state

	if degree_key.begins_with("Fr+6"):
		state["degree_number"] = 4
		state["realization"] = [1, 3, 5]
		if degree_key == "Fr+6inv":
			state["kind"] = "Fr+6inv"
			state["inversion"] = 1
		else:
			state["kind"] = "Fr+6"
			state["inversion"] = 0
		return state

	if degree_key.begins_with("Ger+6"):
		state["degree_number"] = 4
		state["realization"] = [1, 3, 5]
		if degree_key == "Ger+6inv":
			state["kind"] = "Ger+6inv"
			state["inversion"] = 1
		else:
			state["kind"] = "Ger+6"
			state["inversion"] = 0
		return state

	# Accord diatonique
	state["kind"] = "diatonic"

	# Choix de l'inversion / 7e à partir des preferred_inversions ou des suggested_inversions
	var inv_code = ""
	var preferred = edge.get("preferred_inversions", [])
	if preferred.size() > 0:
		var idx = _randi(preferred.size())
		inv_code = String(preferred[idx])
	else:
		var sug = node.get("suggested_inversions", [])
		if sug.size() > 0:
			var idx2 = _randi(sug.size())
			inv_code = String(sug[idx2])

	if inv_code == "":
		inv_code = "5"

	var inversion = 0
	var realization = [1, 3, 5]

	if inv_code == "5":
		inversion = 0
		realization = [1, 3, 5]
	elif inv_code == "6":
		inversion = 1
		realization = [1, 3, 5]
	elif inv_code == "64":
		inversion = 2
		realization = [1, 3, 5]
	elif inv_code == "7":
		inversion = 0
		realization = [1, 3, 5, 7]
	elif inv_code == "65":
		inversion = 1
		realization = [1, 3, 5, 7]
	elif inv_code == "43":
		inversion = 2
		realization = [1, 3, 5, 7]
	elif inv_code == "42":
		inversion = 3
		realization = [1, 3, 5, 7]

	state["inversion"] = inversion
	state["realization"] = realization

	# Mapping clé -> degré
	var base = degree_key

	if base == "I":
		state["degree_number"] = 1
	elif base == "ii":
		state["degree_number"] = 2
	elif base == "iii":
		state["degree_number"] = 3
	elif base == "IV":
		state["degree_number"] = 4
	elif base == "V":
		state["degree_number"] = 5
	elif base == "vi":
		state["degree_number"] = 6
	elif base == "viio":
		state["degree_number"] = 7
	elif base == "i":
		state["degree_number"] = 1
	elif base == "iio":
		state["degree_number"] = 2
	elif base == "III":
		state["degree_number"] = 3
	elif base == "iv":
		state["degree_number"] = 4
	elif base == "VI":
		state["degree_number"] = 6
	elif base == "VII":
		state["degree_number"] = 7

	# Le mode reste celui du nœud (permet la modal mixture et l'utilisation explicite de harmonic_minor)
	return state

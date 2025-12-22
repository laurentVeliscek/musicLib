extends Reference
class_name RuleBank

const TAG = "RuleBank"

const DIRECTION_ASC := "asc"
const DIRECTION_DESC := "desc"


const RULE_OF_THE_OCTAVE:Dictionary = {
	"major": {
		DIRECTION_ASC: {
			1: {"figure":[5, 3], "inversion":0},
			2: {"figure":[6, 3], "inversion":1},
			3: {"figure":[6, 4], "inversion":2},
			4: {"figure":[6, 3], "inversion":1},
			5: {"figure":[5, 3], "inversion":0},
			6: {"figure":[6, 3], "inversion":1},
			7: {"figure":[6, 5, 3], "inversion":1}
		},
		DIRECTION_DESC: {
			7: {"figure":[6, 5, 3], "inversion":1},
			6: {"figure":[6, 3], "inversion":1},
			5: {"figure":[5, 3], "inversion":0},
			4: {"figure":[6, 4], "inversion":2},
			3: {"figure":[6, 3], "inversion":1},
			2: {"figure":[6, 5, 3], "inversion":1},
			1: {"figure":[5, 3], "inversion":0}
		}
	},
	"minor": {
		DIRECTION_ASC: {
			1: {"figure":[5, 3], "inversion":0},
			2: {"figure":[6, 3], "inversion":1},
			3: {"figure":[6, 4], "inversion":2, "mode_variant":"minor"},
			4: {"figure":[6, 3], "inversion":1},
			5: {"figure":[5, 3], "inversion":0},
			6: {"figure":[6, 3], "inversion":1, "mode_variant":"harmonic_minor"},
			7: {"figure":[6, 5, 3], "inversion":1, "mode_variant":"harmonic_minor"}
		},
		DIRECTION_DESC: {
			7: {"figure":[6, 5, 3], "inversion":1, "mode_variant":"harmonic_minor"},
			6: {"figure":[6, 3], "inversion":1, "mode_variant":"harmonic_minor"},
			5: {"figure":[5, 3], "inversion":0},
			4: {"figure":[6, 4], "inversion":2},
			3: {"figure":[6, 3], "inversion":1},
			2: {"figure":[6, 5, 3], "inversion":1},
			1: {"figure":[5, 3], "inversion":0}
		}
	}
}


const CADENCES:Dictionary = {
	"perfect": {
		"name":"cadence_parfaite",
		"pattern":[
			{
				"degree":5,
				"figure":[7, 5, 3],
				"inversion":0,
				"tag":PartimentoBassoEvent.Tag.CADENCE
			},
			{
				"degree":1,
				"figure":[8, 5, 3],
				"inversion":0,
				"tag":PartimentoBassoEvent.Tag.CADENCE
			}
		]
	},
	"phrygian_minor": {
		"name":"cadence_phrygienne",
		"mode":"minor",
		"pattern":[
			{
				"degree":4,
				"figure":[6, 3],
				"inversion":1,
				"tag":PartimentoBassoEvent.Tag.CADENCE
			},
			{
				"degree":5,
				"figure":[5, 3],
				"inversion":0,
				"mode_variant":"harmonic_minor",
				"tag":PartimentoBassoEvent.Tag.CADENCE
			}
		]
	}
}


static func normalize_mode(mode:String) -> String:
	if mode == null:
		return "major"
	return mode.to_lower()


static func normalize_direction(direction:String) -> String:
	var dir := direction
	if dir == null or dir == "":
		dir = DIRECTION_ASC
	dir = dir.to_lower()
	if dir != DIRECTION_ASC and dir != DIRECTION_DESC:
		dir = DIRECTION_ASC
	return dir


static func get_rule(mode:String, direction:String, degree:int) -> Dictionary:
	var mode_key:String = normalize_mode(mode)
	var dir_key:String = normalize_direction(direction)
	if not RULE_OF_THE_OCTAVE.has(mode_key):
		return {}
	if not RULE_OF_THE_OCTAVE[mode_key].has(dir_key):
		return {}
	if not RULE_OF_THE_OCTAVE[mode_key][dir_key].has(degree):
		return {}
	return RULE_OF_THE_OCTAVE[mode_key][dir_key][degree].duplicate(true)


static func get_rule_for_basso(basso_event:PartimentoBassoEvent, mode:String = "major", direction:String = DIRECTION_ASC) -> Dictionary:
	if basso_event == null:
		return {}
	return get_rule(mode, direction, basso_event.get_degree())


static func get_cadence(name:String) -> Dictionary:
	if name == null:
		return {}
	if CADENCES.has(name):
		return CADENCES[name].duplicate(true)
	return {}


static func get_perfect_cadence() -> Dictionary:
	return get_cadence("perfect")


static func get_phrygian_cadence() -> Dictionary:
	return get_cadence("phrygian_minor")


static func get_supported_modes() -> Array:
	return RULE_OF_THE_OCTAVE.keys()


static func build_harmonized_event(basso_event:PartimentoBassoEvent, rule_data:Dictionary) -> PartimentoHarmonizedEvent:
	if basso_event == null or rule_data.empty():
		return null
	var evt:PartimentoHarmonizedEvent = PartimentoHarmonizedEvent.new()
	evt.set_basso_event(basso_event)
	if rule_data.has("figure"):
		evt.set_figure(rule_data["figure"])
	if rule_data.has("inversion"):
		evt.set_inversion(rule_data["inversion"])
	if rule_data.has("mode_variant"):
		evt.set_mode_variant(str(rule_data["mode_variant"]))
	if rule_data.has("is_secondary"):
		evt.set_is_secondary(rule_data["is_secondary"])
	if rule_data.has("secondary_target_degree"):
		evt.set_secondary_target_degree(rule_data["secondary_target_degree"])
	if rule_data.has("is_borrowed"):
		evt.set_is_borrowed(rule_data["is_borrowed"])
	return evt

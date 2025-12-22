extends Reference
class_name PartimentoRealizer

const TAG = "PartimentoRealizer"
const DIR_ASC = "asc"
const DIR_DESC = "desc"

const RO_TABLE = {
	DIR_ASC: {
		1: "5-3",
		2: "6",
		3: "6",
		4: "5-3",
		5: "5-3",
		6: "6",
		7: "6",
		8: "5-3"
	},
	DIR_DESC: {
		1: "5-3",
		2: "6-5",
		3: "6",
		4: "6",
		5: "6-5",
		6: "6",
		7: "6"
	}
}


func realize(basso_events: Array, tonic_key) -> Array:
	var harmonized: Array = []
	if basso_events == null:
		return harmonized

	var is_minor: bool = _is_minor(tonic_key)
	var cadence_window: int = 0

	for i in range(basso_events.size()):
		var bass_event = basso_events[i]
		if bass_event == null:
			continue

		var degree = _extract_degree(bass_event)
		if degree == 0:
			continue

		var cadence_tagged = _has_cadence_tag(bass_event)
		if cadence_tagged:
			cadence_window = 2

		var cadence_active = cadence_tagged or cadence_window > 0
		var direction = _extract_direction(basso_events, i)

		var rule = _lookup_rule_of_octave(degree, direction)
		var mode_data = _mode_variant_for_degree(degree, direction, is_minor)

		var figure = rule["figure"]
		var alterations: Dictionary = mode_data["alterations"]
		var mode_variant = mode_data["variant"]

		if cadence_active:
			var cadence_override = _apply_cadence_override(degree, is_minor, figure, alterations, mode_variant)
			figure = cadence_override["figure"]
			alterations = cadence_override["alterations"]
			mode_variant = cadence_override["variant"]

		var event = _build_event(bass_event, degree, figure, mode_variant, alterations, cadence_active, direction, rule["rule"])
		harmonized.append(event)

		var message = "RO " + direction + " deg " + str(degree) + " -> " + figure
		if mode_variant != "":
			message += " | mode=" + mode_variant
		if alterations.size() > 0:
			message += " | alt=" + str(alterations)
		if cadence_active:
			message += " | cadence"
		LogBus.debug(TAG, message)

		if cadence_active and cadence_window > 0:
			cadence_window -= 1

	return harmonized


func _build_event(bass_event, degree: int, figure: String, mode_variant: String, alterations: Dictionary, cadence: bool, direction: String, source_rule: String) -> Dictionary:
	return {
		"__type": "PartimentoHarmonizedEvent",
		"bass_event": bass_event,
		"degree": degree,
		"figure": figure,
		"mode_variant": mode_variant,
		"alterations": alterations,
		"cadence_locked": cadence,
		"direction": direction,
		"source_rule": source_rule
	}


func _lookup_rule_of_octave(degree: int, direction: String) -> Dictionary:
	var dir = DIR_ASC if direction != DIR_DESC else DIR_DESC
	var table = RO_TABLE.get(dir, RO_TABLE[DIR_ASC])
	var normalized = ((degree - 1) % 7) + 1
	var figure = table.get(normalized, "5-3")
	
	if dir == DIR_ASC:
		return {"figure": figure,"rule":"RO_ASC"}
	else:
		return {"figure": figure,"rule":"RO_DESC"}

func _mode_variant_for_degree(degree: int, direction: String, is_minor: bool) -> Dictionary:
	var alterations: Dictionary = {}
	var raised6: bool = false
	var raised7: bool = false

	if is_minor and direction == DIR_ASC:
		if degree == 6:
			alterations[6] = 1
			raised6 = true
		elif degree == 7:
			alterations[7] = 1
			raised7 = true
	elif is_minor:
		if degree == 7:
			alterations[7] = -1

	return {
		"alterations": alterations,
		"variant": _minor_variant_label(is_minor, raised6, raised7)
	}


func _apply_cadence_override(degree: int, is_minor: bool, base_figure: String, base_alterations: Dictionary, base_variant: String) -> Dictionary:
	var alterations: Dictionary = base_alterations.duplicate()
	var raised6: bool = alterations.get(6, 0) > 0
	var raised7: bool = alterations.get(7, 0) > 0
	var figure = base_figure

	if degree == 5:
		figure = "6-5"
		if is_minor and not alterations.has(7):
			alterations[7] = 1
			raised7 = true
	elif degree == 1 or degree == 8:
		figure = "5-3"

	return {
		"figure": figure,
		"alterations": alterations,
		"variant": _minor_variant_label(is_minor, raised6, raised7, base_variant)
	}


func _minor_variant_label(is_minor: bool, raised6: bool, raised7: bool, base_label: String = "") -> String:
	if not is_minor:
		return "major"

	var tokens: Array = []
	if raised6:
		tokens.append("#6")
	if raised7:
		tokens.append("#7")

	if tokens.size() == 0:
		return base_label if base_label != "" else "natural_minor"
	return "minor(" + ",".join(tokens) + ")"


func _extract_degree(bass_event) -> int:
	if bass_event == null:
		return 0

	if typeof(bass_event) == TYPE_DICTIONARY:
		if bass_event.has("degree"):
			return int(bass_event["degree"])
		if bass_event.has("degree_number"):
			return int(bass_event["degree_number"])
		if bass_event.has("bass_degree"):
			return int(bass_event["bass_degree"])
	elif typeof(bass_event) == TYPE_OBJECT and bass_event.has_method("get"):
		var d = bass_event.get("degree", null)
		if d == null:
			d = bass_event.get("degree_number", null)
		if d == null:
			d = bass_event.get("bass_degree", null)
		if d != null:
			return int(d)

	return 0


func _extract_direction(basso_events: Array, idx: int) -> String:
	if idx < basso_events.size() and idx >= 0:
		var ev = basso_events[idx]
		if typeof(ev) == TYPE_DICTIONARY:
			var manual = String(ev.get("direction", "")).to_lower()
			if manual == DIR_DESC:
				return DIR_DESC
			elif manual == DIR_ASC:
				return DIR_ASC
		elif typeof(ev) == TYPE_OBJECT and ev.has_method("get"):
			var manual_dir = String(ev.get("direction", "")).to_lower()
			if manual_dir == DIR_DESC:
				return DIR_DESC
			elif manual_dir == DIR_ASC:
				return DIR_ASC

	if idx > 0:
		var prev_degree = _extract_degree(basso_events[idx - 1])
		var curr_degree = _extract_degree(basso_events[idx])
		if curr_degree < prev_degree:
			return DIR_DESC
		elif curr_degree > prev_degree:
			return DIR_ASC

	return DIR_ASC


func _has_cadence_tag(bass_event) -> bool:
	if bass_event == null:
		return false

	if typeof(bass_event) == TYPE_DICTIONARY:
		if bass_event.has("cadence"):
			return bool(bass_event["cadence"])
		if bass_event.has("tags"):
			var tags = bass_event["tags"]
			if typeof(tags) == TYPE_ARRAY:
				return tags.has("cadence") or tags.has("cadence_finale")
	elif typeof(bass_event) == TYPE_OBJECT and bass_event.has_method("get"):
		var cadence_flag = bass_event.get("cadence", null)
		if cadence_flag != null and bool(cadence_flag):
			return true
		var tag_array = bass_event.get("tags", null)
		if tag_array != null and typeof(tag_array) == TYPE_ARRAY:
			return tag_array.has("cadence") or tag_array.has("cadence_finale")

	return false


func _is_minor(tonic_key) -> bool:
	if tonic_key == null:
		return false

	if typeof(tonic_key) == TYPE_DICTIONARY:
		return String(tonic_key.get("scale_name", "")).to_lower().find("minor") != -1
	elif typeof(tonic_key) == TYPE_OBJECT and tonic_key.has_method("get"):
		return String(tonic_key.get("scale_name", "")).to_lower().find("minor") != -1

	return false

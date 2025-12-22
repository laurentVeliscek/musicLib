extends Reference
class_name PartimentoConverter

const TAG = "PartimentoConverter"

func partimento_event_to_degree(event_data, tonic_key:HarmonicKey) -> Degree:
	var normalized = _normalize_event(event_data)
	var key_clone = _clone_key(tonic_key)
	key_clone.scale_name = _resolve_scale(normalized, key_clone.scale_name)
	var degree = Degree.new()
	degree.set_key(key_clone)
	degree.set_degree_number(int(normalized["degree_number"]))
	degree.set_kind(str(normalized["kind"]))
	degree._is_secondary = bool(normalized["is_secondary"])

	_apply_alterations(normalized["alterations"], degree)

	var payload = _build_payload(normalized, key_clone)
	degree.set_partimento_json(JSON.print(payload))

	var log_msg = "Partimento→Degree | mode=" + key_clone.scale_name
	log_msg += ", degree=" + str(degree.degree_number)
	log_msg += ", alterations=" + str(normalized["alterations"])
	log_msg += ", secondary=" + str(degree._is_secondary)
	var borrowed = str(normalized.get("borrowed_mode", ""))
	if borrowed != "":
		log_msg += ", borrowed=" + borrowed
	var nuance = str(normalized.get("nuance", ""))
	if nuance != "":
		log_msg += ", nuance=" + nuance
	LogBus.debug(TAG, log_msg)

	return degree


func degree_to_partimento_event(degree:Degree) -> Dictionary:
	var payload = _extract_payload_from_degree(degree)
	payload["degree_number"] = degree.degree_number
	payload["scale_name"] = degree.key.scale_name
	payload["alterations"] = _normalize_alterations(degree._get_alterations())
	payload["kind"] = degree.kind
	payload["is_secondary"] = degree._is_secondary

	degree.set_partimento_json(JSON.print(payload))

	var log_msg = "Degree→Partimento | mode=" + str(payload["scale_name"])
	log_msg += ", degree=" + str(payload["degree_number"])
	log_msg += ", alterations=" + str(payload["alterations"])
	log_msg += ", secondary=" + str(payload["is_secondary"])
	if str(payload.get("borrowed_mode", "")) != "":
		log_msg += ", borrowed=" + str(payload.get("borrowed_mode", ""))
	LogBus.debug(TAG, log_msg)

	return payload


func _clone_key(source:HarmonicKey) -> HarmonicKey:
	var clone = HarmonicKey.new()
	clone.root_midi = source.root_midi
	clone.scale_name = source.scale_name
	return clone


func _normalize_event(event_data) -> Dictionary:
	var normalized:Dictionary = {
		"degree_number": 1,
		"quality": "",
		"nuance": "",
		"alterations": {},
		"is_secondary": false,
		"borrowed_mode": "",
		"kind": "diatonic",
		"secondary_target": "",
		"scale_name": "",
		"degree_text": ""
	}

	if typeof(event_data) == TYPE_DICTIONARY:
		for key in event_data.keys():
			if normalized.has(key):
				normalized[key] = event_data[key]
		if event_data.has("degree"):
			normalized["degree_number"] = event_data["degree"]
		if event_data.has("roman"):
			normalized["degree_text"] = str(event_data["roman"])
	elif typeof(event_data) == TYPE_OBJECT and event_data.has_method("to_dict"):
		return _normalize_event(event_data.to_dict())

	normalized["alterations"] = _normalize_alterations(normalized["alterations"])
	normalized["degree_number"] = int(normalized["degree_number"])
	normalized["is_secondary"] = bool(normalized["is_secondary"])
	normalized["kind"] = str(normalized["kind"])
	normalized["quality"] = str(normalized["quality"])
	normalized["nuance"] = str(normalized["nuance"])
	normalized["borrowed_mode"] = str(normalized["borrowed_mode"])
	normalized["secondary_target"] = str(normalized["secondary_target"])
	normalized["scale_name"] = str(normalized["scale_name"])
	normalized["degree_text"] = str(normalized["degree_text"])
	return normalized


func _normalize_alterations(alterations) -> Dictionary:
	var normalized:Dictionary = {}
	if typeof(alterations) == TYPE_DICTIONARY:
		for k in alterations.keys():
			normalized[int(k)] = int(alterations[k])
	return normalized


func _build_payload(event_dict:Dictionary, key:HarmonicKey) -> Dictionary:
	var payload:Dictionary = event_dict.duplicate(true)
	payload["root_midi"] = key.root_midi
	payload["scale_name"] = key.scale_name
	return payload


func _resolve_scale(event_dict:Dictionary, tonic_scale:String) -> String:
	if event_dict.get("scale_name", "") != "":
		return str(event_dict["scale_name"])

	if tonic_scale != "minor" and tonic_scale != "harmonic_minor":
		return tonic_scale

	var target_scale = "harmonic_minor"
	var degree_number = int(event_dict.get("degree_number", 1))
	var nuance = str(event_dict.get("nuance", "")).to_lower()
	var augmented_third = _is_augmented_third(event_dict)

	if degree_number == 3 and not augmented_third:
		target_scale = "minor"
	elif (degree_number == 5 or degree_number == 7) and (nuance == "naturelle" or nuance == "naturel"):
		target_scale = "minor"

	return target_scale


func _is_augmented_third(event_dict:Dictionary) -> bool:
	var quality = str(event_dict.get("quality", "")).to_lower()
	if quality.find("aug") != -1:
		return true
	var degree_text = str(event_dict.get("degree_text", ""))
	return degree_text.find("+") != -1


func _apply_alterations(alterations:Dictionary, degree:Degree) -> void:
	for k in alterations.keys():
		degree.set_key_alteration(int(k), int(alterations[k]))


func _extract_payload_from_degree(degree:Degree) -> Dictionary:
	if degree.partimento_json != "":
		var parsed = JSON.parse(degree.partimento_json)
		if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
			return parsed.result

	return {
		"degree_number": degree.degree_number,
		"quality": degree.kind,
		"nuance": "",
		"alterations": _normalize_alterations(degree._get_alterations()),
		"is_secondary": degree._is_secondary,
		"borrowed_mode": "",
		"kind": degree.kind,
		"secondary_target": "",
		"scale_name": degree.key.scale_name,
		"degree_text": degree.get_roman_numeral()
	}

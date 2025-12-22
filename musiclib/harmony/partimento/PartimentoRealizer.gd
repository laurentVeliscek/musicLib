extends Reference
class_name PartimentoRealizer

const TAG = "PartimentoRealizer"


func realize(path: Dictionary, tonic_key: HarmonicKey) -> Dictionary:
	var realization: Dictionary = {"events": []}

	if path.empty():
		return realization

	var events = path.get("events", [])
	if typeof(events) != TYPE_ARRAY:
		return realization

	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue

		var item = {
			"start": float(ev.get("start", 0.0)),
			"length_beats": float(ev.get("length_beats", 1.0)),
			"degree_number": int(ev.get("degree_number", 1)),
			"alteration": int(ev.get("alteration", 0)),
			"midi": ev.get("midi", null)
		}
		realization["events"].append(item)

	if tonic_key != null and tonic_key.has_method("to_dict"):
		realization["tonic_key"] = tonic_key.to_dict()
	else:
		realization["tonic_key"] = {}

	return realization

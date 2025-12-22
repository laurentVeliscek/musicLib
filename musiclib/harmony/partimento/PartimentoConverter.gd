extends Reference
class_name PartimentoConverter

const TAG = "PartimentoConverter"


func to_degree_track(realization: Dictionary, tonic_key: HarmonicKey) -> Track:
	var track = Track.new()
	track.name = "Partimento Degrees"

	var events = realization.get("events", [])
	if typeof(events) != TYPE_ARRAY:
		track.partimento_json = realization
		return track

	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue

		var d = Degree.new()
		d.key = tonic_key
		d.degree_number = int(ev.get("degree_number", 1))
		d.length_beats = float(ev.get("length_beats", 1.0))

		var alteration = int(ev.get("alteration", 0))
		if alteration != 0:
			d._set_alterations({d.degree_number: alteration})

		track.add_degree(float(ev.get("start", 0.0)), d)

	track.partimento_json = realization
	return track

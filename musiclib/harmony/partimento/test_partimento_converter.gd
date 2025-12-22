extends Reference

const TAG = "TestPartimentoConverter"

func run() -> void:
	var converter = PartimentoConverter.new()
	var tonic = HarmonicKey.new()
	tonic.root_midi = 57
	tonic.scale_name = "minor"

	var mock_event = {
		"degree_number": 5,
		"nuance": "naturelle",
		"alterations": {2: -1},
		"is_secondary": true,
		"borrowed_mode": "relative_major",
		"kind": "diatonic",
		"degree_text": "V"
	}

	var degree = converter.partimento_event_to_degree(mock_event, tonic)
	assert(degree.key.scale_name == "minor")
	assert(degree._get_alterations().get(2) == -1)
	assert(degree._is_secondary == true)
	assert(degree.partimento_json != "")

	var parsed = JSON.parse(degree.partimento_json)
	assert(parsed.error == OK)

	var round_trip_event = converter.degree_to_partimento_event(degree)
	assert(round_trip_event.get("degree_number") == mock_event["degree_number"])
	assert(str(round_trip_event.get("scale_name")) == "minor")
	assert(round_trip_event.get("alterations", {}).get(2) == -1)
	assert(round_trip_event.get("is_secondary", false) == true)
	assert(str(round_trip_event.get("borrowed_mode", "")) == "relative_major")

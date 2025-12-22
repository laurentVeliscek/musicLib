extends Reference


func _init():
	_run_pipeline_example()


func _run_pipeline_example():
	var key = HarmonicKey.new()
	key.root_midi = 60
	key.scale_name = "major"

	var track = Track.new()
	var notes = [
		{"start": 0.0, "midi": 48},
		{"start": 1.0, "midi": 50},
		{"start": 2.0, "midi": 52},
		{"start": 3.0, "midi": 54}, # F# (altération ascendante sur le degré IV)
		{"start": 4.0, "midi": 55}
	]

	for n in notes:
		var note = Note.new()
		note.midi = n["midi"]
		note.length_beats = 1.0
		track.add_note(n["start"], note)

	var pipeline = PartimentoPipeline.new()
	var degree_track = pipeline.build(track, key)

	assert(degree_track != null)
	assert(degree_track.events.size() == notes.size())
	assert(degree_track.partimento_json != null)

	var expected_degrees = [1, 2, 3, 4, 5]
	for i in range(expected_degrees.size()):
		var ev = degree_track.events[i]
		assert(ev.has("degree"))
		var d: Degree = ev["degree"]
		assert(d.degree_number == expected_degrees[i])
		assert(d.key.root_midi == key.root_midi)

	var alteration_event = degree_track.events[3]["degree"]
	assert(alteration_event._get_alterations().get(4, 0) == 1)

	var pj = degree_track.partimento_json
	assert(pj.has("events"))
	assert(pj["events"].size() == notes.size())

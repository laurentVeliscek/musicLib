extends Reference
class_name PartimentoPipeline

const TAG = "PartimentoPipeline"

var analyzer: MidiDegreeAnalyzer
var realizer: PartimentoRealizer
var converter: PartimentoConverter


func _init():
	analyzer = MidiDegreeAnalyzer.new()
	realizer = PartimentoRealizer.new()
	converter = PartimentoConverter.new()


func build(track_notes: Track, tonic_key: HarmonicKey) -> Track:
	var candidates = analyzer.analyze(track_notes, tonic_key)
	var selected = _select_candidate(candidates)
	var realization = realizer.realize(selected, tonic_key)
	var degree_track = converter.to_degree_track(realization, tonic_key)
	degree_track.partimento_json = realization
	return degree_track


func _select_candidate(candidates: Array) -> Dictionary:
	if candidates.size() == 0:
		return {}

	var best = candidates[0]
	var best_score = _score_path(best)

	for candidate in candidates:
		var score = _score_path(candidate)
		if score < best_score:
			best = candidate
			best_score = score

	return best


func _score_path(path: Dictionary) -> int:
	if not path.has("events"):
		return 0

	var score = 0
	var evs = path["events"]
	if typeof(evs) != TYPE_ARRAY:
		return score

	for ev in evs:
		if typeof(ev) != TYPE_DICTIONARY:
			continue

		score += abs(int(ev.get("alteration", 0)))

	return score

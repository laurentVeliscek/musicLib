extends Reference
class_name PartimentoMidiDegreeAnalyzer

const TAG = "PartimentoMidiDegreeAnalyzer"
const BaseAnalyzer = preload("res://musiclib/harmony/MidiDegreeAnalyzer.gd")

# Adaptateur pour utiliser l'analyse générique sans entrer en collision
# avec la classe globale MidiDegreeAnalyzer (harmony/).
# On se contente d'appeler le module générique et de renvoyer la structure
# de candidats ; l'appelant partimento peut enrichir/filtrer ensuite.

func analyze(track, tonic_key) -> Dictionary:
	if track == null or tonic_key == null:
		return {"contexts": []}
	
	var notes := []
	if track.has("events"):
		for ev in track.events:
			if typeof(ev) != TYPE_DICTIONARY or not ev.has("note"):
				continue
			var note = ev["note"]
			if note == null or not note.has("midi"):
				continue
			notes.append({
				"start": float(ev.get("start", 0.0)),
				"length_beats": float(note.get("length_beats", ev.get("length_beats", 0.0))),
				"midi": int(note.midi)
			})
	# Fallback : si track est déjà un Array de notes
	elif typeof(track) == TYPE_ARRAY:
		for item in track:
			if typeof(item) == TYPE_DICTIONARY and item.has("midi"):
				notes.append(item)
	
	var analyzer: MidiDegreeAnalyzer = BaseAnalyzer.new()
	var result := analyzer.analyze(notes, tonic_key)
	return result

extends Node

# Dans ton script de génération d'accords
onready var satb_client = $satb_client # ou chemin vers ton node

# Méthode 1: Avec des notes directement
var progression = [
	{"notes": ["C", "E", "G"], "duration": 1.0},
	{"notes": ["C", "F", "A"], "duration": 1.0}
]
func _ready():
	satb_client.connect("satb_solved", self, "_on_satb_received")
	satb_client.solve_progression(progression)

	# Méthode 2: Avec des noms d'accords
	satb_client.solve_from_chord_names(["Cmaj", "Emin", "G7"])

	# Écouter le résultat


func _on_satb_received(result):
	print("Soprano: ", result.soprano)
	print("Alto: ", result.alto)
	print("Tenor: ", result.tenor)
	print("Bass: ", result.bass)

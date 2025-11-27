extends Node

const TAG="SATB_Client"

# Configuration de l'API
#var api_url = "http://localhost:8000"
var api_url = "https://theparselmouth.com/satb-api"

# Node HTTPRequest (à ajouter comme enfant dans la scène)
onready var http_request = $"../HTTPRequest"


# Stockage du contexte de la dernière requête
var last_request_context = {}

# File d'attente pour gérer plusieurs requêtes
var request_queue = []
var is_processing = false

func _ready():
	# Connecter le signal de réponse HTTP
	http_request.connect("request_completed", self, "_on_request_completed")

# ========================================
# INTERFACE GÉNÉRIQUE UNIVERSELLE
# ========================================

func call_api(endpoint: String, request_data, context: Dictionary = {}):
	"""
	Interface universelle pour appeler n'importe quel endpoint de l'API
	Accepte Dictionary OU Array selon l'endpoint
	
	Args:
		endpoint: Le chemin de l'endpoint (ex: "/solve-chord", "/solve-progression")
		request_data: Dictionary OU Array à envoyer
		context: Données contextuelles optionnelles
	
	Exemples:
		# Un seul accord (Dictionary)
		call_api("/solve-chord", {"index": 0, "degree_number": 1, ...})
		
		# Progression (Array)
		call_api("/solve-progression", [chord1, chord2, chord3])
	"""
	# Ajouter la requête à la file d'attente
	request_queue.append({
		"endpoint": endpoint,
		"request_data": request_data,
		"context": context
	})
	
	# Traiter la file si pas déjà en cours
	if not is_processing:
		_process_next_request()

func _process_next_request():
	"""Traite la prochaine requête dans la file d'attente"""
	if request_queue.empty():
		is_processing = false
		return
	
	is_processing = true
	var req = request_queue.pop_front()
	
	# Stocker le contexte pour le callback
	last_request_context = req.context
	
	var headers = ["Content-Type: application/json"]
	
	# Déterminer la méthode HTTP
	var method = HTTPClient.METHOD_GET
	var json_body = ""
	
	if req.request_data != null:
		method = HTTPClient.METHOD_POST
		json_body = JSON.print(req.request_data)
	
	var error = http_request.request(
		api_url + req.endpoint,
		headers,
		true,
		method,
		json_body
	)
	
	if error != OK:
		print("Erreur lors de l'envoi de la requête: ", error)
		emit_signal("api_error", error, req.context)
		# Continuer avec la prochaine requête
		_process_next_request()

func _on_request_completed(result, response_code, headers, body):
	"""Callback universel appelé pour toute requête HTTP"""
	
	var context = last_request_context
	
	if response_code != 200:
		print("Erreur HTTP: ", response_code)
		print("Body: ", body.get_string_from_utf8())
		emit_signal("api_error", response_code, context)
		_process_next_request()
		return
	
	# Parser le JSON
	var json = JSON.parse(body.get_string_from_utf8())
	
	if json.error != OK:
		print("Erreur de parsing JSON: ", json.error_string)
		emit_signal("api_error", json.error, context)
		_process_next_request()
		return
	
	var response = json.result
	
	# Émettre un signal générique avec la réponse et le contexte
	emit_signal("api_response", response, context)
	
	# Affichage debug (optionnel, peut être désactivé)
	if OS.is_debug_build():
		print("=== API Response ===")
		if response.has("method"):
			print("Method: ", response.method)
		elif response.has("satb_arrays"):
			print("Progression de ", response.satb_arrays.size(), " accords")
			print("Processing time: ", response.processing_time, "s")
		print("Context: ", context)
	
	# Traiter la prochaine requête dans la file
	_process_next_request()

# ========================================
# SIGNAUX
# ========================================

# Signal émis quand une réponse API est reçue avec succès
signal api_response(response, context)

# Signal émis en cas d'erreur
signal api_error(error_code, context)

# ========================================
# HELPERS OPTIONNELS
# ========================================

func solve_chord(chord_data: Dictionary, context: Dictionary = {}):
	"""Helper pour résoudre un seul accord"""
	call_api("/solve-chord", chord_data, context)

func solve_progression(chords: Array, context: Dictionary = {}):
	"""Helper pour résoudre une progression d'accords"""
	call_api("/solve-progression", chords, context)

func test_connection():
	"""Teste la connexion à l'API avec une requête GET"""
	# Ajouter la requête à la file d'attente
	request_queue.append({
		"endpoint": "/",
		"request_data": null,  # null = requête GET
		"context": {"test": true}
	})
	
	if not is_processing:
		_process_next_request()

# ========================================
# UTILITAIRES
# ========================================

func midi_to_note(midi: int) -> String:
	"""Convertit un numéro MIDI en nom de note"""
	var notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var octave = int(midi / 12) - 1
	var note = notes[midi % 12]
	return note + str(octave)


# ========================================
# EXEMPLE D'UTILISATION
# ========================================


extends Node
#class_name MusicLabGlobals

const AUTOSAVE_SONG_PATH = "user://autosave.json"

# -------------------------------------------------------------------
#	GLOBAL STATE SINGLETON POUR MUSICLIB
# -------------------------------------------------------------------

# Objet Song courant (peut être assigné dynamiquement)
var current_song = Song.new()
var rng = RandomNumberGenerator.new()
# Paramètres utilisateur (persistants si possible)
var user_settings = {}

# Mode debug global
var debug_mode = false

var TAG = "MusicLabGlobals"
var GuitarBase = GuitarChordDatabase.new()
var modulationDatabase 


var midi_player
# -------------------------------------------------------------------
#	INITIALISATION
# -------------------------------------------------------------------

func _ready():
	LogBus.info(TAG,"[MusicLabGlobals] Initialisé")
	_load_globals()
	GuitarBase.load_from_json("res://addons/musiclib/guitar/guitar.json")
	modulationDatabase = ModulationDatabase.new()
	modulationDatabase.load_database()
	
	current_song = load_autosaved_song()
	rng.randomize()
#	print("current_song -> " + str(current_song))
#
#	if current_song == null :
#		current_song = Song.new()
#		current_song.title =  "Empty song"
#		var progression_track : Track = Track.new()
#		progression_track.name =  Song.PROGRESSION_TRACK_NAME
#		var degres = [1,4,2,5]
#		for i in range(0,degres.size()):
#			var d:Degree = Degree.new()
#			d.degree_number = degres[i]
#			d.length_beats = 2
#			progression_track.add_degree(i*2,d)
#			current_song.add_track(progression_track)
		



# -------------------------------------------------------------------
#	SONG MANAGEMENT
# -------------------------------------------------------------------

func setup_midi_player():
	musiclibMidiPlayer.setupMidiPlayer()
	midi_player = musiclibMidiPlayer.midiPlayer

func set_song(song):
	if song == null:
		pass
		#LogBus.info(TAG,"[MusicLabGlobals] set_song(null) !")
	else:
		pass
		#LogBus.info(TAG,"[MusicLabGlobals] set_song() -> " + str(song))
	current_song = song


func get_song():
	return current_song


func clear_song():
	#LogBus.info(TAG,"[MusicLabGlobals] clear_song()")
	current_song = null

# -------------------------------------------------------------------
#	SONG PERSISTENCE (JSON dans user://)
# -------------------------------------------------------------------

func save_current_song_autosave() -> bool:
	# Sauvegarde la Song courante dans AUTOSAVE_SONG_PATH
	return save_current_song_to_file(AUTOSAVE_SONG_PATH)


func load_autosaved_song() -> Song:
	# Charge la Song depuis AUTOSAVE_SONG_PATH (si le fichier existe)
	return load_song_from_file(AUTOSAVE_SONG_PATH)

func save_current_song_to_file(path:String, compressed:bool = false) -> bool:
	if current_song == null or not (current_song is Song):
		LogBus.error(TAG, "save_current_song_to_file(): no current_song to save")
		return false
	
	var data:Dictionary = current_song.to_dict()
	var f := File.new()
	var err = OK
	
	if compressed:
		err = f.open_compressed(path, File.WRITE, File.COMPRESSION_DEFLATE)
	else:
		err = f.open(path, File.WRITE)
	
	if err != OK:
		LogBus.error(TAG, "save_current_song_to_file(): can't open " + path + " (err " + str(err) + ")")
		return false
	
	if compressed:
		# On stocke directement le Dictionary (var) compressé
		f.store_var(data, true)
	else:
		# Ancien format lisible en JSON
		var json:String = JSON.print(data, "\t")
		f.store_string(json)
	
	f.close()
	#LogBus.info(TAG, "Song saved to " + path + " (compressed=" + str(compressed) + ")")
	return true
	
	
	
	
func load_song_from_file(path:String, compressed_hint:bool = true) -> Song:
	var f := File.new()
	var data = null
	var err = OK
	
	# --- 1) On essaie d'abord le format compressé ---
	if compressed_hint:
		err = f.open_compressed(path, File.READ, File.COMPRESSION_DEFLATE)
		if err == OK:
			data = f.get_var(true)
			f.close()
			if typeof(data) != TYPE_DICTIONARY:
				LogBus.error(TAG, "load_song_from_file(): compressed data is not a Dictionary")
				return null
			LogBus.info(TAG, "load_song_from_file(): loaded compressed Song from " + path)
	
	# --- 2) Fallback JSON texte (ancien format) ---
	if data == null:
		if not f.file_exists(path):
			LogBus.error(TAG, "load_song_from_file(): file does not exist: " + path)
			return null
		
		err = f.open(path, File.READ)
		if err != OK:
			LogBus.error(TAG, "load_song_from_file(): can't open " + path + " (err " + str(err) + ")")
			return null
		
		var text:String = f.get_as_text()
		f.close()
		
		var parsed = parse_json(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			LogBus.error(TAG, "load_song_from_file(): parsed JSON is not a Dictionary")
			return null
		
		data = parsed
		LogBus.info(TAG, "loaded JSON Song (uncompressed) from " + path)
	
	# --- Reconstruction de la Song ---
	var dummy:Song = Song.new()
	var song:Song = dummy.from_dict(data)
	set_song(song)
	
	LogBus.info(TAG, "load_song_from_file(): Song restored from " + path)
	return song


func load_song_from_browser_picker() -> void:
		# Ouvre une boîte de dialogue du navigateur (HTML5) pour charger une Song JSON
		if not (OS.has_feature("HTML5") and Engine.has_singleton("JavaScript")):
				LogBus.error(TAG, "load_song_from_browser_picker(): HTML5 + JavaScript required")
				return

		var js_win = JavaScript.get_interface("window")
		if js_win == null:
				LogBus.error(TAG, "load_song_from_browser_picker(): JavaScript window interface unavailable")
				return

		# Callback appelé par le JavaScript du navigateur une fois le fichier lu
		js_win.musiclib_on_song_loaded = JavaScript.create_callback(self, "_on_browser_song_loaded")

		var js_code := ""
		js_code += "(function(){"
		js_code += "  var input=document.createElement('input');"
		js_code += "  input.type='file';"
		js_code += "  input.accept='.json,application/json';"
		js_code += "  input.style.display='none';"
		js_code += "  document.body.appendChild(input);"
		js_code += "  input.addEventListener('change', function(event){"
		js_code += "    var file=input.files && input.files[0];"
		js_code += "    if(!file){ window.musiclib_on_song_loaded(null); document.body.removeChild(input); return; }"
		js_code += "    var reader=new FileReader();"
		js_code += "    reader.onload=function(e){ window.musiclib_on_song_loaded(e.target.result); document.body.removeChild(input); };"
		js_code += "    reader.onerror=function(){ window.musiclib_on_song_loaded(null); document.body.removeChild(input); };"
		js_code += "    reader.readAsText(file);"
		js_code += "  });"
		js_code += "  input.click();"
		js_code += "})();"

		JavaScript.eval(js_code, true)
		LogBus.info(TAG, "load_song_from_browser_picker(): waiting for user file selection")


func _on_browser_song_loaded(result) -> void:
		# Callback interne : 'result' est le contenu du fichier JSON ou null
		if result == null:
				LogBus.error(TAG, "_on_browser_song_loaded(): no data received from browser")
				return

		if typeof(result) != TYPE_STRING:
				LogBus.error(TAG, "_on_browser_song_loaded(): unexpected data type " + str(typeof(result)))
				return

		var parsed = parse_json(result)
		if typeof(parsed) != TYPE_DICTIONARY:
				LogBus.error(TAG, "_on_browser_song_loaded(): parsed JSON is not a Dictionary")
				return

		var dummy:Song = Song.new()
		var song:Song = dummy.from_dict(parsed)
		set_song(song)

		LogBus.info(TAG, "_on_browser_song_loaded(): Song loaded from browser picker -> " + song.title)



func download_current_song_as_json(filename:String = "song.json") -> void:
	if current_song == null or not (current_song is Song):
		LogBus.error(TAG, "download_current_song_as_json(): no current_song")
		return
	
	var data:Dictionary = current_song.to_dict()
	var json:String = JSON.print(data, "\t")
	
	# HTML5 + JavaScript disponible ?
	if OS.has_feature("HTML5") and Engine.has_singleton("JavaScript"):
		var b64:String = Marshalls.utf8_to_base64(json)
		var url:String = "data:application/json;base64," + b64
		
		var js_code:String = ""
		js_code += "var a=document.createElement('a');"
		js_code += "a.href='" + url + "';"
		js_code += "a.download='" + filename + "';"
		js_code += "document.body.appendChild(a);"
		js_code += "a.click();"
		js_code += "document.body.removeChild(a);"
		
		JavaScript.eval(js_code, true)
		LogBus.info(TAG, "download_current_song_as_json(): HTML5 download triggered (" + filename + ")")
	
	else:
		# Pas en HTML5 → on se rabat sur un simple save dans user://
		var path:String = "user://" + filename
		var ok:bool = save_current_song_to_file(path, false)
		if ok:
			LogBus.info(TAG, "download_current_song_as_json(): not HTML5, saved to " + path + " instead")
		else:
			LogBus.error(TAG, "download_current_song_as_json(): fallback save failed")


func import_song_from_json_file(path:String) -> Song:
	# Lit un fichier JSON exporté (song.json) et reconstruit la Song
	var f := File.new()
	
	if not f.file_exists(path):
		LogBus.error(TAG, "import_song_from_json_file(): file does not exist: " + path)
		return null
	
	var err = f.open(path, File.READ)
	if err != OK:
		LogBus.error(TAG, "import_song_from_json_file(): can't open " + path + " (err " + str(err) + ")")
		return null
	
	var text:String = f.get_as_text()
	f.close()
	
	var parsed = parse_json(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		LogBus.error(TAG, "import_song_from_json_file(): parsed JSON is not a Dictionary")
		return null
	
	var dummy:Song = Song.new()
	var song:Song = dummy.from_dict(parsed)
	set_song(song)
	LogBus.clear_console()
	LogBus.info(TAG, song.title + " imported !")
	return song
# -------------------------------------------------------------------
#	DEBUG / INFO
# -------------------------------------------------------------------

func print_globals():
	LogBus.info(TAG,"---- MusicLabGlobals ----")
	LogBus.info(TAG,"debug_mode:" + str(debug_mode))
	LogBus.info(TAG,"user_settings: " + str(user_settings))
	if current_song != null and current_song is Song:
		LogBus.info(TAG,"current_song: " +  current_song.to_string())
	else:
		LogBus.info(TAG,"current_song: <none>")
	LogBus.info(TAG,"-------------------------")


# -------------------------------------------------------------------
#	USER SETTINGS (HTML5-SAFE)
# -------------------------------------------------------------------

func set_user_setting(key, value):
	if not user_settings.has(key):
		# print_verbose("[MusicLabGlobals] new setting '%s'" % key)
		LogBus.info(TAG, str(key) + " --> " + str(value))
	user_settings[key] = value
	_save_globals()


func get_user_setting(key, default_value = null):
	if user_settings.has(key):
		return user_settings[key]
	else:
		return default_value


func clear_user_settings():
	# print_verbose("[MusicLabGlobals] clear_user_settings()")
	LogBus.info(TAG, "MusicLabGlobals settings cleared")
	user_settings = {}
	_save_globals()


# -------------------------------------------------------------------
#	PERSISTENCE HTML5 (localStorage)
# -------------------------------------------------------------------

func _save_globals():
	if OS.has_feature("HTML5") and Engine.has_singleton("JavaScript"):
		var js = Engine.get_singleton("JavaScript")
		var json_data = to_json(user_settings)
		js.eval("localStorage.setItem('musiclab_globals', JSON.stringify(%s))" % json_data)
		#print_verbose("[MusicLabGlobals] Globals sauvegardés dans localStorage")
		LogBus.info(TAG,"MusicLab Globals saved in localStorage")
	else:
		#print_verbose("[MusicLabGlobals] Pas de support HTML5 → sauvegarde ignorée")
		LogBus.info(TAG,"no HTML5 -> cannot save MusicLab Globals ")


func _load_globals():
	if OS.has_feature("HTML5") and Engine.has_singleton("JavaScript"):
		var js = Engine.get_singleton("JavaScript")
		var data = js.eval("localStorage.getItem('musiclab_globals')")
		if data and typeof(data) == TYPE_STRING and data != "":
			var parsed = parse_json(data)
			if typeof(parsed) == TYPE_DICTIONARY:
				user_settings = parsed
				#print_verbose("[MusicLabGlobals] Globals rechargés depuis localStorage")
				LogBus.info(TAG,"MusicLab Globals loaded from localStorage")
				
			else:
				#print_verbose("[MusicLabGlobals] Erreur parse_json (data non-dict)")
				LogBus.error(TAG,"MusicLab Globals Error parse_json (data non-dict)")
		else:
			#print_verbose("[MusicLabGlobals] Aucune donnée locale à charger")
			LogBus.info(TAG,"MusicLab Globals no data to load")
	else:
		#print_verbose("[MusicLabGlobals] Pas de support HTML5 → chargement ignoré")
		LogBus.info(TAG,"no HTML5 -> cannot load MusicLab Globals ")


# -------------------------------------------------------------------
#	RESET COMPLET
# -------------------------------------------------------------------

func reset_all():
	#print_verbose("[MusicLabGlobals] reset_all()")
	LogBus.info(TAG,"MusicLab Globals -> Reset all()")
	current_song = null
	user_settings = {}
	_save_globals()



## SAVE !

# file_name sans .mid
func save_midi_bytes_to_midi_file(bytes: PoolByteArray,filename:String)->String:
	
	#var = Song.get_midi_bytes_type1()
	if bytes.size() <= 0:
		return "No Midi Bytes to export (bytes.size == 0)."
		
	filename += ".mid"	
	var mime_type = "audio/midi"	


	if OS.has_feature("HTML5") and Engine.has_singleton("JavaScript"):
		return _html5_download_bytes(bytes, filename, mime_type)
	else:
		return _save_locally(bytes, "user://" + filename)
	
	

func _html5_download_bytes(bytes: PoolByteArray, fname: String, mime: String) -> String:
	# Encode en base64 côté Godot (rapide et fiable)
	var b64: String = Marshalls.raw_to_base64(bytes)
	
	# Installe une fonction JS si absente, puis appelle le download
	var js_win = JavaScript.get_interface("window")
	if js_win == null:
		#LogBus.error(TAG,"[MidiExport] JavaScript window interface non available.")
		return "[MidiExport] JavaScript window interface non disponible."
	
	if not js_win.has("musiclib_download_b64"):
		var code = ""
		code += "window.musiclib_download_b64 = function(b64, filename, mime) {"
		code += "  try {"
		code += "    var bin = atob(b64);"
		code += "    var len = bin.length;"
		code += "    var arr = new Uint8Array(len);"
		code += "    for (var i = 0; i < len; i++) arr[i] = bin.charCodeAt(i);"
		code += "    var blob = new Blob([arr], {type: mime || 'application/octet-stream'});"
		code += "    var a = document.createElement('a');"
		code += "    a.href = URL.createObjectURL(blob);"
		code += "    a.download = filename || 'export.bin';"
		code += "    document.body.appendChild(a);"
		code += "    a.click();"
		code += "    setTimeout(function(){ URL.revokeObjectURL(a.href); a.remove(); }, 0);"
		code += "  } catch(e) { console.error('musiclib_download_b64 error', e); }"
		code += "};"
		JavaScript.eval(code, true)	#﻿
	
	if OS.has_feature("HTML5") and Engine.has_singleton("JavaScript"):
		# Appel direct
		js_win.musiclib_download_b64(b64, fname, mime)
		return fname + "saved !"
	else:
		return "[MidiExport] JavaScript environment required for export."


func _save_locally(bytes: PoolByteArray, path: String) -> String:
	var f = File.new()
	var err = f.open(path, File.WRITE)
	if err != OK:
		return "[MidiExport] Cannot open file: " +  path + " code=" + str(err)

	f.store_buffer(bytes)
	f.close()
	return "Midi File saved to " + path + " !"



func get_init_song()->Song:
	var song = Song.new()
	song.title =  "Untitled Song"
	return song


func yield(current_scene):
	yield(current_scene.get_tree(), "idle_frame") 
	

func wait_one_frame(current_scene):
	yield(current_scene.get_tree(), "idle_frame") 

	
func save_text_to_file(path:String, text:String) -> bool:
	var f = File.new()
	var err = f.open(path, File.WRITE)
	if err != OK:
		LogBus.error(TAG, "save_text_to_file(): can't open " + path + " (err " + str(err) + ")")
		return false
	
	f.store_string(text)
	f.close()
	
	LogBus.info(TAG, "save_text_to_file(): text saved to " + path)
	return true
	
	
func save_text_html5(text:String, filename:String = "export.txt") -> void:
	# Garde-fou : nom par défaut
	var fname:String = filename
	if fname == "":
		fname = "export.txt"
	
	# Si on est en HTML5 + JavaScript dispo : vrai download navigateur
	if OS.has_feature("HTML5") and Engine.has_singleton("JavaScript"):
		var b64:String = Marshalls.utf8_to_base64(text)
		var url:String = "data:text/plain;base64," + b64
		
		# Attention : ici on suppose un filename sans quotes ni caractères bizarres
		var js:String = ""
		js += "var a=document.createElement('a');"
		js += "a.href='" + url + "';"
		js += "a.download='" + fname + "';"
		js += "document.body.appendChild(a);"
		js += "a.click();"
		js += "document.body.removeChild(a);"
		
		JavaScript.eval(js, true)
		LogBus.info(TAG, "download_text_html5(): HTML5 download triggered (" + fname + ")")
	
	else:
		# Fallback hors HTML5 : on enregistre dans user://
		var path:String = "user://" + fname
		var ok:bool = save_text_to_file(path, text)
		if ok:
			LogBus.info(TAG, "download_text_html5(): not HTML5, saved to " + path + " instead")
		else:
			LogBus.error(TAG, "download_text_html5(): fallback save failed")


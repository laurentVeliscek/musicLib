extends Node
#class_name MusicLabGlobals

const AUTOSAVE_SONG_PATH = "user://autosave.mlab"
const DEFAULT_DOCUMENTS_SUBDIR := "MusicLab"
const SONG_EXTENSION := ".mlab"
const MIDI_EXTENSION := ".mid"
const TEXT_EXTENSION := ".txt"
const LAST_SONG_DIR_KEY := "last_song_dir"
const LAST_MIDI_DIR_KEY := "last_midi_dir"
const LAST_TEXT_DIR_KEY := "last_text_dir"
const GLOBALS_SAVE_PATH := "user://musiclab_globals.json"

const SOUND_FONT_ASPIRIN = "res://soundfonts/Aspirin-Stereo.sf2"
const SOUND_FONT_FLUID_R3  = "res://soundfonts/FluidR3_GM.sf2"
const SOUND_FONT_ESSENTIAL_KEYS = "res://soundfonts/Essential_Keys.sf2"
const SOUND_FONT_MUSICLAB = "res://soundfonts/musicLab.sf2"


var key_command = 16777239
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
	
	#test OS:
	var platform = OS.get_name()
	match platform:
		"OSX": key_command = 16777239
		_: key_command = KEY_CONTROL
	
	
	current_song = load_autosaved_song()
	rng.randomize()
	MusicLabGlobals.setup_midi_player()
	MusicLabGlobals.set_sound_Font(MusicLabGlobals.SOUND_FONT_MUSICLAB)

# -------------------------------------------------------------------
#	SONG MANAGEMENT
# -------------------------------------------------------------------

func setup_midi_player():
	musiclibMidiPlayer.setupMidiPlayer()
	midi_player = musiclibMidiPlayer.midiPlayer

func set_sound_Font(path):
	midi_player.set_soundfont(path)

func set_song(song):
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

	var base_dir := path.get_base_dir()
	if base_dir != "":
			_ensure_directory(base_dir)

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


#
#func download_current_song_as_json(filename:String = "song.json") -> void:
#	if current_song == null or not (current_song is Song):
#		LogBus.error(TAG, "download_current_song_as_json(): no current_song")
#		return
#
#	var data:Dictionary = current_song.to_dict()
#	#var json:String = JSON.print(data, "\t")
#
#
#	var path:String = "user://" + filename
#	var ok:bool = save_current_song_to_file(path, false)
#	if ok:
#		LogBus.info(TAG, "download_current_song_as_json(): not HTML5, saved to " + path + " instead")
#	else:
#		LogBus.error(TAG, "download_current_song_as_json(): fallback save failed")
#
#
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

	var f := File.new()
	var err = f.open(GLOBALS_SAVE_PATH, File.WRITE)
	if err != OK:
			LogBus.error(TAG, "_save_globals(): can't open " + GLOBALS_SAVE_PATH + " (err " + str(err) + ")")
			return

	f.store_string(JSON.print(user_settings, "\t"))
	f.close()
	#LogBus.info(TAG, "MusicLab Globals saved to " + GLOBALS_SAVE_PATH)


func _load_globals():

	var f := File.new()
	if not f.file_exists(GLOBALS_SAVE_PATH):
			return

	var err = f.open(GLOBALS_SAVE_PATH, File.READ)
	if err != OK:
			LogBus.error(TAG, "_load_globals(): can't open " + GLOBALS_SAVE_PATH + " (err " + str(err) + ")")
			return

	var text := f.get_as_text()
	f.close()

	var parsed = parse_json(text)
	if typeof(parsed) == TYPE_DICTIONARY:
			user_settings = parsed
			LogBus.info(TAG, "MusicLab Globals loaded from " + GLOBALS_SAVE_PATH)
	else:
			LogBus.error(TAG, "_load_globals(): invalid data format in " + GLOBALS_SAVE_PATH)

func _ensure_directory(path: String) -> bool:
		var dir := Directory.new()
		if dir.dir_exists(path):
				return true

		var err := dir.make_dir_recursive(path)
		if err != OK:
				LogBus.error(TAG, "_ensure_directory(): can't create " + path + " (err " + str(err) + ")")
				return false

		return true

func get_default_musiclab_dir() -> String:
		var documents := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		var fallback := "user://" + DEFAULT_DOCUMENTS_SUBDIR

		if documents == "":
				_ensure_directory(fallback)
				return fallback

		var target := documents.plus_file(DEFAULT_DOCUMENTS_SUBDIR)
		if _ensure_directory(target):
				return target

		_ensure_directory(fallback)
		return fallback

func _get_validated_dir(setting_key: String) -> String:
		var saved = get_user_setting(setting_key, "")
		var dir := Directory.new()

		if typeof(saved) == TYPE_STRING and saved != "" and dir.dir_exists(saved):
				return saved

		return get_default_musiclab_dir()

func _remember_dir(setting_key: String, path: String) -> void:
		var base_dir := path.get_base_dir()
		if base_dir != "":
				set_user_setting(setting_key, base_dir)

func _build_output_path(setting_key: String, filename: String, extension: String) -> String:
		var base_dir := _get_validated_dir(setting_key)
		_ensure_directory(base_dir)

		var name := filename
		if name == "":
				name = "export"

		if not name.ends_with(extension):
				name += extension

		return base_dir.plus_file(name)

func get_song_export_path(filename: String) -> String:
		return _build_output_path(LAST_SONG_DIR_KEY, filename, SONG_EXTENSION)

func get_midi_export_path(filename: String) -> String:
		return _build_output_path(LAST_MIDI_DIR_KEY, filename, MIDI_EXTENSION)

func get_text_export_path(filename: String) -> String:
		return _build_output_path(LAST_TEXT_DIR_KEY, filename, TEXT_EXTENSION)

func get_song_directory() -> String:
		return _get_validated_dir(LAST_SONG_DIR_KEY)

func get_midi_directory() -> String:
		return _get_validated_dir(LAST_MIDI_DIR_KEY)

func get_text_directory() -> String:
		return _get_validated_dir(LAST_TEXT_DIR_KEY)


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

		var export_path := _build_output_path(LAST_MIDI_DIR_KEY, filename, MIDI_EXTENSION)
		#var mime_type = "audio/midi"
		var result = _save_locally(bytes, export_path)
		_remember_dir(LAST_MIDI_DIR_KEY, export_path)
		return result
	
	


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
	var base_dir := path.get_base_dir()

	if base_dir != "":
			_ensure_directory(base_dir)

	var err = f.open(path, File.WRITE)
	if err != OK:
			LogBus.error(TAG, "save_text_to_file(): can't open " + path + " (err " + str(err) + ")")
			return false
	
	f.store_string(text)
	f.close()
	
	#LogBus.info(TAG, "save_text_to_file(): text saved to " + path)
	return true
	
	

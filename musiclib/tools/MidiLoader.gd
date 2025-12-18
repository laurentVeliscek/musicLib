extends Control

signal midi_loaded(bytes)
signal midi_load_failed(error_text)

export(int) var max_midi_size_bytes = 10485760 # 10 MB

onready var midi_dialog = $MidiFileDialog
onready var load_button = $LoadButton

var _dialog_done = false
var _dialog_selected = false
var _dialog_path = ""

func _ready():
	_setup_midi_dialog()

func _setup_midi_dialog():
	midi_dialog.access = FileDialog.ACCESS_FILESYSTEM
	midi_dialog.mode = FileDialog.MODE_OPEN_FILE
	midi_dialog.clear_filters()
	midi_dialog.add_filter("*.mid ; MIDI")
	midi_dialog.add_filter("*.midi ; MIDI")

	# Godot 3.6: use_native_dialog existe, mais on reste safe
	if midi_dialog.has_method("set_use_native_dialog"):
		midi_dialog.use_native_dialog = true

func _on_LoadButton_pressed():
	var result = yield(request_load(), "completed")
	if result == null:
		return
	emit_signal("midi_loaded", result)

# Public: tu peux appeler ça depuis ta scène principale (yieldable)
# Retourne PoolByteArray ou null
# En cas d'échec, émet midi_load_failed(error_text) en anglais
func request_load():
	_dialog_done = false
	_dialog_selected = false
	_dialog_path = ""

	midi_dialog.popup_centered_ratio(0.7)

	while not _dialog_done:
		yield(get_tree(), "idle_frame")

	if not _dialog_selected:
		_emit_error("No file selected.")
		return null

	return _load_and_validate_midi(_dialog_path)

func _on_MidiFileDialog_file_selected(path):
	_dialog_selected = true
	_dialog_path = path
	_dialog_done = true

func _on_MidiFileDialog_popup_hide():
	if not _dialog_selected:
		_dialog_done = true

func _emit_error(text):
	emit_signal("midi_load_failed", str(text))

func _load_and_validate_midi(path):
	if not _looks_like_midi_path(path):
		_emit_error("Invalid file extension. Please select a .mid or .midi file.")
		return null

	var f = File.new()
	var err = f.open(path, File.READ)
	if err != OK:
		_emit_error("Cannot open file (error code " + str(err) + ").")
		return null

	var size = f.get_len()
	if size <= 0:
		f.close()
		_emit_error("File is empty.")
		return null

	if size > max_midi_size_bytes:
		f.close()
		_emit_error("File is too large (" + str(size) + " bytes).")
		return null

	var bytes = f.get_buffer(size)
	f.close()

	if bytes == null or bytes.size() != size:
		_emit_error("Failed to read file content.")
		return null

	var validation_error = _validate_midi_bytes(bytes)
	if validation_error != "":
		_emit_error(validation_error)
		return null

	return bytes

func _looks_like_midi_path(path):
	var p = path.to_lower()
	if p.ends_with(".mid"):
		return true
	if p.ends_with(".midi"):
		return true
	return false

# Retourne "" si OK, sinon un message d'erreur en anglais
func _validate_midi_bytes(bytes):
	if bytes == null:
		return "No data to validate."

	if bytes.size() < 18:
		return "File is too small to be a valid MIDI file."

	# "MThd"
	if bytes[0] != 0x4D or bytes[1] != 0x54 or bytes[2] != 0x68 or bytes[3] != 0x64:
		return "Missing MIDI header chunk (MThd)."

	# header length must be 6 (big-endian)
	var header_len = _u32_be(bytes, 4)
	if header_len != 6:
		return "Invalid MIDI header length (" + str(header_len) + "). Expected 6."

	# format 0/1/2 (big-endian u16)
	var fmt = _u16_be(bytes, 8)
	if fmt != 0 and fmt != 1 and fmt != 2:
		return "Unsupported MIDI format (" + str(fmt) + ")."

	# number of tracks must be > 0
	var tracks = _u16_be(bytes, 10)
	if tracks <= 0:
		return "Invalid track count (0)."

	# division (u16) must not be 0
	var division = _u16_be(bytes, 12)
	if division == 0:
		return "Invalid time division (0)."

	# Usually next chunk is "MTrk". Some files may include other chunks,
	# but we keep it strict for now.
	if bytes[14] != 0x4D or bytes[15] != 0x54 or bytes[16] != 0x72 or bytes[17] != 0x6B:
		return "Missing first track chunk (MTrk)."

	return ""

func _u16_be(bytes, offset):
	return (int(bytes[offset]) << 8) | int(bytes[offset + 1])

func _u32_be(bytes, offset):
	return (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])

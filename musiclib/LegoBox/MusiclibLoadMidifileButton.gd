extends Button
class_name MusiclibLoadMidifileButton

signal midi_loaded(bytes,file_name)
signal midi_load_failed(error_text)

export(int) var max_midi_size_bytes = 10485760 # 10 MB
export(bool) var treat_cancel_as_error = false
export(bool) var strict_validation = true

var file_dialog = null
var dialog_selected = false

var _popup_retry_count = 0
export(int) var popup_retry_max = 8

func _ready():
	connect("pressed", self, "_on_pressed")

func _exit_tree():
	_cleanup_file_dialog()

func _get_globals():
	if has_node("/root/MusicLabGlobals"):
		return get_node("/root/MusicLabGlobals")
	return null

func _ensure_file_dialog():
	if file_dialog != null and is_instance_valid(file_dialog):
		return

	if not is_inside_tree():
		return

	var root = get_tree().get_root()
	if root == null:
		return

	file_dialog = FileDialog.new()
	file_dialog.name = "MusiclibMidiFileDialog_" + str(get_instance_id())

	# IMPORTANT: deferred pour éviter "Parent node is busy setting up children"
	root.call_deferred("add_child", file_dialog)

	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.mode = FileDialog.MODE_OPEN_FILE
	file_dialog.clear_filters()
	file_dialog.add_filter("*.mid ; MIDI")
	file_dialog.add_filter("*.midi ; MIDI")

	if file_dialog.has_method("set_use_native_dialog"):
		file_dialog.use_native_dialog = true

	if not file_dialog.is_connected("file_selected", self, "_on_file_selected"):
		file_dialog.connect("file_selected", self, "_on_file_selected")
	if not file_dialog.is_connected("popup_hide", self, "_on_popup_hide"):
		file_dialog.connect("popup_hide", self, "_on_popup_hide")

func _cleanup_file_dialog():
	if file_dialog == null:
		return
	if not is_instance_valid(file_dialog):
		file_dialog = null
		return

	# Si le node est déjà en cours de destruction, on ne touche à rien
	if file_dialog.is_queued_for_deletion():
		file_dialog = null

func _on_pressed():
	_ensure_file_dialog()

	if file_dialog == null or not is_instance_valid(file_dialog):
		_emit_error("File dialog is not available.")
		return

	dialog_selected = false
	_popup_retry_count = 0

	# Dossier initial depuis MusicLabGlobals.get_midi_directory()
	var g = _get_globals()
	if g != null and g.has_method("get_midi_directory"):
		var start_dir = g.get_midi_directory()
		if typeof(start_dir) == TYPE_STRING and start_dir != "":
			if file_dialog.has_method("set_current_dir"):
				file_dialog.set_current_dir(start_dir)
			else:
				file_dialog.set("current_dir", start_dir)

	call_deferred("_try_popup_dialog")

func _try_popup_dialog():
	if file_dialog == null or not is_instance_valid(file_dialog):
		_emit_error("File dialog is not available.")
		return

	if not file_dialog.is_inside_tree():
		_popup_retry_count += 1
		if _popup_retry_count > popup_retry_max:
			_emit_error("File dialog failed to enter the scene tree.")
			return
		call_deferred("_try_popup_dialog")
		return

	file_dialog.popup_centered_ratio(0.7)

func _on_file_selected(path):
	dialog_selected = true

	# Mémorise le dernier dossier choisi (cohérent avec MusicLabGlobals)
	var g = _get_globals()
	if g != null and g.has_method("set_user_setting"):
		g.set_user_setting("last_midi_dir", path.get_base_dir())

	var bytes = _load_and_validate_midi(path)
	if bytes == null:
		return
	var file_name = path.get_file()
	
	emit_signal("midi_loaded", bytes,file_name)

func _on_popup_hide():
	if dialog_selected:
		return
	if treat_cancel_as_error:
		_emit_error("No file selected.")

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

	if strict_validation:
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

func _validate_midi_bytes(bytes):
	if bytes == null:
		return "No data to validate."
	if bytes.size() < 18:
		return "File is too small to be a valid MIDI file."

	if bytes[0] != 0x4D or bytes[1] != 0x54 or bytes[2] != 0x68 or bytes[3] != 0x64:
		return "Missing MIDI header chunk (MThd)."

	var header_len = _u32_be(bytes, 4)
	if header_len != 6:
		return "Invalid MIDI header length (" + str(header_len) + "). Expected 6."

	var fmt = _u16_be(bytes, 8)
	if fmt != 0 and fmt != 1 and fmt != 2:
		return "Unsupported MIDI format (" + str(fmt) + ")."

	var tracks = _u16_be(bytes, 10)
	if tracks <= 0:
		return "Invalid track count (0)."

	var division = _u16_be(bytes, 12)
	if division == 0:
		return "Invalid time division (0)."

	if bytes[14] != 0x4D or bytes[15] != 0x54 or bytes[16] != 0x72 or bytes[17] != 0x6B:
		return "Missing first track chunk (MTrk)."

	return ""

func _u16_be(bytes, offset):
	return (int(bytes[offset]) << 8) | int(bytes[offset + 1])

func _u32_be(bytes, offset):
	return (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])

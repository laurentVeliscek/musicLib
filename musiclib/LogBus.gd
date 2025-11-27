extends Node
#class_name LogBus

# Signals
signal log_entry(entry)	# entry: Dictionary {time_str, msec, level, tag, message}

# Modes / niveaux
const LEVEL_INFO = "INFO"
const LEVEL_WARN = "WARN"
const LEVEL_ERROR = "ERROR"
const LEVEL_DEBUG = "DEBUG"

# État
var _verbose = false
var _console = null	# RichTextLabel optionnel
var _use_bbcode = true
var _max_buffer = 200
var _buffer = []	# entries en attente si console absente
var _enabled_tags = {}	# tag -> bool (par défaut true si inconnu)

# Public API -------------------------------------------------------------

func set_verbose(enabled: bool) -> void:
	_verbose = enabled

func is_verbose() -> bool:
	return _verbose

func attach_console(rich_text_label: Object) -> void:
	_console = rich_text_label
	_flush_buffer_to_console()

func detach_console() -> void:
	_console = null

func set_tag_enabled(tag: String, enabled: bool) -> void:
	_enabled_tags[tag] = enabled

func clear_console() -> void:
	if _console and _console is RichTextLabel:
		_console.clear()

# Raccourcis de log
func info(tag: String, message: String) -> void:
	_log(LEVEL_INFO, tag, message)

func warn(tag: String, message: String) -> void:
	_log(LEVEL_WARN, tag, message)

func error(tag: String, message: String) -> void:
	_log(LEVEL_ERROR, tag, message)

func debug(tag: String, message: String) -> void:
	_log(LEVEL_DEBUG, tag, message)

# Fallback standardisé (on le loggue en WARN, comme convenu)
func fallback(tag: String, message: String) -> void:
	_log(LEVEL_WARN, "FALLBACK", tag + " | " + message)

# Core ------------------------------------------------------------------

func _log(level: String, tag: String, message: String) -> void:
	if not _should_emit(level, tag):
		return
	
	var ts = _now_str()
	var ms = OS.get_ticks_msec()
	var line = ts + " | " + level + " | " + tag + " | " + message
	
	# Signal → observateurs
	var entry = {
		"time_str": ts,
		"msec": ms,
		"level": level,
		"tag": tag,
		"message": message
	}
	emit_signal("log_entry", entry)
	
	# Console si dispo, sinon buffer + print
	if _console and _console is RichTextLabel:
		_write_console(level, line)
	else:
		_buffer_push(entry)
		print(line)

func _should_emit(level: String, tag: String) -> bool:
	# Filtre verbose (normal: WARN/ERROR ; verbose: tout)
	if not _verbose:
		if level != LEVEL_WARN and level != LEVEL_ERROR:
			return false
	# Filtre par tag (si explicitement désactivé)
	if _enabled_tags.has(tag) and _enabled_tags[tag] == false:
		return false
	return true

# Console ---------------------------------------------------------------

func _write_console(level: String, line: String) -> void:
	if not (_console and _console is RichTextLabel):
		return
	if _use_bbcode:
		var colored = _colorize(level, line)
		_console.append_bbcode(colored + "\n")
	else:
		_console.add_text(line + "\n")

func _colorize(level: String, line: String) -> String:
	# Palette simple
	var col = "#CCCCCC"	# INFO
	if level == LEVEL_WARN:
		col = "#E0A800"
	elif level == LEVEL_ERROR:
		col = "#FF4D4D"
	elif level == LEVEL_DEBUG:
		col = "#66A3FF"
	return "[color=" + col + "]" + line + "[/color]"

# Buffering -------------------------------------------------------------

func _buffer_push(entry: Dictionary) -> void:
	_buffer.append(entry)
	if _buffer.size() > _max_buffer:
#		# purge FIFO
		_buffer.pop_front()

func _flush_buffer_to_console() -> void:
	if not (_console and _console is RichTextLabel):
		return
	for i in range(_buffer.size()):
		var e = _buffer[i]
		var line = String(e.time_str) + " | " + String(e.level) + " | " + String(e.tag) + " | " + String(e.message)
		_write_console(String(e.level), line)
	_buffer.clear()

# Utils -----------------------------------------------------------------

func _now_str() -> String:
	var dt = OS.get_datetime()
	var h = _two(dt.hour)
	var m = _two(dt.minute)
	var s = _two(dt.second)
	var ms = _three(OS.get_ticks_msec() % 1000)
	return h + ":" + m + ":" + s + "." + ms

func _two(v) -> String:
	var s = str(int(v))
	if s.length() < 2:
		return "0" + s
	return s

func _three(v) -> String:
	var s = str(int(v))
	if s.length() == 1:
		return "00" + s
	if s.length() == 2:
		return "0" + s
	return s

#
#
#Usage éclair
#
#Project → Project Settings → Autoload
#
#Path: res://addons/musiclib/LogBus.gd
#
#Node Name: LogBus (coché Singleton)
#
#Brancher une console (optionnel) :

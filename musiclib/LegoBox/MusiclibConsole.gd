tool
extends RichTextLabel
const TAG = "MusiclibConsole"
class_name MusiclibConsole

export var verbose:bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	MusicLabGlobals.wait_one_frame(self)
	LogBus.connect("log_entry", self, "_on_log_entry")
	LogBus._verbose = true
	
func clear():
	text = ""

func export_to_file():
	MusicLabGlobals.save_text_to_disk(text,"console.txt")
	
	
func _on_log_entry(entry):
	#entry = {time_str, msec, level, tag, message}
	var level = entry["level"]
	var tag = entry["tag"]
	var message = entry["message"]
	
	if level == "INFO":
		#console.text += level + "|"  + tag + "|" + message + "\n"
		text +=  message + "\n"
	else :
		text += level + "|"  + tag + "|" + message + "\n"

	


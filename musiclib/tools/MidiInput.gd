extends Control
class_name MidiInput

signal note_on(pitch, velocity, time_msec)

const TAG = "MidiInput"

var keys = ["C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B"]

onready var midi_player:MidiPlayer 


onready var scene:Control = $"../.."
onready var midi_status:Label = $midi_status_label
onready var note_label:Label = $note_label
onready var midi_label_animation:AnimationPlayer = $midi_status_label/AnimationPlayer
export var midi_monitor_enabled:bool = false

var midi_in_enabled:bool = false setget set_midi_in_enabled, get_midi_in_enabled
var last_midi_note = 60

func set_midi_in_enabled(v:bool):
	midi_in_enabled = v
	visible = v
	if v:
		midi_label_animation.play("flashing_midi_in")
	else:
		midi_label_animation.stop()

func get_midi_in_enabled()-> bool:
	return midi_in_enabled
	
func _ready():
	visible = midi_in_enabled
	#OS.open_midi_inputs()
	var midi_inputs = MusicLabGlobals.midi_inputs
	print(TAG, " MIDI inputs: ", midi_inputs)
	midi_player= MusicLabGlobals.midi_player
	
	
func _input(event):
	if event is InputEventMIDI and midi_in_enabled:
		accept_event()
		var midi_event = event

		if midi_event.message == MIDI_MESSAGE_NOTE_ON:
			# En MIDI, NOTE_ON avec velocity = 0 == NOTE_OFF
			if midi_event.velocity > 0:
				last_midi_note = midi_event.pitch

				var timestamp_msec = OS.get_ticks_msec()
				update_display(last_midi_note)
				emit_signal(
					"note_on",
					midi_event.pitch,
					midi_event.velocity,
					timestamp_msec
				)
	elif event is InputEventKey and midi_in_enabled:
		if  event.is_released():
			return
#		if event.shift == false or  event.alt == false :
#			return
		var midi_pitch = null
		match event.scancode:
			KEY_Q: midi_pitch = 60
			KEY_Z: midi_pitch = 61
			KEY_S: midi_pitch = 62
			KEY_E: midi_pitch = 63
			KEY_D: midi_pitch = 64
			KEY_F: midi_pitch = 65
			KEY_T: midi_pitch = 66
			KEY_G: midi_pitch = 67
			KEY_Y: midi_pitch = 68
			KEY_H: midi_pitch = 69
			KEY_U: midi_pitch = 70
			KEY_J: midi_pitch = 71
			KEY_K: midi_pitch = 72
			KEY_O: midi_pitch = 73
			KEY_L: midi_pitch = 74
			KEY_P: midi_pitch = 75
			KEY_M: midi_pitch = 76
		
		if midi_pitch == null:
			return
			
		var timestamp_msec = OS.get_ticks_msec()
		last_midi_note = midi_pitch
		update_display(last_midi_note)
		emit_signal(
			"note_on",
			midi_pitch,
			100,
			timestamp_msec
		)
		
		
func update_display(pitch):		
	last_midi_note = pitch
	note_label.text = keys[last_midi_note % 12]
	
	if midi_monitor_enabled == false:
		return
	# play note !
	scene.rewind()
	var note:Note = Note.new()
	note.midi = pitch
	note.length_beats = 1
	var track:Track = Track.new()
	track.add_note(0,note)
	var midi_in_song:Song = Song.new()
	midi_in_song.add_track(track)
	midi_player.load_from_bytes(midi_in_song.get_midi_bytes_type1())
	scene.anim_songTrack_view = false
	midi_player.play()	

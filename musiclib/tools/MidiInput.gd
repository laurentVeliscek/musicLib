extends Control
class_name MidiInput

signal note_on(pitch, velocity, time_msec)

const TAG = "MidiInput"

var last_midi_note = 60

func _ready():
	OS.open_midi_inputs()
	var midi_inputs = OS.get_connected_midi_inputs()
	print(TAG, " MIDI inputs: ", midi_inputs)

func _input(event):
	if event is InputEventMIDI:
		accept_event()
		var midi_event = event

		if midi_event.message == MIDI_MESSAGE_NOTE_ON:
			# En MIDI, NOTE_ON avec velocity = 0 == NOTE_OFF
			if midi_event.velocity > 0:
				last_midi_note = midi_event.pitch

				var timestamp_msec = OS.get_ticks_msec()

				emit_signal(
					"note_on",
					midi_event.pitch,
					midi_event.velocity,
					timestamp_msec
				)
	elif event is InputEventKey:
		if  event.is_released():
			return
		if event.shift == false or  event.alt == false :
			return
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

		emit_signal(
			"note_on",
			midi_pitch,
			100,
			timestamp_msec
		)
		
		

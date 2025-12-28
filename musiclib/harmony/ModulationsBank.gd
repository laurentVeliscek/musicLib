extends Reference
class_name ModulationsBank

const TAG = "ModulationsBank"



const modulations = [
	{
		"name":"Chromatic soft by pivot",
		"start_mode":"major",
		"target_mode": "major",
		"key_offset":3,
		"chords":[
			{	#C
				"root_offset":0,
				"degree_number":1,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"major",
				"kind":"diatonic",
				"comment":"starting chord"
			},
			{	# F
				"root_offset":0,
				"degree_number":4,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"major",
				"kind":"diatonic",
				"comment":"IV of the major scale"
			},
			{	# Fm
				"root_offset":0,
				"degree_number":4,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"harmonic_minor",
				"kind":"diatonic",
				"comment":"iv of the parallel minor scale"
			},
			{	# Eb
				"root_offset":3,
				"degree_number":1,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"harmonic_minor",
				"kind":"diatonic",
				"comment":"VI of the minor scale is I in the major target key"
			},
			{	# Bb
				"root_offset":3,
				"degree_number":5,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"harmonic_minor",
				"kind":"diatonic",
				"comment":"V of the target key"
			},
			{	# Bb
				"root_offset":3,
				"degree_number":1,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"harmonic_minor",
				"kind":"diatonic",
				"comment":"I of the target key"
			}
		]
	},
########################################################	
	{
		"name":"Chromatic by altered secondary dominant V7b9",
		"start_mode":"major",
		"target_mode": "major",
		"key_offset":8,
		"chords":[
			{	#C
				"root_offset":0,
				"degree_number":1,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"major",
				"kind":"diatonic",
				"comment":"starting chord"
			},
			{	#G7
				"root_offset":0,
				"degree_number":5,
				"realization":[1,3,5,7],
				"inversion":0,
				"scale_name":"major",
				"kind":"diatonic",
				"comment":"Dominant in the starting key"
			},
			{	# G7b9
				"root_offset":0,
				"degree_number":5,
				"realization":[1,3,7,9],
				"inversion":0,
				"scale_name":"major",
				"kind":"chrom",
				"jazz_chord_suffixe":"7b9",
				"key_alterations":{6:-1},
				"comment":"Altered Dominant b9"
			},
			{	# Ab
				"root_offset":8,
				"degree_number":1,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"major",
				"kind":"diatonic",
				"jazz_chord_suffixe":"7b9",
				"key_alterations":{6:-1},
				"comment":"bVI in starting key is I target key"
			},
			{	# Eb
				"root_offset":8,
				"degree_number":5,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"major",
				"kind":"diatonic",
				"comment":"Dominant of target key"
			},
			{	# Ab
				"root_offset":8,
				"degree_number":1,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"major",
				"kind":"diatonic",
				"comment":"I of target key"
			},
		]		
	},
########################################################
	{
		"name":"Chromatic enharmonic (°7)",
		"start_mode":"major",
		"target_mode": "minor",
		"key_offset":1,
		"chords":[
			{	#C
				"root_offset":0,
				"degree_number":1,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"major",
				"kind":"diatonic",
				"comment":"starting chord"
			},
			{	#Dm
				"root_offset":0,
				"degree_number":2,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"major",
				"kind":"diatonic",
				"comment":"ii in the starting key"
			},
			{	#D°7
				"root_offset":3,
				"degree_number":7,
				"realization":[1,3,5,7],
				"inversion":0,
				"scale_name":"harmonic_minor",
				"kind":"diatonic",
				"comment":"vii°7/V of the starting key"
			},
			{	# Ebm
				"root_offset":1,
				"degree_number":2,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"harmonic_minor",
				"kind":"diatonic",
				"comment":"ii° in the target key"
			},
			{	# Ab7
				"root_offset":1,
				"degree_number":5,
				"realization":[1,3,5,7],
				"inversion":0,
				"scale_name":"harmonic_minor",
				"kind":"diatonic",
				"comment":"Dominant in the target key"
			},
			{	# Dm
				"root_offset":1,
				"degree_number":1,
				"realization":[1,3,5],
				"inversion":0,
				"scale_name":"harmonic_minor",
				"kind":"diatonic",
				"comment":"Dominant in the target key"
			},


		]		
	}
########################################################
	
]

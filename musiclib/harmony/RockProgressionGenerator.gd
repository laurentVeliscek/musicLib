extends Reference
class_name RockProgressionGenerator

var TAG = "RockProgressionGenerator"

const TWO_CHORDS:Array = [[1,4],[1,7],[1,5],[1,3],[1,6],[1,2],[1,0.5],[1,7.5]]
const THREE_CHORDS:Array = [[2,5,1],[4,5,1],[5,4,1],[4,7,1],[7,4,1],[6,7,1]]
const THREE_CHORDS_RARE:Array = [[6,5,1],[6,7,1],[6,4,1],[4,6,1],[3,5,1]]
const FOUR_CHORDS_PART1:Array = [[7,4,5,1],[5,7,4,1],[4,7,5,1],[6,2,5,1],[6,4,5,1],[3,4,5,1]]
const FOUR_CHORDS_PART2:Array = [[4,6,5,1],[6,5,4,1],[5,6,4,1],[6,3,7,1]]
const FOUR_CHORDS_PART3:Array = [[5,2,4,1],[4,2,5,1],[3,7,4,1],[7,6,5,1]]

var four_chords_array:Array = []

func _init():
		#generate 4chords
	
	four_chords_array.append_array(make_4chords_from_TWO_CHORDS())
	four_chords_array.append_array(make_4chords_from_TWO_CHORDS())
	four_chords_array.append_array(make_4chords_from_THREE_CHORDS(THREE_CHORDS))
	four_chords_array.append_array(make_4chords_from_THREE_CHORDS(THREE_CHORDS))
	four_chords_array.append_array(make_4chords_from_THREE_CHORDS(THREE_CHORDS))
	four_chords_array.append_array(make_4chords_from_THREE_CHORDS(THREE_CHORDS_RARE))
	four_chords_array.append_array(make_4chords_from_FOUR_CHORDS(FOUR_CHORDS_PART1))
	four_chords_array.append_array(make_4chords_from_FOUR_CHORDS(FOUR_CHORDS_PART1))
	four_chords_array.append_array(make_4chords_from_FOUR_CHORDS(FOUR_CHORDS_PART1))
	four_chords_array.append_array(make_4chords_from_FOUR_CHORDS(FOUR_CHORDS_PART2))
	four_chords_array.append_array(make_4chords_from_FOUR_CHORDS(FOUR_CHORDS_PART2))
	four_chords_array.append_array(make_4chords_from_FOUR_CHORDS(FOUR_CHORDS_PART3))

func generate( key_root:int = -1,scale:String = "",_seed:int = -1, lastDegree = null) -> Array:
	
	var track = Track.new()
	var rng = RandomNumberGenerator.new()
	if _seed > -1:
		rng.seed = _seed
	else:
		rng.randomize()
	
	
	var key:HarmonicKey = HarmonicKey.new()
	if key_root == -1:
		key.root_midi = rng.randi() %12
	else :
		key.root_midi = key_root
	
	var _scale
	if scale == "":
		# "major" -> "minor" -> "harmonic minor" -> "melodic_minor" 
		#func rand_weighted(dict_list: Array, _seed: int = -1) -> String:
		_scale = rand_weighted([{"major":2.0},{"minor":3.0},{"harmonic_minor":.5},{"melodic_minor":.1}],rng)
	else :
		_scale = scale 

	
	key.scale_name = _scale

	# on peut forcer la tonalité en envoyeant un Degree	
	if scale == "" and key_root == -1 and lastDegree != null:
		#LogBus.info(TAG,"lastdegree key: " + lastDegree.to_string())
		if lastDegree is Degree:
			key = lastDegree.key
	

	LogBus.info(TAG,"generator key set to "+ key.to_string())
	
	var chord_array = four_chords_array[rng.randi()%four_chords_array.size()]
	LogBus.info(TAG,"Generator pattern: "+str(chord_array))
	
	var degrees_array = []
	for i in range(0,4) :
		var d = number_to_degree(chord_array[i],key)
		degrees_array.append(d)

	return degrees_array 




# GENERATE ALL 4 CHORDS FROM TWO_CHORDS
func make_4chords_from_TWO_CHORDS() -> Array:
	var arr2 = []
	for arr in TWO_CHORDS:
		var arr22 = []
		arr22.append(arr[0])
		arr22.append(arr[1])
		arr22.append(arr[0])
		arr22.append(arr[1])
		arr2.append(arr22)
	
	return arr2

# genere toutes les combinaisons depuis THREE_CHORDS ou THREE_CHORDS_RARE
func make_4chords_from_THREE_CHORDS(arr:Array) -> Array:

	var arr2 = []
	var arr_with_rotations = []
	for a in arr :
		var rotations = generate_rotations(a)
		arr_with_rotations.append_array(rotations)
	#LogBus.debug(TAG,"rotations: "+str(rotations))
	
	
	for ar in arr_with_rotations:
		arr2.append([ar[0],ar[1],ar[2],ar[2]])
		arr2.append([ar[0],ar[0],ar[1],ar[2]])
	return arr2
	
func make_4chords_from_FOUR_CHORDS(arr:Array) -> Array:
	var arr2 = []
	var arr_with_rotations = []
	for a in arr :
		var rotations = generate_rotations(a)
		arr_with_rotations.append_array(rotations)
	#LogBus.debug(TAG,"rotations: "+str(rotations))
	
	
	for ar in arr_with_rotations:
		arr2.append([ar[0],ar[1],ar[2],ar[3]])
	return arr2

func number_to_degree(number:float,key:HarmonicKey) -> Degree:
	var d:Degree = Degree.new()
	
	d.key = key
	d.degree_number = int(number)
	var scale = key.scale_name
	
	# on ajuste si key n'est pas exotique
	match scale:
		"major":
			match number:
				7.0: # on utilise la VII mineur
					var k2:HarmonicKey = HarmonicKey.new()
					k2.root_midi = key.root_midi
					k2.scale_name = "minor"
					d.key = k2
				7.5: # on utilise le 7 harmonic_minor
					var k2:HarmonicKey = HarmonicKey.new()
					k2.root_midi = key.root_midi
					k2.scale_name = "harmonic_minor"
					d.key = k2
				0.5: # on utilise #I
					var k2:HarmonicKey = HarmonicKey.new()
					k2.root_midi = (1 + key.root_midi) % 12
					d.degree_number= 1
					d.key = k2
		"minor":
			match number:
				7.5: # on utilise le 7 harmonic_minor
					var k2:HarmonicKey = HarmonicKey.new()
					k2.root_midi = key.root_midi
					k2.scale_name = "harmonic_minor"
					d.key = k2
				0.5: # on utilise le #I
					var k2:HarmonicKey = HarmonicKey.new()
					k2.root_midi = (1 + key.root_midi) % 12
					d.degree_number= 1
					d.key = k2
				2.0:
					var k2:HarmonicKey = HarmonicKey.new() # major
					k2.root_midi = key.root_midi
					d.degree_number= 2
					d.key = k2
				
		"harmonic_minor":
			match number:
				7.5: # on utilise le 7 harmonic_minor
					pass
				0.5: # on utilise le #I
					var k2:HarmonicKey = HarmonicKey.new()
					k2.root_midi = (1 + key.root_midi) % 12
					d.degree_number= 1
					d.key = k2
				2.0:
					d.inversion = 1
				3.0: 
					var k2:HarmonicKey = HarmonicKey.new() # major
					k2.scale_name = "minor"
					k2.root_midi = key.root_midi
					d.degree_number= 3
					d.key = k2
				4.0:
					var k2:HarmonicKey = HarmonicKey.new() # major
					k2.scale_name = "minor"
					k2.root_midi = key.root_midi
					d.degree_number= 4
					d.key = k2
		"melodic_minor":
			match number:
				7.5: # on utilise le 7 harmonic_minor
					var k2:HarmonicKey = HarmonicKey.new()
					k2.root_midi = key.root_midi
					k2.scale_name = "harmonic_minor"
					d.key = k2
				0.5: # on utilise le #I
					var k2:HarmonicKey = HarmonicKey.new()
					k2.root_midi = (1 + key.root_midi) % 12
					d.degree_number= 1
					d.key = k2
				3.0: 
					var k2:HarmonicKey = HarmonicKey.new() # major
					k2.scale_name = "minor"
					k2.root_midi = key.root_midi
					d.degree_number= 3
					d.key = k2
				6.0:
					var k2:HarmonicKey = HarmonicKey.new() # major
					k2.scale_name = "minor"
					k2.root_midi = key.root_midi
					d.degree_number= 6
					d.key = k2
				7.0:
					var k2:HarmonicKey = HarmonicKey.new() # major
					k2.scale_name = "minor"
					k2.root_midi = key.root_midi
					d.degree_number= 7	
					d.key = k2
	return d 


### HELPERS
func rotate_array(arr:Array) -> Array:
	var arr_dup = arr.duplicate(true)
	var pop = arr_dup.pop_front()
	arr_dup.append(pop)
	return arr_dup

# GENERATE ALL ROTATIONS FROM AN ARRAY
func generate_rotations(arr:Array)-> Array:
	var rotations:Array = []
	for i in range(0,arr.size()):
		arr = rotate_array(arr)
		rotations.append(arr)
	return rotations
		
	

func rand_weighted(dict_list: Array, rng:RandomNumberGenerator) -> String:
	# dict_list = [{element: poids}, {element: poids}, ...]
	# seed optionnel pour reproductibilité
	
	if dict_list.empty():
		return ""
	


	
	# Calcul du total des poids
	var total_weight = 0.0
	for entry in dict_list:
		for k in entry.keys():
			total_weight += float(entry[k])
	
	if total_weight <= 0.0:
		return ""
	
	# Tirage aléatoire selon les poids
	var r = rng.randf() * total_weight
	var cumulative = 0.0
	
	for entry in dict_list:
		for k in entry.keys():
			cumulative += float(entry[k])
			if r <= cumulative:
				return k
	
	# fallback (ne devrait pas arriver)
	return dict_list[-1].keys()[0]

		

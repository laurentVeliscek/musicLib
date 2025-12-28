extends Reference
class_name ChordDurationPatternGenerator

const TOTAL_BEATS_PER_MEASURE = 4.0

# 2 mesures (8 temps), 4 accords
# Patterns simples (que des noires)
const BASE_PATTERNS_2BARS_SIMPLE = [
	[2.0, 2.0, 2.0, 2.0],
	[3.0, 1.0, 2.0, 2.0],
	[2.0, 2.0, 3.0, 1.0],
	[1.0, 3.0, 2.0, 2.0],
	[2.0, 1.0, 3.0, 2.0]
]

# 2 mesures (8 temps), 4 accords
# Patterns avec croches, symétriques et simples
const BASE_PATTERNS_2BARS_SYNCOPATED = [
	[1.5, 2.5, 2.5, 1.5],
	[2.5, 1.5, 1.5, 2.5],
	[1.5, 2.5, 1.5, 2.5],
	[2.5, 1.5, 2.5, 1.5],
	[2.0, 1.5, 2.5, 2.0],
	[2.0, 2.5, 1.5, 2.0]
]

# 4 mesures (16 temps), 4 accords
# Patterns simples, très lisibles
const BASE_PATTERNS_4BARS_SIMPLE = [
	[4.0, 4.0, 4.0, 4.0],   # 1 accord par mesure
	[2.0, 2.0, 4.0, 8.0],   # plus de sustain à la fin
	[4.0, 2.0, 2.0, 8.0],
	[2.0, 4.0, 4.0, 6.0],
	[6.0, 2.0, 4.0, 4.0],
	[3.0, 3.0, 4.0, 6.0],
	[6.0, 4.0, 3.0, 3.0]
]

# 4 mesures (16 temps), 4 accords
# Patterns avec croches, inspirés de push/pop “and of 4”
const BASE_PATTERNS_4BARS_SYNCOPATED = [
	[3.5, 4.5, 4.0, 4.0],   # changement anticipé sur la fin de M1
	[4.0, 3.5, 4.5, 4.0],
	[3.5, 4.5, 4.5, 3.5],   # symétrique début/fin
	[4.0, 4.5, 4.0, 3.5],
	[3.5, 4.0, 4.5, 4.0],
	[4.0, 4.0, 3.5, 4.5],
	[3.0, 5.0, 4.0, 4.0],
	[4.0, 4.0, 5.0, 3.0]
]

var rng = MusicLabGlobals.rng
# measures   : 2 ou 4
# complexity : 0 = simple (que des noires)
#              1 = mix simple + syncopé
#              2 = privilégie les patterns syncopés
# _seed       : pour un résultat déterministe (0 = random)
func get_pattern(measures:int, complexity:int = 1, _seed:int = 0) -> PoolRealArray:
	var total_beats = float(measures) * TOTAL_BEATS_PER_MEASURE
	
	
	if _seed != 0:
		rng.seed = _seed
	else:
		rng.randomize()
	
	var base_patterns = _get_base_patterns(measures, complexity)
	
	if base_patterns.size() == 0:
		# Fallback: découpe égale, et on log pour ne pas masquer le problème
		var fallback_length = total_beats / 4.0
		var fallback = [
			fallback_length,
			fallback_length,
			fallback_length,
			fallback_length
		]
		print("ChordDurationPatternGenerator: no base patterns for measures = " + str(measures) + ", using equal split.")
		return _to_pool_real_array(fallback)
	
	var index = rng.randi_range(0, base_patterns.size() - 1)
	var chosen = base_patterns[index]
	
	return _to_pool_real_array(chosen)

func _filter_patterns_without_delays(patterns:Array, total_beats:float) -> Array:
	var result = []
	var ideal_step = total_beats / 4.0
	
	for pattern in patterns:
		# On ne garde que les patterns à 4 valeurs
		if pattern.size() != 4:
			continue
		
		var start = 0.0
		var ok = true
		
		for i in range(4):
			if i > 0:
				start = start + float(pattern[i - 1])
			
			var ideal = float(i) * ideal_step
			
			# Si l'accord commence APRÈS le point "naturel", c'est un retard → on exclut
			if start > ideal + 0.001:
				ok = false
				break
		
		if ok:
			result.append(pattern)
	
	return result


func _get_base_patterns(measures:int, complexity:int) -> Array:
	var patterns_simple = []
	var patterns_sync = []
	
	if measures == 2:
		patterns_simple = BASE_PATTERNS_2BARS_SIMPLE
		patterns_sync = BASE_PATTERNS_2BARS_SYNCOPATED
	elif measures == 4:
		patterns_simple = BASE_PATTERNS_4BARS_SIMPLE
		patterns_sync = BASE_PATTERNS_4BARS_SYNCOPATED
	
	var result = []
	
	if patterns_simple.size() == 0 and patterns_sync.size() == 0:
		return result
	
	if complexity <= 0:
		# uniquement les patterns simples
		result = patterns_simple.duplicate()
	elif complexity == 1:
		# mélange simple + syncopé
		result = patterns_simple.duplicate()
		for p in patterns_sync:
			result.append(p)
	else:
		# privilégier les patterns syncopés
		result = patterns_sync.duplicate()
		
		# Si on n'a pas de syncopés pour ce cas, on retombe au simple
		if result.size() == 0 and patterns_simple.size() > 0:
			result = patterns_simple.duplicate()
	
	# Ici on filtre tous les patterns qui créent des retards
	var total_beats = float(measures) * TOTAL_BEATS_PER_MEASURE
	result = _filter_patterns_without_delays(result, total_beats)
	
	return result



func _to_pool_real_array(values:Array) -> PoolRealArray:
	var out = PoolRealArray()
	for v in values:
		out.append(float(v))
	return out

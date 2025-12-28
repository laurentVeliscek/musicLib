extends Node
class_name ParallelChecker

#---------------------------------------------------------------------------------------------------
#	ParallelChecker
#	- analyze_progression(chords: Array) -> Dictionary
#		chords: Array d'accords, chaque accord = Array[4] de MIDI ints [S, A, T, B]
#	Rapport retourné:
#	{
#		"parallel_fifths_indices": PoolIntArray,	# indices i où (accord i -> i+1) a ≥1 quinte parallèle
#		"parallel_octaves_indices": PoolIntArray,	# indices i où (accord i -> i+1) a ≥1 octave parallèle
#		"total_parallel_fifths": int,				# nombre total de paires de voix en quintes parallèles
#		"total_parallel_octaves": int,				# nombre total de paires de voix en octaves parallèles
#		"details": Array							# par pas, détail des paires fautives
#	}
#---------------------------------------------------------------------------------------------------

# Paires de voix à vérifier (indices dans [S, A, T, B] = [0,1,2,3])
var _voice_pairs = [
	[0, 1], [0, 2], [0, 3],	# S–A, S–T, S–B
	[1, 2], [1, 3],			# A–T, A–B
	[2, 3]					# T–B
]

# NOTE:
# - On traite en MIDI "bruts" (pas de normalisation d'octave). Ça permet de détecter les parallèles
#   sur des positions réelles de tessiture.
# - On considère "mouvement parallèle" seulement si les deux voix bougent dans le même sens
#   (toutes deux montent ou toutes deux descendent). Si l’une reste fixe, on NE compte PAS.
# - Une "quinte" = intervalle modulo 12 == 7, une "octave" = 0 (unisson/8ve) entre les deux voix.
# - On ne filtre pas ici les cas d’enharmonie : MIDI oblige, c’est déjà “purement” intervallic.

func analyze_progression(chords: Array) -> Dictionary:
	var result = {
		"parallel_fifths_indices": PoolIntArray(),
		"parallel_octaves_indices": PoolIntArray(),
		"total_parallel_fifths": 0,
		"total_parallel_octaves": 0,
		"details": []
	}

	if chords == null or chords.size() < 2:
		return result

	# Parcours des pas i -> i+1
	for i in range(chords.size() - 1):
		var c1 = chords[i]
		var c2 = chords[i + 1]

		# Validation minimale (4 voix)
		if c1 == null or c2 == null or c1.size() != 4 or c2.size() != 4:
			#	#DEBUG: entrée invalide; on ignore ce pas
			continue

		var step_fifths = []
		var step_octaves = []

		for pair in _voice_pairs:
			var v1 = pair[0]
			var v2 = pair[1]

			var n1a = int(c1[v1])
			var n1b = int(c1[v2])
			var n2a = int(c2[v1])
			var n2b = int(c2[v2])

			# Mouvement (même sens requis)
			var d1 = n2a - n1a
			var d2 = n2b - n1b
			if d1 == 0 or d2 == 0:
				#	#RÈGLE: si une voix reste fixe, pas de "parallèle" (contrairement à mouvement oblique)
				continue
			if (d1 > 0 and d2 > 0) or (d1 < 0 and d2 < 0):
				# Intervalle au départ et à l’arrivée (mod 12)
				var int_start = _mod12(n1a - n1b)
				var int_end = _mod12(n2a - n2b)

				# Normaliser direction-insensitif (5e = ±7 mod 12, 8ve = 0)
				if int_start == 7 and int_end == 7:
					step_fifths.append({"voices": pair, "from": n1a, "to": n2a, "from_other": n1b, "to_other": n2b})
				elif int_start == 0 and int_end == 0:
					step_octaves.append({"voices": pair, "from": n1a, "to": n2a, "from_other": n1b, "to_other": n2b})

		# Accumulation des résultats
		if step_fifths.size() > 0:
			result.parallel_fifths_indices.append(i)
			result.total_parallel_fifths += step_fifths.size()
		if step_octaves.size() > 0:
			result.parallel_octaves_indices.append(i)
			result.total_parallel_octaves += step_octaves.size()

		result.details.append({
			"index": i,
			"fifths": step_fifths,
			"octaves": step_octaves
		})

	return result


func _mod12(v: int) -> int:
	var m = v % 12
	if m < 0:
		m += 12
	return m

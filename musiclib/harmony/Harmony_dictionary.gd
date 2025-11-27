extends Node
class_name Harmony_dictionary

const TAG = "Harmony_dictionary"

static func get_blabla(d:Degree) -> String:
	var txt = ""
	match d.kind:
		"N6":
			txt += "N6: Napolitan Sixth is a pre-dominant chord. Can be followed by: \n- cad64 [shift-C]\n"
			txt += "- the dominant V [shift-5] (use [shift-M] if you get a 'v' in lowercase.)\n"
			txt += "- Ger+6 [shift-G] -> you can press twice to get the inverted Ger+6\n"
			txt += "- vii°/V : [Alt-Shift-7] before a V dominant chord:  N6 -> vii°/V -> V\n"
			txt += "- vii°/V : [Alt-Shift-7] before a V dominant chord:  N6 -> vii°/V -> V\n"
			txt += "- N6 can be set as a secondary N6, press [Shift-Alt-N] to target any V chord"
			return txt
		"diatonic":
			match d.degree_number:
				1:  
					txt += 'The first Degree is the tonic of the scale. It is the "home" chord, beginning with Degree1 will set the key root\n'
					txt += "The 5 to 1 (perfect cadence is a very strong move) is often used at the end of a progression"
					txt += "Using a 1 in first inversion [Shift + ] after a V will attenuate the ending effect"
					txt += "For a chromatic gesture, Degree 1 in minor scale can go to a German augmented Sixth [Shift-G], especially in first inversion"
					
				2:
					txt += "The degree 2 can be followed by the degree 4, 5, 6 or degree 1 with an inversion.\n"
					txt += "[Shift-(degree number)], use [Shift + ] to invert the selected degree\n"
					txt += "\nFor a chromatic gesture, 2 can go to a N6 [Shift-N]\n"
					txt += "Degree 2 in first inversion ([Shift] + ) can also be followed by an Augmented Sixth [Shift-I] / [Shift-F] / [Shift-G]"
				
				3:
					txt += "The degree 3 is a mediant chord. Degree 1 to degree 3 is a kind of static move\n"
					txt += "in minor key, the III chord sets a major mood. In major key, the iii chord sets a minor mood.\n"
					txt += "It is a good candidate for modal mixture: A major III in major key acts as a secondary dominant of the relative minor key and creates a darmatic effect.\n"
					txt += "Using the Third Degree is not common in the harmonic minor key because of its augmented triad).\n"
	
				
				4:
					txt += "The degree 4 can be followed by the degree 2, 5, 6 or to degree 1 for a plagal cadence, [Shift-(degree number)]\n"
					txt += "\nFor a chromatic gesture, Degree 4 may precede a N6 [Shift-N], or an Augmented Sixth [Shift-I] / [Shift-F] / [Shift-G], especially in first inversion [Shift +]\n" 
					txt += "Degree 4 is also a good candidate for a modal mixture [Shift-M] (Major to mineur scale)\n"
				
				5:
					txt += "The degree 5 is the dominant chord in tonal keys if it is a major chord (and if degree 1 is not diminished or augmented).\n"
					txt += "Then, V can be followed by the tonic degree (degree 1) for a perfect cadence or by the degree 6 for a deceptive cadence\n"
					txt += "In a modal progression, avoid perfect cadence (V -> I or V -> i). But the reverse motion i -> V or I to V works fine at the end to loop of a modal progression\n"
				
				
			
		_:
			LogBus.error(TAG,d.kind + " degree " + str(d.degree_number) + " not implemented")
			
	return txt
	
			 

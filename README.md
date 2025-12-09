# musicLib
MusicLib est une librairie Godot 3.6 qui permet de manipuler des progressions d’accords en se référant à l’approche de l’harmonie classique: Tonalités, degrés, et les outils classiques : sixtes napolitaines, augmentées, dominantes secondaires…


L’objet central de musicLib est l’objet Degree

Pour créer un Degree:
var d:Degree = Degree.new()
Par défaut, un degré est le degré 1 de la tonalité Do majeur (une triade de Do majeur)

Pour assigner une tonalité à un degré :
d.key =  hk

Ou hk est un objet HarmonicKey (HarmonicKey.gd)

Une tonalité HarmonicKey est définie par 

- root_midi:int  la hauteur midi de la note racine de la tonalité
Par exemple pour instancier la tonalité La mineur, le root peut être 67 ou 7 
(cela revient au même car en interne elle est traitée modulo 12:  0 pour Do, 1 pour Do#, 2 pour Ré etc… jusqu’à Si = 11)

- scale_name:string  c’est le mode de la tonalité
En tonal, nous avons les 4 modes de base: « major », « minor » « harmonic_minor » et « melodic_minor »

Mais la tonalité peut être modale ou exotique. Chaque mode comporte 7 notes et donc 7 degrés lui sont associés.

La liste des modes ou valeurs disponibles de scale_name est : [ionian, dorian, phrygian, lydian, mixolydian, aeolian, locrian, major, minor, harmonic_minor, locrian_n6, ionian_#5, ukrainian_dorian, phrygian_dominant, lydian_#2, ultralocrian, melodic_minor, dorian_b2, lydian_#5, overtone, hindu, half_diminished, altered, harmonic_major, double_harmonic, double_harmonic_major, byzantine, gypsy_major, hungarian_major, hungarian_minor, gypsy_minor, neapolitan_major, neapolitan_minor, enigmatic, persian, major_locrian, leading_whole_tone, romanian_major]

Pour instancier une tonalité :
var myKey:HarmonicKey = HarmonicKey.new() 
myKey.root_midi = 2 			# ré
myKey.scale_name = "harmonic_minor" # mode mineur harmonique

On peut alors assigner une tonalité à notre degré:
d.key = myKey

Le Degree a aussi une propriété degree_number qui définit son degré dans la tonalité 

d.degree_number:int un nombre de 1 à 7
Attention, pour suivre la terminologie de l’harmonie classique, le degré tonique de la tonalité est le degré 1, pas le degré 0.
Si d.degree_number = 2	

Chaque objet a une fonction to_string() -> string qui permet d’afficher ses caractéristiques

D’autre part, MusicLib utilise un objet LogBus pour tracer / debugger, afficher des messages à l’utilisateur
Chaque objet de musicLib a une constante const TAG = nom_de_l_objet
Et peut communiquer ainsi 
	
Par exemple :
LogBus.debug(TAG,d.to_string() )


Affichera :
Degree: ii° of key: D harmonic_minor(62), Duration: 4 beats, harmonic function: PD
kind: diatonic, realization: [1, 3, 5], inversion: 0
Roman Numeral: ii°, jazz chord: Edim, midi: [64, 67, 70] -> [E4, G4, A#4] 

On observe d’autres variables du Degree:

Sa durée (exprimée en beat) : d.length_beats = 4 # une ronde
Sa réalisation d.realization = [1,3,5,7] -> notre degré sera une tétrade composé de sa fondamentale, sa tierce, sa quinte et sa septième)
Son renversement : d.inversion:int = 1 # premier renversement, la basse de l’accord est sa tierce 
Sa fonction harmonique : T PD ou D pour Tonique, Dominante ou Sous-Dominante
Par exemple : d.set_harmonic_function(« PD »)
Un degré a un kind.
Par défaut, le kind est « diatonique »
Mais il peut aussi être la sixte Napolitaine N6 ou une sixte augmentée, ou l’accord cadentiel cad64.
Dans ce cas, le degré degree_number est ignoré ainsi que realization.
Des setters existent pour former ces degrés spéciaux.
d.Set_N6() pour faire de notre degré la sixte napolitaine
d.set_aug6_It() pour la sixte augmentée italienne

On a aussi des kind  pour un accord avec 9eme ou 11eme ou un accord sus2 ou sus4.

Enfin, le kind « melodic » est un degré qui a pour particularité de ne contenir qu’un seule note, la fondamentale du degré.

Voici la liste des kind reconnus :
["melodic","diatonic","secondary","It+6","Fr+6","Ger+6", "It+6inv","Fr+6inv","Ger+6inv", "N6","chrom.","cad64","sus2","sus4","add9","add11"]
(« Chrom » n’est à ce jour pas implémententé)


D’autre part, le degré peut être altéré :
func set_key_alteration(degree:int,alter:alter):
Ou degree est le degré DANS LA TONALITE et alter l’alteration appliquée
Par exemple, le degré peut altérer sa tonalité harmonic_minor avec :
d. set_key_alteration(6,1) pour ajouter un dièse au sixième degré et en faire la tonalité melodic_minor.

Les altérations sont stockés dans dictionnaire contenant un dictionnaire pour chaque degré altéré
d._alterations : {6:1}

Enfin, un champs d.comment:String permet d’écrire librement un commentaire dans le degré, pour signaler une dominante secondaire par exemple…

Nos degrés peuvent être placés dans une piste Track:

var tr:Track = Track.new()

Pour ajouter notre degré dans la piste tr sur le 3eme temps 
tr.add_degree(2,d)
(Le temps 0 de track est le 1er temps, et réciproquement, pour placer le degré d sur le 3eme temps, la valeur en temps renseignée pour add_degree  sera 2)

Les degrés ont aussi une valeur de vélocité midi
d.velocity = 90 affectera la valeur 90 à la vélocité des notes midi quand le degré sera joué.


Les objets Track peuvent être ajoutées à un objet Song.
Var mySong:Song = Song.new()
Les variables intéressantes sont
La signature rythmique :

Par exemple, 
mySong.time_num = 3
mySong.time_den = 4 
... pour une signature de valse.

Et bien sur un tempo, par exemple 
mySong.tempo_bpm = 140 

Enfin les objets « classiques »:
Les objets Note, ProgramChange et MidiCC (dans le dossier music lib/Core) 
qui sont plutôt orientés midi.

MusicLib permet d’associer des accords de guitare à un degré quelconque, de les afficher,  et également d’afficher le contenu d’une piste sous différentes formes : notation roman numéral, notes midi, jazz chord ou enfin clavier grâce à l’objet songTrackView.

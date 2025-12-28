# TitleGenerator.gd (Godot 3.x)
extends Node
class_name TitleGenerator


# Attacher à titleGenerator un child Node "dico"  
# et lui attacher le script EnglishDico.gd  !!!!
export onready var dico = $dico

onready var _adjectives = dico.array_adjectifs
onready var _nouns = dico.array_nom_communs

var rng = RandomNumberGenerator.new()

		
func _clean_word(s:String) -> String:
	return s.strip_edges()  # supprime espaces/tabs en début/fin

func _pick_random(list:Array) -> String:
	if list.empty():
		return ""
		print("empty !")
	return list[rng.randi() % list.size()]


# capitalize_each_word = true => "brave world" -> "Brave World"
func generate_title(mySeed, capitalize_each_word = true) -> String:
	#LogBus.info("TAG","Random seed: "+str(mySeed))
	rng.seed = mySeed
	var adj  = _pick_random(_adjectives)
	var noun = _pick_random(_nouns)

	if adj == "" and noun == "":
		print("la loose")
		return ""

	var title = (adj + " " + noun).strip_edges()
	if capitalize_each_word:
		title = title.to_lower().capitalize()
	return title



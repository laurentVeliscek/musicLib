extends Node

const TAG = "TestPartimentoLoad"

const PartimentoRealizer = preload("res://addons/musiclib/harmony/partimento/PartimentoRealizer.gd")
const PartimentoConverter = preload("res://addons/musiclib/harmony/partimento/PartimentoConverter.gd")

func _ready():
	run()

func run():
	var realizer = PartimentoRealizer.new()
	var converter = PartimentoConverter.new()
	assert(realizer is PartimentoRealizer)
	assert(converter is PartimentoConverter)
	LogBus.info(TAG, "PartimentoRealizer instancié: " + str(realizer))
	LogBus.info(TAG, "PartimentoConverter instancié: " + str(converter))

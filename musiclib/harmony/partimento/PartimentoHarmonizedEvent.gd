extends Reference
class_name PartimentoHarmonizedEvent

const TAG = "PartimentoHarmonizedEvent"

var basso_event:PartimentoBassoEvent = null setget set_basso_event, get_basso_event
var figure:Array = [] setget set_figure, get_figure
var inversion:int = 0 setget set_inversion, get_inversion
var mode_variant:String = "" setget set_mode_variant, get_mode_variant
var is_secondary:bool = false setget set_is_secondary, get_is_secondary
var secondary_target_degree:int = 0 setget set_secondary_target_degree, get_secondary_target_degree
var is_borrowed:bool = false setget set_is_borrowed, get_is_borrowed
var options:Dictionary = {}


func set_basso_event(event:PartimentoBassoEvent) -> void:
	basso_event = event


func get_basso_event() -> PartimentoBassoEvent:
	return basso_event


func set_figure(value:Array) -> void:
	figure = []
	for v in value:
		if typeof(v) == TYPE_INT:
			figure.append(v)


func get_figure() -> Array:
	return figure


func set_inversion(value:int) -> void:
	inversion = max(0, value)


func get_inversion() -> int:
	return inversion


func set_mode_variant(value:String) -> void:
	mode_variant = value


func get_mode_variant() -> String:
	return mode_variant


func set_is_secondary(value:bool) -> void:
	is_secondary = value


func get_is_secondary() -> bool:
	return is_secondary


func set_secondary_target_degree(value:int) -> void:
	secondary_target_degree = max(0, value)


func get_secondary_target_degree() -> int:
	return secondary_target_degree


func set_is_borrowed(value:bool) -> void:
	is_borrowed = value


func get_is_borrowed() -> bool:
	return is_borrowed


func to_dict() -> Dictionary:
	var data:Dictionary = {
		"figure": figure.duplicate(),
		"inversion": inversion,
		"mode_variant": mode_variant,
		"is_secondary": is_secondary,
		"secondary_target_degree": secondary_target_degree,
		"is_borrowed": is_borrowed,
		"options": options.duplicate(true)
	}
	if basso_event != null:
		data["basso"] = basso_event.to_dict()
	return data

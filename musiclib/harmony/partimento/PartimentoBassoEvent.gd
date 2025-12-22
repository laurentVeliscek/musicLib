extends Reference
class_name PartimentoBassoEvent

const TAG = "PartimentoBassoEvent"

enum Tag {
	NONE,
	CADENCE,
	SEQUENCE
}

var degree:int = 1 setget set_degree, get_degree
var position:float = 0.0 setget set_position, get_position
var duration:float = 1.0 setget set_duration, get_duration
var tags:Array = [] setget set_tags, get_tags
var label:String = ""
var metadata:Dictionary = {}


func _init(_degree:int = 1, _position:float = 0.0, _duration:float = 1.0, _tags:Array = []):
	set_degree(_degree)
	set_position(_position)
	set_duration(_duration)
	set_tags(_tags)


func set_degree(value:int) -> void:
	degree = int(clamp(value, 1, 7))


func get_degree() -> int:
	return degree


func set_position(value:float) -> void:
	position = max(0.0, value)


func get_position() -> float:
	return position


func set_duration(value:float) -> void:
	duration = max(0.0, value)


func get_duration() -> float:
	return duration


func set_tags(values:Array) -> void:
	tags = []
	for t in values:
		if typeof(t) == TYPE_INT and not tags.has(t):
			tags.append(t)


func get_tags() -> Array:
	return tags


func add_tag(tag:int) -> void:
	if typeof(tag) == TYPE_INT and not tags.has(tag):
		tags.append(tag)


func has_tag(tag:int) -> bool:
	return tags.has(tag)


func to_dict() -> Dictionary:
	return {
		"degree": degree,
		"position": position,
		"duration": duration,
		"tags": tags.duplicate(),
		"label": label,
		"metadata": metadata.duplicate(true)
	}

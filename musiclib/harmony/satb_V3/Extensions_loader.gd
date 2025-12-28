# res://musiclib/extensions_loader.gd
extends Reference
class_name Extensions_loader

var spec: Dictionary = {}

# le style est défini lors de l'appel de 
# get_policy(fig:String, rn:String, style:String) -> Dictionary:
# par défaut, il adopte la valeur de style_default
var style_default = "classique"	# ou "moderne"


var path:String =  "res://addons/musiclib/harmony/satb_V3/specs/extensions.json"
var TAG = "[Extensions_loader]"

func _init():
	LogBus.debug(TAG,"loading JSON from path:"+ path+"...")
	load_from(path)



func load_from(path:String) -> bool:
	var f = File.new()
	if not f.file_exists(path):
		LogBus.error(TAG,"[extensions] file not found: " + path)
		push_error(str("[extensions] file not found: ", path))
		return false
	var err = f.open(path, File.READ)
	if err != OK:
		LogBus.error(TAG,"[extensions] open error: " + str(err))
		push_error(str("[extensions] open error: ", err))
		return false
	var txt = f.get_as_text()
	f.close()
	var p = JSON.parse(txt)
	if p.error != OK:
		LogBus.error(TAG,"[extensions] JSON parse error at line " + str(p.error_line) +  ": " +  p.error_string)
		push_error(str("[extensions] JSON parse error at line ", p.error_line, ": ", p.error_string))
		return false
	var data = p.result
	if not data.has("extensions"):
		LogBus.error(TAG,"[extensions] missing 'extensions' array")
		push_error("[extensions] missing 'extensions' array")
		return false
	else:
		LogBus.debug(TAG,"[extensions] successfully loaded !")
		
	spec = data
	style_default = "classique"
	return true

func get_style_default() -> String:
	return style_default

func get_global_rules() -> Dictionary:
	if spec.has("global_rules"):
		return spec["global_rules"]
	return {}

func get_extension_ids() -> Array:
	var ids = []
	if not spec.has("extensions"):
		return ids
	for e in spec["extensions"]:
		if e.has("id"):
			ids.append(e["id"])
	return ids

func get_policy(fig:String, rn:String, style:String) -> Dictionary:
	if not spec.has("extensions"):
		return {}
	var s = style
	if s == null or s == "":
		s = style_default
	for e in spec["extensions"]:
		if e.get("id","") != fig:
			continue
		if not e.has("variants"):
			continue
		for v in e["variants"]:
			var scope_ok = false
			if v.has("roman_scope"):
				for tag in v["roman_scope"]:
					if tag == rn:
						scope_ok = true
						break
					if tag == "V/deg" and rn.begins_with("V"):
						scope_ok = true
						break
			if not scope_ok:
				continue
			var out = v.duplicate(true)
			if v.has("style") and v["style"].has(s):
				out["treatment"] = v["style"][s].get("treatment", "essential")
				if v["style"][s].has("require_immediate_resolution"):
					out["require_immediate_resolution"] = v["style"][s]["require_immediate_resolution"]
				if v["style"][s].has("allow_as_chord_tone"):
					out["allow_as_chord_tone"] = v["style"][s]["allow_as_chord_tone"]
				if v["style"][s].has("limit_beyond_9"):
					out["limit_beyond_9"] = v["style"][s]["limit_beyond_9"]
			return out
	return {}


#func load_from(path:String) -> bool:
#	# Charge le JSON et fait une validation légère
#	var f = File.new()
#	var ok = f.file_exists(path)
#	if not ok:
#		LogBus.error(TAG,"[extensions] file not found: " + path)
#		push_error(str("[extensions] file not found: ", path))
#		return false
#	var err = f.open(path, File.READ)
#	if err != OK:
#		LogBus.error(TAG,"[extensions] open error: " + str(err))
#		push_error(str("[extensions] open error: ", err))
#		return false
#	var txt = f.get_as_text()
#	f.close()
#	var data = {}
#	var parse = JSON.parse(txt)
#	if parse.error != OK:
#		LogBus.error(TAG,"[extensions] JSON parse error at line " + str(parse.error_line) +  ": " +  parse.error_string)
#		push_error(str("[extensions] JSON parse error at line ", parse.error_line, ": ", parse.error_string))
#		return false
#	data = parse.result
#	# validations minimales
#	if not data.has("extensions"):
#		push_error("[extensions] missing 'extensions' array")
#		return false
#	spec = data
#	style_default = "classique"
#	if data.has("style_switch") and data["style_switch"].has("moderne"):
#		# on garde "classique" par défaut sauf si tu veux changer ici
#		pass
#	return true
#
#func get_style_default() -> String:
#	return style_default
#
#func get_global_rules() -> Dictionary:
#	if spec.has("global_rules"):
#		return spec["global_rules"]
#	return {}
#
#func get_extension_ids() -> Array:
#	var ids = []
#	if not spec.has("extensions"):
#		return ids
#	for e in spec["extensions"]:
#		if e.has("id"):
#			ids.append(e["id"])
#	return ids
#
#func get_policy(fig:String, rn:String, style:String) -> Dictionary:
#	# Retourne la meilleure variante (policy) pour une extension et un RN donnés
#	# fig ex: "9","b9","#9","11","#11","13","b13","add6","add9","6/9"
#	# rn ex: "V","ii","I",...
#	# style: "classique" ou "moderne"
#	if not spec.has("extensions"):
#		return {}
#	var s = style
#	if s == null or s == "":
#		s = style_default
#	for e in spec["extensions"]:
#		if e.get("id","") != fig:
#			continue
#		if not e.has("variants"):
#			continue
#		# chercher la 1ère variante dont roman_scope contient le rn demandé (ou un fallback)
#		var best = {}
#		for v in e["variants"]:
#			var scope_ok = false
#			if v.has("roman_scope"):
#				for tag in v["roman_scope"]:
#					if tag == rn:
#						scope_ok = true
#						break
#					# support simple V/deg: on matche "V" si rn commence par "V"
#					if tag == "V/deg" and rn.begins_with("V"):
#						scope_ok = true
#						break
#			if not scope_ok:
#				continue
#			# fusionne style local si présent
#			var out = v.duplicate(true)
#			if v.has("style") and v["style"].has(s):
#				out["treatment"] = v["style"][s].get("treatment", "essential")
#				if v["style"][s].has("require_immediate_resolution"):
#					out["require_immediate_resolution"] = v["style"][s]["require_immediate_resolution"]
#				if v["style"][s].has("allow_as_chord_tone"):
#					out["allow_as_chord_tone"] = v["style"][s]["allow_as_chord_tone"]
#				if v["style"][s].has("limit_beyond_9"):
#					out["limit_beyond_9"] = v["style"][s]["limit_beyond_9"]
#			best = out
#			break
#		return best
#	return {}

class PlayerClass extends RefCounted:
	var max_hp : int
	var display_name : String
	var id : int
	var deck_id : int
	

	# takes in a json string which is the data representation for a given class
	func _init(data: Dictionary = {}):

		max_hp = int(data.get("max_hp"))
		display_name = data.get("display_name")
		id = int(data.get("id"))
		deck_id = int(data.get("deck_id"))

static func from_json_string(json_string: String) -> PlayerClass:
	var json = JSON.new()
	var error =  json.parse(json_string)
	if error != OK:
		push_error("Failed to parse PlayerClass JSON: %s (line %d)" % [json.get_error_message(), json.get_error_line()])
		return null
	
	return PlayerClass.new(json.data)


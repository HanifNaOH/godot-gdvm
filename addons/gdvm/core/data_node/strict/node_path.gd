extends DataNodeStrict
const DataNodeStrict = preload("./base.gd")

var _data: NodePath

func _init(value: NodePath) -> void:
	render(value)

func _set_value(value: Variant) -> bool:
	assert(is_instance_of(value, TYPE_STRING) or is_instance_of(value, TYPE_STRING_NAME) or is_instance_of(value, TYPE_NODE_PATH))
	_data = str(value)
	return true

func _get_value() -> Variant:
	return _data
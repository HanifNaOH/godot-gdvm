extends DataNodeStrict
const DataNodeStrict = preload("./base.gd")

var _data: float

func _init(value: float) -> void:
	render(value)

func _set_value(value: Variant) -> bool:
	assert(is_instance_of(value, TYPE_INT) or is_instance_of(value, TYPE_BOOL) or is_instance_of(value, TYPE_FLOAT))
	_data = value
	return true

func _get_value() -> Variant:
	return _data
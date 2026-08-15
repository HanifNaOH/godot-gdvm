## TodoItemModel
## The Model layer — plain source data (not observable by the View), matching
## the example-9 architecture: Model -> ViewModel -> View.
class_name TodoItemModel
extends RefCounted

var content: String = ""
var checked: bool = false


func _init(p_content: String = "", p_checked: bool = false) -> void:
	content = p_content
	checked = p_checked

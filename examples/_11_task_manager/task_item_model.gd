## TaskItemModel
## The Model layer for _11_task_manager — plain source data, not observable.
##
## Holds the source-of-truth fields the ViewModel translates into view-ready
## state. Follows the Model -> ViewModel -> View architecture (example 9/10).
class_name TaskItemModel
extends RefCounted

## Priority levels (stored as int for easy sorting).
enum Priority { NONE = 0, LOW = 1, MEDIUM = 2, HIGH = 3 }

var title: String = ""
var done: bool = false
var priority: int = Priority.NONE
## Due date as a unix timestamp (seconds). 0 means no due date.
var due_date: int = 0
## Creation time (unix seconds) — used as a stable tiebreak for sorting.
var created: int = 0


func _init(p_title: String = "", p_priority: int = Priority.NONE, p_due_date: int = 0) -> void:
	title = p_title
	priority = p_priority
	due_date = p_due_date
	created = int(Time.get_unix_time_from_system())

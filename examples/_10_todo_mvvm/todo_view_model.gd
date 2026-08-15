## TodoViewModel
## The single ViewModel for _10_todo_mvvm — the only ViewModel in the example
## (matching example 9). Extends ObservableObject and exposes view-ready,
## change-notifying properties that the scene binds to via _gdvm_binding metadata.
##
## The list of todos is an Array of TodoItemModel (plain data). Per-item row
## views read/write those models through this VM's methods (edit, toggle,
## remove). No Messenger, no per-item ViewModel — just one VM.
class_name TodoViewModel
extends ObservableObject

const TodoItemModelScript = preload("./todo_item_model.gd")

## The observable collection bound to the Todos container (list binding).
var items: Array = []:
	set(v):
		if set_property(&"items", items, v):
			items = v
			_recompute_aggregates()

## Footer / header aggregate state (all bound one-way in the scene).
var items_count: int = 0:
	set(v):
		if set_property(&"items_count", items_count, v):
			items_count = v

var items_left: int = 0:
	set(v):
		if set_property(&"items_left", items_left, v):
			items_left = v

var items_left_text: String = "":
	set(v):
		if set_property(&"items_left_text", items_left_text, v):
			items_left_text = v

var all_checked: bool = false:
	set(v):
		if set_property(&"all_checked", all_checked, v):
			all_checked = v

var has_items: bool = false:
	set(v):
		if set_property(&"has_items", has_items, v):
			has_items = v


func _init() -> void:
	items = []
	add_item("Example task")


## ── Actions (bound to View events via the code-behind) ─────────────────────

## Add a new todo from the input line edit text.
func add_item(content: String) -> void:
	if content.is_empty():
		return
	items.append(TodoItemModelScript.new(content, false))
	_items_changed()


## Toggle every item to `checked` (SelectAll checkbox).
func set_all_checked(checked: bool) -> void:
	for m: TodoItemModel in items:
		m.checked = checked
	_recompute_aggregates()


## Remove every completed item.
func clear_completed() -> void:
	var kept := items.filter(func(m: TodoItemModel) -> bool:
		return not m.checked
	)
	if kept.size() == items.size():
		return
	items = kept


## ── Per-item mutations (called by item row views) ──────────────────────────

func set_item_checked(model: TodoItemModel, checked: bool) -> void:
	model.checked = checked
	_recompute_aggregates()


func set_item_content(model: TodoItemModel, content: String) -> void:
	if content.is_empty():
		return
	model.content = content


func remove_item(model: TodoItemModel) -> void:
	if items.has(model):
		items.erase(model)
		_items_changed()


## ── Internal ────────────────────────────────────────────────────────────────

## Notify the list binding + aggregates after an in-place structural mutation.
## GDScript's deep Array `==` means `items = items` compares equal, so the
## change must be broadcast explicitly (ObservableObject manual-notify API).
func _items_changed() -> void:
	_recompute_aggregates()
	notify_property_changed(&"items")


func _recompute_aggregates() -> void:
	var size := items.size()
	var completed := 0
	for m: TodoItemModel in items:
		if m.checked:
			completed += 1
	items_count = size
	items_left = size - completed
	items_left_text = "%s item%s left" % [items_left, "s" if items_left != 1 else ""]
	all_checked = size > 0 and completed == size
	has_items = size > 0

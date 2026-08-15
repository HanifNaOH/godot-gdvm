## TaskViewModel
## The single ViewModel for _11_task_manager (matching example 9's pattern).
##
## Owns the Array[TaskItemModel] and exposes:
##   - `items`          — the VISIBLE list (after filter + search + sort), bound
##                        to the Todos container via GdvmView list binding.
##   - `all_items`      — the full source list (all tasks, unsorted).
##   - aggregates       — items_count, active_count, completed_count, has_items.
##   - `filter`         — ALL / ACTIVE / COMPLETED.
##   - `search_text`    — filters by title substring.
##   - `sort_by`        — NONE / DUE / PRIORITY.
##
## Mutations always rebuild `items` from `all_items`, so the list binding stays
## in sync. Undo/redo uses snapshot stacks of the full task list.
class_name TaskViewModel
extends ObservableObject

const TaskItemModelScript = preload("./task_item_model.gd")

## ── State ───────────────────────────────────────────────────────────────────

## Full source list (all tasks regardless of filter/sort).
var all_items: Array = []:
	set(v):
		if set_property(&"all_items", all_items, v):
			all_items = v
			_rebuild_visible()

## The visible (filtered + searched + sorted) list bound to the view.
var items: Array = []:
	set(v):
		if set_property(&"items", items, v):
			items = v

## ── Filter / search / sort (observable, drive the visible list) ────────────
enum FilterMode { ALL, ACTIVE, COMPLETED }
enum SortMode { NONE, DUE, PRIORITY }

var filter: int = FilterMode.ALL:
	set(v):
		if set_property(&"filter", filter, v):
			filter = v
			_rebuild_visible()

var search_text: String = "":
	set(v):
		if set_property(&"search_text", search_text, v):
			search_text = v
			_rebuild_visible()

var sort_by: int = SortMode.NONE:
	set(v):
		if set_property(&"sort_by", sort_by, v):
			sort_by = v
			_rebuild_visible()

## ── Aggregates (bound in the scene) ────────────────────────────────────────
var items_count: int = 0:
	set(v):
		if set_property(&"items_count", items_count, v):
			items_count = v

var active_count: int = 0:
	set(v):
		if set_property(&"active_count", active_count, v):
			active_count = v

var completed_count: int = 0:
	set(v):
		if set_property(&"completed_count", completed_count, v):
			completed_count = v

var has_items: bool = false:
	set(v):
		if set_property(&"has_items", has_items, v):
			has_items = v

var active_left_text: String = "":
	set(v):
		if set_property(&"active_left_text", active_left_text, v):
			active_left_text = v

## Whether all tasks are done (SelectAll checkbox state). This is a *computed*
## read-mostly value; the view's SelectAll checkbox writes to it via
## set_all_done(). Keeping the setter side-effect-free avoids undo-snapshot
## churn during recompute and two-way echo loops.
var all_done: bool = false:
	set(v):
		if set_property(&"all_done", all_done, v):
			all_done = v

## Whether an undo is available (drives the Undo button's disabled state).
var can_undo: bool = false:
	set(v):
		if set_property(&"can_undo", can_undo, v):
			can_undo = v

var can_redo: bool = false:
	set(v):
		if set_property(&"can_redo", can_redo, v):
			can_redo = v

## ── Undo/redo snapshot stacks ──────────────────────────────────────────────
var _undo_stack: Array = []
var _redo_stack: Array = []


func _init() -> void:
	all_items = []
	add_task("Example task")


## ── Actions (bound to View events) ─────────────────────────────────────────

## Add a new task. Returns the created model (for optional follow-up).
func add_task(title: String, priority: int = TaskItemModel.Priority.NONE, due_date: int = 0) -> TaskItemModel:
	var title_trimmed := title.strip_edges()
	if title_trimmed.is_empty():
		return null
	_push_snapshot()
	var m := TaskItemModelScript.new(title_trimmed, priority, due_date)
	all_items.append(m)
	_after_mutation()
	return m


## Remove a task.
func remove_task(model: TaskItemModel) -> void:
	if not all_items.has(model):
		return
	_push_snapshot()
	all_items.erase(model)
	_after_mutation()


## Remove every completed task.
func clear_completed() -> void:
	var has_completed := all_items.any(func(m: TaskItemModel) -> bool:
		return m.done
	)
	if not has_completed:
		return
	_push_snapshot()
	all_items = all_items.filter(func(m: TaskItemModel) -> bool:
		return not m.done
	)
	_after_mutation()


## Toggle every task to `done` (bulk select-all).
func set_all_done(done: bool) -> void:
	if all_items.is_empty():
		return
	var changed := false
	for m: TaskItemModel in all_items:
		if m.done != done:
			changed = true
			break
	if not changed:
		return
	_push_snapshot()
	for m: TaskItemModel in all_items:
		m.done = done
	_after_mutation()


## Set the search filter text (driven by the Search LineEdit's text_changed).
func set_search_text(text: String) -> void:
	search_text = text


## ── Per-task mutations (called by row views) ───────────────────────────────

## Edit several fields at once (title/priority/due) under a single undo step.
func edit_task(model: TaskItemModel, title: String = "", priority: int = -1, due_date: int = -1) -> void:
	var trimmed := title.strip_edges()
	if trimmed.is_empty():
		trimmed = model.title
	var changed := trimmed != model.title
	if priority >= 0 and priority != model.priority:
		changed = true
	if due_date >= 0 and due_date != model.due_date:
		changed = true
	if not changed:
		return
	_push_snapshot()
	model.title = trimmed
	if priority >= 0:
		model.priority = priority
	if due_date >= 0:
		model.due_date = due_date
	_after_mutation()


func set_title(model: TaskItemModel, title: String) -> void:
	var trimmed := title.strip_edges()
	if trimmed.is_empty():
		return
	_push_snapshot()
	model.title = trimmed
	_after_mutation()


func set_done(model: TaskItemModel, done: bool) -> void:
	if model.done == done:
		return
	_push_snapshot()
	model.done = done
	_after_mutation()


func set_priority(model: TaskItemModel, priority: int) -> void:
	if model.priority == priority:
		return
	_push_snapshot()
	model.priority = priority
	_after_mutation()


func set_due_date(model: TaskItemModel, due_date: int) -> void:
	if model.due_date == due_date:
		return
	_push_snapshot()
	model.due_date = due_date
	_after_mutation()


## ── Undo / redo ─────────────────────────────────────────────────────────────

func undo() -> void:
	if _undo_stack.is_empty():
		return
	_redo_stack.push_front(_snapshot())
	all_items = _restore(_undo_stack.pop_front())
	_after_mutation()


func redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.push_front(_snapshot())
	all_items = _restore(_redo_stack.pop_front())
	_after_mutation()


## ── Internal ────────────────────────────────────────────────────────────────

## Take a deep snapshot of all_items as plain dictionaries. Array.duplicate(true)
## does NOT clone RefCounted objects (they are shared by reference), so we
## serialize each TaskItemModel into a dict to make undo/redo truly independent.
func _snapshot() -> Array:
	var out: Array = []
	for m: TaskItemModel in all_items:
		out.append({
			"title": m.title,
			"done": m.done,
			"priority": m.priority,
			"due_date": m.due_date,
			"created": m.created,
		})
	return out


## Rebuild a fresh list of TaskItemModel instances from a snapshot array.
func _restore(snapshot: Array) -> Array:
	var out: Array = []
	for d: Dictionary in snapshot:
		var m := TaskItemModelScript.new(d["title"], d["priority"], d["due_date"])
		m.done = d["done"]
		m.created = d["created"]
		out.append(m)
	return out


## Push the current state onto the undo stack (called before a mutation).
func _push_snapshot() -> void:
	_undo_stack.push_front(_snapshot())
	if _undo_stack.size() > 100:
		_undo_stack.pop_back()
	_redo_stack.clear()


## Refresh aggregates + visible list + undo/redo flags after any mutation.
func _after_mutation() -> void:
	_update_undo_flags()
	_rebuild_visible()


## Rebuild `items` from `all_items` applying filter + search + sort.
func _rebuild_visible() -> void:
	var result: Array = []
	for m: TaskItemModel in all_items:
		# Filter
		match filter:
			TaskViewModel.FilterMode.ACTIVE:
				if m.done:
					continue
			TaskViewModel.FilterMode.COMPLETED:
				if not m.done:
					continue
		# Search (case-insensitive substring)
		if not search_text.is_empty():
			if not m.title.to_lower().contains(search_text.to_lower()):
				continue
		result.append(m)

	# Sort
	match sort_by:
		TaskViewModel.SortMode.DUE:
			_sort_by_due(result)
		TaskViewModel.SortMode.PRIORITY:
			_sort_by_priority(result)

	items = result
	_recompute_aggregates()


## Sort by due date (no-due last), then by creation time for stability.
func _sort_by_due(list: Array) -> void:
	list.sort_custom(func(a: TaskItemModel, b: TaskItemModel) -> bool:
		if a.due_date == b.due_date:
			return a.created < b.created
		# No-due tasks go to the end.
		if a.due_date == 0:
			return false
		if b.due_date == 0:
			return true
		return a.due_date < b.due_date
	)


## Sort by priority (descending, high first), then by due date, then created.
func _sort_by_priority(list: Array) -> void:
	list.sort_custom(func(a: TaskItemModel, b: TaskItemModel) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		if a.due_date != b.due_date:
			if a.due_date == 0:
				return false
			if b.due_date == 0:
				return true
			return a.due_date < b.due_date
		return a.created < b.created
	)


func _recompute_aggregates() -> void:
	var active := 0
	for m: TaskItemModel in all_items:
		if not m.done:
			active += 1
	items_count = all_items.size()
	active_count = active
	completed_count = all_items.size() - active
	has_items = all_items.size() > 0
	active_left_text = "%s task%s left" % [active, "s" if active != 1 else ""]
	# all_done = every task is done (and there is at least one). Setting it here
	# (rather than via the setter's side effect) keeps the checkbox in sync.
	var every_done := all_items.size() > 0 and active == 0
	if all_done != every_done:
		all_done = every_done


func _update_undo_flags() -> void:
	can_undo = not _undo_stack.is_empty()
	can_redo = not _redo_stack.is_empty()

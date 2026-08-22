## TaskManagerMainView
## The root View code-behind for _11_task_manager — thin, like example 9.
##
##   1. Creates the GdvmBinder and single TaskViewModel for explicit code-first
##      data binding (list + aggregates + search + filter/sort).
##   2. Binds each control's event to a ViewModel *function*.
##
## No business logic or state mutation lives here.
extends Control

var binder: GdvmBinder
@onready var select_all_checkbox := %SelectAll as CheckBox
@onready var new_task_line_edit := %NewTask as LineEdit
@onready var search_line_edit := %Search as LineEdit
@onready var tasks_container := %Tasks as VBoxContainer
@onready var footer := %Footer as Control
@onready var active_left_label := %ActiveLeft as Label
@onready var undo_button := %Undo as Button
@onready var redo_button := %Redo as Button
@onready var filter_all_button := %Filter/All as Button
@onready var filter_active_button := %Filter/Active as Button
@onready var filter_completed_button := %Filter/Completed as Button
@onready var sort_due_button := %SortDue as Button
@onready var sort_priority_button := %SortPriority as Button
@onready var clear_completed_button := %ClearCompleted as Button

const TaskRowScene = preload("./task_item.tscn")

var view_model: TaskViewModel


func _ready() -> void:
	binder = GdvmBinder.new(self)
	view_model = TaskViewModel.new()
	binder.set_view_model(view_model)

	# ── Code-first data bindings (VM -> node) ─────────────────────────────
	# Footer visibility + aggregate label.
	binder.bind(footer, "has_items", "visible")
	binder.bind(active_left_label, "active_left_text", "text")
	# Undo/Redo enabled state (can_undo true => disabled false).
	binder.bind(undo_button, "can_undo", "disabled", {
		"converter": &"bool_flip",
	})
	binder.bind(redo_button, "can_redo", "disabled", {
		"converter": &"bool_flip",
	})
	# SelectAll checkbox reflects all_done (one-way VM -> node).
	binder.bind(select_all_checkbox, "all_done", "button_pressed")
	# The task list: instantiate one task_item.tscn per model in `items`.
	# New rows slide in; removed rows slide out then free themselves.
	binder.bind_list(tasks_container, "items", TaskRowScene, {
		"on_added": _slide_row_in,
		"on_removed": _slide_row_out,
	})

	# Task creation
	new_task_line_edit.text_submitted.connect(_on_new_task_submitted)

	# Select-all (the checkbox state is bound one-way from all_done; the toggle
	# event drives the bulk mutation).
	select_all_checkbox.toggled.connect(view_model.set_all_done)

	# Filter buttons
	filter_all_button.pressed.connect(func(): view_model.filter = TaskViewModel.FilterMode.ALL)
	filter_active_button.pressed.connect(func(): view_model.filter = TaskViewModel.FilterMode.ACTIVE)
	filter_completed_button.pressed.connect(func(): view_model.filter = TaskViewModel.FilterMode.COMPLETED)

	# Sort buttons
	sort_due_button.pressed.connect(func(): _toggle_sort(TaskViewModel.SortMode.DUE))
	sort_priority_button.pressed.connect(func(): _toggle_sort(TaskViewModel.SortMode.PRIORITY))

	# Bulk / undo
	clear_completed_button.pressed.connect(view_model.clear_completed)
	undo_button.pressed.connect(view_model.undo)
	redo_button.pressed.connect(view_model.redo)

	# Undo/redo shortcut keys
	var shortcut_undo := Shortcut.new()
	shortcut_undo.events = [InputEventKey.new()]
	(shortcut_undo.events[0] as InputEventKey).keycode = KEY_Z
	(shortcut_undo.events[0] as InputEventKey).ctrl_pressed = true
	undo_button.shortcut = shortcut_undo
	undo_button.shortcut_feedback = false

	var shortcut_redo := Shortcut.new()
	shortcut_redo.events = [InputEventKey.new()]
	(shortcut_redo.events[0] as InputEventKey).keycode = KEY_Y
	(shortcut_redo.events[0] as InputEventKey).ctrl_pressed = true
	redo_button.shortcut = shortcut_redo
	redo_button.shortcut_feedback = false

	# Search: explicit event binding (avoids two_way echo that corrupts typing).
	search_line_edit.text_changed.connect(view_model.set_search_text)
	search_line_edit.text_submitted.connect(func(_t: String): search_line_edit.release_focus())


func _exit_tree() -> void:
	if binder != null:
		binder.dispose()


func _on_new_task_submitted(new_text: String) -> void:
	if not new_text.is_empty():
		view_model.add_task(new_text)
		new_task_line_edit.text = ""
	new_task_line_edit.release_focus()


func _toggle_sort(mode: int) -> void:
	# Clicking the active sort button again clears sorting.
	view_model.sort_by = TaskViewModel.SortMode.NONE if view_model.sort_by == mode else mode


## Row enter animation (bound via bind_list's on_added).
## Animate the row's custom_minimum_size.y + alpha so the container reflows
## smoothly and neighbors slide with it — no overlap/collision.
func _slide_row_in(item: Node) -> void:
	if not item is Control:
		return
	var control := item as Control
	var target_height: float = control.custom_minimum_size.y
	if target_height <= 0.0:
		target_height = control.size.y
	# Start collapsed + invisible.
	control.custom_minimum_size.y = 0.0
	control.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "custom_minimum_size:y", target_height, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.25)


## Row exit animation (bound via bind_list's on_removed). Collapses the row's
## custom_minimum_size.y + fades out, so the container reflows neighbors with it.
## The engine calls this AFTER removing the row from the tree.
func _slide_row_out(item: Node) -> void:
	if not item is Control:
		item.queue_free()
		return
	var control := item as Control
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "custom_minimum_size:y", 0.0, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(control, "modulate:a", 0.0, 0.2)
	tween.tween_callback(control.queue_free)

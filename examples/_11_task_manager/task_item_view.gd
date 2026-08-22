## TaskItemView
## The View code-behind for a single task row (task_item.tscn). Thin, like ex9/10.
##
## Holds only *view* logic: checkbox toggle, double-click-to-edit title, remove.
## All data mutation is delegated to the root TaskViewModel. The row receives
## its backing TaskItemModel via the GdvmBinder list binding's `set_item()`.
extends VBoxContainer

@onready var normal_mode_container := %NormalMode as PanelContainer
@onready var edit_mode_container := %EditMode as PanelContainer
@onready var done_checkbox := %Done as CheckBox
@onready var title_label := %Title as RichTextLabel
@onready var meta_label := %Meta as Label
@onready var remove_button := %Remove as Button
@onready var title_input := %TitleEdit as LineEdit
@onready var priority_input := %Priority as OptionButton
@onready var due_input := %Due as SpinBox

## The root ViewModel, resolved from the ancestor root view.
var view_model: TaskViewModel
## This row's backing Model, handed in by the list binding.
var model: TaskItemModel

## Cache the last hover state to avoid the button-vs-row hover flicker.
var _hovered: bool = false
## True once _ready() has run (so set_item can tell first-build vs in-place update).
var _ready_called: bool = false


## Invoked by the GdvmBinder list binding for each element. Fires BEFORE the node
## enters the tree on first creation, but is ALSO called to update an existing
## (already in-tree) row in place when the list reconciles (filter/search/sort).
## So we store the model and, if the node is already ready, re-render immediately.
func set_item(element) -> void:
	model = element
	if _ready_called:
		_render()


func _ready() -> void:
	view_model = _find_root_view_model()
	if model != null:
		_render()
	_ready_called = true

	# Populate the priority dropdown (None/Low/Medium/High).
	priority_input.clear()
	priority_input.add_item("None", TaskItemModel.Priority.NONE)
	priority_input.add_item("Low", TaskItemModel.Priority.LOW)
	priority_input.add_item("Medium", TaskItemModel.Priority.MEDIUM)
	priority_input.add_item("High", TaskItemModel.Priority.HIGH)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	remove_button.pressed.connect(func():
		if view_model != null:
			view_model.remove_task(model)
	)
	done_checkbox.toggled.connect(func(toggled_on: bool):
		if view_model != null:
			view_model.set_done(model, toggled_on)
		_render()
	)
	title_label.gui_input.connect(_on_double_click_title)
	title_input.text_submitted.connect(_on_title_submitted)
	title_input.gui_input.connect(_on_title_gui_input)
	title_input.focus_exited.connect(_on_title_exited)


## Walk up the hierarchy to find the ancestor root view that owns the ViewModel.
func _find_root_view_model() -> TaskViewModel:
	var ancestor := get_parent()
	while ancestor != null:
		if "view_model" in ancestor:
			var vm = ancestor.get("view_model")
			if vm is TaskViewModel:
				return vm
		ancestor = ancestor.get_parent()
	return null


## Render the current model state into the row's controls.
func _render() -> void:
	done_checkbox.set_pressed_no_signal(model.done)
	title_label.text = "[s]%s[/s]" % model.title if model.done else model.title
	meta_label.text = _format_meta()


func _format_meta() -> String:
	var parts: Array[String] = []
	if model.due_date > 0:
		var dt := Time.get_datetime_dict_from_unix_time(model.due_date)
		parts.append("%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]])
	match model.priority:
		TaskItemModel.Priority.HIGH:
			parts.append("HIGH")
		TaskItemModel.Priority.MEDIUM:
			parts.append("MED")
		TaskItemModel.Priority.LOW:
			parts.append("LOW")
	return "  ·  ".join(parts)


## Hover: reveal the remove button via alpha (keeps layout constant, no flicker).
func _on_mouse_entered() -> void:
	_hovered = true
	remove_button.modulate.a = 1.0
	remove_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_mouse_exited() -> void:
	_hovered = false
	remove_button.modulate.a = 0.0
	remove_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_double_click_title(event: InputEvent) -> void:
	if event is InputEventMouseButton and \
	event.button_index == MOUSE_BUTTON_LEFT and \
	event.double_click == true:
		_enter_edit_mode()


func _enter_edit_mode() -> void:
	normal_mode_container.visible = false
	edit_mode_container.visible = true
	title_input.text = model.title
	priority_input.select(model.priority)
	# Interpret the SpinBox value as "days from now"; 0 means no due date.
	var days := 0
	if model.due_date > 0:
		days = maxi(0, int((model.due_date - Time.get_unix_time_from_system()) / 86400.0))
	due_input.value = days
	title_input.grab_focus()
	title_input.select_all()
	get_window().set_input_as_handled()


func _on_title_submitted(new_text: String) -> void:
	if view_model != null:
		view_model.edit_task(model, new_text, priority_input.selected, _due_days_to_unix(int(due_input.value)))
	_exit_edit_mode()


func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_exit_edit_mode()
		title_input.accept_event()


func _on_title_exited() -> void:
	if not edit_mode_container.visible:
		return
	if view_model != null and (title_input.text != model.title or priority_input.selected != model.priority or _due_days_to_unix(int(due_input.value)) != model.due_date):
		view_model.edit_task(model, title_input.text, priority_input.selected, _due_days_to_unix(int(due_input.value)))
	_exit_edit_mode()


## Convert a "days from now" SpinBox value to a unix timestamp (0 = none).
func _due_days_to_unix(days: int) -> int:
	if days <= 0:
		return 0
	return int(Time.get_unix_time_from_system()) + days * 86400


func _exit_edit_mode() -> void:
	normal_mode_container.visible = true
	edit_mode_container.visible = false
	_render()

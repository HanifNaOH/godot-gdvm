## TodoItemView
## The View code-behind for a single todo row (item.tscn). Thin, like example 9.
## Holds only *view* logic: hover to reveal the remove button, double-click to
## edit, and wiring each control's event to a ViewModel method. No data mutation
## here — all state lives in the root TodoViewModel.
extends VBoxContainer

@onready var normal_mode_container := %NormalMode as PanelContainer
@onready var edit_mode_container := %EditMode as PanelContainer
@onready var completed_checkbox := %Completed as CheckBox
@onready var content_label := %Content as RichTextLabel
@onready var remove_button := %Remove as Button
@onready var edit_input := %Edit as LineEdit

## The root ViewModel, resolved from the ancestor root view.
var view_model: TodoViewModel
## This row's backing Model, handed in by the list binding via set_item().
var model: TodoItemModel


## Invoked by the GdvmView list binding for each element. Because `item_prop`
## is empty in the item scene's metadata, gdvm_view calls `set_item(element)`
## where element is the array value — the TodoItemModel. This fires BEFORE the
## node is added to the tree, so we just store the model and render in _ready().
func set_item(element) -> void:
	model = element


func _ready() -> void:
	# The root view (our ancestor) owns the ViewModel.
	view_model = _find_root_view_model()

	if model != null:
		_render()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	remove_button.pressed.connect(func():
		if view_model != null:
			view_model.remove_item(model)
	)
	completed_checkbox.toggled.connect(func(toggled_on: bool):
		if view_model != null:
			view_model.set_item_checked(model, toggled_on)
		_render()  # update strikethrough on the label
	)
	content_label.gui_input.connect(_on_double_clicking_content)
	edit_input.text_submitted.connect(_on_edit_submitted)
	edit_input.gui_input.connect(_on_edit_gui_input)
	edit_input.focus_exited.connect(_on_edit_exited)


## Walk up the parent hierarchy to find the ancestor with a `view_model`.
func _find_root_view_model() -> TodoViewModel:
	var ancestor := get_parent()
	while ancestor != null:
		if "view_model" in ancestor:
			var vm = ancestor.get("view_model")
			if vm is TodoViewModel:
				return vm
		ancestor = ancestor.get_parent()
	return null


## Hover: the Remove button is always visible now, so these are no-ops kept for
## clarity (can be removed if hover behavior is not wanted).
func _on_mouse_entered() -> void:
	pass


func _on_mouse_exited() -> void:
	pass


## Render the current model state into the row's controls.
func _render() -> void:
	completed_checkbox.set_pressed_no_signal(model.checked)
	content_label.text = "[s]%s[/s]" % model.content if model.checked else model.content


func _on_double_clicking_content(event: InputEvent) -> void:
	if event is InputEventMouseButton and \
	event.button_index == MOUSE_BUTTON_LEFT and \
	event.double_click == true:
		normal_mode_container.visible = false
		edit_mode_container.visible = true
		edit_input.text = model.content
		edit_input.grab_focus()
		edit_input.select_all()
		get_window().set_input_as_handled()


## Commit on Enter (text_submitted).
func _on_edit_submitted(new_text: String) -> void:
	if view_model != null and not new_text.is_empty():
		view_model.set_item_content(model, new_text)
	_exit_edit_mode()


## Cancel on ESC (gui_input) — discard the edit.
func _on_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_exit_edit_mode()
		edit_input.accept_event()


## Clicking away while editing: commit the edit, like pressing Enter.
## (After ESC the container is already hidden, so this early-returns.)
func _on_edit_exited() -> void:
	if not edit_mode_container.visible:
		return
	if edit_input.text != model.content:
		if view_model != null and not edit_input.text.is_empty():
			view_model.set_item_content(model, edit_input.text)
	_exit_edit_mode()


func _exit_edit_mode() -> void:
	normal_mode_container.visible = true
	edit_mode_container.visible = false
	_render()  # refresh the label from the model

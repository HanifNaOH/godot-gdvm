extends Control

## TodoMainView
## The View code-behind for the root _10_todo_mvvm scene — thin, like example 9.
##
##   1. Creates the single ViewModel (TodoViewModel) and hands it to the
##      GdvmView child for declarative data binding (list + footer/header
##      aggregates) declared via _gdvm_binding metadata in the scene.
##   2. Binds each control's event to a ViewModel *function*.
##
## No business logic or state mutation lives here.

@onready var gdvm_view: GdvmView = $GdvmView
@onready var new_item_line_edit := %NewItem as LineEdit
@onready var filter_all_button := %Filter/All as Button
@onready var filter_active_button := %Filter/Active as Button
@onready var filter_completed_button := %Filter/Completed as Button
@onready var clear_completed_button := %ClearCompleted as Button

var view_model: TodoViewModel

enum FilterState { ALL, ACTIVE, COMPLETED }
var filter: FilterState = FilterState.ALL:
	set(value):
		filter = value
		_apply_filter()


func _ready() -> void:
	# Create the single ViewModel and let GdvmView bind it to the scene metadata.
	view_model = TodoViewModel.new()
	gdvm_view.set_view_model(view_model)

	# Event binding: View events -> ViewModel functions.
	new_item_line_edit.text_submitted.connect(_on_new_item_submitted)
	filter_all_button.pressed.connect(func(): filter = FilterState.ALL)
	filter_active_button.pressed.connect(func(): filter = FilterState.ACTIVE)
	filter_completed_button.pressed.connect(func(): filter = FilterState.COMPLETED)
	clear_completed_button.pressed.connect(view_model.clear_completed)


func _on_new_item_submitted(new_text: String) -> void:
	if not new_text.is_empty():
		view_model.add_item(new_text)
		new_item_line_edit.text = ""
		_apply_filter()  # keep the active filter applied to the new row
	new_item_line_edit.release_focus()


## Filtering is a *view* concern: it toggles each item row's visibility based on
## the model state. It reads models from the VM but mutates only view nodes.
func _apply_filter() -> void:
	var todos: Node = %Todos
	match filter:
		FilterState.ALL:
			for child in todos.get_children():
				child.visible = true
		FilterState.ACTIVE:
			for child in todos.get_children():
				child.visible = not child.model.checked
		FilterState.COMPLETED:
			for child in todos.get_children():
				child.visible = child.model.checked

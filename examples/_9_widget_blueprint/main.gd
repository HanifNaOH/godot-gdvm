## DemoView
## The demo's View code-behind — the thinnest possible layer (Unreal-style).
##
## The View only:
##   1. creates the ViewModel and declares explicit code-first bindings
##   2. binds each control's event to a ViewModel *function* (no ICommand)
##   3. hosts the Model's HTTPRequest node in the scene tree
##
## No state mutation, no HTTP, no business logic lives here.
extends Control

@onready var update_button: Button = $Panel/VBox/UpdateButton
@onready var count_button: Button = $Panel/VBox/CountButton
@onready var world_time_button: Button = $Panel/VBox/WorldTimeButton

var view_model: GreetingViewModel
var binder: GdvmBinder


func _ready() -> void:
	# "Create Instance" resolver: the View owns its ViewModel instance.
	view_model = GreetingViewModel.new()
	binder = GdvmBinder.new(self)
	binder.set_view_model(view_model)
	binder.bind($Panel/VBox/GreetingLabel, &"greeting", "text")
	binder.bind($Panel/VBox/CountLabel, &"count", "text")
	binder.bind($Panel/VBox/WorldTimeLabel, &"world_time", "text")

	# Event binding: Unreal MVVM binds widget events to ViewModel functions.
	update_button.pressed.connect(view_model.update_greeting)
	count_button.pressed.connect(view_model.increment)
	world_time_button.pressed.connect(view_model.fetch_world_time)

	# The Model owns its HTTP node; the View only hosts it in the tree (an
	# HTTPRequest must be in-tree to poll in Godot).
	add_child(view_model.world_time_service.http_request)


func _exit_tree() -> void:
	if binder != null:
		binder.dispose()

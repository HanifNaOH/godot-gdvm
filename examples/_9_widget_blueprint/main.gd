## DemoView
## The demo's View code-behind — the thinnest possible layer (Unreal-style).
##
## The View only:
##   1. creates the ViewModel (Unreal's "Create Instance" resolver) and hands
##      it to GdvmView for declarative data binding
##   2. binds each control's event to a ViewModel *function* (no ICommand)
##   3. hosts the Model's HTTPRequest node in the scene tree
##
## No state mutation, no HTTP, no business logic lives here.
extends Control

@onready var gdvm_view: GdvmView = $GdvmView
@onready var update_button: Button = $Panel/VBox/UpdateButton
@onready var count_button: Button = $Panel/VBox/CountButton
@onready var world_time_button: Button = $Panel/VBox/WorldTimeButton

var view_model: GreetingViewModel


func _ready() -> void:
	# "Create Instance" resolver: the View owns its ViewModel instance.
	view_model = GreetingViewModel.new()

	# Data binding: GdvmView wires the ViewModel's `changed` signal to the
	# labels declared via `_gdvm_binding` metadata in the scene.
	gdvm_view.set_view_model(view_model)

	# Event binding: Unreal MVVM binds widget events to ViewModel functions.
	update_button.pressed.connect(view_model.update_greeting)
	count_button.pressed.connect(view_model.increment)
	world_time_button.pressed.connect(view_model.fetch_world_time)

	# The Model owns its HTTP node; the View only hosts it in the tree (an
	# HTTPRequest must be in-tree to poll in Godot).
	add_child(view_model.world_time_service.http_request)

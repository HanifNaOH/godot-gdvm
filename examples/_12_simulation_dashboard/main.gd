extends Control

const SimulationVm = preload("./simulation_view_model.gd")

var view_model: SimulationDashboardViewModel
var binder: GdvmBinder
var timer: Timer

@onready var tick_label := %Tick as Label
@onready var status_label := %Status as Label
@onready var active_label := %Active as Label
@onready var units_list := %Units as ItemList
@onready var selected_label := %Selected as Label
@onready var health_bar := %Health as ProgressBar
@onready var events_label := %Events as Label

func _ready() -> void:
	view_model = SimulationVm.new()
	binder = GdvmBinder.new(self)
	binder.set_view_model(view_model)
	for unit: SimulationDashboardViewModel.UnitViewModel in view_model.units:
		unit.changed.connect(_on_unit_changed.bind(unit))
	binder.bind(tick_label, &"tick", "text", {"converter": &"str"})
	binder.bind(status_label, &"world_status", "text")
	binder.bind(active_label, &"active_units", "text", {
		"converter": func(value): return "%d active units" % value,
	})
	view_model.changed.connect(_on_view_model_changed)
	units_list.item_clicked.connect(_on_unit_clicked)
	timer = Timer.new()
	timer.wait_time = 0.25
	timer.timeout.connect(view_model.step_simulation)
	add_child(timer)
	timer.start()
	_render_units()
	_render_selection()
	_render_events()

func _on_view_model_changed(property_name: StringName, _old_value, _new_value) -> void:
	if property_name == &"units":
		_render_units()
	elif property_name == &"selected_unit":
		_render_selection(_new_value)
	elif property_name == &"event_log":
		_render_events()

func _render_units() -> void:
	units_list.clear()
	for unit: SimulationDashboardViewModel.UnitViewModel in view_model.units:
		units_list.add_item("%s  |  %s%%  |  %s" % [unit.unit_name, int(unit.health), unit.status])

func _render_selection(unit: SimulationDashboardViewModel.UnitViewModel = null) -> void:
	if unit == null:
		selected_label.text = "No unit selected"
		health_bar.value = 0.0
		return
	selected_label.text = unit.unit_name
	health_bar.value = unit.health

func _on_unit_changed(property_name: StringName, _old_value, new_value, unit: SimulationDashboardViewModel.UnitViewModel) -> void:
	if unit != view_model.selected_unit:
		return
	if property_name == &"health":
		health_bar.value = new_value

func _render_events() -> void:
	events_label.text = "\n".join(view_model.event_log)

func _on_unit_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	view_model.select_unit(view_model.units[index])
	_render_selection(view_model.selected_unit)

func _exit_tree() -> void:
	if timer != null:
		timer.queue_free()
	if binder != null:
		binder.dispose()

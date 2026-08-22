class_name SimulationDashboardViewModel
extends ObservableObject

class UnitViewModel extends ObservableObject:
	var unit_id: int
	var unit_name: String
	var health: float:
		set(value):
			if set_property(&"health", health, value):
				health = value
	var status: String:
		set(value):
			if set_property(&"status", status, value):
				status = value

	func _init(id: int, name: String) -> void:
		unit_id = id
		unit_name = name
		health = 100.0
		status = "Ready"

var tick: int = 0:
	set(value):
		if set_property(&"tick", tick, value):
			tick = value

var world_status: String = "Running":
	set(value):
		if set_property(&"world_status", world_status, value):
			world_status = value

var active_units: int = 0:
	set(value):
		if set_property(&"active_units", active_units, value):
			active_units = value

var selected_unit: UnitViewModel:
	set(value):
		if set_property(&"selected_unit", selected_unit, value):
			selected_unit = value
var units: Array = []
var event_log: Array[String] = []

func _init() -> void:
	for id in range(1, 9):
		units.append(UnitViewModel.new(id, "Unit %02d" % id))
	active_units = units.size()
	event_log = ["Simulation initialized", "%d units online" % units.size()]

func step_simulation() -> void:
	tick += 1
	for unit: UnitViewModel in units:
		var next_health := maxf(0.0, unit.health - (float((tick + unit.unit_id) % 4) * 0.5))
		unit.health = next_health
		unit.status = "Critical" if next_health < 25.0 else "Active"
	active_units = units.filter(func(unit: UnitViewModel): return unit.health > 0.0).size()
	if tick % 5 == 0:
		event_log.push_front("Tick %d completed" % tick)
		if event_log.size() > 8:
			event_log.pop_back()
		notify_property_changed(&"event_log")

func select_unit(unit: UnitViewModel) -> void:
	selected_unit = unit
	event_log.push_front("Selected %s" % unit.unit_name)
	if event_log.size() > 8:
		event_log.pop_back()
	notify_property_changed(&"event_log")

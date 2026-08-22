extends GutTest


## A minimal observable model that follows the documented setter convention.
class Model extends ObservableObject:
	var health: int:
		set(v):
			if set_property(&"health", health, v):
				health = v


## Records hook call order for on_property_changing / on_property_changed.
class RecordingModel extends ObservableObject:
	var events: Array = []

	var value: int:
		set(v):
			if set_property(&"value", value, v):
				value = v

	func on_property_changing(_property_name: StringName, _old_value, _new_value) -> void:
		events.append(&"changing")

	func on_property_changed(_property_name: StringName) -> void:
		events.append(&"changed")


func test_set_property_emits_when_different() -> void:
	var m := Model.new()
	var received: Array = []
	m.changed.connect(func(prop_name, old_val, new_val): received.append([prop_name, old_val, new_val]))

	m.health = 10

	assert_eq(m.health, 10)
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], &"health")
	assert_eq(received[0][1], 0)
	assert_eq(received[0][2], 10)


func test_set_property_does_not_emit_when_same() -> void:
	var m := Model.new()
	var received: Array = []
	m.changed.connect(func(prop_name, old_val, new_val): received.append([prop_name, old_val, new_val]))

	m.health = 0

	assert_eq(m.health, 0)
	assert_eq(received.size(), 0)


func test_set_property_returns_whether_it_changed() -> void:
	var m := Model.new()

	var changed := m.set_property(&"health", 0, 5)
	assert_true(changed)

	var unchanged := m.set_property(&"health", 5, 5)
	assert_false(unchanged)


func test_set_properties_emits_once_for_bulk_change() -> void:
	var m := Model.new()
	var received: Array = []
	m.changed.connect(func(prop_name, old_val, new_val): received.append([prop_name, old_val, new_val]))

	var count := m.set_properties({
		&"a": [0, 1],
		&"b": [0, 2],
		&"c": [5, 5],  # unchanged, should not count
	})

	assert_eq(count, 2)
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], &"")
	assert_null(received[0][1])
	assert_eq(received[0][2], {&"a": 1, &"b": 2})


func test_set_properties_returns_zero_when_nothing_changed() -> void:
	var m := Model.new()
	var received: Array = []
	m.changed.connect(func(prop_name, old_val, new_val): received.append([prop_name, old_val, new_val]))

	var count := m.set_properties({
		&"a": [1, 1],
		&"b": [2, 2],
	})

	assert_eq(count, 0)
	assert_eq(received.size(), 0)


func test_hook_order_changing_then_changed() -> void:
	var m : RecordingModel = RecordingModel.new()

	m.value = 1

	assert_eq(m.events, [&"changing", &"changed"])


func test_hooks_not_called_when_value_unchanged() -> void:
	var m := RecordingModel.new()

	m.value = 0

	assert_eq(m.events, [])


func test_would_change() -> void:
	var m := Model.new()

	assert_true(m.would_change(0, 1))
	assert_false(m.would_change(1, 1))


func test_notify_property_changed_emits_signal() -> void:
	var m := Model.new()
	m.health = 42
	var received: Array = []
	m.changed.connect(func(prop_name, old_val, new_val): received.append([prop_name, old_val, new_val]))

	m.notify_property_changed(&"health")

	assert_eq(received.size(), 1)
	assert_eq(received[0][0], &"health")
	assert_null(received[0][1])
	assert_eq(received[0][2], 42)


func test_notify_property_changed_runs_hook() -> void:
	var m := RecordingModel.new()

	m.notify_property_changed(&"value")

	# only the "changed" hook runs
	assert_eq(m.events, [&"changed"])

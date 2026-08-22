extends GutTest

const DashboardScene = preload("res://examples/_12_simulation_dashboard/main.tscn")

func _create_dashboard() -> Control:
	var dashboard := DashboardScene.instantiate() as Control
	add_child(dashboard)
	await get_tree().process_frame
	return dashboard

func test_clicking_unit_updates_selection_and_health_bar() -> void:
	var dashboard := await _create_dashboard()
	var units := dashboard.get_node("Layout/Columns/UnitsPanel/Units") as ItemList
	var selected := dashboard.get_node("Layout/Columns/Inspector/Selected") as Label
	var health := dashboard.get_node("Layout/Columns/Inspector/Health") as ProgressBar

	units.item_clicked.emit(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)

	assert_eq(selected.text, "Unit 01")
	assert_eq(health.value, 100.0)
	dashboard.free()

func test_selected_unit_health_updates_during_simulation() -> void:
	var dashboard := await _create_dashboard()
	var units := dashboard.get_node("Layout/Columns/UnitsPanel/Units") as ItemList
	var health := dashboard.get_node("Layout/Columns/Inspector/Health") as ProgressBar

	units.item_clicked.emit(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	var initial_health := health.value
	await wait_physics_frames(20)

	assert_lt(health.value, initial_health)
	dashboard.free()

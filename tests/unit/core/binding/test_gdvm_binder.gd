extends GutTest


class Vm extends ObservableObject:
	var greeting: String = "hello":
		set(v):
			if set_property(&"greeting", greeting, v):
				greeting = v


func test_code_first_binding_updates_and_disposes() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var vm := Vm.new()
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_true(binder.bind(label, &"greeting", "text"))
	assert_eq(label.text, "hello")

	vm.greeting = "updated"
	assert_eq(label.text, "updated")

	binder.dispose()
	assert_eq(label.text, "updated")
	autofree(view_owner)


func test_invalid_view_model_path_is_rejected() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(Vm.new())

	assert_false(binder.bind(label, &"missing", "text"))
	assert_push_error("no property 'missing'")
	binder.dispose()
	autofree(view_owner)


func test_invalid_node_property_is_rejected() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(Vm.new())

	assert_false(binder.bind(label, &"greeting", "missing"))
	assert_push_error("has no property 'missing'")
	binder.dispose()
	autofree(view_owner)


func test_multiple_bindings_receive_updates() -> void:
	var view_owner := Node.new()
	var first := Label.new()
	var second := Label.new()
	view_owner.add_child(first)
	view_owner.add_child(second)
	var binder := GdvmBinder.new(view_owner)
	var vm := Vm.new()
	binder.set_view_model(vm)

	assert_true(binder.bind(first, &"greeting", "text"))
	assert_true(binder.bind(second, &"greeting", "text"))
	vm.greeting = "both"

	assert_eq(first.text, "both")
	assert_eq(second.text, "both")
	autofree(view_owner)
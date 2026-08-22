extends GutTest


class Vm extends ObservableObject:
	var greeting: String = "hello":
		set(v):
			if set_property(&"greeting", greeting, v):
				greeting = v


class IntVm extends ObservableObject:
	var number: int = 0:
		set(v):
			if set_property(&"number", number, v):
				number = v


class ListVm extends ObservableObject:
	var items: Array = []:
		set(v):
			if set_property(&"items", items, v):
				items = v


class BadVm:
	var greeting: String = "bad"


func _make_label_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := Label.new()
	var error := scene.pack(root)
	assert_eq(error, OK)
	return scene


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


func test_one_time_binding_ignores_later_updates() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var binder := GdvmBinder.new(view_owner)
	var vm := Vm.new()
	binder.set_view_model(vm)

	assert_true(binder.bind(label, &"greeting", "text", {
		"mode": GdvmBinder.Mode.ONE_TIME,
	}))
	assert_eq(label.text, "hello")
	vm.greeting = "changed"
	assert_eq(label.text, "hello")
	binder.dispose()
	autofree(view_owner)


func test_list_binding_adds_removes_and_disposes_rows() -> void:
	var view_owner := Node.new()
	var container := VBoxContainer.new()
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = ["A"]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)
	var removed: Array = []

	assert_true(binder.bind_list(container, &"items", _make_label_scene(), {
		"item_prop": &"text",
		"on_removed": func(item: Node):
			removed.append(item)
			item.queue_free(),
	}))
	assert_eq(container.get_child_count(), 1)
	assert_eq((container.get_child(0) as Label).text, "A")

	vm.items = ["A", "B"]
	assert_eq(container.get_child_count(), 2)
	vm.items = []
	assert_eq(container.get_child_count(), 0)
	assert_eq(removed.size(), 2)

	binder.dispose()
	assert_eq(container.get_child_count(), 0)
	autofree(view_owner)


func test_freed_bound_node_is_ignored_on_later_view_model_change() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var binder := GdvmBinder.new(view_owner)
	var vm := Vm.new()
	binder.set_view_model(vm)
	assert_true(binder.bind(label, &"greeting", "text"))

	label.free()
	vm.greeting = "after free"

	binder.dispose()
	autofree(view_owner)


func test_unknown_converter_is_rejected_with_error() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var binder := GdvmBinder.new(view_owner)
	var vm := Vm.new()
	binder.set_view_model(vm)

	assert_false(binder.bind(label, &"greeting", "text", {
		"converter": &"missing_converter",
	}))
	assert_push_error("unknown converter 'missing_converter'")
	binder.dispose()
	autofree(view_owner)


func test_invalid_list_template_is_rejected_with_error() -> void:
	var view_owner := Node.new()
	var container := VBoxContainer.new()
	view_owner.add_child(container)
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(ListVm.new())
	var invalid_template := PackedScene.new()

	assert_false(binder.bind_list(container, &"items", invalid_template))
	assert_push_error("list binding requires a valid container, path, and template")
	binder.dispose()
	autofree(view_owner)


func test_invalid_view_model_does_not_replace_current_view_model() -> void:
	var view_owner := Node.new()
	var binder := GdvmBinder.new(view_owner)
	var valid_vm := Vm.new()
	binder.set_view_model(valid_vm)

	assert_false(binder.set_view_model(BadVm.new()))
	assert_push_error("missing signal 'changed'")
	assert_same(binder.get_view_model(), valid_vm)
	binder.dispose()
	autofree(view_owner)


func test_two_way_binding_can_reverse_convert_node_value() -> void:
	var view_owner := Node.new()
	var edit := LineEdit.new()
	view_owner.add_child(edit)
	var binder := GdvmBinder.new(view_owner)
	var vm := IntVm.new()
	vm.number = 4
	binder.set_view_model(vm)

	assert_true(binder.bind(edit, &"number", "text", {
		"mode": GdvmBinder.Mode.TWO_WAY,
		"signal": &"text_changed",
		"converter": &"str",
		"reverse_converter": func(value): return int(value),
	}))
	assert_eq(edit.text, "4")
	edit.text = "12"
	edit.text_changed.emit("12")
	assert_eq(vm.number, 12)
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


func test_invalid_signal_on_detached_node_is_rejected() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(Vm.new())

	assert_false(binder.bind(label, &"greeting", "text", {
		"mode": GdvmBinder.Mode.TWO_WAY,
		"signal": &"missing",
	}))
	assert_push_error("missing binding signal 'missing'")
	binder.dispose()
	autofree(view_owner)


func test_replacing_view_model_repairs_existing_bindings() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var first_vm := Vm.new()
	first_vm.greeting = "first"
	var second_vm := Vm.new()
	second_vm.greeting = "second"
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(first_vm)
	assert_true(binder.bind(label, &"greeting", "text"))

	binder.set_view_model(second_vm)
	assert_eq(label.text, "second")
	first_vm.greeting = "ignored"
	assert_eq(label.text, "second")
	second_vm.greeting = "updated"
	assert_eq(label.text, "updated")
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


func test_list_binding_reuses_rows_by_item_key_when_reordered() -> void:
	var view_owner := Node.new()
	var container := VBoxContainer.new()
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = [{"id": 1, "text": "A"}, {"id": 2, "text": "B"}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)
	GdvmBinder.register_converter(&"item_text", func(value): return value["text"])
	assert_true(binder.bind_list(container, &"items", _make_label_scene(), {
		"item_prop": &"text",
		"item_key": &"id",
		"item_converter": &"item_text",
	}))
	var first_row := container.get_child(0)
	var second_row := container.get_child(1)

	vm.items = [{"id": 2, "text": "B2"}, {"id": 1, "text": "A2"}]

	assert_same(container.get_child(0), second_row)
	assert_same(container.get_child(1), first_row)
	assert_eq((container.get_child(0) as Label).text, "B2")
	assert_eq((container.get_child(1) as Label).text, "A2")
	GdvmBinder.clear_converters()
	binder.dispose()
	autofree(view_owner)


func test_duplicate_item_keys_are_rejected_without_mutating_rows() -> void:
	var view_owner := Node.new()
	var container := VBoxContainer.new()
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = [{"id": 1, "text": "A"}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)
	assert_true(binder.bind_list(container, &"items", _make_label_scene(), {
		"item_prop": &"text",
		"item_key": &"id",
	}))

	vm.items = [{"id": 1, "text": "A2"}, {"id": 1, "text": "duplicate"}]

	assert_eq(container.get_child_count(), 1)
	assert_eq((container.get_child(0) as Label).text, "A")
	assert_push_error("duplicate item_key")
	binder.dispose()
	autofree(view_owner)


func test_missing_item_key_is_rejected_before_binding_creation() -> void:
	var view_owner := Node.new()
	var container := VBoxContainer.new()
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = [{"text": "missing id"}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_false(binder.bind_list(container, &"items", _make_label_scene(), {
		"item_prop": &"text",
		"item_key": &"id",
	}))
	assert_eq(container.get_child_count(), 0)
	assert_push_error("missing item_key 'id'")
	binder.dispose()
	autofree(view_owner)
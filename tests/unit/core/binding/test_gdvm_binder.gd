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


class ItemRow extends Node:
	var item_view_model: Object
	@onready var label := $Label as Label
	var binder: GdvmBinder

	func set_item_view_model(value: Object) -> void:
		item_view_model = value
		binder = GdvmBinder.new(self)
		binder.set_view_model(value)
		binder.bind(label, &"greeting", "text")


class FailingItemRow extends Node:
	var item_view_model: Object

	func set_item_view_model(value: Object) -> bool:
		if value is Vm and value.greeting == "reject":
			return false
		item_view_model = value
		return true


func _make_label_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := Label.new()
	var error := scene.pack(root)
	assert_eq(error, OK)
	root.free()
	return scene


func _make_item_row_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := ItemRow.new()
	var label := Label.new()
	label.name = "Label"
	root.add_child(label)
	label.owner = root
	var error := scene.pack(root)
	assert_eq(error, OK)
	root.free()
	return scene


func _make_failing_item_row_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := FailingItemRow.new()
	var error := scene.pack(root)
	assert_eq(error, OK)
	root.free()
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
			item.free(),
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
	view_owner.free()


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


func test_invalid_replacement_list_does_not_report_success_or_mutate_rows() -> void:
	var view_owner := Node.new()
	var container := VBoxContainer.new()
	view_owner.add_child(container)
	var first_vm := ListVm.new()
	first_vm.items = [{"id": 1, "text": "A"}]
	var second_vm := ListVm.new()
	second_vm.items = [{"id": 1, "text": "B"}, {"id": 1, "text": "duplicate"}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(first_vm)
	assert_true(binder.bind_list(container, &"items", _make_label_scene(), {
		"item_prop": &"text",
		"item_key": &"id",
		"item_converter": func(value): return value["text"],
	}))

	assert_false(binder.set_view_model(second_vm))
	assert_eq(container.get_child_count(), 1)
	assert_eq((container.get_child(0) as Label).text, "A")
	assert_push_error("duplicate item_key")
	binder.dispose()
	view_owner.free()


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


func test_one_value_updates_multiple_visual_properties() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	var progress := ProgressBar.new()
	view_owner.add_child(label)
	view_owner.add_child(progress)
	var vm := IntVm.new()
	vm.number = 25
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_true(binder.bind(label, &"number", "text", {"converter": &"percent"}))
	assert_true(binder.bind(progress, &"number", "value"))
	assert_eq(label.text, "2500%")
	assert_eq(progress.value, 25.0)

	vm.number = 40
	assert_eq(label.text, "4000%")
	assert_eq(progress.value, 40.0)
	binder.dispose()
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
	view_owner.free()


func test_list_binding_creates_per_item_view_models() -> void:
	var view_owner := Node.new()
	var container := Node.new()
	add_child(view_owner)
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = [{"id": 1}, {"id": 2}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)
	var created: Array = []
	assert_true(binder.bind_list(container, &"items", _make_item_row_scene(), {
		"item_key": &"id",
		"item_view_model_factory": func(value):
			var item_vm := Vm.new()
			item_vm.greeting = "item_%d" % value["id"]
			created.append(item_vm)
			return item_vm,
	}))

	assert_eq(created.size(), 2)
	assert_same((container.get_child(0) as ItemRow).item_view_model, created[0])
	assert_same((container.get_child(1) as ItemRow).item_view_model, created[1])
	binder.dispose()
	view_owner.free()


func test_each_item_view_model_drives_its_own_row_binder() -> void:
	var view_owner := Node.new()
	var container := Node.new()
	add_child(view_owner)
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = [{"id": 1}, {"id": 2}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_true(binder.bind_list(container, &"items", _make_item_row_scene(), {
		"item_key": &"id",
		"item_view_model_factory": func(value):
			var item_vm := Vm.new()
			item_vm.greeting = "item_%d" % value["id"]
			return item_vm,
	}))
	var first_row := container.get_child(0) as ItemRow
	var second_row := container.get_child(1) as ItemRow

	(first_row.item_view_model as Vm).greeting = "first updated"

	assert_eq(first_row.label.text, "first updated")
	assert_eq(second_row.label.text, "item_2")
	binder.dispose()
	view_owner.free()


func test_item_view_model_factory_rejects_rows_without_a_view_model_setter() -> void:
	var view_owner := Node.new()
	var container := Node.new()
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = [{"id": 1}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_false(binder.bind_list(container, &"items", _make_label_scene(), {
		"item_key": &"id",
		"item_view_model_factory": func(_value): return Vm.new(),
	}))
	assert_eq(container.get_child_count(), 0)
	assert_push_error("must implement set_item_view_model() or set_view_model()")
	binder.dispose()
	view_owner.free()


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
		"item_converter": func(value): return value["text"],
	}))

	vm.items = [{"id": 1, "text": "A2"}, {"id": 1, "text": "duplicate"}]

	assert_eq(container.get_child_count(), 1)
	assert_eq((container.get_child(0) as Label).text, "A")
	assert_push_error("duplicate item_key")
	assert_push_error("failed to reconcile list binding")
	binder.dispose()
	view_owner.free()


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
	view_owner.free()


func test_builtin_converters_transform_values() -> void:
	var view_owner := Node.new()
	var lower_label := Label.new()
	var upper_label := Label.new()
	var percent_label := Label.new()
	var flip_label := Label.new()
	view_owner.add_child(lower_label)
	view_owner.add_child(upper_label)
	view_owner.add_child(percent_label)
	view_owner.add_child(flip_label)
	var vm := Vm.new()
	vm.greeting = "MiXeD"
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_true(binder.bind(lower_label, &"greeting", "text", {"converter": &"lowercase"}))
	assert_true(binder.bind(upper_label, &"greeting", "text", {"converter": &"uppercase"}))
	assert_true(binder.bind(percent_label, &"greeting", "text", {"converter": &"percent"}))
	assert_true(binder.bind(flip_label, &"greeting", "text", {"converter": &"bool_flip"}))

	assert_eq(lower_label.text, "mixed")
	assert_eq(upper_label.text, "MIXED")
	assert_eq(percent_label.text, "0%")
	assert_eq(flip_label.text, "false")
	binder.dispose()
	autofree(view_owner)


func test_callable_converter_updates_bound_node() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var vm := Vm.new()
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_true(binder.bind(label, &"greeting", "text", {
		"converter": func(value): return "[%s]" % value,
	}))
	assert_eq(label.text, "[hello]")
	vm.greeting = "updated"
	assert_eq(label.text, "[updated]")
	binder.dispose()
	autofree(view_owner)


func test_global_converter_can_be_registered_and_unregistered() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(Vm.new())
	GdvmBinder.register_converter(&"bracket", func(value): return "<%s>" % value)
	var second_label := Label.new()
	view_owner.add_child(second_label)

	assert_true(binder.bind(label, &"greeting", "text", {"converter": &"bracket"}))
	assert_eq(label.text, "<hello>")
	GdvmBinder.unregister_converter(&"bracket")

	assert_false(binder.bind(second_label, &"greeting", "text", {"converter": &"bracket"}))
	assert_push_error("unknown converter 'bracket'")
	GdvmBinder.clear_converters()
	binder.dispose()
	autofree(view_owner)


func test_one_way_to_source_binding_writes_back_to_view_model() -> void:
	var view_owner := Node.new()
	var edit := LineEdit.new()
	view_owner.add_child(edit)
	var vm := Vm.new()
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_true(binder.bind(edit, &"greeting", "text", {
		"mode": GdvmBinder.Mode.ONE_WAY_TO_SOURCE,
		"signal": &"text_changed",
	}))
	edit.text = "from_node"
	edit.text_changed.emit(edit.text)
	assert_eq(vm.greeting, "from_node")
	binder.dispose()
	autofree(view_owner)


func test_on_changed_callback_receives_node_value_and_old_value() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var vm := Vm.new()
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)
	var calls: Array = []

	assert_true(binder.bind(label, &"greeting", "text", {
		"on_changed": func(node, value, old_value): calls.append([node, value, old_value]),
	}))
	vm.greeting = "next"

	assert_eq(calls.size(), 2)
	assert_same(calls[0][0], label)
	assert_eq(calls[0][1], "hello")
	assert_eq(calls[0][2], null)
	assert_eq(calls[1][1], "next")
	assert_eq(calls[1][2], "hello")
	binder.dispose()
	autofree(view_owner)


func test_invalid_optional_callbacks_are_rejected() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(Vm.new())

	assert_false(binder.bind(label, &"greeting", "text", {"on_changed": "not callable"}))
	assert_push_error("on_changed must be a valid Callable")
	binder.dispose()
	autofree(view_owner)


func test_setting_view_model_to_null_stops_existing_bindings() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var vm := Vm.new()
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)
	binder.bind(label, &"greeting", "text")
	binder.set_view_model(null)

	vm.greeting = "ignored"
	assert_eq(label.text, "hello")
	binder.dispose()
	autofree(view_owner)


func test_list_binding_emits_added_and_removed_counts() -> void:
	var view_owner := Node.new()
	var container := VBoxContainer.new()
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = ["A"]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)
	var changes: Array = []
	binder.items_changed.connect(func(_container, added, removed): changes.append([added, removed]))

	assert_true(binder.bind_list(container, &"items", _make_label_scene(), {"item_prop": &"text"}))
	vm.items = ["A", "B"]
	vm.items = []

	assert_eq(changes, [[1, 0], [1, 0], [0, 2]])
	binder.dispose()
	view_owner.free()


func test_callable_item_converter_transforms_each_row() -> void:
	var view_owner := Node.new()
	var container := VBoxContainer.new()
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = [{"text": "one"}, {"text": "two"}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_true(binder.bind_list(container, &"items", _make_label_scene(), {
		"item_prop": &"text",
		"item_converter": func(value): return value["text"].to_upper(),
	}))
	assert_eq((container.get_child(0) as Label).text, "ONE")
	assert_eq((container.get_child(1) as Label).text, "TWO")
	binder.dispose()
	view_owner.free()


func test_item_view_model_factory_reuses_keyed_rows() -> void:
	var view_owner := Node.new()
	var container := Node.new()
	add_child(view_owner)
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = [{"id": 1}, {"id": 2}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)
	var created: Array = []

	assert_true(binder.bind_list(container, &"items", _make_item_row_scene(), {
		"item_key": &"id",
		"item_view_model_factory": func(value):
			var item_vm := Vm.new()
			item_vm.greeting = "item_%d" % value["id"]
			created.append(item_vm)
			return item_vm,
	}))
	var first_row := container.get_child(0)
	var second_row := container.get_child(1)

	vm.items = [{"id": 2}, {"id": 1}]

	assert_eq(created.size(), 2)
	assert_same(container.get_child(0), second_row)
	assert_same(container.get_child(1), first_row)
	binder.dispose()
	view_owner.free()


func test_replacing_parent_view_model_replaces_nested_item_view_models() -> void:
	var view_owner := Node.new()
	var container := Node.new()
	add_child(view_owner)
	view_owner.add_child(container)
	var first_vm := ListVm.new()
	first_vm.items = [{"id": 1}]
	var second_vm := ListVm.new()
	second_vm.items = [{"id": 1}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(first_vm)
	var created: Array = []

	assert_true(binder.bind_list(container, &"items", _make_item_row_scene(), {
		"item_key": &"id",
		"item_view_model_factory": func(value):
			var item_vm := Vm.new()
			item_vm.greeting = "vm_%d_%d" % [created.size(), value["id"]]
			created.append(item_vm)
			return item_vm,
	}))
	var row := container.get_child(0) as ItemRow
	var original_item_vm := row.item_view_model

	binder.set_view_model(second_vm)

	assert_eq(created.size(), 2)
	assert_not_same(row.item_view_model, original_item_vm)
	assert_eq(row.label.text, "vm_1_1")
	binder.dispose()
	view_owner.free()


func test_failed_item_view_model_assignment_rejects_replacement() -> void:
	var view_owner := Node.new()
	var container := Node.new()
	view_owner.add_child(container)
	var first_vm := ListVm.new()
	first_vm.items = [{"id": 1, "name": "first"}]
	var second_vm := ListVm.new()
	second_vm.items = [{"id": 1, "name": "reject"}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(first_vm)
	assert_true(binder.bind_list(container, &"items", _make_failing_item_row_scene(), {
		"item_key": &"id",
		"item_view_model_factory": func(value):
			var item_vm := Vm.new()
			item_vm.greeting = value["name"]
			return item_vm,
	}))
	var row := container.get_child(0) as FailingItemRow
	var original_item_vm := row.item_view_model

	assert_false(binder.set_view_model(second_vm))
	assert_same(row.item_view_model, original_item_vm)
	assert_push_error("rejected its ViewModel")
	binder.dispose()
	view_owner.free()


func test_keyed_collection_mutation_reuses_survivors_and_removes_stale_rows() -> void:
	var view_owner := Node.new()
	var container := VBoxContainer.new()
	view_owner.add_child(container)
	var vm := ListVm.new()
	vm.items = [{"id": 1, "text": "A"}, {"id": 2, "text": "B"}]
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(vm)

	assert_true(binder.bind_list(container, &"items", _make_label_scene(), {
		"item_key": &"id",
		"item_prop": &"text",
		"item_converter": func(value): return value["text"],
	}))
	var original_second_row := container.get_child(1)

	vm.items = [{"id": 2, "text": "B2"}, {"id": 3, "text": "C"}]

	assert_eq(container.get_child_count(), 2)
	assert_same(container.get_child(0), original_second_row)
	assert_eq((container.get_child(0) as Label).text, "B2")
	assert_eq((container.get_child(1) as Label).text, "C")
	binder.dispose()
	view_owner.free()


func test_invalid_callable_converter_is_rejected() -> void:
	var view_owner := Node.new()
	var label := Label.new()
	view_owner.add_child(label)
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(Vm.new())

	assert_false(binder.bind(label, &"greeting", "text", {"converter": Callable()}))
	assert_push_error("converter must be a valid Callable")
	binder.dispose()
	autofree(view_owner)


func test_invalid_item_view_model_factory_is_rejected() -> void:
	var view_owner := Node.new()
	var container := Node.new()
	view_owner.add_child(container)
	var binder := GdvmBinder.new(view_owner)
	binder.set_view_model(ListVm.new())

	assert_false(binder.bind_list(container, &"items", _make_label_scene(), {
		"item_view_model_factory": Callable(),
	}))
	assert_push_error("item_view_model_factory must be a valid Callable")
	binder.dispose()
	view_owner.free()

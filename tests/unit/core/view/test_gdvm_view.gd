extends GutTest


class Vm extends ObservableObject:
	var greeting: String:
		set(v):
			if set_property(&"greeting", greeting, v):
				greeting = v


class BoolVm extends ObservableObject:
	var checked: bool:
		set(v):
			if set_property(&"checked", checked, v):
				checked = v


class ListVm extends ObservableObject:
	var items: Array = []:
		set(v):
			if set_property(&"items", items, v):
				items = v


class IntVm extends ObservableObject:
	var number: int = 0:
		set(v):
			if set_property(&"number", number, v):
				number = v

	var ratio: float = 0.0:
		set(v):
			if set_property(&"ratio", ratio, v):
				ratio = v


class BulkVm extends ObservableObject:
	var first: String = "old first":
		set(v):
			if set_property(&"first", first, v):
				first = v

	var second: String = "old second":
		set(v):
			if set_property(&"second", second, v):
				second = v

	func update_values(new_first: String, new_second: String) -> void:
		if set_properties({
			&"first": [first, new_first],
			&"second": [second, new_second],
		}):
			first = new_first
			second = new_second


class CustomSignalVm extends ObservableObject:
	signal custom_changed(property_name: StringName, old_value, new_value)

	var greeting: String:
		set(v):
			if greeting != v:
				var old_value := greeting
				greeting = v
				custom_changed.emit(&"greeting", old_value, v)


class ContextProvider extends Node:
	var view_model: Object

	func _init(vm: Object) -> void:
		view_model = vm


func test_one_way_initial_push() -> void:
	var vm := Vm.new()
	vm.greeting = "Hello"

	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "greeting", "prop": "text", "mode": 0})

	var view := GdvmView.new()
	view.add_child(label)
	view.set_view_model(vm)

	assert_eq(label.text, "Hello")
	autoqfree(view)


func test_one_way_updates_on_change() -> void:
	var vm := Vm.new()
	vm.greeting = "Hello"

	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "greeting", "prop": "text", "mode": 0})

	var view := GdvmView.new()
	view.add_child(label)
	view.set_view_model(vm)

	vm.greeting = "World"

	assert_eq(label.text, "World")
	autoqfree(view)


func test_one_way_ignores_unrelated_change() -> void:
	var vm := Vm.new()
	vm.greeting = "Hello"

	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "greeting", "prop": "text", "mode": 0})

	var view := GdvmView.new()
	view.add_child(label)
	view.set_view_model(vm)

	# notify a different property; the label bound to "greeting" must not change
	vm.notify_property_changed(&"other")
	assert_eq(label.text, "Hello")
	autoqfree(view)


func test_bulk_change_uses_authoritative_values_for_each_binding() -> void:
	var vm := BulkVm.new()
	var first_label := Label.new()
	first_label.set_meta(&"_gdvm_binding", {"path": "first", "prop": "text", "mode": 0})
	var second_label := Label.new()
	second_label.set_meta(&"_gdvm_binding", {"path": "second", "prop": "text", "mode": 0})

	var view := GdvmView.new()
	view.add_child(first_label)
	view.add_child(second_label)
	view.set_view_model(vm)

	vm.update_values("new first", "new second")

	assert_eq(first_label.text, "new first")
	assert_eq(second_label.text, "new second")
	autoqfree(view)


func test_change_signal_override_works_before_and_after_view_model_assignment() -> void:
	var vm := CustomSignalVm.new()
	vm.greeting = "Initial"
	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "greeting", "prop": "text", "mode": 0})
	var view := GdvmView.new()
	view.add_child(label)
	view.set_change_signal(&"custom_changed")
	view.set_view_model(vm)

	vm.greeting = "Before override"
	assert_eq(label.text, "Before override")
	view.set_change_signal(&"custom_changed")
	vm.greeting = "After override"
	assert_eq(label.text, "After override")
	autoqfree(view)


func test_nested_node_binding() -> void:
	var vm := Vm.new()
	vm.greeting = "Nested"

	var panel := Panel.new()
	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "greeting", "prop": "text", "mode": 0})
	panel.add_child(label)

	var view := GdvmView.new()
	view.add_child(panel)
	view.set_view_model(vm)

	assert_eq(label.text, "Nested")
	autoqfree(view)


func test_set_view_model_rebuilds_bindings() -> void:
	var vm1 := Vm.new()
	vm1.greeting = "One"
	var vm2 := Vm.new()
	vm2.greeting = "Two"

	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "greeting", "prop": "text", "mode": 0})

	var view := GdvmView.new()
	view.add_child(label)

	view.set_view_model(vm1)
	assert_eq(label.text, "One")

	view.set_view_model(vm2)
	assert_eq(label.text, "Two")

	# old VM changes should no longer propagate
	vm1.greeting = "Changed"
	assert_eq(label.text, "Two")
	autoqfree(view)


# ─── one_way_to_source ───────────────────────────────────────────────────────

func test_one_way_to_source_writes_to_vm() -> void:
	var vm := Vm.new()
	vm.greeting = "Initial"

	var edit := LineEdit.new()
	edit.text = "User Typed"
	edit.set_meta(&"_gdvm_binding", {"path": "greeting", "prop": "text", "mode": 2, "signal": "text_changed"})

	var view := GdvmView.new()
	view.add_child(edit)
	view.set_view_model(vm)

	# Simulate user input by emitting the signal (programmatic .text = ... does
	# not emit text_changed). The handler reads the node's current text.
	edit.text = "User Typed!"
	edit.text_changed.emit("User Typed!")

	assert_eq(vm.greeting, "User Typed!")
	autoqfree(view)


# ─── two_way ────────────────────────────────────────────────────────────────

func test_two_way_vm_to_node_and_back() -> void:
	var vm := BoolVm.new()
	vm.checked = false

	var box := CheckBox.new()
	box.set_meta(&"_gdvm_binding", {"path": "checked", "prop": "button_pressed", "mode": 3, "signal": "toggled"})

	var view := GdvmView.new()
	view.add_child(box)
	view.set_view_model(vm)

	# VM -> node initial push
	assert_eq(box.button_pressed, false)

	# VM -> node
	vm.checked = true
	assert_eq(box.button_pressed, true)

	# node -> VM: simulate a user click by toggling the box (emits `toggled`)
	box.button_pressed = false
	box.toggled.emit(false)

	assert_eq(vm.checked, false)
	autoqfree(view)


func test_two_way_no_echo_loop() -> void:
	# CheckBox `toggled` emits on user interaction. Drive VM -> node, then ensure
	# a programmatic node set does NOT echo back into the VM (the guard + setter
	# diff prevent a loop).
	var vm := BoolVm.new()
	vm.checked = false

	var box := CheckBox.new()
	box.set_meta(&"_gdvm_binding", {"path": "checked", "prop": "button_pressed", "mode": 3, "signal": "toggled"})

	var view := GdvmView.new()
	view.add_child(box)
	view.set_view_model(vm)

	# VM -> node; the guarded write must not re-trigger the node callback.
	vm.checked = true
	assert_eq(box.button_pressed, true)
	assert_eq(vm.checked, true)

	# No infinite loop / no unexpected VM mutation after a single change.
	vm.checked = false
	assert_eq(box.button_pressed, false)
	assert_eq(vm.checked, false)
	autoqfree(view)


# ─── one_time ────────────────────────────────────────────────────────────

func test_one_time_sets_once_and_ignores_changes() -> void:
	var vm := Vm.new()
	vm.greeting = "Initial"

	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "greeting", "prop": "text", "mode": 1})

	var view := GdvmView.new()
	view.add_child(label)
	view.set_view_model(vm)

	# Initial push happens at build time.
	assert_eq(label.text, "Initial")

	# Subsequent changes must NOT propagate.
	vm.greeting = "Changed"
	assert_eq(label.text, "Initial")
	autoqfree(view)


# ─── list bindings (template) ───────────────────────────────────────────────

func _make_label_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := Label.new()
	root.name = "Item"
	var err := scene.pack(root)
	assert_eq(err, OK, "pack() failed")
	return scene


func test_list_template_initial_population() -> void:
	var vm := ListVm.new()
	vm.items = ["Apple", "Banana", "Cherry"]

	var container := VBoxContainer.new()
	container.set_meta(&"_gdvm_binding", {"path": "items", "template": _make_label_scene(), "item_prop": "text"})

	var view := GdvmView.new()
	view.add_child(container)
	view.set_view_model(vm)

	assert_eq(container.get_child_count(), 3)
	assert_eq((container.get_child(0) as Label).text, "Apple")
	assert_eq((container.get_child(1) as Label).text, "Banana")
	assert_eq((container.get_child(2) as Label).text, "Cherry")
	autoqfree(view)


func test_list_template_reconciles_and_emits_items_changed() -> void:
	var vm := ListVm.new()
	vm.items = ["Apple", "Banana"]

	var container := VBoxContainer.new()
	container.set_meta(&"_gdvm_binding", {"path": "items", "template": _make_label_scene(), "item_prop": "text"})

	var view := GdvmView.new()
	view.add_child(container)
	view.set_view_model(vm)

	var events: Array = []
	view.items_changed.connect(func(_c: Node, added: int, removed: int): events.append([added, removed]))

	# Grow: +2 items.
	vm.items = ["Apple", "Banana", "Cherry", "Date"]
	assert_eq(container.get_child_count(), 4)
	assert_eq((container.get_child(3) as Label).text, "Date")

	# Shrink: -2 items.
	vm.items = ["Apple", "Banana"]
	assert_eq(container.get_child_count(), 2)

	# One grow event (added=2) and one shrink event (removed=2).
	assert_eq(events.size(), 2)
	assert_eq(events[0], [2, 0])
	assert_eq(events[1], [0, 2])
	autoqfree(view)


# ─── ViewModel resolvers (Phase 5) ───────────────────────────────────────────

func test_resolver_manual_uses_existing_vm() -> void:
	var vm := Vm.new()
	vm.greeting = "Manual"

	var view := GdvmView.new()
	view.set_view_model(vm)

	# "manual" is the default; resolve_view_model keeps the existing VM.
	assert_eq(view.view_model_resolver, &"manual")
	var resolved = view.resolve_view_model()
	assert_eq(resolved, vm)
	autoqfree(view)


func test_resolver_create_instance() -> void:
	var view := GdvmView.new()
	view.view_model_resolver = &"create_instance"
	view.view_model_class = Vm

	var resolved = view.resolve_view_model()

	assert_not_null(resolved)
	assert_true(resolved is Vm)
	assert_eq(view.get_view_model(), resolved)
	autoqfree(view)


func test_resolver_global() -> void:
	ServiceLocator.clear()
	var vm := Vm.new()
	vm.greeting = "Global"
	ServiceLocator.register_singleton(&"GlobalVm", vm)

	var view := GdvmView.new()
	view.view_model_resolver = &"global"
	view.view_model_key = &"GlobalVm"

	var resolved = view.resolve_view_model()

	assert_eq(resolved, vm)
	assert_eq(view.get_view_model(), vm)
	ServiceLocator.clear()
	autoqfree(view)


func test_resolver_context_walks_parent_hierarchy() -> void:
	var vm := Vm.new()
	vm.greeting = "Context"

	var parent := ContextProvider.new(vm)
	var view := GdvmView.new()
	parent.add_child(view)

	view.view_model_resolver = &"context"
	var resolved = view.resolve_view_model()

	assert_eq(resolved, vm)
	assert_eq(view.get_view_model(), vm)
	autoqfree(parent)


# ─── Converters (Phase 6) ────────────────────────────────────────────────────

func after_each() -> void:
	GdvmView.clear_converters()


func test_converter_builtin_str() -> void:
	var vm := IntVm.new()
	vm.number = 42

	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "number", "prop": "text", "mode": 0, "converter": "str"})

	var view := GdvmView.new()
	view.add_child(label)
	view.set_view_model(vm)

	assert_eq(label.text, "42")

	vm.number = 99
	assert_eq(label.text, "99")
	autoqfree(view)


func test_converter_builtin_bool_flip() -> void:
	var vm := BoolVm.new()
	vm.checked = false

	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "checked", "prop": "text", "mode": 0, "converter": "str"})

	# str(false) == "False" in Godot; verify via bool_flip on a visibility use case.
	var box := CheckBox.new()
	box.set_meta(&"_gdvm_binding", {"path": "checked", "prop": "button_pressed", "mode": 0, "converter": "bool_flip"})

	var view := GdvmView.new()
	view.add_child(box)
	view.set_view_model(vm)

	# bool_flip: false -> true
	assert_eq(box.button_pressed, true)

	vm.checked = true
	assert_eq(box.button_pressed, false)
	autoqfree(view)


func test_converter_global_registry() -> void:
	GdvmView.register_converter(&"double_str", func(v): return str(int(v) * 2))

	var vm := IntVm.new()
	vm.number = 21

	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "number", "prop": "text", "mode": 0, "converter": "double_str"})

	var view := GdvmView.new()
	view.add_child(label)
	view.set_view_model(vm)

	assert_eq(label.text, "42")
	autoqfree(view)


func test_converter_unknown_falls_back_to_identity() -> void:
	var vm := Vm.new()
	vm.greeting = "Hello"

	var label := Label.new()
	label.set_meta(&"_gdvm_binding", {"path": "greeting", "prop": "text", "mode": 0, "converter": "does_not_exist"})

	var view := GdvmView.new()
	view.add_child(label)
	view.set_view_model(vm)

	# Unknown converter falls back to identity.
	assert_eq(label.text, "Hello")
	assert_push_warning("unknown converter")
	autoqfree(view)


# ─── Code-first bind() API ──────────────────────────────────────────────────

func test_bind_code_first_one_way() -> void:
	var vm := Vm.new()
	vm.greeting = "CodeFirst"

	var label := Label.new()
	var view := GdvmView.new()
	view.add_child(label)
	view.set_view_model(vm)

	# bind() (no mode -> default ONE_WAY) pushes the value immediately.
	view.bind(label, "greeting", "text")
	assert_eq(label.text, "CodeFirst")

	vm.greeting = "Updated"
	assert_eq(label.text, "Updated")
	autoqfree(view)


func test_bind_code_first_two_way_echo_guarded() -> void:
	var vm := BoolVm.new()
	vm.checked = false

	var box := CheckBox.new()
	var view := GdvmView.new()
	view.add_child(box)
	view.set_view_model(vm)

	view.bind(box, "checked", "button_pressed", {"mode": GdvmView.Mode.TWO_WAY, "signal": &"toggled"})
	assert_eq(box.button_pressed, false)

	# VM -> node
	vm.checked = true
	assert_eq(box.button_pressed, true)

	# node -> VM (simulate user toggle)
	box.button_pressed = false
	box.toggled.emit(false)
	assert_eq(vm.checked, false)
	autoqfree(view)


func test_bind_on_changed_replaces_snap() -> void:
	var vm := IntVm.new()
	vm.number = 1

	var label := Label.new()
	var view := GdvmView.new()
	view.add_child(label)
	view.set_view_model(vm)

	var calls: Array = []
	view.bind(label, "number", "text", {
		"on_changed": func(node: Node, new_value, _old): calls.append([node, new_value]),
	})

	# on_changed replaces the default write, so the label is NOT auto-set.
	assert_eq(label.text, "")
	assert_eq(calls.size(), 1)  # initial push fired the hook

	vm.number = 5
	assert_eq(calls.size(), 2)
	assert_eq(calls[1], [label, 5])
	autoqfree(view)


func test_bind_list_code_first_populates_and_reconciles() -> void:
	var vm := ListVm.new()
	vm.items = ["A", "B"]

	var container := VBoxContainer.new()
	var view := GdvmView.new()
	view.add_child(container)
	view.set_view_model(vm)

	view.bind_list(container, "items", _make_label_scene(), {"item_prop": "text"})
	assert_eq(container.get_child_count(), 2)

	vm.items = ["A", "B", "C"]
	assert_eq(container.get_child_count(), 3)
	assert_eq((container.get_child(2) as Label).text, "C")

	vm.items = ["A"]
	assert_eq(container.get_child_count(), 1)
	autoqfree(view)


func test_bind_list_on_added_hook() -> void:
	var vm := ListVm.new()
	vm.items = []

	var container := VBoxContainer.new()
	var view := GdvmView.new()
	view.add_child(container)
	view.set_view_model(vm)

	var added: Array = []
	view.bind_list(container, "items", _make_label_scene(), {"item_prop": "text", "on_added": func(item: Node): added.append(item)})

	vm.items = ["X"]
	assert_eq(added.size(), 1)
	assert_eq(added[0], container.get_child(0))
	autoqfree(view)


func test_bind_list_on_removed_hook_owns_free() -> void:
	var vm := ListVm.new()
	vm.items = ["A", "B"]

	var container := VBoxContainer.new()
	var view := GdvmView.new()
	view.add_child(container)
	view.set_view_model(vm)

	var removed: Array = []
	view.bind_list(container, "items", _make_label_scene(), {
		"item_prop": "text",
		"on_removed": func(item: Node):
			removed.append(item)
			item.free()  # on_removed owns freeing the row
	})

	vm.items = ["A"]
	assert_eq(removed.size(), 1)
	assert_eq(container.get_child_count(), 1)
	# The removed row was freed by the hook; remaining row + container freed by autoqfree.
	autoqfree(view)

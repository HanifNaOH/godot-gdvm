## GdvmBinder
## Code-first, runtime-only binding manager for Godot views.
##
## The binder is owned by a real scene Node but is not itself added to the tree.
## It owns signal connections and releases them when the owner exits the tree.
class_name GdvmBinder
extends RefCounted

## Binding direction modes.
enum Mode { ONE_WAY, ONE_TIME, ONE_WAY_TO_SOURCE, TWO_WAY }

static var _global_converters: Dictionary = {}

var _owner: Node
var _view_model: Object
var _change_signal: StringName = &"changed"
var _bindings: Array = []
var _list_bindings: Array = []
var _disposed: bool = false

signal items_changed(container: Node, added: int, removed: int)

class Binding:
	var node: Node
	var prop: NodePath
	var path: StringName
	var mode: int
	var signal_name: StringName
	var callback: Callable
	var converter: StringName
	var reverse_converter: Callable
	var on_changed: Callable
	var tween_opts: Dictionary
	var tween: Tween
	var writing: bool = false

	func _init(p_node: Node, p_path: StringName, p_prop: NodePath, p_mode: int) -> void:
		node = p_node
		path = p_path
		prop = p_prop
		mode = p_mode
		converter = &""
		on_changed = Callable()
		tween_opts = {}

class ListBinding:
	var container: Node
	var path: StringName
	var template: PackedScene
	var item_prop: StringName
	var item_converter: StringName
	var item_key: StringName
	var item_nodes: Array = []
	var item_identities: Array = []
	var on_added: Callable
	var on_removed: Callable

	func _init(p_container: Node, p_path: StringName, p_template: PackedScene, p_item_prop: StringName) -> void:
		container = p_container
		path = p_path
		template = p_template
		item_prop = p_item_prop
		item_converter = &""
		item_key = &""
		on_added = Callable()
		on_removed = Callable()


func _init(owner: Node) -> void:
	if owner == null or not is_instance_valid(owner):
		push_error("GdvmBinder: owner must be a valid Node.")
		_disposed = true
		return
	_owner = owner
	_owner.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)

static func register_converter(name: StringName, converter: Callable) -> void:
	assert(not name.is_empty(), "GdvmBinder.register_converter: name cannot be empty.")
	assert(converter.is_valid(), "GdvmBinder.register_converter: converter must be valid.")
	_global_converters[name] = converter

static func unregister_converter(name: StringName) -> void:
	_global_converters.erase(name)

static func clear_converters() -> void:
	_global_converters.clear()

func set_view_model(vm: Object) -> bool:
	assert(not _disposed, "GdvmBinder: binder has been disposed.")
	if vm != null:
		var signal_name := _resolve_change_signal(vm)
		if not vm.has_signal(signal_name):
			push_error("GdvmBinder: ViewModel is missing signal '%s'." % signal_name)
			return false
	_clear_connections()
	_view_model = vm
	if vm == null:
		return true
	_change_signal = _resolve_change_signal(vm)
	vm.connect(_change_signal, _on_vm_changed)
	for binding in _bindings:
		_push(binding)
	for list_binding in _list_bindings:
		_reconcile_list(list_binding, _read_vm(list_binding.path))
	return true

func get_view_model() -> Object:
	return _view_model

func bind(node: Node, path: StringName, prop: String, opts: Dictionary = {}) -> bool:
	if not _validate_binding(node, path, prop):
		return false
	var mode: int = _mode_from_value(opts.get("mode", Mode.ONE_WAY))
	if mode < Mode.ONE_WAY or mode > Mode.TWO_WAY:
		push_error("GdvmBinder: unsupported binding mode '%s'." % opts.get("mode"))
		return false
	var binding := Binding.new(node, path, NodePath(prop), mode)
	binding.converter = StringName(opts.get("converter", ""))
	if not _validate_converter(binding.converter, "converter"):
		return false
	binding.on_changed = opts.get("on_changed", Callable())
	if opts.get("tween", {}) is Dictionary:
		binding.tween_opts = opts.get("tween", {})
	if mode == Mode.ONE_WAY_TO_SOURCE or mode == Mode.TWO_WAY:
		var signal_name := StringName(opts.get("signal", ""))
		if signal_name.is_empty() or not node.has_signal(signal_name):
			push_error("GdvmBinder: node '%s' is missing binding signal '%s'." % [_node_label(node), signal_name])
			return false
		var reverse_converter = opts.get("reverse_converter", Callable())
		if reverse_converter != null and not reverse_converter is Callable:
			push_error("GdvmBinder: reverse_converter must be a valid Callable.")
			return false
		if reverse_converter is Callable and not reverse_converter.is_valid():
			push_error("GdvmBinder: reverse_converter must be a valid Callable.")
			return false
		binding.signal_name = signal_name
		binding.callback = _make_node_callback(binding)
		node.connect(signal_name, binding.callback)
		binding.reverse_converter = reverse_converter if reverse_converter is Callable else Callable()
	_bindings.append(binding)
	if mode == Mode.ONE_WAY or mode == Mode.ONE_TIME or mode == Mode.TWO_WAY:
		_push(binding)
	return true

func bind_list(container: Node, path: StringName, template: PackedScene, opts: Dictionary = {}) -> bool:
	if not _validate_binding(container, path, ""):
		return false
	if template == null or not template.can_instantiate():
		push_error("GdvmBinder: list binding requires a valid container, path, and template.")
		return false
	var binding := ListBinding.new(container, path, template, StringName(opts.get("item_prop", "")))
	binding.item_converter = StringName(opts.get("item_converter", ""))
	binding.item_key = StringName(opts.get("item_key", ""))
	if not _validate_converter(binding.item_converter, "item_converter"):
		return false
	binding.on_added = opts.get("on_added", Callable())
	binding.on_removed = opts.get("on_removed", Callable())
	_list_bindings.append(binding)
	_reconcile_list(binding, _read_vm(path))
	return true

func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	if _owner != null and is_instance_valid(_owner) and _owner.tree_exiting.is_connected(dispose):
		_owner.tree_exiting.disconnect(dispose)
	_clear_connections()
	for list_binding in _list_bindings:
		for item in list_binding.item_nodes:
			if is_instance_valid(item):
				item.queue_free()
		list_binding.item_nodes.clear()
		list_binding.item_identities.clear()
	_list_bindings.clear()
	_bindings.clear()
	_view_model = null

func _validate_binding(node: Node, path: StringName, prop: String) -> bool:
	if _disposed:
		push_error("GdvmBinder: cannot bind after dispose().")
		return false
	if _owner == null or not is_instance_valid(_owner):
		push_error("GdvmBinder: owner is no longer valid.")
		return false
	if node == null or not is_instance_valid(node):
		push_error("GdvmBinder: target node is invalid.")
		return false
	if _view_model == null or not is_instance_valid(_view_model):
		push_error("GdvmBinder: call set_view_model() before bind().")
		return false
	if path.is_empty():
		push_error("GdvmBinder: ViewModel path cannot be empty.")
		return false
	if not _view_model.get_property_list().any(func(p): return StringName(p.name) == path):
		push_error("GdvmBinder: ViewModel has no property '%s'." % path)
		return false
	if not prop.is_empty() and not node.get_property_list().any(func(p): return StringName(p.name) == StringName(prop)):
		push_error("GdvmBinder: node '%s' has no property '%s'." % [_node_label(node), prop])
		return false
	return true

func _node_label(node: Node) -> String:
	return str(node.get_path()) if node.is_inside_tree() else node.name

func _validate_converter(name: StringName, field_name: String) -> bool:
	if name.is_empty() or name == &"identity" or name in [&"str", &"bool_flip", &"percent", &"lowercase", &"uppercase"]:
		return true
	if _global_converters.has(name) and _global_converters[name] is Callable and _global_converters[name].is_valid():
		return true
	push_error("GdvmBinder: unknown %s '%s'." % [field_name, name])
	return false

func _mode_from_value(value) -> int:
	if value is String or value is StringName:
		match StringName(value):
			&"one_way": return Mode.ONE_WAY
			&"one_time": return Mode.ONE_TIME
			&"one_way_to_source": return Mode.ONE_WAY_TO_SOURCE
			&"two_way": return Mode.TWO_WAY
	return int(value)

func _resolve_change_signal(vm: Object) -> StringName:
	var script := vm.get_script() as Script
	if script != null:
		var constants := script.get_script_constant_map()
		if constants.has("CHANGE_SIGNAL"):
			return StringName(constants["CHANGE_SIGNAL"])
	if "change_signal" in vm and not StringName(vm.get("change_signal")).is_empty():
		return StringName(vm.get("change_signal"))
	return &"changed"

func _read_vm(path: StringName):
	return _view_model.get(path) if is_instance_valid(_view_model) else null

func _push(binding: Binding) -> void:
	binding.writing = true
	_apply(binding, _read_vm(binding.path), null)
	binding.writing = false

func _apply(binding: Binding, value, old_value) -> void:
	if not is_instance_valid(binding.node):
		return
	if binding.on_changed.is_valid():
		binding.on_changed.call(binding.node, value, old_value)
	elif binding.tween_opts.is_empty():
		binding.node.set_indexed(binding.prop, _convert(value, binding.converter))
	else:
		if binding.tween != null and binding.tween.is_valid():
			binding.tween.kill()
		binding.tween = _owner.create_tween()
		binding.tween.tween_property(binding.node, binding.prop, _convert(value, binding.converter), float(binding.tween_opts.get("duration", 0.25)))

func _make_node_callback(binding: Binding) -> Callable:
	return func(_a = null, _b = null, _c = null): _on_node_changed(binding)

func _on_node_changed(binding: Binding) -> void:
	if binding.writing or not is_instance_valid(_view_model):
		return
	var value = binding.node.get_indexed(binding.prop)
	if binding.reverse_converter.is_valid():
		value = binding.reverse_converter.call(value)
	_view_model.set(binding.path, value)

func _on_vm_changed(property_name: StringName, old_value, new_value) -> void:
	_prune_invalid_bindings()
	for binding in _bindings:
		if binding.mode == Mode.ONE_TIME or binding.mode == Mode.ONE_WAY_TO_SOURCE:
			continue
		if property_name.is_empty() or property_name == binding.path:
			var value = new_value
			if property_name.is_empty() and new_value is Dictionary:
				value = new_value.get(binding.path, _read_vm(binding.path))
			_apply(binding, value, old_value)
	for binding in _list_bindings:
		if property_name.is_empty() or property_name == binding.path:
			var value = new_value
			if property_name.is_empty() and new_value is Dictionary:
				value = new_value.get(binding.path, _read_vm(binding.path))
			_reconcile_list(binding, value)

func _prune_invalid_bindings() -> void:
	for i in range(_bindings.size() - 1, -1, -1):
		var binding: Binding = _bindings[i]
		if not is_instance_valid(binding.node):
			_bindings.remove_at(i)
	for i in range(_list_bindings.size() - 1, -1, -1):
		var binding: ListBinding = _list_bindings[i]
		if not is_instance_valid(binding.container):
			_list_bindings.remove_at(i)
			continue
		for item_i in range(binding.item_nodes.size() - 1, -1, -1):
			if not is_instance_valid(binding.item_nodes[item_i]):
				binding.item_nodes.remove_at(item_i)
				binding.item_identities.remove_at(item_i)

func _reconcile_list(binding: ListBinding, value) -> void:
	var values: Array = value if value is Array else []
	var old_nodes := binding.item_nodes.duplicate()
	var old_identities := binding.item_identities.duplicate()
	var old_by_identity: Dictionary = {}
	for i in old_nodes.size():
		old_by_identity[old_identities[i]] = old_nodes[i]
	var next_nodes: Array = []
	var next_identities: Array = []
	var added := 0
	for i in values.size():
		var identity = _item_identity(values[i], binding.item_key, i)
		var item: Node = old_by_identity.get(identity)
		if item != null and is_instance_valid(item):
			old_by_identity.erase(identity)
		else:
			item = binding.template.instantiate()
			binding.container.add_child(item)
			added += 1
			if binding.on_added.is_valid(): binding.on_added.call(item)
		_write_item(item, binding.item_prop, values[i], binding.item_converter)
		next_nodes.append(item)
		next_identities.append(identity)
		if item.get_index() != i:
			binding.container.move_child(item, i)
	var removed := 0
	for item in old_by_identity.values():
		if not is_instance_valid(item):
			continue
		removed += 1
		binding.container.remove_child(item)
		if binding.on_removed.is_valid(): binding.on_removed.call(item)
		else: item.queue_free()
	binding.item_nodes = next_nodes
	binding.item_identities = next_identities
	if added > 0 or removed > 0:
		items_changed.emit(binding.container, added, removed)

func _item_identity(value, key: StringName, index: int):
	if not key.is_empty():
		if value is Dictionary:
			return value.get(key, index)
		if value is Object and key in value:
			return value.get(key)
	return value if value is Object else "%s:%s:%s" % [typeof(value), str(value), index]

func _write_item(item: Node, prop: StringName, value, converter: StringName) -> void:
	if not prop.is_empty(): item.set(prop, _convert(value, converter))
	elif item.has_method("bind"): item.bind(value)
	elif item.has_method("set_item"): item.set_item(value)

func _convert(value, name: StringName):
	match name:
		&"", &"identity": return value
		&"str": return str(value)
		&"bool_flip": return not bool(value)
		&"percent": return "%d%%" % int(float(value) * 100.0)
		&"lowercase": return String(value).to_lower()
		&"uppercase": return String(value).to_upper()
		_:
			if _global_converters.has(name): return _global_converters[name].call(value)
			push_warning("GdvmBinder: unknown converter '%s'; using identity." % name)
			return value

func _clear_connections() -> void:
	if is_instance_valid(_view_model) and _view_model.has_signal(_change_signal) and _view_model.is_connected(_change_signal, _on_vm_changed):
		_view_model.disconnect(_change_signal, _on_vm_changed)
	for binding in _bindings:
		if binding.tween != null and binding.tween.is_valid(): binding.tween.kill()
		if binding.callback.is_valid() and is_instance_valid(binding.node) and binding.node.is_connected(binding.signal_name, binding.callback):
			binding.node.disconnect(binding.signal_name, binding.callback)

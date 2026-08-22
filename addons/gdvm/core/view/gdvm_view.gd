## GdvmView
## Widget-Blueprint-style declarative View (Unreal MVVM inspired).
##
## A base class for view scenes. Scene nodes declare binding via
## `metadata/_gdvm_binding`; GdvmView auto-discovers that metadata and wires the
## bindings to a change-notifying ViewModel (an `ObservableObject`).
##
## Binding metadata (on any descendant node):
##   metadata/_gdvm_binding = {
##       "path": "greeting",    # ViewModel property name
##       "prop": "text",        # node property to write
##       "mode": 0,             # GdvmView.Mode enum int (0=one_way, 1=one_time,
##                              #   2=one_way_to_source, 3=two_way)
##       "signal": "text_changed",  # (two_way / one_way_to_source) node signal
##       "converter": "str",         # (optional) value converter name
##       "template": "item.tscn",   # (list binding) sub-scene per element
##       "item_prop": "text",       # (list binding) item property to write
##       "item_converter": "str",   # (list binding) per-item converter
##   }
##
## Converters (Unreal §5, three tiers):
##   1. Built-in   — identity, str, bool_flip, percent, lowercase, uppercase
##   2. Global     — GdvmView.register_converter(name, callable)
##   3. Implicit   — identity (Godot coerces where possible) when none is named
##
## Modes:
##   one_way            ViewModel -> node (labels, health bars)
##   one_time           set once at build, never re-checked (static data)
##   one_way_to_source  node -> ViewModel (driven by `signal`)
##   two_way            ViewModel <-> node (checkboxes, sliders, inputs)
##
## List bindings: when `template` is present, the bound ViewModel property is an
## Array. GdvmView instantiates one `template` scene per element as a child of
## the annotated node and keeps them in sync, emitting `items_changed` on
## add/remove.
##
## Usage:
##   class MyView extends GdvmView:
##       pass
##
##   view.set_view_model(my_view_model)
##
## The ViewModel must emit a change signal with the signature
## `(property_name, old, new)` where `new_value` is authoritative.
## `ObservableObject` emits `changed`; other ViewModels may declare
## `const CHANGE_SIGNAL := &"property_changed"` (or an exported
## `change_signal`) to point GdvmView at their own signal (required for
## Resource-based ViewModels, whose `changed` is native).
class_name GdvmView
extends Node

## Current ViewModel (a change-notifying object).
var _view_model: Object

## The ViewModel's change-notification signal name.
## Defaults to `changed` (the `ObservableObject` convention). Resource-based
## ViewModels may use `property_changed` to avoid `Resource.changed`.
var _change_signal: StringName = &"changed"
var _change_signal_overridden: bool = false

## ── ViewModel resolution (Unreal §4) ──────────────────────────────────────

## Binding direction modes. Use these (not magic strings) everywhere — both the
## code-first bind() API and the scene metadata (which stores the enum int).
enum Mode {
	ONE_WAY,            ## ViewModel -> node (labels, health bars)
	ONE_TIME,           ## set once at build, never re-checked
	ONE_WAY_TO_SOURCE,  ## node -> ViewModel (driven by `signal`)
	TWO_WAY,            ## ViewModel <-> node (checkboxes, inputs)
}

## Which resolver to use when `resolve_view_model()` is called:
##   "manual"          — VM already assigned via `set_view_model` (default)
##   "create_instance" — instantiate `view_model_class` (Create Instance)
##   "global"          — resolve from `ServiceLocator` via `view_model_key`
##   "context"         — walk up the parent scene for an ancestor's VM
@export var view_model_resolver: StringName = &"manual"

## (create_instance) The ViewModel script to instantiate.
@export var view_model_class: Script

## (global) The ServiceLocator key to resolve the ViewModel under.
@export var view_model_key: StringName

## The ServiceLocator is a global class_name; resolved directly (no hard path).

## Active bindings.
var _bindings: Array = []

## Active list bindings (container -> template).
var _list_bindings: Array = []

## Emitted when a list binding adds or removes child items.
signal items_changed(container: Node, added: int, removed: int)


## ── Conversion system (Unreal §5) ───────────────────────────────────────────

## Global converter registry: {StringName -> Callable}. Users register reusable
## converters here, analogous to Unreal's UMVVMConversionLibraries.
static var _global_converters: Dictionary = {}


## Register a reusable converter under a name (callable takes one value,
## returns the converted value).
static func register_converter(converter_name: StringName, converter: Callable) -> void:
	assert(converter.is_valid(), "GdvmView.register_converter: converter must be valid.")
	_global_converters[converter_name] = converter


## Remove a registered converter.
static func unregister_converter(converter_name: StringName) -> void:
	_global_converters.erase(converter_name)


## Whether a converter is registered under the given name.
static func is_converter_registered(converter_name: StringName) -> bool:
	return _global_converters.has(converter_name)


## Clear all registered converters (mainly for tests).
static func clear_converters() -> void:
	_global_converters.clear()


## A single binding's state, used to guard against two-way echo loops.
class Binding:
	var node: Node
	var prop: NodePath
	var path: StringName
	var mode: int = Mode.ONE_WAY
	var signal_name: StringName
	var node_callback: Callable
	var converter: StringName = &""
	## Optional callback: func(node, new_value, old_value) -> void. When set, it
	## REPLACES the default snap-write so the view can react/animate (tween, etc.).
	var on_changed: Callable
	## Optional tween options: { "duration": float, "trans": int, "ease": int }.
	## When set (and no on_changed), the bound property is tweened toward the
	## new value instead of snapped.
	var tween_opts: Dictionary = {}
	## The active tween handle for this binding (killed on teardown/retween).
	var _tween: Tween
	## True while this binding is writing VM -> node, so the node signal handler
	## can ignore its own echo.
	var writing: bool = false

	func _init(p_node: Node, p_prop: NodePath, p_path: StringName, p_mode: int = Mode.ONE_WAY) -> void:
		node = p_node
		prop = p_prop
		path = p_path
		mode = p_mode


## A list binding: reconciles a container's children against a ViewModel Array.
class ListBinding:
	var container: Node
	var path: StringName
	var template: PackedScene
	var item_prop: StringName
	var item_converter: StringName = &""
	var item_nodes: Array = []
	## Optional callbacks fired when rows are added/removed (for enter/exit
	## animations). Signature: func(item: Node) -> void.
	var on_added: Callable
	var on_removed: Callable

	func _init(p_container: Node, p_path: StringName, p_template: PackedScene, p_item_prop: StringName, p_item_converter: StringName = &"") -> void:
		container = p_container
		path = p_path
		template = p_template
		item_prop = p_item_prop
		item_converter = p_item_converter


## Assign the ViewModel and (re)build all bindings.
## The change-notification signal is discovered from the ViewModel itself
## (see `_resolve_change_signal`), so views do not hardcode a signal name.
func set_view_model(vm: Object) -> void:
	_clear_bindings()
	_view_model = vm
	if vm != null:
		if not _change_signal_overridden:
			_change_signal = _resolve_change_signal(vm)
		_view_model.connect(_change_signal, _on_vm_changed)
		_build_bindings()


## Get the current ViewModel.
func get_view_model() -> Object:
	return _view_model


## ── Code-first binding API (Godot-native authoring) ───────────────────────

## Create a one-way VM->node binding from code (no scene metadata needed).
##
## opts (Dictionary, all optional):
##   "mode"       : GdvmView.Mode enum — default ONE_WAY
##   "signal"     : node signal for two_way / one_way_to_source
##   "converter"  : converter name (str, bool_flip, custom, ...)
##   "on_changed" : Callable(node, new_value, old_value) — replaces default snap-write
##   "tween"      : Dictionary { "duration": float, "trans": int, "ease": int }
##                  tween the prop toward new_value instead of snapping
func bind(node: Node, path: StringName, prop: String, opts: Dictionary = {}) -> void:
	assert(node != null, "GdvmView.bind: node is null.")
	assert(_view_model != null, "GdvmView.bind: call set_view_model first.")
	var meta := {
		"path": path,
		"prop": prop,
	}
	meta["mode"] = int(opts.get("mode", Mode.ONE_WAY))
	if opts.has("signal"):
		meta["signal"] = opts["signal"]
	if opts.has("converter"):
		meta["converter"] = opts["converter"]
	_build_binding_from_meta(node, meta, opts)


## Build a Binding from resolved meta + code-first opts. Unlike `_create_*`,
## this applies on_changed / tween_opts BEFORE the initial push so those hooks
## are honored on first write too.
func _build_binding_from_meta(node: Node, meta: Dictionary, opts: Dictionary) -> void:
	var mode: int = int(meta.get("mode", Mode.ONE_WAY))
	var binding := _make_binding(node, meta, mode)
	binding.on_changed = opts.get("on_changed", Callable())
	var tween_opts = opts.get("tween", {})
	if tween_opts is Dictionary and not tween_opts.is_empty():
		binding.tween_opts = tween_opts
	_bindings.append(binding)

	match mode:
		Mode.ONE_WAY, Mode.ONE_TIME:
			_push_vm_to_node(binding)
		Mode.ONE_WAY_TO_SOURCE, Mode.TWO_WAY:
			binding.signal_name = _require_signal(meta)
			binding.node_callback = _make_node_callback(binding)
			node.connect(binding.signal_name, binding.node_callback)
			if mode == Mode.TWO_WAY:
				_push_vm_to_node(binding)


## Create a list binding (container + template) from code.
##
## opts (Dictionary, all optional):
##   "item_prop"      : property to write on each instantiated row
##   "item_converter" : per-item converter
##   "on_added"       : Callable(item) — row enter animation
##   "on_removed"     : Callable(item) — row exit animation
func bind_list(node: Node, path: StringName, template: PackedScene, opts: Dictionary = {}) -> void:
	assert(node != null, "GdvmView.bind_list: node is null.")
	assert(template != null, "GdvmView.bind_list: template is null.")
	assert(_view_model != null, "GdvmView.bind_list: call set_view_model first.")
	var meta := {
		"path": path,
		"template": template,
	}
	if opts.has("item_prop"):
		meta["item_prop"] = opts["item_prop"]
	if opts.has("item_converter"):
		meta["item_converter"] = opts["item_converter"]
	_create_list(node, meta)
	var lb := _last_list_binding()
	if lb != null:
		lb.on_added = opts.get("on_added", Callable())
		lb.on_removed = opts.get("on_removed", Callable())


## Return the most recently created list binding (used by bind_list()).
func _last_list_binding() -> ListBinding:
	return _list_bindings.back() if _list_bindings.size() > 0 else null


## Resolve the ViewModel according to `view_model_resolver`, then apply it.
## Returns the resolved ViewModel (or null if resolution failed).
func resolve_view_model() -> Object:
	var vm: Object = null
	match view_model_resolver:
		&"create_instance":
			vm = _resolve_create_instance()
		&"global":
			vm = _resolve_global()
		&"context":
			vm = _resolve_context()
		_:
			# "manual": VM must already be set via set_view_model().
			vm = _view_model
	if vm != null:
		set_view_model(vm)
	return vm


## Resolver: Create Instance — the View instantiates its own ViewModel.
func _resolve_create_instance() -> Object:
	if view_model_class == null:
		push_error("GdvmView: 'create_instance' resolver requires 'view_model_class' to be set.")
		return null
	var vm = view_model_class.new()
	return vm


## Resolver: Global — resolve from the ServiceLocator.
func _resolve_global() -> Object:
	if view_model_key.is_empty():
		push_error("GdvmView: 'global' resolver requires 'view_model_key' to be set.")
		return null
	if not ServiceLocator.is_registered(view_model_key):
		push_error("GdvmView: 'global' resolver could not find '%s' in ServiceLocator." % view_model_key)
		return null
	return ServiceLocator.resolve(view_model_key)


## Resolver: Context — walk up the parent hierarchy for a ViewModel.
##
## An ancestor "provides" a ViewModel if it has a `view_model` property, or a
## `get_view_model()` method returning a non-null object.
func _resolve_context() -> Object:
	var ancestor := get_parent()
	while ancestor != null:
		var vm: Object = null
		if "view_model" in ancestor:
			vm = ancestor.get("view_model")
		elif ancestor.has_method("get_view_model"):
			vm = ancestor.call("get_view_model")
		if vm != null and vm != self:
			return vm
		ancestor = ancestor.get_parent()
	push_error("GdvmView: 'context' resolver found no ViewModel in the parent hierarchy.")
	return null


## Override the change-notification signal name (default `changed`).
## Prefer declaring `const CHANGE_SIGNAL` on the ViewModel instead; this manual
## override remains for edge cases where the signal cannot be declared there.
func set_change_signal(signal_name: StringName) -> void:
	if _view_model != null and is_instance_valid(_view_model):
		if _view_model.is_connected(_change_signal, _on_vm_changed):
			_view_model.disconnect(_change_signal, _on_vm_changed)
	_change_signal = signal_name
	_change_signal_overridden = true
	if _view_model != null and is_instance_valid(_view_model):
		_view_model.connect(_change_signal, _on_vm_changed)


## Discover the ViewModel's change-notification signal.
##
## A ViewModel may declare `const CHANGE_SIGNAL := &"property_changed"` to point
## GdvmView at its change signal (needed for Resource-based ViewModels, which
## cannot reuse the native `Resource.changed`). It may instead expose the name
## as an exported `change_signal` property. When neither is present, fall back
## to `changed` (the `ObservableObject` convention).
func _resolve_change_signal(vm: Object) -> StringName:
	var script: Script = vm.get_script() as Script
	if script != null:
		var constants: Dictionary = script.get_script_constant_map()
		if constants.has("CHANGE_SIGNAL"):
			return StringName(constants["CHANGE_SIGNAL"])
	if "change_signal" in vm:
		var signal_name: StringName = vm.get("change_signal")
		if signal_name != &"":
			return signal_name
	return &"changed"


## (Re)build bindings by scanning the view root and all descendants for
## `_gdvm_binding` metadata.
##
## The "view root" is the node to scan. When GdvmView is the scene root itself
## (as in unit tests), that is `self`. When GdvmView is a helper child node of a
## view root (as in the demo, where the annotated nodes are siblings under the
## parent Control), the root is `get_parent()`.
func _build_bindings() -> void:
	var root: Node = get_parent() if get_parent() != null else self
	_scan_node(root)


## Recursively scan a node and its children for binding metadata.
func _scan_node(node: Node) -> void:
	if node.has_meta(&"_gdvm_binding"):
		_create_binding(node, node.get_meta(&"_gdvm_binding"))
	for child in node.get_children():
		_scan_node(child)


## Create a binding for one annotated node.
func _create_binding(node: Node, meta: Dictionary) -> void:
	if meta.has("template"):
		_create_list(node, meta)
		return
	var mode: int = int(meta.get("mode", Mode.ONE_WAY))
	match mode:
		Mode.ONE_WAY:
			_create_one_way(node, meta)
		Mode.ONE_TIME:
			_create_one_time(node, meta)
		Mode.ONE_WAY_TO_SOURCE:
			_create_one_way_to_source(node, meta)
		Mode.TWO_WAY:
			_create_two_way(node, meta)
		_:
			push_warning("GdvmView: unsupported binding mode '%s'." % mode)


## One-way binding: ViewModel property -> node property.
func _create_one_way(node: Node, meta: Dictionary) -> void:
	var binding : Binding = _make_binding(node, meta, Mode.ONE_WAY)
	_bindings.append(binding)
	_push_vm_to_node(binding)


## One-time binding: ViewModel property -> node property, set once at build.
func _create_one_time(node: Node, meta: Dictionary) -> void:
	var binding : Binding = _make_binding(node, meta, Mode.ONE_TIME)
	_bindings.append(binding)
	_push_vm_to_node(binding)


## One-way-to-source binding: node signal -> ViewModel property.
func _create_one_way_to_source(node: Node, meta: Dictionary) -> void:
	var binding : Binding = _make_binding(node, meta, Mode.ONE_WAY_TO_SOURCE)
	binding.signal_name = _require_signal(meta)
	binding.node_callback = _make_node_callback(binding)
	node.connect(binding.signal_name, binding.node_callback)
	_bindings.append(binding)


## Two-way binding: ViewModel <-> node, with a loop guard.
func _create_two_way(node: Node, meta: Dictionary) -> void:
	var binding : Binding = _make_binding(node, meta, Mode.TWO_WAY)
	binding.signal_name = _require_signal(meta)

	# Connect the node -> VM direction first so the guarded initial push
	# (below) is correctly ignored as a self-echo.
	binding.node_callback = _make_node_callback(binding)
	node.connect(binding.signal_name, binding.node_callback)

	_bindings.append(binding)

	_push_vm_to_node(binding)


## Build a node->VM callback that tolerates the signal's argument count.
## Godot requires a connected callable to accept at least as many args as the
## signal emits; UI signals emit 0-2 args (pressed=0, toggled=1, value_changed=1,
## item_selected=1, ...). We read the value from the node property directly, so
## the signal args are ignored.
func _make_node_callback(binding: Binding) -> Callable:
	return func(_a = null, _b = null, _c = null): _on_node_changed(binding)


## Build a Binding from metadata, validating common fields.
func _make_binding(node: Node, meta: Dictionary, mode: int) -> Binding:
	var path : StringName = StringName(meta.get("path", ""))
	var prop : NodePath = NodePath(meta.get("prop", ""))

	assert(not path.is_empty(), "GdvmView: binding requires 'path'.")
	assert(not prop.is_empty(), "GdvmView: binding requires 'prop'.")
	assert(_view_model != null, "GdvmView: cannot bind without a ViewModel.")

	var binding := Binding.new(node, prop, path, mode)
	binding.converter = StringName(meta.get("converter", ""))
	return binding


## Extract and validate the required `signal` field.
func _require_signal(meta: Dictionary) -> StringName:
	var signal_name : StringName = StringName(meta.get("signal", ""))
	assert(not signal_name.is_empty(), "GdvmView: this mode requires a 'signal' field.")
	return signal_name


## ── List bindings (template) ────────────────────────────────────────────────

## Create a list binding: reconcile a container's children against a ViewModel
## Array property, instantiating one `template` scene per element.
func _create_list(node: Node, meta: Dictionary) -> void:
	var path : StringName = StringName(meta.get("path", ""))
	assert(not path.is_empty(), "GdvmView: list binding requires 'path'.")
	var template := _resolve_template(meta.get("template"))
	assert(template != null, "GdvmView: list binding requires a valid 'template' (PackedScene or scene path).")
	var item_prop : StringName = StringName(meta.get("item_prop", ""))
	var item_converter : StringName = StringName(meta.get("item_converter", ""))
	var binding := ListBinding.new(node, path, template, item_prop, item_converter)
	_list_bindings.append(binding)
	_reconcile_list(binding, _read_vm_value(path))


## Normalize the `template` metadata value to a PackedScene.
func _resolve_template(value) -> PackedScene:
	if value is PackedScene:
		return value
	if value is String and not (value as String).is_empty():
		var loaded = load(value)
		if loaded is PackedScene:
			return loaded
		push_warning("GdvmView: template '%s' did not resolve to a PackedScene." % value)
	return null


## Reconcile a container's children against a new Array value.
func _reconcile_list(binding: ListBinding, new_value) -> void:
	var new_array: Array = new_value if new_value is Array else []
	var old_count := binding.item_nodes.size()
	var new_count := new_array.size()
	var common := mini(old_count, new_count)

	# Update the shared prefix in place.
	for i in common:
		_write_item_value(binding.item_nodes[i], binding.item_prop, new_array[i], binding.item_converter)

	# Instantiate new items for the tail.
	var added := 0
	for i in range(common, new_count):
		var item: Node = binding.template.instantiate()
		_write_item_value(item, binding.item_prop, new_array[i], binding.item_converter)
		binding.container.add_child(item)
		binding.item_nodes.append(item)
		added += 1
		if binding.on_added.is_valid():
			binding.on_added.call(item)

	# Remove trailing items that no longer have a corresponding element.
	var removed := maxi(0, old_count - new_count)
	if removed > 0:
		for i in range(removed):
			var item: Node = binding.item_nodes[new_count]
			binding.item_nodes.remove_at(new_count)
			if binding.on_removed.is_valid():
				# The on_removed callback owns animating AND freeing the row (e.g.
				# slide out, then queue_free). We still remove it from the tree.
				binding.container.remove_child(item)
				binding.on_removed.call(item)
			else:
				binding.container.remove_child(item)
				item.queue_free()

	if added > 0 or removed > 0:
		items_changed.emit(binding.container, added, removed)


## Write an element value into an instantiated item node.
func _write_item_value(item: Node, item_prop: StringName, value, converter: StringName = &"") -> void:
	if not item_prop.is_empty():
		item.set(item_prop, _apply_converter(value, converter))
	elif item.has_method("bind"):
		item.bind(value)
	elif item.has_method("set_item"):
		item.set_item(value)


## Apply a converter to a value, resolving built-ins then the global registry.
## Falls back to identity (implicit tier) when the name is empty or unknown.
func _apply_converter(value, converter_name: StringName):
	var name := StringName(converter_name)
	if name == &"" or name == &"identity":
		return value
	match name:
		&"str":
			return str(value)
		&"bool_flip":
			return not bool(value)
		&"percent":
			return "%d%%" % int(float(value) * 100.0)
		&"lowercase":
			return String(value).to_lower()
		&"uppercase":
			return String(value).to_upper()
		_:
			if _global_converters.has(name):
				return _global_converters[name].call(value)
			push_warning("GdvmView: unknown converter '%s'; using identity." % name)
			return value


## Push the ViewModel's current value into the node (guarded against echo).
func _push_vm_to_node(binding: Binding) -> void:
	binding.writing = true
	_apply_binding_value(binding, _read_vm_value(binding.path), null)
	binding.writing = false


## Apply a new value to a binding, honoring on_changed / tween / default snap.
func _apply_binding_value(binding: Binding, new_value, old_value) -> void:
	# on_changed replaces the default write entirely (full custom reaction).
	if binding.on_changed.is_valid():
		binding.on_changed.call(binding.node, new_value, old_value)
		return
	# tween mode animates the property toward the new value.
	if not binding.tween_opts.is_empty():
		_tween_to(binding, new_value)
		return
	_write_to_node(binding.node, binding.prop, new_value, binding.converter)


## Tween the bound node property toward a target value using binding.tween_opts.
func _tween_to(binding: Binding, target) -> void:
	if not is_instance_valid(binding.node):
		return
	# Kill any in-flight tween for this binding so a new change retargets it.
	if binding._tween != null and binding._tween.is_valid():
		binding._tween.kill()
	var dur: float = float(binding.tween_opts.get("duration", 0.25))
	var trans: int = int(binding.tween_opts.get("trans", Tween.TRANS_SINE))
	var ease: int = int(binding.tween_opts.get("ease", Tween.EASE_OUT))
	binding._tween = create_tween()
	var target_prop := NodePath(binding.prop)
	binding._tween.tween_property(binding.node, target_prop, target, dur).set_trans(trans).set_ease(ease)


## Called when the ViewModel emits its change signal (connected once per view).
## NOTE: set_property emits `changed` BEFORE the setter writes, so the signal's
## `new_value` is authoritative and must be used (do not re-read the VM).
func _on_vm_changed(property_name: StringName, old_value, new_value) -> void:
	for binding in _bindings:
		# one_way_to_source is node -> VM only; one_time never re-checks.
		if binding.mode == Mode.ONE_WAY_TO_SOURCE or binding.mode == Mode.ONE_TIME:
			continue
		if property_name.is_empty() or property_name == binding.path:
			var value = new_value
			if property_name.is_empty():
				value = new_value.get(binding.path, _read_vm_value(binding.path)) if new_value is Dictionary else _read_vm_value(binding.path)
			binding.writing = true
			_apply_binding_value(binding, value, old_value)
			binding.writing = false
	for list_binding in _list_bindings:
		if property_name.is_empty() or property_name == list_binding.path:
			var value = new_value
			if property_name.is_empty():
				value = new_value.get(list_binding.path, _read_vm_value(list_binding.path)) if new_value is Dictionary else _read_vm_value(list_binding.path)
			_reconcile_list(list_binding, value)


## Called when a bound node signal fires (node -> VM direction).
## Ignores its own writer's echo via the `writing` guard, then reads the node's
## current value and writes it to the ViewModel (whose setter diffs, so a
## no-op write does not re-emit).
func _on_node_changed(binding: Binding) -> void:
	if binding.writing:
		return
	var value = _read_node_value(binding.node, binding.prop)
	if is_instance_valid(_view_model):
		_view_model.set(binding.path, value)


## Read the ViewModel's current value for a property.
func _read_vm_value(path: StringName):
	if is_instance_valid(_view_model):
		return _view_model.get(path)
	return null


## Read a node property value.
func _read_node_value(node: Node, prop: NodePath):
	if is_instance_valid(node):
		return node.get_indexed(prop)
	return null


## Write a value to a node property (if the node is still valid), applying
## any configured converter.
func _write_to_node(node: Node, prop: NodePath, value, converter: StringName = &"") -> void:
	if is_instance_valid(node):
		node.set_indexed(prop, _apply_converter(value, converter))


## Tear down all active bindings.
func _clear_bindings() -> void:
	if _view_model != null and is_instance_valid(_view_model):
		if _view_model.is_connected(_change_signal, _on_vm_changed):
			_view_model.disconnect(_change_signal, _on_vm_changed)
		for binding in _bindings:
			if binding._tween != null and binding._tween.is_valid():
				binding._tween.kill()
			if binding.node_callback.is_valid() and is_instance_valid(binding.node):
				if binding.node.is_connected(binding.signal_name, binding.node_callback):
					binding.node.disconnect(binding.signal_name, binding.node_callback)
	_bindings.clear()
	for list_binding in _list_bindings:
		for item in list_binding.item_nodes:
			if is_instance_valid(item):
				item.queue_free()
		list_binding.item_nodes.clear()
	_list_bindings.clear()

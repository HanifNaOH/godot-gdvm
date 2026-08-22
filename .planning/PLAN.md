# GDVM Binding-First Plan

## Product goal

GDVM exists to make ViewModel binding easy in Godot, with an editor workflow
inspired by Unreal's MVVM binding experience.

The primary user should be able to reference a scene node from a view script,
choose a ViewModel property and node property, choose a direction, and declare a
valid binding without editing scene metadata or adding an invisible helper node.

The product promise is:

> Code-first ViewModel binding for Godot scenes.

Unreal feature parity is reference material, not the roadmap. Commands,
messaging, and advanced collection behavior are secondary
until the binding workflow is reliable and pleasant.

## Supported architecture

```text
ObservableObject ViewModel
  -> GdvmBinder owned by the real View node
  -> explicit bindings in the view script
  -> Godot node properties and signals
```

The supported binding stack is:

- `ObservableObject` for change-notifying ViewModels
- `GdvmBinder` for code-first runtime binding and cleanup
- The real view node owns the binder; the binder is not added to the scene tree
- Editor-authored metadata is optional future tooling, not part of the runtime API

The legacy DataNode/Observer/Writer/Binder layer is deprecated and should not
receive new features.

## Production gate

The binding system is not production-ready until all of these are true:

- Multiple subscribers receive the same Messenger message.
- Bulk ViewModel changes cannot write incorrect `null` values into bindings.
- Notification timing is documented and matches hook behavior.
- ViewModel signal selection works for manual overrides and automatic discovery.
- Replacing a ViewModel disconnects all old signals and node callbacks.
- Removing or freeing a bound node does not produce errors or stale callbacks.
- Invalid paths, properties, signals, converters, and templates produce useful
  diagnostics that identify the node and binding.
- Code-first binding options use one stable, readable representation for modes.
- Every supported binding mode has focused code-first tests.
- A headless test command runs successfully in the supported Godot version.

## Roadmap

### Phase 0: Runtime correctness

- [x] Fix Messenger registration so every recipient is retained in a message list.
- [x] Define bulk notification semantics that cannot overwrite unrelated bindings.
- [x] Decide and document `on_property_changed` timing consistently.
- [x] Make `set_change_signal` reconnect correctly and define its precedence over
  ViewModel-discovered signals.
- [x] Verify Messenger callback lifetime behavior for bound methods.

**Exit criteria:** focused regression tests pass for each production-gate item
above that concerns the current runtime.

### Phase 1: Binding lifecycle and validation

- [x] Give bindings explicit attach/detach cleanup behavior.
- [x] Disconnect old ViewModels before assigning replacements.
- [x] Handle bound nodes being freed at runtime.
- [x] Validate ViewModel paths, node properties, and node signals before creating
  a binding.
- [x] Validate converters and list templates before creating a binding.
- [x] Report the scene node name/path, ViewModel path, and invalid field in diagnostics.

**Exit criteria:** repeated setup/teardown and invalid metadata tests pass with
no stale callbacks or partial bindings.

### Phase 2: Optional editor binding workflow

- Add an optional editor plugin only if a scene-authored workflow is later needed.
- Discover eligible ViewModel properties for the selected view.
- Discover node properties and compatible signals.
- Keep code-first binding as the primary workflow; any future metadata format is
  secondary and must not be required by the runtime binder.
- Show validation errors before the scene is run.
- Preserve existing metadata when editing one field.

**Exit criteria:** any future editor workflow remains optional and does not
reintroduce an invisible runtime helper node.

### Phase 3: Binding behavior and test coverage

- [x] Test code-first one-way and two-way binding behavior.
- [x] Test initial values, ViewModel replacement, disposal, invalid paths, and
  invalid node signals/properties.
- [x] Define explicit reverse conversion support for two-way bindings.
- [x] Add tests for one-time, list lifecycle, node teardown, and converter failure.
- Add a small runtime binding inspection/diagnostic mode for debugging.

**Exit criteria:** the binding contract is covered by focused GUT tests and
failures identify the offending binding.

### Phase 4: Collections and ViewModel ownership

- [x] Define the real view Node as the owner of a `GdvmBinder` instance.
- [x] Dispose the binder from the view's `_exit_tree()` lifecycle.
- [x] Document that ViewModels are not network authorities and are local
  presentation state.
- [x] Improve list reconciliation beyond index-only updates with optional
  `item_key` identity.
- [x] Reject missing and duplicate `item_key` values before mutating rows.
- [ ] Define per-item ViewModel/context behavior only if real binding scenarios
  need it.

**Exit criteria:** list and resolver behavior is documented, deterministic, and
covered by lifecycle tests.

### Phase 5: Toolkit expansion

Only after the binding gate is met:

- Improve implicit and two-way converters.
- [x] Add command cancellation, errors, progress, and argument support.
- Add stronger Messenger registration semantics where real use cases require it.
- Expand async awaitable support.

The command slice now supports optional argument arrays, logical cancellation,
progress reporting, and explicit failure signaling.

These are useful toolkit features, but they are not prerequisites for the core
binding product.

### Phase 6: Legacy removal and documentation

- Deprecate, then remove `utils.gd`, `core/data_node/`, `core/observer/`,
  `core/writer/`, and `binder/`.
- Remove legacy examples and tests only after replacement coverage exists.
- Keep `gdvm.gd` as a small facade for the supported classes.
- Rewrite the README around the inspector-driven binding workflow.
- Document supported Godot versions and the binding metadata contract.

## Current status

The code-first runtime binder, observable objects, commands, and messaging
toolkit exist. They should be treated as **prototype/partial**, not as
production-complete. The next work is diagnostics, collection edge cases, and
real-world example coverage; metadata/editor authoring is optional and follows
the code-first API.

The scalability example is `examples/_12_simulation_dashboard/`: one screen
ViewModel coordinates child unit ViewModels, while the view keeps binding local
and explicit.
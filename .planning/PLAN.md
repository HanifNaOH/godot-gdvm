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
messaging, dependency injection, and advanced collection behavior are secondary
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
- Metadata uses one stable, readable representation for binding modes.
- Every supported binding mode has tests using serialized scene metadata.
- A headless test command runs successfully in the supported Godot version.

## Roadmap

### Phase 0: Runtime correctness

- [x] Fix Messenger registration so every recipient is retained in a message list.
- [x] Define bulk notification semantics that cannot overwrite unrelated bindings.
- [x] Decide and document `on_property_changed` timing consistently.
- [x] Make `set_change_signal` reconnect correctly and define its precedence over
  ViewModel-discovered signals.
- [ ] Verify command and messenger callback lifetime behavior.

**Exit criteria:** focused regression tests pass for each production-gate item
above that concerns the current runtime. Callback lifetime verification remains
open until the messaging storage contract is finalized.

### Phase 1: Binding lifecycle and validation

- Give bindings explicit attach/detach cleanup behavior.
- Disconnect old ViewModels before assigning replacements.
- Handle bound nodes being removed or freed at runtime.
- Validate ViewModel paths, node properties, node signals, converters, and list
  templates before creating a binding.
- Report the scene node path, ViewModel path, and invalid field in diagnostics.

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

- Test one-way, one-time, one-way-to-source, and two-way bindings from actual
  scene metadata.
- Test initial values, unrelated notifications, repeated ViewModel replacement,
  node teardown, and echo suppression.
- Define converter failure behavior and two-way conversion requirements.
- Add a small runtime binding inspection/diagnostic mode for debugging.

**Exit criteria:** the binding contract is covered by focused GUT tests and
failures identify the offending binding.

### Phase 4: Collections and ViewModel ownership

- Define ownership for ViewModels created by a view, resolved globally, or
  supplied by context.
- Document disposal behavior for views, ViewModels, commands, and services.
- Improve list reconciliation beyond index-only updates where stable identity is
  needed.
- Define per-item ViewModel/context behavior only if real binding scenarios need
  it.

**Exit criteria:** list and resolver behavior is documented, deterministic, and
covered by lifecycle tests.

### Phase 5: Toolkit expansion

Only after the binding gate is met:

- Improve implicit and two-way converters.
- Add command cancellation, errors, progress, and argument support.
- Add scoped DI and stronger Messenger registration semantics.
- Expand async awaitable support.

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

The code-first runtime binder, observable objects, commands, messaging, and
service locator exist. They should be treated as **prototype/partial**, not as
production-complete. The next work is lifecycle hardening and invalid-binding
coverage; metadata/editor authoring is optional and follows the code-first API.
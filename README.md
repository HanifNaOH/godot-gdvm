# Godot View Model by GDScript

[![Tests](https://github.com/HanifNaOH/godot-gdvm/actions/workflows/test.yml/badge.svg)](https://github.com/HanifNaOH/godot-gdvm/actions/workflows/test.yml)
[![Documentation Status](https://readthedocs.org/projects/godot-gdvm/badge/?version=latest)](https://godot-gdvm.readthedocs.io/zh-cn/latest/)
[![GitHub License](https://img.shields.io/github/license/qt911025/godot-gdvm)](https://github.com/qt911025/godot-gdvm/blob/main/LICENSE)

## Supported versions

| GDVM | Godot |
|------|-------|
| 1.0.0 | ^4.7 |

## What is this

A Godot plugin for **easy, code-first ViewModel binding**, inspired by Unreal's
MVVM workflow. It pairs an `ObservableObject` ViewModel with a `GdvmBinder`
that binds scene-node properties to ViewModel fields.

The goal is simple: reference your nodes in the view script, choose a ViewModel
property and node property, and declare the binding in one readable place. The
scene stays visual-only and is not modified with binding metadata. The
accompanying commands, messaging, and service locator are supporting toolkit
features.

The Model-View-ViewModel triad:

- **Model** — plain data/services (`RefCounted`, `Resource`, `Node`). Knows nothing
  about the View or ViewModel.
- **ViewModel** — an `ObservableObject` that owns a reference to the Model and
  exposes **view-ready** properties. It notifies the View of changes via the
  `changed` signal (the Unreal `FieldNotify` equivalent).
- **View** — a `.tscn` scene plus a view script. The script owns a
	`GdvmBinder` and declares bindings; the scene remains visual-only.

## Quick start

Create a ViewModel:

```gdscript
class_name GreetingViewModel
extends ObservableObject

var greeting: String = "hello":
	set(v):
		if set_property(&"greeting", greeting, v):
			greeting = v
```

Declare bindings directly in the view script:

```gdscript
extends Control

@onready var greeting_label := %Greeting as Label

var view_model: GreetingViewModel
var binder: GdvmBinder

func _ready() -> void:
	view_model = GreetingViewModel.new()
	binder = GdvmBinder.new(self)
	binder.set_view_model(view_model)
	binder.bind(greeting_label, &"greeting", "text")

func _exit_tree() -> void:
	binder.dispose()
```

Binding is code-first; scene metadata is not required. See
`examples/_11_task_manager/` for the full pattern.

For a larger UI, see `examples/_12_simulation_dashboard/`. It demonstrates a
screen ViewModel coordinating child unit ViewModels while the view keeps its
bindings and UI behavior explicit.

## Project status

GDVM 1.0.0 is the current stable public API for Godot 4.7. The runtime is
covered by the repository's automated test and integration suites.

For Windows exports, install the export templates matching the editor build
being used. The included `Windows` preset is intended for the Mono editor and
requires the matching `4.7.1.stable.mono` templates.

The project continues to harden the following areas:

- Runtime correctness for multiple message subscribers and bulk ViewModel changes
- Reliable ViewModel replacement and bound-node teardown
- Validation and diagnostics for invalid paths, properties, signals, converters, and templates
- A stable, readable code-first binding contract
- Regression tests covering code-first bindings and lifecycle behavior
- Optional editor tooling for users who prefer scene-authored bindings

The current roadmap is in [`.planning/PLAN.md`](.planning/PLAN.md). Unreal
feature parity is reference material; reliable and easy binding comes first.

## Architecture

```
Model (plain data) → ViewModel (ObservableObject) → View (.tscn + GdvmBinder)
   "source data"       "translator, change-          "visual + binding metadata,
                        notifying via changed"        no business logic"
```

### Binding modes

| Mode (enum) | Metadata int | Direction | Use |
|------|------|-----------|-----|
| `Mode.ONE_WAY` | `0` | ViewModel → node | labels, health bars |
| `Mode.ONE_TIME` | `1` | set once at build | static data |
| `Mode.ONE_WAY_TO_SOURCE` | `2` | node → ViewModel | driven by a node `signal` |
| `Mode.TWO_WAY` | `3` | ViewModel ↔ node | inputs, checkboxes, sliders |

In the code-first API use the `GdvmBinder.Mode` enum. Two-way and
one-way-to-source bindings require a `signal` option naming the node signal that
drives the node → ViewModel direction. When the displayed value needs
conversion in both directions, provide a `reverse_converter` callable in the
binding options.

List bindings reuse rows by value or object identity. For dictionaries or model
objects whose identity must survive reordering, provide an `item_key` option:

```gdscript
binder.bind_list(%Tasks, &"items", TaskRowScene, {
	"item_key": &"id",
	"item_prop": &"text",
})
```

For rows with independent state or behavior, provide an
`item_view_model_factory`. Each created row must implement
`set_item_view_model(view_model)` or `set_view_model(view_model)`:

```gdscript
binder.bind_list(%Units, &"units", UnitRowScene, {
	"item_key": &"id",
	"item_view_model_factory": func(unit): return UnitViewModel.new(unit),
})
```

### ViewModel resolvers

ViewModels are created by the view or composition root and receive their
dependencies explicitly. Use Godot autoloads for genuinely application-wide
services, not for ViewModel state.

### Converters

Three tiers, applied when writing a value to a node:

1. **Built-in** — `str`, `bool_flip`, `percent`, `lowercase`, `uppercase`, `identity`.
2. **Global** — `GdvmBinder.register_converter(name, callable)`.
3. **Implicit** — identity fallback when no converter is named.

For Messenger recipients, prefer `register_method()` or a non-capturing handler.
A closure that captures the recipient intentionally keeps it alive.

## MVVM Toolkit (CommunityToolkit-style)

GDVM also ships the companion abstractions documented in
[`MVVM_TOOLKIT.md`](MVVM_TOOLKIT.md):

- `RelayCommand` / `AsyncRelayCommand` — commands (Unreal: ICommand). Commands
	accept an optional argument array; async commands also expose cancellation,
	progress, and failure signals. Pass an optional cancellation callback to
	`AsyncRelayCommand.new()` when the underlying operation supports cancellation.
- `Messenger` / `RequestMessage` — decoupled pub/sub and request/response.
- `ObservableRecipient` — `ObservableObject` + automatic `Messenger` lifecycle.

## Important: `set_property` emit-before-write contract

`ObservableObject.set_property` emits `changed` **before** the setter writes the
value. Listeners must use the signal's `new_value` argument (authoritative) and
must **not** re-read the property inside a `changed` handler (they would see the
stale value).

## Usage notes

### Public API and compatibility

The supported public API is exposed through the `Gdvm` facade and the
code-first classes documented in this README and `MVVM_TOOLKIT.md`:
`ObservableObject`, `ObservableRecipient`, `GdvmBinder`, `RelayCommand`,
`AsyncRelayCommand`, `Messenger`, and the request message types. Files under
`addons/gdvm/core/` are implementation locations, not a promise that every
internal symbol is public.

The public API follows SemVer: breaking public API changes require a major
version, backward-compatible features use minor versions, and fixes use patch
versions. Deprecated APIs remain available for at least one minor release when
practical, with migration notes in release documentation.

The previous DataNode/Observer/Writer/Binder data-binding layer has been
**removed** in favor of the code-first `ObservableObject` + `GdvmBinder` stack.
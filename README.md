# Godot View Model by GDScript

[![Tests](https://github.com/HanifNaOH/godot-gdvm/actions/workflows/test.yml/badge.svg)](https://github.com/HanifNaOH/godot-gdvm/actions/workflows/test.yml)
[![Documentation Status](https://readthedocs.org/projects/godot-gdvm/badge/?version=latest)](https://godot-gdvm.readthedocs.io/zh-cn/latest/)
[![GitHub License](https://img.shields.io/github/license/qt911025/godot-gdvm)](https://github.com/qt911025/godot-gdvm/blob/main/LICENSE)

## Supported versions

| GDVM | Godot |
|------|-------|
| ~0.3 | ^4.5 |

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

authored bindings and future editor tooling. It is not required for code-first
Binding is code-first; scene metadata is not required. See
`examples/_11_task_manager/` for the full pattern.

## Project status

GDVM is currently **beta/prototype**, not a production-ready framework. The
runtime binding engine exists, but the production foundation is still being
hardened.

Before using GDVM as a shared production dependency, the project must complete:

- Runtime correctness for multiple message subscribers and bulk ViewModel changes
- Reliable ViewModel replacement and bound-node teardown
- Validation and diagnostics for invalid paths, properties, signals, converters, and templates
- A stable, readable scene metadata contract for binding modes
- Regression tests covering serialized scene bindings and lifecycle behavior
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
drives the node → ViewModel direction.

### ViewModel resolvers

ViewModel resolution is handled by the view script and `GdvmBinder`:

| Resolver | Behavior |
|----------|----------|
| `manual` | caller provides VM via `set_view_model` |
| `create_instance` | View instantiates `view_model_class` |
| `global` | resolve from `ServiceLocator` via `view_model_key` |
| `context` | walk up the parent hierarchy for an ancestor's VM |

### Converters

Three tiers, applied when writing a value to a node:

1. **Built-in** — `str`, `bool_flip`, `percent`, `lowercase`, `uppercase`, `identity`.
2. **Global** — `GdvmBinder.register_converter(name, callable)`.
3. **Implicit** — identity fallback when no converter is named.

## MVVM Toolkit (CommunityToolkit-style)

GDVM also ships the companion abstractions documented in
[`MVVM_TOOLKIT.md`](MVVM_TOOLKIT.md):

- `RelayCommand` / `AsyncRelayCommand` — commands (Unreal: ICommand).
- `Messenger` / `RequestMessage` — decoupled pub/sub and request/response.
- `ServiceLocator` — IoC service resolution (Unreal: MVVMSubsystem).
- `ObservableRecipient` — `ObservableObject` + automatic `Messenger` lifecycle.

## Important: `set_property` emit-before-write contract

`ObservableObject.set_property` emits `changed` **before** the setter writes the
value. Listeners must use the signal's `new_value` argument (authoritative) and
must **not** re-read the property inside a `changed` handler (they would see the
stale value).

## Usage notes

**Gdvm is still in beta.** APIs are not yet stable; updates before 1.0 are
breaking. Use with care.

The previous DataNode/Observer/Writer/Binder data-binding layer has been
**removed** in favor of the code-first `ObservableObject` + `GdvmBinder` stack.
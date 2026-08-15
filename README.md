# Godot View Model by GDScript

[![Tests](https://github.com/HanifNaOH/godot-gdvm/actions/workflows/test.yml/badge.svg)](https://github.com/HanifNaOH/godot-gdvm/actions/workflows/test.yml)
[![Documentation Status](https://readthedocs.org/projects/godot-gdvm/badge/?version=latest)](https://godot-gdvm.readthedocs.io/zh-cn/latest/)
[![GitHub License](https://img.shields.io/github/license/qt911025/godot-gdvm)](https://github.com/qt911025/godot-gdvm/blob/main/LICENSE)

## Supported versions

| GDVM | Godot |
|------|-------|
| ~0.3 | ^4.5 |

## What is this

A Godot plugin implementing an **Unreal-inspired MVVM** framework: an
`ObservableObject` ViewModel paired with a declarative `GdvmView` that binds
scene-node properties to ViewModel fields via `.tscn` metadata.

The Model-View-ViewModel triad:

- **Model** — plain data/services (`RefCounted`, `Resource`, `Node`). Knows nothing
  about the View or ViewModel.
- **ViewModel** — an `ObservableObject` that owns a reference to the Model and
  exposes **view-ready** properties. It notifies the View of changes via the
  `changed` signal (the Unreal `FieldNotify` equivalent).
- **View** — a `.tscn` scene whose root carries a `GdvmView` script. Nodes declare
  bindings via `metadata/_gdvm_binding`; the view holds zero business logic.

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

Declare bindings in the scene, on each bound node:

```
metadata/_gdvm_binding = {
	"mode": 0,   # GdvmView.Mode enum int: 0=one_way, 1=one_time, 2=one_way_to_source, 3=two_way
	"path": "greeting",
	"prop": "text"
}
```

Wire the ViewModel to the View in the code-behind:

```gdscript
extends Control

@onready var gdvm_view: GdvmView = $GdvmView

var view_model: GreetingViewModel

func _ready() -> void:
	view_model = GreetingViewModel.new()
	gdvm_view.set_view_model(view_model)
```

See `examples/_9_widget_blueprint/` for the full pattern.

## Architecture

```
Model (plain data) → ViewModel (ObservableObject) → View (.tscn + GdvmView)
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

In the code-first API use the `GdvmView.Mode` enum; in scene metadata store the
integer shown above. Two-way and one-way-to-source bindings require a `signal`
field naming the node signal that drives the node → ViewModel direction.

### ViewModel resolvers

`GdvmView` resolves its ViewModel via `view_model_resolver`:

| Resolver | Behavior |
|----------|----------|
| `manual` | caller provides VM via `set_view_model` |
| `create_instance` | View instantiates `view_model_class` |
| `global` | resolve from `ServiceLocator` via `view_model_key` |
| `context` | walk up the parent hierarchy for an ancestor's VM |

### Converters

Three tiers, applied when writing a value to a node:

1. **Built-in** — `str`, `bool_flip`, `percent`, `lowercase`, `uppercase`, `identity`.
2. **Global** — `GdvmView.register_converter(name, callable)`.
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
**removed** in favor of the Unreal-ish `ObservableObject` + `GdvmView` stack.
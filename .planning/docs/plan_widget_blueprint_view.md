# Plan: Scalable Code-First MVVM

**Status:** Runtime binder implemented; per-item ViewModel support implemented

## Goal

Support large Godot UIs without forcing one giant ViewModel or one giant binder.
Views declare bindings in their own scripts, and list rows may own independent
ViewModels when their behavior becomes substantial.

## Architecture

```text
ScreenView
  owns ScreenViewModel + GdvmBinder
  -> SectionView
       owns SectionViewModel + GdvmBinder
  -> ListView
       owns ListViewModel + GdvmBinder
       -> RowView
            owns RowViewModel + GdvmBinder
```

A child ViewModel is justified when a UI component owns meaningful state or
behavior such as commands, validation, loading, permissions, or async work.
Simple rows can continue receiving a plain model and using the parent ViewModel.

## Code-first binding contract

`GdvmBinder` extends `RefCounted` and is owned by a real view `Node`. It is not
added to the scene tree.

```gdscript
binder = GdvmBinder.new(self)
binder.set_view_model(view_model)
binder.bind(%Title, &"title", "text")
```

The view must call `binder.dispose()` in `_exit_tree()`. The binder also listens
to the owner's `tree_exiting` signal as a safety net.

## Per-item ViewModel contract

`bind_list()` accepts an optional `item_view_model_factory` callable. The factory
receives the collection element and returns that row's ViewModel. The row scene
must implement one of:

```gdscript
func set_item_view_model(view_model: Object) -> void:
    ...

# or
func set_view_model(view_model: Object) -> void:
    ...
```

Example:

```gdscript
binder.bind_list(%Units, &"units", UnitRowScene, {
    "item_key": &"id",
    "item_view_model_factory": func(unit): return UnitViewModel.new(unit),
})
```

The parent binder creates and assigns row ViewModels. The row owns its local
binder and presentation lifecycle. Existing rows are reused by `item_key` during
reordering; duplicate, missing, or empty keys are rejected before mutation.

## Responsibilities

- `ObservableObject`: ViewModel state and change notifications
- `GdvmBinder`: local property/list binding, signal connections, conversion, cleanup
- View script: creates dependencies, creates ViewModels, declares bindings, handles
  view-specific events
- Model/network layer: authoritative data and multiplayer synchronization
- Row ViewModel: row-specific state and behavior when needed

GDVM does not own networking, authority, replication, or RPC behavior. Each peer
creates local ViewModels and binders from its current presentation state.

## Deferred work

- Per-item context inheritance beyond explicit factory assignment
- Virtualized lists for very large collections
- More advanced collection diffing and batching
- Runtime binding inspection tools
- Optional editor authoring, only if code-first binding proves insufficient

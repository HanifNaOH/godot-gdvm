# MVVM Feature Comparison: GDVM vs Unreal Engine

**Type:** Reference / Gap analysis (not an implementation plan)
**Created:** 2026-08-14
**Updated:** 2026-08-15 — re-anchored to the Unreal-ish MVVM layer (legacy DataNode/Observer/Writer deprecated)
**Status:** Open for discussion

---

## Purpose

Unreal Engine ships an official, performance-oriented MVVM framework (`UMVVMViewModelBase`,
`MVVMView`, `MVVMSubsystem`). This document compares its feature set against GDVM's MVVM
implementation, and identifies where GDVM has an equivalent, a partial equivalent, or a gap.

> This is **not** a roadmap. It is a comparison to clarify what GDVM already provides and
> where the two systems differ, so future decisions are grounded.

---

## 1. Core architecture

| Unreal MVVM | GDVM (Unreal-ish) | Status |
|-------------|-------------------|--------|
| **Model** — C++ classes, Data Tables, Actor variables | plain `RefCounted` / `Resource` / `Node` (no GDVM base class) | ✅ equivalent |
| **ViewModel** — `UMVVMViewModelBase` (`UObject`) | `ObservableObject` / `ObservableRecipient` | ✅ equivalent |
| **View** — Widget Blueprint | `.tscn` scene + `GdvmView` (metadata-driven binding) | ✅ equivalent |

## 2. FieldNotify system (replaces Tick/polling)

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| `FieldNotify` specifier / "Bell" icon on variables | `changed` signal via `ObservableObject.set_property` | ✅ equivalent (event-driven) |
| `BlueprintPure` FieldNotify functions (e.g. `GetHealthPercent()`) | getter-only derived properties + `notify_property_changed` | ✅ equivalent |
| `UE_MVVM_BROADCAST_FIELD_VALUE_CHANGED(Name)` manual broadcast | `ObservableObject.notify_property_changed(name)` | ✅ equivalent |

## 3. Binding modes

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| **One Way** (Source → Dest) | `mode: "one_way"` | ✅ |
| **Two Way** (Source ↔ Dest) | `mode: "two_way"` + `signal` (loop-guarded) | ✅ |
| **One Way to Source** (Dest → Source) | `mode: "one_way_to_source"` + `signal` | ✅ |
| **One Time** (set once, never re-checked) | `mode: "one_time"` | ✅ |

## 4. ViewModel resolution / discovery

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| **Create Instance** (widget makes its own VM) | `view_model_resolver = "create_instance"` | ✅ |
| **Manual** (`SetViewModel`) | `set_view_model(vm)` | ✅ |
| **Global VM collection** (`MVVMSubsystem` singleton) | `ServiceLocator` + `view_model_resolver = "global"` | ✅ |
| **Context Resolver** (search parent hierarchy) | `view_model_resolver = "context"` | ✅ |

## 5. Conversion functions

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| Simple converters (bool flip, number→text) | built-ins (`str`, `bool_flip`, `percent`, `lowercase`, `uppercase`) | ✅ |
| Global conversion libraries (`UMVVMConversionLibraries`) | `GdvmView.register_converter(name, callable)` | ✅ |
| Implicit converters (UE 5.8+) | identity fallback when no converter is named | ⚠️ partial (no auto-coercion) |

## 6. C++ macros / setter control

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| `UE_MVVM_SET_PROPERTY_VALUE(Field, NewValue)` (compare + broadcast) | `ObservableObject.set_property` / `set_properties` | ✅ equivalent |
| Custom getter/setter specifiers (`Setter="SetHealth"`) | GDScript property setter blocks | ✅ equivalent |

## 7. Panel widget view extensions (dynamic lists)

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| Bind a `TArray` to a `ListView`/`TileView`; auto-create/destroy child widgets | `GdvmView` list binding (`template` + `item_prop`) | ✅ equivalent |
| `OnItemsChanged` delegate for custom animation | `GdvmView.items_changed` signal | ✅ equivalent |

## 8. Performance & best practices

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| Event-driven (no polling) | `changed` signal convention | ✅ equivalent |
| ViewModel testable in isolation | GUT unit tests exist (`tests/unit/core/*`) | ✅ equivalent |
| Avoid hard references (GC / memory) | `WeakRef` used in `Messenger` | ✅ equivalent |

---

## Gap summary

Remaining gaps after the Unreal-ish rewrite:

1. **Editor plugin** — no inspector UI to author `_gdvm_binding` metadata (Phase 7, not implemented).
2. **Implicit converters** — only identity fallback; no automatic type coercion (UE 5.8-style).
3. **Per-item ViewModel resolution in lists** — list bindings reconcile a `template` scene per
   element but do not resolve a per-item context/ViewModel.
4. **`AsyncRelayCommand` awaitable coverage** — completion detection relies on a returned
   `Signal`; coroutine/`await` return values are not handled.

---

## Notes / open questions

- The legacy `utils.gd` type system and DataNode strict nodes are **deprecated**; they have no
  role in the Unreal-ish layer and are scheduled for removal.
- Whether the remaining gaps (editor plugin, implicit converters, per-item VM resolution) are
  worth addressing is tracked in [`plan_widget_blueprint_view.md`](./plan_widget_blueprint_view.md).

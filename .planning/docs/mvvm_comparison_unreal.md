# MVVM Feature Comparison: GDVM vs Unreal Engine

**Type:** Reference / Gap analysis (not an implementation plan)
**Created:** 2026-08-14
**Updated:** 2026-08-15 — re-anchored to the Unreal-ish MVVM layer (legacy DataNode/Observer/Writer deprecated)
**Status:** Reference only; not a production-readiness claim

---

## Purpose

Unreal Engine ships an official, performance-oriented MVVM framework (`UMVVMViewModelBase`,
`MVVMView`, `MVVMSubsystem`). This document compares its feature set against GDVM's MVVM
implementation, and identifies where GDVM has an equivalent, a partial equivalent, or a gap.

> This is **not** a roadmap or a claim that the implementation is production-ready. It is a
> comparison to clarify the intended design vocabulary. The product priority is easy,
> validated, inspector-driven binding in Godot; Unreal feature parity is secondary.

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

## Binding-first gap summary

The highest-priority gaps are not Unreal feature gaps; they are requirements for
making binding dependable and easy to author:

1. **Editor workflow** — no inspector UI creates or edits `_gdvm_binding` metadata.
2. **Validation and diagnostics** — invalid paths, properties, signals, converters, and templates
   need actionable editor and runtime errors.
3. **Lifecycle** — ViewModel replacement, node removal, teardown, and ownership need explicit
   contracts and tests.
4. **Notification correctness** — bulk updates, hook timing, and custom change-signal overrides
   need consistent behavior.
5. **Metadata contract** — mode values must use one stable representation; documented strings and
   runtime integer enums currently disagree.

Secondary gaps are implicit converters, per-item ViewModel resolution, advanced collection
diffing, and broader async command coverage. They should follow the binding production gate.

---

## Notes / open questions

- The legacy `utils.gd` type system and DataNode strict nodes are **deprecated**; they have no
  role in the Unreal-ish layer and are scheduled for removal.
- The binding-first roadmap and production gate are tracked in [`../PLAN.md`](../PLAN.md).

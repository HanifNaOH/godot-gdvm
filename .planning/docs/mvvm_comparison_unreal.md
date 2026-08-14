# MVVM Feature Comparison: GDVM vs Unreal Engine

**Type:** Reference / Gap analysis (not an implementation plan)
**Created:** 2026-08-14
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

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| **Model** — C++ classes, Data Tables, Actor variables | `core/data_node/*` (Variant/Struct/List/Dict/Node/Strict) + `ObservableObject` | ✅ equivalent |
| **ViewModel** — `UMVVMViewModelBase` (`UObject`) | `core/component_model/observable_object.gd` / `observable_recipient.gd` | ✅ equivalent |
| **View** — Widget Blueprint | (GDVM leaves View to the scene tree; binding via Observer/Writer) | ⚠️ different shape |

## 2. FieldNotify system (replaces Tick/polling)

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| `FieldNotify` specifier / "Bell" icon on variables | `changed` signal convention (`ObservableObject.set_property`, `DataNode.changed`) | ✅ equivalent (event-driven) |
| `BlueprintPure` FieldNotify functions (e.g. `GetHealthPercent()`) | `DataNodeStruct` computed properties (`add_computed_properties`) | ✅ equivalent |
| `UE_MVVM_BROADCAST_FIELD_VALUE_CHANGED(Name)` manual broadcast | `DataNode.mark_changed()` / `notify_can_execute_changed()` | ✅ equivalent |

## 3. Binding modes

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| **One Way** (Source → Dest) | `Observer` (source → DataNode) | ✅ equivalent |
| **Two Way** (Source ↔ Dest) | `Observer` + `Writer` together | ✅ equivalent |
| **One Way to Source** (Dest → Source) | `Writer` (DataNode → source) | ✅ equivalent |
| **One Time** (set once, never re-checked) | none | ❌ **gap** (no "one-time" binding mode) |

## 4. ViewModel resolution / discovery

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| **Create Instance** (widget makes its own VM) | manual instantiation | ⚠️ equivalent (manual) |
| **Manual** (`SetViewModel`) | manual wiring in `ObserverPack` / `WriterPack` | ✅ equivalent |
| **Global VM collection** (`MVVMSubsystem` singleton) | `core/dependency_injection/service_locator.gd` | ✅ equivalent |
| **Context Resolver** (search parent hierarchy, UE 5.6+) | none | ❌ **gap** (no parent-hierarchy VM discovery) |

## 5. Conversion functions

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| Simple converters (bool flip, number→text) | strict nodes' coercion (e.g. `strict/string.gd` `str()`) | ⚠️ partial (coercion, not display conversion) |
| Global conversion libraries (`UMVVMConversionLibraries`) | none | ❌ **gap** (no reusable conversion library) |
| Implicit converters (UE 5.8+) | strict-node coercions | ⚠️ partial |

## 6. C++ macros / setter control

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| `UE_MVVM_SET_PROPERTY_VALUE(Field, NewValue)` (compare + broadcast) | `ObservableObject.set_property` / `set_properties` | ✅ equivalent |
| Custom getter/setter specifiers (`Setter="SetHealth"`) | GDScript property setter blocks | ✅ equivalent |

## 7. Panel widget view extensions (dynamic lists)

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| Bind a `TArray` to a `ListView`/`TileView`; auto-create/destroy child widgets | `core/observer/node.gd` + `core/writer/node.gd` with `DataNodeList` | ✅ equivalent |
| `OnItemsChanged` delegate for custom animation | `DataNodeList.order_changed` / `changed` signals | ✅ equivalent |

## 8. Performance & best practices

| Unreal MVVM | GDVM | Status |
|-------------|------|--------|
| Event-driven (no polling) | `changed` signal convention | ✅ equivalent |
| ViewModel testable in isolation | GUT unit tests exist (`tests/unit/core/*`) | ✅ equivalent |
| Avoid hard references (GC / memory) | `WeakRef` used in Observer/Writer/Messenger | ✅ equivalent |

---

## Gap summary

Three features exist in Unreal MVVM but have **no GDVM equivalent**:

1. **One-Time binding mode** — set once at construction, never re-checked (perf for static data).
2. **Context Resolver** — a widget searches its parent hierarchy to find a ViewModel (UE 5.6+).
3. **Global conversion libraries** — reusable, user-defined value converters (beyond primitive coercion).

---

## Notes / open questions

- GDVM's type system (`utils.gd` 4-form notation, strict nodes) has no Unreal analogue because
  GDScript lacks C++ property reflection; the comparison above treats GDVM's coercion as its
  "conversion" story.
- Whether the three gaps are worth addressing is deliberately **out of scope** for this ticket.

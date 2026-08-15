# Plan: Unreal-ish MVVM (the sole retained architecture)

**Status:** Core implemented (Phases 0–6 done); legacy DataNode/Observer/Writer/Binder deprecated
**Created:** 2026-08-14
**Updated:** 2026-08-15 (re-scoped: delete legacy layer, keep Unreal-ish MVVM)
**Related:** [`mvvm_comparison_unreal.md`](./mvvm_comparison_unreal.md)

---

## 1. Goal

Make the **Unreal-ish MVVM stack** the single supported architecture: `ObservableObject`
ViewModel + `GdvmView` declarative binding, with a code-behind script for view logic — the
Widget Blueprint (WBP) model adapted to Godot.

The legacy **DataNode / Observer / Writer / Binder** layer is deprecated and will be removed:
it was the "UI-agnostic" imperative binding system (`ObserverPackTree`/`WriterPackTree` opts
dicts, manual lambdas). That layer carries no binding metadata in the scene; the new `GdvmView`
moves binding **into the `.tscn`** as node metadata, matching WBP's "asset declares look AND
binding".

## 2. Locked decisions

These are final; everything below follows from them.

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | `GdvmView` **extends `Node`**, not `Control` | UI-agnostic; the binder only needs `Node` API (`get_node`, `get_children`, `child_order_changed`, `add_child`, `set_indexed`). Works for `Control`/`Node2D`/`Node3D` roots. |
| D2 | **Default ViewModel = `ObservableObject`** | Simpler to author (plain class + setters), pairs with the existing toolkit, and avoids the DataNode/strict machinery on the view side. |
| D3 | `DataTree` is **deprecated** (legacy) | Replaced by `ObservableObject` + `GdvmView`; removed from the public surface. |
| D4 | Binding is **metadata on scene nodes** (`_gdvm_binding`) | Data lives in the `.tscn`; logic lives in the `GdvmView` code-behind. |
| D5 | Build **smallest vertical slice first** | Prove the loop (metadata → `one_way` bind → demo) before expanding. |

## 3. Architecture

```
Model (plain data) → ViewModel (ObservableObject) → View (.tscn + GdvmView)
     "source data"        "translator, change-      "visual + binding metadata,
                          notifying via changed"      no business logic"
```

### Three pillars (Unreal §1)

- **Model** — plain source data (`RefCounted`/`Resource` classes, dictionaries, data tables).
  Not observable by the view.
- **ViewModel** — an `ObservableObject` (or `DataTree`) that *owns a reference to the Model*
  and exposes **view-ready** properties + signals. The "translator".
- **View** — a `.tscn` scene whose root carries a `GdvmView` script; nodes declare binding via
  metadata. Binding `path` addresses the **ViewModel, never the Model**.

### Core shape

```
┌─ View (a .tscn, root has GdvmView script) ─────────────┐
│  Nodes with metadata/_gdvm_binding annotations         │
│  └─ GdvmView (extends Node) base:                      │
│       set_view_model(vm) → scans scene → builds        │
│       Observer/Writer from metadata → binds            │
└────────────────────────────────────────────────────────┘
```

## 4. Binding annotation (scene metadata)

Per-node, stored in `.tscn` metadata (data-only, serializable):

```tscn
[node name="HealthLabel" type="Label" parent="Panel"]
text = "HP"
metadata/_gdvm_binding = {
  "path": "health_text",      # key into the ViewModel (property name for ObservableObject)
  "prop": "text",             # the node property to bind
  "mode": "one_way",          # one_way | two_way | one_way_to_source | one_time
  "signal": "text_changed",   # (two_way / one_way_to_source only) node → VM source signal
  "template": "item.tscn"     # (list binding only) sub-scene instantiated per element
}
```

### Field semantics

| Field | When required | Purpose |
|-------|---------------|---------|
| `path` | always | VM property name (or DataNode path) |
| `prop` | always | target node property |
| `mode` | always | binding direction |
| `signal` | `two_way`, `one_way_to_source` | which node signal drives node → VM |
| `template` | list binding | sub-scene to instantiate per element |

> **Constraint:** `.tscn` metadata cannot hold `Callable`s. Data-only fields live in metadata;
> logic (converters, signal-getters) lives in the `GdvmView` code-behind. This mirrors Unreal's
> split: data in the asset, logic in the code-behind.

## 5. `GdvmView` base class (`extends Node`)

Responsibilities:
- `set_view_model(vm)` — store VM, trigger `_build_bindings()`
- `_build_bindings()` — walk children, read `_gdvm_binding` metadata, instantiate the matching
  `Observer`/`Writer`
- Resolver support (Phase 5)
- Code-behind surface: view scripts override hooks like `get_converter(path)` for logic

## 6. ViewModel contract (FieldNotify equivalent, Unreal §2)

`GdvmView` binds to a **change-notifying** ViewModel. The VM must emit change notification:

- **Variables** → `ObservableObject.changed` signal (via setters using `set_property`).
- **Derived data** → a derived property kept in sync by a setter (simplest); an optional
  `get_derived(path)` view override for computed values (Phase 6).
- **Manual notification** → `ObservableObject.notify_property_changed(name)` (added in Phase 0;
  the `UE_MVVM_BROADCAST_FIELD_VALUE_CHANGED` equivalent).

> **Change routing.** The `changed` signal carries `property_name` (and old/new values). The
> binding engine must **filter by `property_name`** and map it back to the matching `path` so a
> single VM `changed` emission updates only the affected binding(s), not the whole view.

## 7. Binding modes (Unreal §3)

| Mode | Direction | Use | Phase |
|------|-----------|-----|-------|
| `one_way` | VM → node | labels, health bars | 1 |
| `one_way_to_source` | node → VM | (rare; driven by `signal`) | 2 |
| `two_way` | VM ↔ node | checkboxes, sliders, inputs | 2 |
| `one_time` | set once at build | static data (perf) | 4 |

### Loop guard (two-way, Phase 2) — **critical**

`two_way` has an echo hazard: the writer sets a node property, which may re-emit `signal`, which
the observer feeds back into the VM, which re-emits `changed`, ad infinitum. Whether this
happens depends on the node type — e.g. setting `LineEdit.text` programmatically **does** emit
`text_changed`, while setting `CheckBox.button_pressed` **does not** emit `pressed`.

To make `two_way` safe regardless of node type, the binding engine must track **change source**:
- The `Observer` (node → VM) must skip writing when the VM value it is about to write equals the
  value it just received from the `Writer` (no-op on echo), or
- the engine suppresses re-entry per binding (a one-tick "writing" flag) so a programmatic
  property set is not interpreted as a user edit.

Recommended: per-binding **source-tagging** — mark writes as `FROM_VM`; the observer ignores
`signal` emissions originating from its own writer. This must be designed into Phase 2, not
retro-fitted.

## 8. ViewModel resolvers (Unreal §4, Phase 5)

| Resolver | Behavior |
|----------|----------|
| `create_instance` | View creates its own VM instance |
| `manual` | caller provides VM via `set_view_model` |
| `global` | resolve from `ServiceLocator` |
| `context` | walk up the parent scene for an ancestor with a VM |

## 9. List / panel view extensions (Unreal §7, Phase 4)

When a bound property is a collection:
- Bind it to a container node; **auto-create / destroy** child view instances per element
  (reuse `WriterNode`/`DataNodeList` + the `template` sub-scene).
- Emit `items_changed` (added/removed) so views can run custom add/remove animation — the
  `OnItemsChanged` equivalent.

## 10. Conversion functions (Unreal §5, Phase 6)

Three tiers (all in code-behind / a conversion library, since metadata can't hold `Callable`s):
1. **Built-in** — number→text, bool flip, number→percent, string case, identity no-op.
2. **Global library** — a static registry of reusable converters (`SecondsToMinutes`,
   `ItemTypeToIcon`) analogous to `UMVVMConversionLibraries`.
3. **Implicit** — default fallback on type mismatch (UE 5.8-style), overridable per view.

## 11. What we keep vs. remove

- **Keep:** the MVVM toolkit (`ObservableObject`, `ObservableRecipient`, `RelayCommand`,
  `AsyncRelayCommand`, `Messenger`, `RequestMessage`, `ServiceLocator`) + `GdvmView`.
- **Remove (deprecate → delete):** `DataNode` tree (incl. `strict/`), `Observer`/`Writer` core,
  `DataTree`/`ObserverPack`/`WriterPack` binder, and `utils.gd`.
- **This is a rewrite toward Unreal-ish MVVM only.** The legacy imperative API is not kept.

## 12. Phased implementation

Built as a minimal vertical slice first, then expanded outward.

| Phase | What | Result |
|-------|------|--------|
| **0** | `ObservableObject.notify_property_changed(name)` + test | manual-broadcast parity (~5 lines) |
| **1** | `GdvmView` (Node) + metadata read + `one_way` binding + a demo | proven core loop |
| **2** | `one_way_to_source` + `two_way` (using `signal`) | bidirectional binding |
| **3** | `set_view_model` polish (export + manual) | stable VM assignment |
| **4** | `one_time` + list `template` + `items_changed` | static + collection rendering |
| **5** | 4 resolvers (create/manual/global/context) | WBP-style VM discovery |
| **6** | conversion system (built-ins → global lib → implicit) | type-mismatch handling |
| **7** | `EditorPlugin` to author metadata in inspector | "Binding tab" DX |

**Implementation status:** Phases 0–6 are **implemented** in `core/view/gdvm_view.gd` (with
tests in `tests/unit/core/view/`). Phase 7 (editor plugin) is the only remaining item.

**Recommended scope for the next version:** Phase 7 (editor plugin) plus the deprecation/removal
of the legacy layer (see §11).

## 13. Unreal feature coverage

| Unreal feature | Plan section | Status |
|----------------|-------------|--------|
| §1 Core architecture (Model/VM/View) | §3 | ✅ Model separation explicit |
| §2 FieldNotify (vars, functions, manual) | §6 | ✅ + Phase 0 helper |
| §3 Binding modes (One/Two/One-to-Src/One-Time) | §7 | ✅ + `signal` field + loop guard |
| §4 ViewModel resolvers (4) | §8 | ✅ |
| §5 Conversion functions | §10 | ✅ 3-tier |
| §6 C++ macros / setter control | §11 (keep) | ✅ inherited |
| §7 Panel view extensions (lists) | §9 | ✅ + `template` field |
| §8 Performance & best practices | §11 (keep) | ✅ WeakRef/event-driven/testable |

## 14. Open questions (remaining)

- Editor plugin UX for authoring `_gdvm_binding` metadata (Phase 7).
- Per-item ViewModel/context resolution for list bindings.
- `AsyncRelayCommand` coverage for non-`Signal` awaitables.
- Removal sequencing for the legacy layer (`utils.gd`, `core/data_node`, `core/observer`,
  `core/writer`, `binder/`) and its tests/examples (`_1`–`_7`).

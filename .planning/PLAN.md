# GDVM Audit — Plan

## Done

- [x] Fix bitwise type guards in all strict DataNodes (`& TYPE_` → `is_instance_of`)
- [x] Fix `Utils.type_can_be_nodepath`
- [x] Fix `Utils.type_is_type` script-inheritance check
- [x] Fix `DataTree.duplicate()` dead return
- [x] Fix `AsyncRequestMessage.get_response()` bool return
- [x] Remove Godot 3 `GDScriptFunctionState` legacy in `AsyncRelayCommand`
- [x] Standardize `ObservableObject.set_property(property_name, old_value, new_value)`
- [x] Wire `on_property_changing` / `on_property_changed` hooks
- [x] Emit `changed(property_name, old_value, new_value)`
- [x] Fix `WriterPropertyArray._on_order_changed` wrong member (`source_child_id` → `source_element_id`)
- [x] Update `MVVM_TOOLKIT.md` docs

## Todo

- [ ] Deprecate legacy layer: `utils.gd`, `core/data_node/`, `core/observer/`, `core/writer/`, `binder/`
- [ ] Add `class_name ObservableObject` / `class_name ObservableRecipient`
- [ ] Fix `res://` hardcode in `core/view/gdvm_view.gd` (use relative `../dependency_injection/service_locator.gd`)
- [ ] Rewrite `gdvm.gd` facade to only preload the retained classes
- [ ] Delete legacy examples `_1`–`_7` and legacy tests (`test_utils`, `data_node`, `observer`, `writer`, `binder`, `use_case/binder`)
- [ ] Rewrite `README.md` to lead with `ObservableObject` + `GdvmView`
- [ ] Decide `ObservableObject.set_property` emit-before-write semantics (document or invert)
- [ ] Run GUT test suite to verify the retained layer passes

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

- [ ] Add unit test for `DataNodeStruct.remove_property` sibling-computed-output edge case
- [ ] Clean stray whitespace in `observer/node.gd`
- [ ] Consider replacing `assert`-only validation with `push_error` for release builds
- [ ] Run GUT test suite to verify all fixes

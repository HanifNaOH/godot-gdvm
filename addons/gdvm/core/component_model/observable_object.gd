## ObservableObject
## Equivalent to CommunityToolkit.Mvvm.ComponentModel.ObservableObject
## 
## A base class for objects that need to support property change notifications.
## Extends RefCounted and follows GDVM's `changed` signal convention.
##
## IMPORTANT — GDScript setter behavior:
##   Inside a setter body, `property = value` does NOT re-trigger the setter.
##   Therefore: the CALLER writes the value, set_property only compares & emits.
##
## Usage:
##   class PlayerModel extends ObservableObject:
##     var health: int:
##       set(v):
##         if set_property(&"health", health, v):  # compare & emit
##           health = v                            # write inside setter (safe, no recursion)
##
## @see https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/observableobject
class_name ObservableObject
extends RefCounted

## Emitted when any property changes via set_property.
## Follows the `changed` signal convention (the FieldNotify equivalent).
## [property_name] The name of the property that changed (empty for bulk changes).
## [old_value] The value before the change.
## [new_value] The candidate new value.
signal changed(property_name: StringName, old_value, new_value)

## Compare old_value against new_value. If different, run the changing/changed
## hooks, emit `changed`, and return true. The CALLER must perform the actual
## write inside the setter body — `property = value` inside a setter does NOT
## recurse in GDScript.
##
## IMPORTANT — emit-before-write contract:
##   `changed` is emitted BEFORE the setter body writes the value. Listeners that
##   need the new value MUST use the signal's `new_value` argument (authoritative),
##   and MUST NOT re-read the property inside the `changed` handler (they would
##   observe the stale/old value). This is the GDVM analogue of Unreal's
##   FieldNotify broadcast: the notification describes the change, the caller
##   completes the write immediately after.
##
## [property_name] The name of the property being set.
## [old_value] The current value of the property (read with getter or `property`).
## [new_value] The candidate new value.
func set_property(property_name: StringName, old_value, new_value) -> bool:
	if old_value != new_value:
		on_property_changing(property_name, old_value, new_value)
		on_property_changed(property_name)
		changed.emit(property_name, old_value, new_value)
		return true
	return false

## Set multiple properties at once. Only emits `changed` once.
## Returns the number of properties that changed.
## The CALLER must write each value inside its respective setter.
## [checks] A Dictionary of {property_name: [old_value, new_value]}.
func set_properties(checks: Dictionary) -> int:
	var change_count := 0
	for property_name: StringName in checks:
		var pair: Array = checks[property_name]
		if pair[0] != pair[1]:
			change_count += 1
			on_property_changing(property_name, pair[0], pair[1])
	if change_count > 0:
		for property_name: StringName in checks:
			var pair: Array = checks[property_name]
			if pair[0] != pair[1]:
				on_property_changed(property_name)
		changed.emit(&"", null, null)
	return change_count

## Manually notify listeners that a property has changed.
## Equivalent to CommunityToolkit's [ObservableProperty] manual notification and
## Unreal's UE_MVVM_BROADCAST_FIELD_VALUE_CHANGED.
## Use when a value changes outside a standard setter (e.g. an internal mutation
## that bypasses set_property), so bound Views can still refresh.
## Emits the property's CURRENT value as new_value (old is unknown/null).
## [property_name] The name of the property to refresh (empty for bulk).
func notify_property_changed(property_name: StringName) -> void:
	on_property_changed(property_name)
	changed.emit(property_name, null, get(property_name))

## Check if a property would change (without side effects).
func would_change(old_value, new_value) -> bool:
	return old_value != new_value

## Override this to react to property changes in subclasses.
## Called BEFORE the value is set and BEFORE `changed` is emitted.
func on_property_changing(property_name: StringName, old_value, new_value) -> void:
	pass

## Override this to react to property changes in subclasses.
## Called AFTER the value is set (by the caller) and BEFORE `changed` is emitted.
func on_property_changed(property_name: StringName) -> void:
	pass

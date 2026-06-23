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
##         if set_property(health, v):  # compare & emit
##           health = v                 # write inside setter (safe, no recursion)
##
## @see https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/observableobject
extends RefCounted
const ObservableObject = preload("./observable_object.gd")

## Emitted when any property changes via set_property.
## Follows the same convention as DataNode.changed —
## Observer classes can connect this to DataNode.render().
signal changed

## Compare old_value against new_value. If different, emit `changed` and
## return true. The CALLER must perform the actual write inside the setter
## body — `property = value` inside a setter does NOT recurse in GDScript.
##
## [old_value] The current value of the property (read with getter or `property`).
## [new_value] The candidate new value.
func set_property(old_value, new_value) -> bool:
	if old_value != new_value:
		changed.emit()
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
	if change_count > 0:
		changed.emit()
	return change_count

## Check if a property would change (without side effects).
func would_change(old_value, new_value) -> bool:
	return old_value != new_value

## Override this to react to property changes in subclasses.
## Called BEFORE the `changed` signal is emitted.
func on_property_changed(property_name: StringName) -> void:
	pass

## Override this to react to property changes in subclasses.
## Called BEFORE the value is set.
func on_property_changing(property_name: StringName, old_value, new_value) -> void:
	pass

extends LineEdit

## Clicking away from an editing LineEdit releases focus, which triggers the
## owning view's focus_exited handler (commit-on-blur for edit mode).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed == true:
		var current_focus := get_window().gui_get_focus_owner()
		if current_focus == self:
			release_focus()

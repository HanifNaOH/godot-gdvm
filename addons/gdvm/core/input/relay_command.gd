## RelayCommand
## Equivalent to CommunityToolkit.Mvvm.Input.RelayCommand
##
## A command whose sole purpose is to relay its functionality to other
## objects by invoking delegates. This is the standard MVVM pattern for
## binding View actions (button presses, menu items, etc.) to ViewModel
## methods without the View needing to know about the implementation.
##
## Usage:
##   vm.increment_command = RelayCommand.new(func(): vm.counter += 1)
##   vm.delete_command = RelayCommand.new(
##     func(): vm.delete_selected(),
##     func(): return vm.has_selection
##   )
##
## In the View:
##   button.pressed.connect(vm.increment_command.execute)
##   delete_button.disabled = not vm.delete_command.can_execute()
##   vm.delete_command.can_execute_changed.connect(
##     func(): delete_button.disabled = not vm.delete_command.can_execute()
##   )
##
## @see https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/relaycommand
class_name RelayCommand
extends RefCounted

## Emitted when the result of can_execute() might have changed.
## View elements should listen to this to update enabled/disabled state.
signal can_execute_changed

var _execute: Callable
var _can_execute: Callable

## Create a new RelayCommand.
## [execute] The action to invoke when the command is executed (required).
## [can_execute] Optional predicate. If omitted, the command is always executable.
##                When provided, this is called before execute() to guard execution.
func _init(execute: Callable, can_execute: Callable = Callable()) -> void:
	assert(execute.is_valid(), "RelayCommand: execute callback must be valid.")
	_execute = execute
	if can_execute.is_valid():
		_can_execute = can_execute
	else:
		_can_execute = func() -> bool: return true

## Execute the command. Does nothing if can_execute() returns false.
func execute() -> void:
	if _can_execute.call():
		_execute.call()

## Check whether the command can currently execute.
func can_execute() -> bool:
	return _can_execute.call()

## Notify listeners that the can_execute state may have changed.
## Call this from your ViewModel whenever conditions that affect
## can_execute change (e.g., selection state, permissions, etc.).
func notify_can_execute_changed() -> void:
	can_execute_changed.emit()

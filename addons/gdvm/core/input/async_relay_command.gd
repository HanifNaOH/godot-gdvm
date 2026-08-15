## AsyncRelayCommand
## Equivalent to CommunityToolkit.Mvvm.Input.AsyncRelayCommand
##
## A command that supports asynchronous execution. While executing,
## it can report its running state so the View can show loading indicators,
## disable buttons, etc.
##
## The can_execute check automatically returns false while the command
## is already running, preventing double-execution.
##
## Usage:
##   vm.save_command = AsyncRelayCommand.new(
##     func(): return vm.save_to_disk_async()
##   )
##
## In the View:
##   save_button.pressed.connect(vm.save_command.execute)
##   vm.save_command.execution_state_changed.connect(
##     func(running: bool):
##       save_button.disabled = running
##       loading_spinner.visible = running
##   )
##
## @see https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/relaycommand
class_name AsyncRelayCommand
extends RelayCommand


## Emitted when execution starts (true) and finishes (false).
signal execution_state_changed(is_running: bool)

var _is_running: bool = false
var _async_execute: Callable

## Create a new AsyncRelayCommand.
## [async_execute] The async action (must return a value that can be awaited, or null).
## [can_execute] Optional predicate. Auto-false while running.
func _init(async_execute: Callable, can_execute: Callable = Callable()) -> void:
	assert(async_execute.is_valid(), "AsyncRelayCommand: async_execute callback must be valid.")
	_async_execute = async_execute
	# Wire up a combined can_execute that also checks _is_running
	var base_can_execute = can_execute if can_execute.is_valid() else func() -> bool: return true
	var combined = func() -> bool:
		return not _is_running and base_can_execute.call()
	super._init(_execute_async, combined)

## Internal execute wrapper that handles the async lifecycle.
## This must NOT be a coroutine (no `await` in this function body);
## otherwise RelayCommand.execute() would call it without await and error.
func _execute_async() -> void:
	_is_running = true
	execution_state_changed.emit(true)
	notify_can_execute_changed()
	
	var result = _async_execute.call()
	# In Godot 4, an async callable returns a Signal: either an explicit signal
	# (e.g. `timer.timeout`) or the coroutine's implicit completion signal when
	# the callable body contains `await`. We connect to it to know when the
	# async work finishes. A non-Signal return means the work completed
	# synchronously (no `await`), so we finish immediately.
	if result is Signal:
		if not result.is_connected(_on_async_finished):
			result.connect(_on_async_finished, CONNECT_ONE_SHOT)
		else:
			_on_async_finished()
	else:
		# Synchronous completion (no async callable)
		_on_async_finished()

func _on_async_finished(_unused = null) -> void:
	_is_running = false
	execution_state_changed.emit(false)
	notify_can_execute_changed()

## Whether the command is currently executing.
func is_running() -> bool:
	return _is_running

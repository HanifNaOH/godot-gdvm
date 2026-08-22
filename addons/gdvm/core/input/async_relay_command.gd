## AsyncRelayCommand
## Equivalent to CommunityToolkit.Mvvm.Input.AsyncRelayCommand
##
## A command that supports asynchronous execution. While executing,
## it can report its running state so the View can show loading indicators,
## disable buttons, etc.
##
## The can_execute check automatically returns false while the command
## is already running, preventing double-execution.
## Use cancel() to stop tracking the current operation, report_progress() to
## publish progress, and fail() to report an operation error.
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

class CancellationToken extends RefCounted:
	var is_cancelled: bool = false

func get_cancellation_token() -> CancellationToken:
	return _cancellation_token

## Emitted when execution starts (true) and finishes (false).
signal execution_state_changed(is_running: bool)
signal progress_changed(progress)
signal execution_failed(error)
signal execution_cancelled

var _is_running: bool = false
var _async_execute: Callable
var _cancel_execute: Callable
var _cancellation_token: CancellationToken
var _execution_id: int = 0
var _cancelled_id: int = -1
var _failed_id: int = -1

## Create a new AsyncRelayCommand.
## [async_execute] The async action (must return a value that can be awaited, or null).
## [can_execute] Optional predicate. Auto-false while running.
func _init(async_execute: Callable, can_execute: Callable = Callable(), cancel_execute: Callable = Callable()) -> void:
	assert(async_execute.is_valid(), "AsyncRelayCommand: async_execute callback must be valid.")
	_async_execute = async_execute
	_cancel_execute = cancel_execute
	# Wire up a combined can_execute that also checks _is_running
	var base_can_execute = can_execute if can_execute.is_valid() else func() -> bool: return true
	var combined = func(args: Array) -> bool:
		return not _is_running and RelayCommand._call_callback(base_can_execute, args)
	super._init(_execute_async, combined)

## Internal execute wrapper that handles the async lifecycle.
## This must NOT be a coroutine (no `await` in this function body);
## otherwise RelayCommand.execute() would call it without await and error.

func _execute_async(args: Array = []) -> void:
	_is_running = true
	_execution_id += 1
	var execution_id := _execution_id
	_cancellation_token = CancellationToken.new()
	execution_state_changed.emit(true)
	notify_can_execute_changed()
	
	var result = _async_execute.call(args, _cancellation_token) if _async_execute.get_argument_count() >= 2 else RelayCommand._call_callback(_async_execute, args)
	# In Godot 4, an async callable returns a Signal: either an explicit signal
	# (e.g. `timer.timeout`) or the coroutine's implicit completion signal when
	# the callable body contains `await`. We connect to it to know when the
	# async work finishes. A non-Signal return means the work completed
	# synchronously (no `await`), so we finish immediately.
	if result is Signal:
		var finished := func(_unused = null): _on_async_finished(execution_id)
		result.connect(finished, CONNECT_ONE_SHOT)
	else:
		# Synchronous completion (no async callable)
		_on_async_finished(execution_id)

func _on_async_finished(execution_id: int) -> void:
	if execution_id != _execution_id or not _is_running:
		return
	_is_running = false
	if _failed_id == execution_id:
		_failed_id = -1
	elif _cancelled_id == execution_id:
		_cancelled_id = -1
	execution_state_changed.emit(false)
	notify_can_execute_changed()

## Request cancellation of the current execution. The underlying operation is
## not forcibly interrupted; its eventual completion is ignored.
func cancel() -> void:
	if not _is_running:
		return
	_cancellation_token.is_cancelled = true
	if _cancel_execute.is_valid():
		if _cancel_execute.get_argument_count() >= 1:
			_cancel_execute.call(_cancellation_token)
		else:
			_cancel_execute.call()
	_cancelled_id = _execution_id
	execution_cancelled.emit()
	_on_async_finished(_execution_id)

## Report progress from the running operation.
func report_progress(progress) -> void:
	if _is_running:
		progress_changed.emit(progress)

## Report an operation failure and finish the current execution.
func fail(error) -> void:
	if not _is_running:
		return
	_failed_id = _execution_id
	execution_failed.emit(error)
	_on_async_finished(_execution_id)

## Whether the command is currently executing.
func is_running() -> bool:
	return _is_running

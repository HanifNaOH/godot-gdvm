extends GutTest


func test_synchronous_completion() -> void:
	var calls := [0]
	var states: Array = []
	var cmd := AsyncRelayCommand.new(func(): calls[0] += 1)
	cmd.execution_state_changed.connect(func(running: bool): states.append(running))

	cmd.execute()

	assert_eq(calls[0], 1)
	assert_eq(states, [true, false])
	assert_false(cmd.is_running())


func test_prevents_double_execution_while_running() -> void:
	var timer := get_tree().create_timer(0.1)
	var calls := [0]
	var cmd := AsyncRelayCommand.new(func():
		calls[0] += 1
		return timer.timeout
	)

	cmd.execute()
	# Second execute while the first is still running should be blocked.
	cmd.execute()

	assert_eq(calls[0], 1)
	assert_true(cmd.is_running())

	await timer.timeout
	await wait_physics_frames(1)
	assert_false(cmd.is_running())
	assert_eq(calls[0], 1)


func test_execution_state_changed_lifecycle() -> void:
	var timer := get_tree().create_timer(0.1)
	var states: Array = []
	var cmd := AsyncRelayCommand.new(func():
		return timer.timeout
	)
	cmd.execution_state_changed.connect(func(running: bool): states.append(running))

	cmd.execute()
	assert_eq(states, [true])

	await timer.timeout
	await wait_physics_frames(1)
	assert_eq(states, [true, false])


func test_can_execute_false_while_running() -> void:
	var timer := get_tree().create_timer(0.1)
	var cmd := AsyncRelayCommand.new(func():
		return timer.timeout
	)

	assert_true(cmd.can_execute())
	cmd.execute()
	assert_false(cmd.can_execute())

	await timer.timeout
	await wait_physics_frames(1)
	assert_true(cmd.can_execute())


func test_async_command_receives_arguments() -> void:
	var received: Array = []
	var cmd := AsyncRelayCommand.new(func(args): received.append(args[0]))

	cmd.execute(["argument"])

	assert_eq(received, ["argument"])
	assert_false(cmd.is_running())


func test_cancel_finishes_execution_and_ignores_late_completion() -> void:
	var timer := get_tree().create_timer(0.1)
	var states: Array = []
	var cancelled := [0]
	var cmd := AsyncRelayCommand.new(func(): return timer.timeout)
	cmd.execution_state_changed.connect(func(running): states.append(running))
	cmd.execution_cancelled.connect(func(): cancelled[0] += 1)

	cmd.execute()
	cmd.cancel()
	assert_false(cmd.is_running())
	assert_eq(cancelled[0], 1)
	assert_eq(states, [true, false])

	await timer.timeout
	await wait_physics_frames(1)
	assert_eq(states, [true, false])


func test_cancel_invokes_optional_cancellation_callback() -> void:
	var timer := get_tree().create_timer(0.1)
	var cancellations := [0]
	var cmd := AsyncRelayCommand.new(
		func(): return timer.timeout,
		Callable(),
		func(): cancellations[0] += 1
	)

	cmd.execute()
	cmd.cancel()

	assert_eq(cancellations[0], 1)


func test_async_callback_receives_cancellation_token() -> void:
	var timer := get_tree().create_timer(0.1)
	var tokens: Array = []
	var cmd := AsyncRelayCommand.new(func(_args, token):
		tokens.append(token)
		return timer.timeout
	)

	cmd.execute()
	assert_eq(tokens.size(), 1)
	assert_false(tokens[0].is_cancelled)
	cmd.cancel()
	assert_true(tokens[0].is_cancelled)


func test_report_progress_emits_only_while_running() -> void:
	var progress: Array = []
	var command_holder: Array = [null]
	var cmd := AsyncRelayCommand.new(func():
		command_holder[0].report_progress(0.5)
	)
	command_holder[0] = cmd
	cmd.progress_changed.connect(func(value): progress.append(value))

	cmd.report_progress(0.1)
	cmd.execute()
	cmd.report_progress(1.0)

	assert_eq(progress, [0.5])


func test_fail_emits_error_and_finishes_execution() -> void:
	var errors: Array = []
	var states: Array = []
	var command_holder: Array = [null]
	var cmd := AsyncRelayCommand.new(func(): command_holder[0].fail("network"))
	command_holder[0] = cmd
	cmd.execution_failed.connect(func(error): errors.append(error))
	cmd.execution_state_changed.connect(func(running): states.append(running))

	cmd.execute()

	assert_eq(errors, ["network"])
	assert_eq(states, [true, false])
	assert_false(cmd.is_running())

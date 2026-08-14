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

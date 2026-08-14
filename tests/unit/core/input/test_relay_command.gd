extends GutTest


func test_execute_calls_action() -> void:
	var calls := [0]
	var cmd := RelayCommand.new(func(): calls[0] += 1)

	cmd.execute()

	assert_eq(calls[0], 1)


func test_default_can_execute_is_true() -> void:
	var cmd := RelayCommand.new(func(): pass)

	assert_true(cmd.can_execute())


func test_can_execute_guards_execution() -> void:
	var calls := [0]
	var cmd := RelayCommand.new(
		func(): calls[0] += 1,
		func(): return false
	)

	cmd.execute()

	assert_eq(calls[0], 0)
	assert_false(cmd.can_execute())


func test_can_execute_allows_execution_when_true() -> void:
	var calls := [0]
	var cmd := RelayCommand.new(
		func(): calls[0] += 1,
		func(): return true
	)

	cmd.execute()

	assert_eq(calls[0], 1)


func test_notify_can_execute_changed_emits_signal() -> void:
	var cmd := RelayCommand.new(func(): pass)
	var emitted := [0]
	cmd.can_execute_changed.connect(func(): emitted[0] += 1)

	cmd.notify_can_execute_changed()

	assert_eq(emitted[0], 1)

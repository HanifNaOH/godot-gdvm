extends GutTest

const RequestMessage = Gdvm.RequestMessage


# ─── ValueChangedMessage ───────────────────────────────────────────────────

func test_value_changed_message_holds_value() -> void:
	var msg := RequestMessage.ValueChangedMessage.new(100)

	assert_eq(msg.value, 100)


# ─── RequestMessage ────────────────────────────────────────────────────────

func test_request_message_reply_and_get_response() -> void:
	var msg := RequestMessage.RequestMessage.new()

	assert_false(msg.has_response())

	msg.reply(42)

	assert_true(msg.has_response())
	assert_eq(msg.get_response(), 42)


func test_request_message_no_response_returns_null() -> void:
	var msg := RequestMessage.RequestMessage.new()

	assert_null(msg.get_response())
	assert_false(msg.has_response())
	assert_push_warning("No response was provided")


# ─── AsyncRequestMessage ───────────────────────────────────────────────────

func test_async_request_message_awaitable_response() -> void:
	var msg := RequestMessage.AsyncRequestMessage.new()
	var timer := get_tree().create_timer(0.05)

	msg.reply(timer.timeout)

	# get_response() awaits the Signal; the await should complete without error
	# and resolve to the signal's (empty) payload.
	var result = await msg.get_response()
	assert_null(result)


func test_async_request_message_plain_response() -> void:
	var msg := RequestMessage.AsyncRequestMessage.new()

	msg.reply("done")

	assert_eq(await msg.get_response(), "done")


func test_async_request_message_no_response() -> void:
	var msg := RequestMessage.AsyncRequestMessage.new()

	assert_null(await msg.get_response())
	assert_push_warning("No response was provided")


# ─── CollectionRequestMessage ──────────────────────────────────────────────

func test_collection_request_message_reply() -> void:
	var msg := RequestMessage.CollectionRequestMessage.new()

	assert_false(msg.has_response())

	msg.reply([1, 2, 3])

	assert_true(msg.has_response())
	assert_eq(msg.get_response(), [1, 2, 3])


func test_collection_request_message_no_response() -> void:
	var msg := RequestMessage.CollectionRequestMessage.new()

	assert_eq(msg.get_response(), [])
	assert_false(msg.has_response())
	assert_push_warning("No response was provided")

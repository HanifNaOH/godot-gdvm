extends GutTest


class Listener:
	var received: Array = []

	func on_message(_recipient, payload) -> void:
		received.append(payload)


func before_each() -> void:
	Messenger.reset_default()


func after_each() -> void:
	Messenger.reset_default()


func test_register_and_send() -> void:
	var listener := Listener.new()

	Messenger.default().register(listener, &"test_topic", listener.on_message)
	Messenger.default().send(&"test_topic", 42)

	assert_eq(listener.received, [42])


func test_send_to_unregistered_type_is_noop() -> void:
	var listener := Listener.new()

	Messenger.default().send(&"unknown_topic", 42)

	assert_eq(listener.received, [])


func test_send_passes_recipient_and_payload() -> void:
	var listener := Listener.new()
	var captured: Array = []

	Messenger.default().register(listener, &"topic", func(recipient, payload):
		captured.append([recipient, payload])
	)
	Messenger.default().send(&"topic", "hello")

	assert_eq(captured.size(), 1)
	assert_same(captured[0][0], listener)
	assert_eq(captured[0][1], "hello")


func test_multiple_recipients_all_receive() -> void:
	var a := Listener.new()
	var b := Listener.new()

	Messenger.default().register(a, &"topic", a.on_message)
	Messenger.default().register(b, &"topic", b.on_message)
	Messenger.default().send(&"topic", 7)

	assert_eq(a.received, [7])
	assert_eq(b.received, [7])


func test_unregister_specific_type() -> void:
	var listener := Listener.new()

	Messenger.default().register(listener, &"topic", listener.on_message)
	Messenger.default().unregister(listener, &"topic")
	Messenger.default().send(&"topic", 1)

	assert_eq(listener.received, [])


func test_unregister_all_types() -> void:
	var listener := Listener.new()

	Messenger.default().register(listener, &"topic_a", listener.on_message)
	Messenger.default().register(listener, &"topic_b", listener.on_message)
	Messenger.default().unregister(listener)
	Messenger.default().send(&"topic_a", 1)
	Messenger.default().send(&"topic_b", 2)

	assert_eq(listener.received, [])


func test_is_registered() -> void:
	var listener := Listener.new()

	assert_false(Messenger.default().is_registered(listener, &"topic"))
	Messenger.default().register(listener, &"topic", listener.on_message)
	assert_true(Messenger.default().is_registered(listener, &"topic"))
	Messenger.default().unregister(listener, &"topic")
	assert_false(Messenger.default().is_registered(listener, &"topic"))


func test_registration_count() -> void:
	var a := Listener.new()
	var b := Listener.new()

	assert_eq(Messenger.default().registration_count(), 0)

	Messenger.default().register(a, &"topic", a.on_message)
	Messenger.default().register(b, &"topic", b.on_message)

	assert_eq(Messenger.default().registration_count(&"topic"), 2)
	assert_eq(Messenger.default().registration_count(), 2)


func test_send_cleans_up_dead_recipients() -> void:
	var messenger := Messenger.new()
	var listener = Listener.new()

	# Non-capturing lambda: the handler does NOT hold a strong reference.
	messenger.register(listener, &"topic", func(_recipient, _payload): pass)
	# Drop the only strong reference; the recipient is now dead.
	listener = null

	messenger.send(&"topic", 1)
	assert_eq(messenger.registration_count(&"topic"), 0)


func test_cleanup_removes_dead_registrations() -> void:
	var messenger := Messenger.new()
	var listener = Listener.new()

	messenger.register(listener, &"topic", func(_recipient, _payload): pass)
	listener = null

	messenger.cleanup()
	assert_eq(messenger.registration_count(&"topic"), 0)


func test_default_is_lazy_singleton() -> void:
	Messenger.reset_default()

	assert_same(Messenger.default(), Messenger.default())

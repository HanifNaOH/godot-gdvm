extends GutTest

const ObservableRecipient = Gdvm.ObservableRecipient


class Recipient extends ObservableRecipient:
	var received: Array = []

	func _init() -> void:
		messenger_register(&"ping", _on_ping)

	func _on_ping(_recipient, payload) -> void:
		received.append(payload)


func before_each() -> void:
	Messenger.reset_default()


func after_each() -> void:
	Messenger.reset_default()


func test_register_and_receive_message() -> void:
	var r := Recipient.new()

	Messenger.default().send(&"ping", 42)

	assert_eq(r.received, [42])


func test_messenger_send_through_recipient() -> void:
	var r := Recipient.new()

	r.messenger_send(&"ping", "hello")

	assert_eq(r.received, ["hello"])


func test_unregister_specific_type() -> void:
	var r := Recipient.new()

	r.messenger_unregister(&"ping")
	Messenger.default().send(&"ping", 1)

	assert_eq(r.received, [])


func test_unregister_all_types() -> void:
	var r := Recipient.new()

	r.messenger_unregister()
	Messenger.default().send(&"ping", 1)

	assert_eq(r.received, [])


func test_deactivate_cleans_up() -> void:
	var r := Recipient.new()

	r.deactivate()
	Messenger.default().send(&"ping", 1)

	assert_eq(r.received, [])


func test_get_messenger_returns_default() -> void:
	var r := Recipient.new()

	assert_true(r.get_messenger() == Messenger.default())


func test_set_messenger_unregisters_from_old() -> void:
	var r := Recipient.new()
	var old_messenger = r.get_messenger()

	var other := Messenger.new()
	r.set_messenger(other)

	assert_false(old_messenger.is_registered(r, &"ping"))
	assert_true(r.get_messenger() == other)

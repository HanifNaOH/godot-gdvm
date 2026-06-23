## Messenger
## Equivalent to CommunityToolkit.Mvvm.Messaging.WeakReferenceMessenger
##
## A type that can be used to exchange messages between different objects
## without requiring direct references. Uses weak references internally to
## automatically clean up dead recipients — no manual unregistration needed
## (though it's still good practice).
##
## This enables truly decoupled communication between ViewModels, Models,
## and other modules that have no shared ancestor node.
##
## Usage — sending:
##   Messenger.default().send(&"user_logged_in", user)
##
## Usage — receiving:
##   func _ready():
##     Messenger.default().register(self, &"user_logged_in",
##       func(recipient, user):
##         print("User logged in: ", user.name)
##     )
##
## Usage — unregistering:
##   Messenger.default().unregister(self)  # all message types
##   Messenger.default().unregister(self, &"user_logged_in")  # one type
##
## @see https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/messenger
extends RefCounted

## The default singleton Messenger instance.
static var _default

## Get the default Messenger instance (lazy-created).
static func default():
	if _default == null:
		_default = new()
	return _default

## Reset the default instance (mainly for testing).
static func reset_default() -> void:
	_default = null

## Internal storage: { message_type(StringName): [{recipient(WeakRef), handler(Callable)}] }
var _registrations: Dictionary = {}

## Register a recipient for a message type.
## [recipient] The object that will receive the message (used as key, weak-referenced).
## [message_type] The StringName identifying the message type.
## [handler] A Callable with signature: func(recipient: Object, payload) -> void.
##           The recipient is passed as the first argument to avoid capturing `self`.
func register(recipient: Object, message_type: StringName, handler: Callable) -> void:
	assert(is_instance_valid(recipient), "Messenger.register: recipient must be a valid instance.")
	assert(not message_type.is_empty(), "Messenger.register: message_type cannot be empty.")
	assert(handler.is_valid(), "Messenger.register: handler must be a valid Callable.")
	
	if not _registrations.has(message_type):
		_registrations[message_type] = []
	_registrations[message_type].append({
		recipient = weakref(recipient),
		handler = handler
	})

## Send a message to all registered recipients of this type.
## Automatically cleans up dead (freed) recipients during send.
## [message_type] The StringName identifying the message type.
## [payload] Optional data to send with the message.
func send(message_type: StringName, payload = null) -> void:
	if not _registrations.has(message_type):
		return
	
	var registrations: Array = _registrations[message_type]
	var alive: Array = []
	
	for reg in registrations:
		var recipient = reg.recipient.get_ref()
		if is_instance_valid(recipient):
			reg.handler.call(recipient, payload)
			alive.append(reg)
		# Dead recipients are silently dropped
	
	_registrations[message_type] = alive

## Unregister a recipient from a specific message type, or all types.
## [recipient] The object to unregister.
## [message_type] If empty/omitted, unregisters from ALL message types.
func unregister(recipient: Object, message_type: StringName = &"") -> void:
	if message_type.is_empty():
		# Unregister from all types
		for key in _registrations.keys():
			_registrations[key] = _registrations[key].filter(
				func(reg): return reg.recipient.get_ref() != recipient
			)
			if _registrations[key].is_empty():
				_registrations.erase(key)
	elif _registrations.has(message_type):
		_registrations[message_type] = _registrations[message_type].filter(
			func(reg): return reg.recipient.get_ref() != recipient
		)
		if _registrations[message_type].is_empty():
			_registrations.erase(message_type)

## Check if a recipient is registered for a message type.
func is_registered(recipient: Object, message_type: StringName) -> bool:
	if not _registrations.has(message_type):
		return false
	for reg in _registrations[message_type]:
		if reg.recipient.get_ref() == recipient:
			return true
	return false

## Get the number of registrations (including dead ones until next send/cleanup).
func registration_count(message_type: StringName = &"") -> int:
	if message_type.is_empty():
		var total := 0
		for key in _registrations:
			total += _registrations[key].size()
		return total
	return _registrations.get(message_type, []).size()

## Immediately clean up all dead registrations without sending.
func cleanup() -> void:
	for key in _registrations.keys():
		_registrations[key] = _registrations[key].filter(
			func(reg): return is_instance_valid(reg.recipient.get_ref())
		)
		if _registrations[key].is_empty():
			_registrations.erase(key)

## ObservableRecipient
## Equivalent to CommunityToolkit.Mvvm.ComponentModel.ObservableRecipient
##
## A base class for observable objects that also act as recipients for the
## Messenger. Combines ObservableObject with automatic Messenger registration
## lifecycle management.
##
## When the object's `deactivate()` is called (or the object is freed),
## all Messenger registrations are automatically cleaned up.
##
## Usage:
##   class PlayerViewModel extends ObservableRecipient:
##     var player_name: String:
##       set(v):
##         if set_property(&"player_name", player_name, v):
##           player_name = v
##
##     func _init():
##       messenger_register(&"player_died", _on_player_died)
##
##     func _on_player_died(_recipient, payload):
##       player_name = "Dead"
##
## @see https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/observablerecipient
class_name ObservableRecipient
extends ObservableObject


var _messenger
var _registered_message_types: Array[StringName] = []

## Get the Messenger instance this recipient uses.
func get_messenger():
	if _messenger == null:
		_messenger = Messenger.default()
	return _messenger

## Set a custom Messenger instance (e.g., for testing or isolated contexts).
func set_messenger(messenger) -> void:
	if _messenger != null:
		_unregister_all()
	_messenger = messenger

## Register this recipient for a message type on the Messenger.
## The handler receives (recipient, payload).
## [message_type] The StringName message identifier.
## [handler] A Callable with signature func(recipient: Object, payload) -> void.
func messenger_register(message_type: StringName, handler: Callable) -> void:
	get_messenger().register(self, message_type, handler)
	if not _registered_message_types.has(message_type):
		_registered_message_types.append(message_type)

## Send a message through this recipient's Messenger.
func messenger_send(message_type: StringName, payload = null) -> void:
	get_messenger().send(message_type, payload)

## Unregister from a specific message type, or all types if omitted.
func messenger_unregister(message_type: StringName = &"") -> void:
	get_messenger().unregister(self, message_type)
	if message_type.is_empty():
		_registered_message_types.clear()
	else:
		_registered_message_types.erase(message_type)

## Deactivate this recipient. Called automatically on NOTIFICATION_PREDELETE
## if this is a Node. For RefCounted, call manually or from _notification.
func deactivate() -> void:
	_unregister_all()

## Internal: unregister from all tracked message types.
func _unregister_all() -> void:
	if _messenger != null:
		_messenger.unregister(self)
	_registered_message_types.clear()

## Override to auto-deactivate on free.
## Inline the cleanup rather than calling deactivate() to avoid
## calling methods on a partially-freed instance during NOTIFICATION_PREDELETE.
## NOTE: NOTIFICATION_PREDELETE fires for both Node and RefCounted, so
## RefCounted recipients are cleaned up automatically too.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _messenger != null:
			_messenger.unregister(self)
		_registered_message_types.clear()

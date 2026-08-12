## RequestMessage
## Equivalent to CommunityToolkit.Mvvm.Messaging.Messages.RequestMessage<T>
## and ValueChangedMessage<T>
##
## Message types for the Messenger system that support request-response
## patterns between decoupled modules.
##
## ValueChangedMessage: carries a value that changed.
## RequestMessage: sends a request and expects a reply.
## AsyncRequestMessage: sends a request and expects an async reply.
##
## Usage — ValueChangedMessage:
##   Messenger.default().send(&"score_changed", ValueChangedMessage.new(100))
##
## Usage — RequestMessage:
##   # Receiver registers:
##   Messenger.default().register(self, &"get_current_user",
##     func(recipient, msg: RequestMessage):
##       msg.reply(recipient.current_user)
##   )
##   # Sender requests:
##   var msg = RequestMessage.new()
##   Messenger.default().send(&"get_current_user", msg)
##   var user = msg.get_response()  # returns the reply value, or null if none
##
## @see https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/messenger


## A message carrying a value that has changed.
class ValueChangedMessage:
	var value
	
	func _init(value) -> void:
		self.value = value


## A message that requests a value from the receiver.
## The receiver should call reply() with the requested value.
class RequestMessage:
	var _response = null
	var _has_response: bool = false
	
	## Reply to the request with a value.
	func reply(value) -> void:
		_response = value
		_has_response = true
	
	## Get the response value. Returns null and prints a warning if no reply was sent.
	func get_response():
		if not _has_response:
			push_warning("RequestMessage: No response was provided for this request.")
		return _response
	
	func has_response() -> bool:
		return _has_response


## A message that requests an async value from the receiver.
## The receiver should call reply() with a value or a Signal (the only awaitable
## return type in Godot 4).
class AsyncRequestMessage:
	var _response = null
	var _has_response: bool = false
	
	## Reply to the request with a value (or an awaitable).
	func reply(value) -> void:
		_response = value
		_has_response = true
	
	## Await the async response.
	func get_response():
		if not _has_response:
			push_warning("AsyncRequestMessage: No response was provided for this request.")
			return null
		var result = _response
		if result is Signal:
			result = await result

		return result


## A message requesting a collection of items.
class CollectionRequestMessage:
	var _response: Array = []
	var _has_response: bool = false
	
	func reply(items: Array) -> void:
		_response = items
		_has_response = true
	
	func get_response() -> Array:
		if not _has_response:
			push_warning("CollectionRequestMessage: No response was provided for this request.")
		return _response
	
	func has_response() -> bool:
		return _has_response

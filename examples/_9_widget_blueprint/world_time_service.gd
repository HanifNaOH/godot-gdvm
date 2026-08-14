## WorldTimeService
## The Model layer for the _9_widget_blueprint demo.
##
## Plain data access: owns the network request and knows nothing about MVVM,
## Views, or change notification. It fetches time and reports results via its
## own signals; the ViewModel translates those results into observable state.
##
## This mirrors Unreal MVVM's Model tier — source data / services that are not
## themselves observable by the View.
extends RefCounted

## Emitted on success with the parsed fields.
signal time_fetched(datetime: String, timezone: String)

## Emitted on failure with a human-readable message.
signal fetch_failed(message: String)

## The HTTPRequest must live in the scene tree to poll; the View hosts this
## node (the ViewModel re-exposes it).
var http_request: HTTPRequest = HTTPRequest.new()


func fetch_world_time() -> void:
	var error := http_request.request("https://timeapi.io/api/Time/current/zone?timeZone=UTC")
	if error != OK:
		fetch_failed.emit("HTTP error (%d)" % error)
		return
	if not http_request.request_completed.is_connected(_on_completed):
		http_request.request_completed.connect(_on_completed, CONNECT_ONE_SHOT)


func _on_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		fetch_failed.emit("HTTP error (%d)" % response_code)
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		fetch_failed.emit("Invalid response")
		return
	time_fetched.emit(
		str(json.get("dateTime", "?")),
		str(json.get("timeZone", "?"))
	)

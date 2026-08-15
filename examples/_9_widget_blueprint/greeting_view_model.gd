## GreetingViewModel
## The ViewModel layer for the _9_widget_blueprint demo — Unreal MVVM style.
##
## Equivalent to Unreal's `UMVVMViewModelBase`: extends GDVM's
## `ObservableObject` (the `changed` signal convention) and owns a reference to
## the Model, exposing *view-ready* properties and functions.
##
## Unlike CommunityToolkit MVVM (Example 8), there are **no commands** here.
## Unreal binds a button's event directly to a ViewModel function, which is
## what the View's thin code-behind does.
class_name GreetingViewModel
extends ObservableObject

const WorldTimeService = preload("./world_time_service.gd")

## The Model — source of world-time data. Not observable by the View; the
## ViewModel translates its results into observable state.
var world_time_service: WorldTimeService

var greeting: String = "hello world binding success":
	set(v):
		if set_property(&"greeting", greeting, v):
			greeting = v

var count: int = 0:
	set(v):
		if set_property(&"count", count, v):
			count = v

## Fetched world time, shown in a bound label.
var world_time: String = "--":
	set(v):
		if set_property(&"world_time", world_time, v):
			world_time = v


func _init() -> void:
	world_time_service = WorldTimeService.new()
	world_time_service.time_fetched.connect(_on_time_fetched)
	world_time_service.fetch_failed.connect(_on_fetch_failed)


## ── Actions (Unreal: events bind to ViewModel functions, not ICommand) ──────

func update_greeting() -> void:
	greeting = "button pressed and binding success!"


func increment() -> void:
	count += 1


func fetch_world_time() -> void:
	world_time = "Loading..."
	world_time_service.fetch_world_time()


## ── Model result translation ────────────────────────────────────────────

func _on_time_fetched(datetime: String, timezone: String) -> void:
	world_time = "%s  (%s)" % [datetime, timezone]


func _on_fetch_failed(message: String) -> void:
	world_time = message

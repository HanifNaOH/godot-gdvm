## ServiceLocator
## Equivalent to CommunityToolkit.Mvvm.DependencyInjection.Ioc
##
## A simple service locator / IoC container for registering and resolving
## services by type. This enables loosely-coupled architecture where
## ViewModels and other components can resolve dependencies without
## having direct references.
##
## Note: Godot's Autoload system already provides a form of service location.
## Use ServiceLocator when you need:
## - Interface-based resolution (register a type, resolve by type)
## - Scoped/lifetime-managed services
## - Test-friendly swappable implementations
##
## Usage:
##   # Registration (during app startup / autoload _ready):
##   ServiceLocator.register(&"PlayerRepository", func(): return PlayerRepo.new())
##   ServiceLocator.register_singleton(&"AudioManager", AudioManager.new())
##
##   # Resolution (anywhere):
##   var repo = ServiceLocator.resolve(&"PlayerRepository")
##   var audio: AudioManager = ServiceLocator.resolve(&"AudioManager")
##
## @see https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/ioc
class_name ServiceLocator
extends RefCounted

## Singleton storage: { type_name(StringName): {factory: Callable, singleton: bool, instance} }
static var _services: Dictionary = {}

## Register a transient service (new instance created each time it's resolved).
## [type_name] The StringName key to register the service under.
## [factory] A Callable that returns a new instance when called.
static func register(type_name: StringName, factory: Callable) -> void:
	assert(not type_name.is_empty(), "ServiceLocator.register: type_name cannot be empty.")
	assert(factory.is_valid(), "ServiceLocator.register: factory must be a valid Callable.")
	_services[type_name] = {
		factory = factory,
		singleton = false,
		instance = null
	}

## Register a singleton service (same instance returned every time).
## [type_name] The StringName key to register the service under.
## [instance] The singleton instance to return on resolve.
static func register_singleton(type_name: StringName, instance) -> void:
	assert(not type_name.is_empty(), "ServiceLocator.register_singleton: type_name cannot be empty.")
	assert(is_instance_valid(instance), "ServiceLocator.register_singleton: instance must be valid.")
	_services[type_name] = {
		factory = Callable(),
		singleton = true,
		instance = instance
	}

## Register a lazy singleton (created on first resolve, then cached).
## [type_name] The StringName key to register the service under.
## [factory] A Callable that returns the singleton instance (called once).
static func register_lazy_singleton(type_name: StringName, factory: Callable) -> void:
	assert(not type_name.is_empty(), "ServiceLocator.register_lazy_singleton: type_name cannot be empty.")
	assert(factory.is_valid(), "ServiceLocator.register_lazy_singleton: factory must be a valid Callable.")
	_services[type_name] = {
		factory = factory,
		singleton = true,
		instance = null
	}

## Resolve a service by type name. Returns null if not registered.
## Transient services create a new instance each call.
## Singleton services return the cached instance.
static func resolve(type_name: StringName):
	if not _services.has(type_name):
		return null
	
	var entry: Dictionary = _services[type_name]
	if entry.singleton:
		if entry.instance == null:
			entry.instance = entry.factory.call()
		return entry.instance
	else:
		return entry.factory.call()

## Check if a service is registered.
static func is_registered(type_name: StringName) -> bool:
	return _services.has(type_name)

## Remove a registered service.
static func unregister(type_name: StringName) -> void:
	_services.erase(type_name)

## Clear all registered services (useful for testing teardown).
static func clear() -> void:
	_services.clear()

## Get all registered service names.
static func get_registered_types() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_services.keys())
	return result

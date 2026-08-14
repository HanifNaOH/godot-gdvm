extends GutTest


class Service:
	pass


func before_each() -> void:
	ServiceLocator.clear()


func after_each() -> void:
	ServiceLocator.clear()


func test_register_and_resolve_transient() -> void:
	ServiceLocator.register(&"Service", func(): return Service.new())

	var a = ServiceLocator.resolve(&"Service")
	var b = ServiceLocator.resolve(&"Service")

	assert_true(a is Service)
	assert_true(b is Service)
	# Transient: each resolve returns a new instance.
	assert_false(a == b)


func test_resolve_unregistered_returns_null() -> void:
	var result = ServiceLocator.resolve(&"Missing")

	assert_null(result)


func test_register_singleton_returns_same_instance() -> void:
	var instance := Service.new()
	ServiceLocator.register_singleton(&"Service", instance)

	var a = ServiceLocator.resolve(&"Service")
	var b = ServiceLocator.resolve(&"Service")

	assert_same(a, instance)
	assert_same(b, instance)


func test_lazy_singleton_created_once() -> void:
	var creations := [0]
	ServiceLocator.register_lazy_singleton(&"Service", func():
		creations[0] += 1
		return Service.new()
	)

	var a = ServiceLocator.resolve(&"Service")
	var b = ServiceLocator.resolve(&"Service")

	assert_same(a, b)
	assert_eq(creations[0], 1)


func test_is_registered() -> void:
	assert_false(ServiceLocator.is_registered(&"Service"))

	ServiceLocator.register(&"Service", func(): return Service.new())

	assert_true(ServiceLocator.is_registered(&"Service"))


func test_unregister() -> void:
	ServiceLocator.register(&"Service", func(): return Service.new())
	assert_true(ServiceLocator.is_registered(&"Service"))

	ServiceLocator.unregister(&"Service")

	assert_false(ServiceLocator.is_registered(&"Service"))


func test_clear_removes_all() -> void:
	ServiceLocator.register(&"A", func(): return Service.new())
	ServiceLocator.register(&"B", func(): return Service.new())

	ServiceLocator.clear()

	assert_eq(ServiceLocator.get_registered_types(), [])
	assert_false(ServiceLocator.is_registered(&"A"))
	assert_false(ServiceLocator.is_registered(&"B"))


func test_get_registered_types() -> void:
	ServiceLocator.register(&"A", func(): return Service.new())
	ServiceLocator.register(&"B", func(): return Service.new())

	var types = ServiceLocator.get_registered_types()

	assert_eq(types.size(), 2)
	assert_true(types.has(&"A"))
	assert_true(types.has(&"B"))

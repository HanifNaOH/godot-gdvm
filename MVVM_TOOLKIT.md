# MVVM Toolkit for GDVM

GDVM integrates an implementation of Microsoft's **.NET Community Toolkit MVVM** pattern to provide powerful, battle-tested abstractions for structuring large applications.

This integration resolves several critical limitations of vanilla MVVM implementations, namely how to keep action logic cleanly separated (Commands), how to decouple ViewModels without direct references (Messenger), and how to reduce `changed` signal emission boilerplate.

## Architecture & Namespaces

The toolkit features are strictly separated into their semantic namespaces within `addons/gdvm/core/`, mirroring the .NET implementation.

You can resolve them globally via the `Gdvm` singleton:

```gdscript
const ObservableObject = Gdvm.ObservableObject
const RelayCommand = Gdvm.RelayCommand
const AsyncRelayCommand = Gdvm.AsyncRelayCommand
const Messenger = Gdvm.Messenger
const ObservableRecipient = Gdvm.ObservableRecipient
const ServiceLocator = Gdvm.ServiceLocator
```

---

## 1. Component Model

`addons/gdvm/core/component_model/`

The backbone of ViewModel construction.

### `ObservableObject`
A base class for objects that need to support property change notifications. It provides a `set_property` wrapper that handles value-diffing and automatic emission of the `changed` signal.

**Usage:**
```gdscript
class PlayerModel extends ObservableObject:
	var health: int:
		set(v): set_property(&"health", health, v)
```

### `ObservableRecipient`
Extends `ObservableObject` to natively include `Messenger` integration. It automatically tracks any messages you register to and cleans them up entirely when `deactivate()` is called (or on `NOTIFICATION_PREDELETE`).

**Usage:**
```gdscript
class PlayerViewModel extends ObservableRecipient:
	func _init():
		messenger_register(&"player_died", _on_player_died)

	func _on_player_died(recipient, payload):
		print("Player died!")
```

---

## 2. Input (Commands)

`addons/gdvm/core/input/`

Provides standard command implementations (`ICommand`) that encapsulate an action, its execution state, and conditions under which it can be triggered.

### `RelayCommand`
Used to bind a standard synchronous method to UI buttons or actions.

```gdscript
var heal_command = RelayCommand.new(
	func(): _player.heal(15),                              # The Action
	func(): return _player.health < _player.max_health     # The Execution Guard (can_execute)
)

# In your View / Binder:
heal_button.pressed.connect(vm.heal_command.execute)
```

### `AsyncRelayCommand`
An asynchronous variant. It handles `await` automatically, preventing double-execution while it is running, and emits an `execution_state_changed(is_running)` signal for loading spinners.

```gdscript
var save_command = AsyncRelayCommand.new(func():
	await _save_to_disk()
)

# In your view:
vm.save_command.execution_state_changed.connect(func(running): 
	save_spinner.visible = running 
)
```

---

## 3. Messaging

`addons/gdvm/core/messaging/`

A robust publisher-subscriber system that allows deeply decoupled modules to broadcast and reply to typed messages globally without strong references.

### `Messenger`
A weak-referenced message bus equivalent to `.NET's WeakReferenceMessenger`. Dead instances are quietly cleared out.

**Broadcasting:**
```gdscript
Messenger.default().send(&"game_saved", { "player_id": 12 })
```

**Receiving:**
```gdscript
Messenger.default().register(self, &"game_saved", func(_recipient, payload):
	print("Game was saved!", payload)
)
```

### `RequestMessage`
Provides `RequestMessage`, `AsyncRequestMessage`, and `CollectionRequestMessage`. Enables request/response polling between decoupled modules.

```gdscript
# Asking for stats:
var msg = RequestMessage.new()
Messenger.default().send(&"player_count_request", msg)
var count = msg.get_response()

# Replaying to stats request:
Messenger.default().register(self, &"player_count_request", func(_r, msg):
	msg.reply(10) # Fulfill request
)
```

---

## 4. Dependency Injection

`addons/gdvm/core/dependency_injection/`

### `ServiceLocator`
A simple IoC (Inversion of Control) container for interface-centric service fetching. Rather than having singletons directly hardcoded or coupling ViewModels to specific Repositories, you resolve instances via strings/abstract identifiers.

```gdscript
# During boot:
ServiceLocator.register_singleton(&"PlayerRepository", PlayerRepository.new())

# Anywhere else:
var players = ServiceLocator.resolve(&"PlayerRepository")
```

---

## Example 8: Integration
You can view a fully cohesive example using all of these features concurrently in `examples/_8_mvvm_toolkit/main.gd`.
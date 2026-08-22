class_name Gdvm

## GDVM — Unreal-ish MVVM facade.
##
## Aggregates the retained (Unreal-inspired) MVVM toolkit into a single global
## access point so consumers write `Gdvm.ObservableObject` instead of hand-written
## `preload` paths.
##
## The legacy DataNode / Observer / Writer / Binder layer has been removed.

# Component model — the ViewModel backbone (Unreal: UMVVMViewModelBase)
const ObservableObject = preload("./core/component_model/observable_object.gd")
const ObservableRecipient = preload("./core/component_model/observable_recipient.gd")

# Input — commands (Unreal: ICommand / command bindings)
const RelayCommand = preload("./core/input/relay_command.gd")
const AsyncRelayCommand = preload("./core/input/async_relay_command.gd")

# Messaging — decoupled publisher/subscriber + request/response
const Messenger = preload("./core/messaging/messenger.gd")
const RequestMessage = preload("./core/messaging/request_message.gd")

# Code-first runtime binding
const GdvmBinder = preload("./core/binding/gdvm_binder.gd")
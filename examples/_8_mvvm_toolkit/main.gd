extends Control

# 示例8：MVVM Toolkit完整示例
# 演示RelayCommand、AsyncRelayCommand、Messenger、ServiceLocator、RequestMessage
# RelayCommand, AsyncRelayCommand, Messenger, ServiceLocator are global class_names
# RequestMessage inner classes are accessed via Gdvm.RequestMessage

const RequestMessage = Gdvm.RequestMessage

# ─── Scene Nodes ───────────────────────────────────────────────────────────
@onready var name_label: Label = %NameLabel
@onready var health_label: Label = %HealthLabel
@onready var dead_label: Label = %DeadLabel
@onready var attack_btn: Button = %AttackBtn
@onready var heal_btn: Button = %HealBtn
@onready var save_btn: Button = %SaveBtn
@onready var reset_btn: Button = %ResetBtn
@onready var stats_btn: Button = %StatsBtn
@onready var status_label: Label = %StatusLabel

# ─── Model ─────────────────────────────────────────────────────────────────
class PlayerModel:
	signal changed

	var health: int:
		set(v):
			if v != health:
				health = v
				changed.emit()

	var max_health: int:
		set(v):
			if v != max_health:
				max_health = v
				changed.emit()

	var name: String:
		set(v):
			if v != name:
				name = v
				changed.emit()

	var is_alive: bool:
		set(v):
			if v != is_alive:
				is_alive = v
				changed.emit()

	func _init(p_name: String, p_health: int) -> void:
		health = p_health
		max_health = p_health
		name = p_name
		is_alive = true

	func take_damage(amount: int) -> void:
		if not is_alive:
			return
		health = maxi(0, health - amount)
		if health <= 0:
			is_alive = false

	func heal(amount: int) -> void:
		if not is_alive:
			return
		health = mini(max_health, health + amount)

# ─── Repository ────────────────────────────────────────────────────────────
class PlayerRepository:
	var _players: Array[PlayerModel] = []

	func add_player(player: PlayerModel) -> void:
		_players.append(player)

	func get_alive_players() -> Array[PlayerModel]:
		var result: Array[PlayerModel] = []
		for p in _players:
			if p.is_alive:
				result.append(p)
		return result

	func get_player_count() -> int:
		return _players.size()

	func get_alive_count() -> int:
		return get_alive_players().size()

# ─── ViewModel (Game) ──────────────────────────────────────────────────────
class GameViewModel:
	signal changed

	var player_name: String:
		set(v):
			if v != player_name:
				player_name = v
				changed.emit()

	var health_display: String:
		set(v):
			if v != health_display:
				health_display = v
				changed.emit()

	var is_dead: bool:
		set(v):
			if v != is_dead:
				is_dead = v
				changed.emit()

	var is_loading: bool:
		set(v):
			if v != is_loading:
				is_loading = v
				changed.emit()

	var attack_command: RelayCommand
	var heal_command: RelayCommand
	var save_command: AsyncRelayCommand

	var _player: PlayerModel
	var _repo: PlayerRepository

	func _init(player: PlayerModel) -> void:
		_player = player
		_repo = ServiceLocator.resolve(&"PlayerRepository")

		attack_command = RelayCommand.new(
			func(): _player.take_damage(20),
			func(): return _player.is_alive
		)

		heal_command = RelayCommand.new(
			func(): _player.heal(15),
			func(): return _player.health < _player.max_health
		)

		save_command = AsyncRelayCommand.new(
			func(): return _simulate_save()
		)

		_player.changed.connect(_sync_from_model)

		var m = Messenger.default()
		m.register(self, &"game_reset", func(_r, _p): _on_game_reset())
		m.register(self, &"player_count_request", func(_r, msg): _on_player_count_request(msg))

		_sync_from_model()

	func _sync_from_model() -> void:
		player_name = _player.name
		health_display = "%d / %d" % [_player.health, _player.max_health]
		is_dead = not _player.is_alive
		attack_command.notify_can_execute_changed()
		heal_command.notify_can_execute_changed()

	func _simulate_save():
		var timer = Engine.get_main_loop().create_timer(1.5)
		timer.timeout.connect(func():
			Messenger.default().send(&"game_saved", {
				"player": _player.name,
				"health": _player.health
			})
		)
		return timer.timeout

	func _on_game_reset() -> void:
		_player.heal(_player.max_health)
		_sync_from_model()

	func _on_player_count_request(msg) -> void:
		msg.reply({
			"total": _repo.get_player_count(),
			"alive": _repo.get_alive_count()
		})

# ─── ViewModel (Menu) ──────────────────────────────────────────────────────
class MenuViewModel:
	signal changed

	var status_text: String:
		set(v):
			if v != status_text:
				status_text = v
				changed.emit()

	var reset_command: RelayCommand
	var stats_command: AsyncRelayCommand

	func _init() -> void:
		reset_command = RelayCommand.new(_do_reset)
		stats_command = AsyncRelayCommand.new(_fetch_stats)

		var m = Messenger.default()
		m.register(self, &"game_saved", func(_r, payload): _on_game_saved(payload))
		status_text = "Ready."

	func _do_reset() -> void:
		Messenger.default().send(&"game_reset", {"reason": "manual_reset"})
		status_text = "Game reset triggered!"

	func _fetch_stats():
		var msg = RequestMessage.RequestMessage.new()
		Messenger.default().send(&"player_count_request", msg)
		var stats = msg.get_response()
		if stats != null:
			status_text = "Players: %d alive / %d total" % [stats.alive, stats.total]
		else:
			status_text = "Failed to fetch stats."

	func _on_game_saved(payload) -> void:
		status_text = "Last save: %s (HP: %d)" % [payload.player, payload.health]

# ─── Entry Point ───────────────────────────────────────────────────────────
func _ready() -> void:
	ServiceLocator.register_singleton(&"PlayerRepository", PlayerRepository.new())
	var repo: PlayerRepository = ServiceLocator.resolve(&"PlayerRepository")

	var player = PlayerModel.new("Hero", 100)
	repo.add_player(player)
	repo.add_player(PlayerModel.new("Sidekick", 60))

	var game_vm = GameViewModel.new(player)
	var menu_vm = MenuViewModel.new()

	# ── ViewModel changed → UI ───────────────────────────────────────────
	game_vm.changed.connect(func():
		name_label.text = game_vm.player_name
		health_label.text = game_vm.health_display
		dead_label.visible = game_vm.is_dead
	)

	menu_vm.changed.connect(func():
		status_label.text = menu_vm.status_text
	)

	# ── Buttons → Commands ───────────────────────────────────────────────
	attack_btn.pressed.connect(game_vm.attack_command.execute)
	heal_btn.pressed.connect(game_vm.heal_command.execute)
	save_btn.pressed.connect(game_vm.save_command.execute)
	reset_btn.pressed.connect(menu_vm.reset_command.execute)
	stats_btn.pressed.connect(menu_vm.stats_command.execute)

	# ── can_execute → button states ─────────────────────────────────────
	game_vm.attack_command.can_execute_changed.connect(
		func(): attack_btn.disabled = not game_vm.attack_command.can_execute()
	)
	game_vm.heal_command.can_execute_changed.connect(
		func(): heal_btn.disabled = not game_vm.heal_command.can_execute()
	)

	# ── Async running → button feedback ─────────────────────────────────
	game_vm.save_command.execution_state_changed.connect(func(running: bool):
		save_btn.text = "⏳ Saving..." if running else "💾 Save"
		save_btn.disabled = running
	)

	# ── Initial state ───────────────────────────────────────────────────
	name_label.text = game_vm.player_name
	health_label.text = game_vm.health_display
	dead_label.visible = game_vm.is_dead
	status_label.text = menu_vm.status_text
	attack_btn.disabled = not game_vm.attack_command.can_execute()
	heal_btn.disabled = not game_vm.heal_command.can_execute()

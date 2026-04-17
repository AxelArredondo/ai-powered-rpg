extends CanvasLayer

var _quality_mode := true

@onready var _performance_btn: Button = $Background/Center/Panel/VBox/ModeRow/PerformanceBtn
@onready var _quality_btn: Button = $Background/Center/Panel/VBox/ModeRow/QualityBtn

func _ready() -> void:
	hide()
	_update_mode_buttons()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		_close()
		get_viewport().set_input_as_handled()
	else:
		var chat_ui := get_tree().get_first_node_in_group("dialogue_ui")
		if chat_ui == null or not chat_ui.chat_open:
			_open()
			get_viewport().set_input_as_handled()

func _open() -> void:
	show()
	get_tree().paused = true

func _close() -> void:
	hide()
	get_tree().paused = false

func _on_resume_btn_pressed() -> void:
	_close()

func _on_restart_btn_pressed() -> void:
	_quality_mode = true
	get_tree().paused = false
	hide()
	get_tree().reload_current_scene()

func _on_quit_btn_pressed() -> void:
	get_tree().quit()

func _on_performance_btn_pressed() -> void:
	if _quality_mode:
		_quality_mode = false
		_apply_mode()
		_update_mode_buttons()

func _on_quality_btn_pressed() -> void:
	if not _quality_mode:
		_quality_mode = true
		_apply_mode()
		_update_mode_buttons()

func _apply_mode() -> void:
	var chat_ui := get_tree().get_first_node_in_group("dialogue_ui")
	if chat_ui == null:
		return
	var blob: Node = chat_ui.get_node_or_null("Blob")
	if blob == null:
		return
	if _quality_mode:
		blob.system_prompt = BlobDialogue.BLOB_SYSTEM_PROMPT
		if "n_predict" in blob:
			blob.n_predict = -1
	else:
		blob.system_prompt = BlobDialogue.BLOB_PERFORMANCE_PROMPT
		if "n_predict" in blob:
			blob.n_predict = 60

func _update_mode_buttons() -> void:
	_performance_btn.modulate = Color.WHITE if not _quality_mode else Color(0.5, 0.5, 0.5, 1.0)
	_quality_btn.modulate = Color.WHITE if _quality_mode else Color(0.5, 0.5, 0.5, 1.0)

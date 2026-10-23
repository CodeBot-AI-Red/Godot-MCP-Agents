@tool
extends Control

## UI Dock script for Godot MCP plugin, handling server controls & direct AI client.

const MCPServerScript := preload("res://addons/godot_mcp/mcp_server.gd")
const MCPAIClientScript := preload("res://addons/godot_mcp/mcp_ai_client.gd")

var _mcp_server: Node = null
var _ai_client: Node = null

@onready var _server_state_label: Label = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/ServerStateLabel"
)
@onready var _port_spin: SpinBox = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/PortGrid/PortSpin"
)
@onready var _auth_edit: LineEdit = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/PortGrid/AuthEdit"
)
@onready var _server_toggle_btn: Button = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/ServerToggleBtn"
)
@onready var _log_text: TextEdit = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/LogText"
)

@onready var _provider_option: OptionButton = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ProviderGrid/ProviderOption"
)
@onready var _model_edit: LineEdit = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ProviderGrid/ModelEdit"
)
@onready var _apikey_edit: LineEdit = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ProviderGrid/APIKeyEdit"
)
@onready var _custom_url_edit: LineEdit = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ProviderGrid/CustomURLEdit"
)
@onready var _chat_text: TextEdit = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ChatText"
)
@onready var _prompt_edit: LineEdit = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/InputHBox/PromptEdit"
)
@onready var _send_btn: Button = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/InputHBox/SendBtn"
)
@onready var _clear_btn: Button = get_node_or_null(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/InputHBox/ClearBtn"
)


func _ready() -> void:
	_ensure_nodes()
	_populate_providers()
	_adapt_layout_for_viewport()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_adapt_layout_for_viewport):
		vp.size_changed.connect(_adapt_layout_for_viewport)


func _exit_tree() -> void:
	if is_instance_valid(_mcp_server):
		if _mcp_server.has_method("is_running") and _mcp_server.is_running():
			_mcp_server.stop_server()


func _ensure_nodes() -> void:
	if not is_instance_valid(_mcp_server):
		_mcp_server = MCPServerScript.new()
		add_child(_mcp_server)

	if not is_instance_valid(_ai_client):
		_ai_client = MCPAIClientScript.new()
		add_child(_ai_client)

	_connect_signals()


func _populate_providers() -> void:
	if not _provider_option:
		return
	_provider_option.clear()
	_provider_option.add_item("OpenAI (ChatGPT)", MCPAIClient.Provider.OPENAI)
	_provider_option.add_item("Anthropic (Claude)", MCPAIClient.Provider.ANTHROPIC)
	_provider_option.add_item("Ollama (Local AI)", MCPAIClient.Provider.OLLAMA)
	_provider_option.add_item("Custom / Local Endpoint", MCPAIClient.Provider.CUSTOM)
	_provider_option.select(0)


func _connect_signals() -> void:
	if is_instance_valid(_mcp_server):
		if not _mcp_server.log_message.is_connected(_on_server_log):
			_mcp_server.log_message.connect(_on_server_log)
		if not _mcp_server.server_state_changed.is_connected(_on_server_state_changed):
			_mcp_server.server_state_changed.connect(_on_server_state_changed)

	if is_instance_valid(_ai_client):
		if not _ai_client.response_received.is_connected(_on_ai_response):
			_ai_client.response_received.connect(_on_ai_response)
		if not _ai_client.error_occurred.is_connected(_on_ai_error):
			_ai_client.error_occurred.connect(_on_ai_error)
		if not _ai_client.tool_executed.is_connected(_on_ai_tool_executed):
			_ai_client.tool_executed.connect(_on_ai_tool_executed)

	if _server_toggle_btn and not _server_toggle_btn.pressed.is_connected(_on_server_toggle_pressed):
		_server_toggle_btn.pressed.connect(_on_server_toggle_pressed)

	if _send_btn and not _send_btn.pressed.is_connected(_on_send_pressed):
		_send_btn.pressed.connect(_on_send_pressed)

	if _prompt_edit and not _prompt_edit.text_submitted.is_connected(_on_prompt_submitted):
		_prompt_edit.text_submitted.connect(_on_prompt_submitted)

	if _clear_btn and not _clear_btn.pressed.is_connected(_on_clear_pressed):
		_clear_btn.pressed.connect(_on_clear_pressed)

	if _provider_option and not _provider_option.item_selected.is_connected(_on_provider_selected):
		_provider_option.item_selected.connect(_on_provider_selected)


func _adapt_layout_for_viewport() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var screen_width := get_viewport_rect().size.x
	# Check if running in small screens or mobile editor view
	if screen_width < 450:
		if _server_toggle_btn:
			_server_toggle_btn.custom_minimum_size = Vector2(0, 48)
		if _send_btn:
			_send_btn.custom_minimum_size = Vector2(60, 48)
		if _clear_btn:
			_clear_btn.custom_minimum_size = Vector2(50, 48)
	else:
		if _server_toggle_btn:
			_server_toggle_btn.custom_minimum_size = Vector2(0, 36)
		if _send_btn:
			_send_btn.custom_minimum_size = Vector2(70, 36)
		if _clear_btn:
			_clear_btn.custom_minimum_size = Vector2(60, 36)


func _on_server_toggle_pressed() -> void:
	_ensure_nodes()
	if not is_instance_valid(_mcp_server):
		_on_server_log("Error: MCPServer instance could not be initialized.")
		return

	if _mcp_server.is_running():
		_mcp_server.stop_server()
	else:
		_mcp_server.auth_token = _auth_edit.text.strip_edges() if _auth_edit else ""
		var p := int(_port_spin.value) if _port_spin else 8080
		_mcp_server.start_server(p)


func _on_server_state_changed(is_running: bool) -> void:
	if not is_instance_valid(_mcp_server):
		return
	if is_running:
		if _server_state_label:
			_server_state_label.text = (
				"MCP Server Status: Running (Port " + str(_mcp_server.port) + ")"
			)
		if _server_toggle_btn:
			_server_toggle_btn.text = "Stop MCP Server"
	else:
		if _server_state_label:
			_server_state_label.text = "MCP Server Status: Stopped"
		if _server_toggle_btn:
			_server_toggle_btn.text = "Start MCP Server"


func _on_server_log(msg: String) -> void:
	if _log_text:
		_log_text.append_text("[" + Time.get_time_string_from_system() + "] " + msg + "\n")


func _on_provider_selected(idx: int) -> void:
	_ensure_nodes()
	if not _provider_option or not is_instance_valid(_ai_client):
		return
	var prov_id: int = _provider_option.get_item_id(idx)
	_ai_client.provider = prov_id as MCPAIClient.Provider
	match prov_id:
		MCPAIClient.Provider.OPENAI:
			if _model_edit:
				_model_edit.text = "gpt-4o-mini"
		MCPAIClient.Provider.ANTHROPIC:
			if _model_edit:
				_model_edit.text = "claude-3-5-sonnet-20241022"
		MCPAIClient.Provider.OLLAMA:
			if _model_edit:
				_model_edit.text = "llama3.2"


func _on_send_pressed() -> void:
	_submit_ai_prompt()


func _on_prompt_submitted(_text: String) -> void:
	_submit_ai_prompt()


func _submit_ai_prompt() -> void:
	_ensure_nodes()
	if not is_instance_valid(_ai_client) or not _prompt_edit:
		return

	var prompt := _prompt_edit.text.strip_edges()
	if prompt.is_empty():
		return

	if _apikey_edit:
		_ai_client.api_key = _apikey_edit.text.strip_edges()
	if _model_edit:
		_ai_client.model_name = _model_edit.text.strip_edges()
	if _custom_url_edit:
		_ai_client.custom_url = _custom_url_edit.text.strip_edges()

	_append_chat("User", prompt)
	_prompt_edit.clear()
	_ai_client.send_message(prompt)


func _on_clear_pressed() -> void:
	_ensure_nodes()
	if _chat_text:
		_chat_text.clear()
	if is_instance_valid(_ai_client):
		_ai_client.clear_history()


func _on_ai_response(response_text: String) -> void:
	_append_chat("AI", response_text)


func _on_ai_error(error_msg: String) -> void:
	_append_chat("Error", error_msg)


func _on_ai_tool_executed(tool_name: String, _args: Dictionary, output: String) -> void:
	_append_chat("Tool (" + tool_name + ")", output)


func _append_chat(sender: String, text: String) -> void:
	if _chat_text:
		_chat_text.append_text("[" + sender + "]\n" + text + "\n\n")

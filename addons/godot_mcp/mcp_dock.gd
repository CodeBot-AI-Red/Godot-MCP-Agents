@tool
extends Control

## UI Dock script for Godot MCP plugin, handling server controls & direct AI client.

var _mcp_server: MCPServer = null
var _ai_client: MCPAIClient = null

@onready var _server_state_label: Label = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/ServerStateLabel"
)
@onready var _port_spin: SpinBox = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/PortGrid/PortSpin"
)
@onready var _auth_edit: LineEdit = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/PortGrid/AuthEdit"
)
@onready var _server_toggle_btn: Button = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/ServerToggleBtn"
)
@onready var _log_text: TextEdit = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/Server Settings/LogText"
)

@onready var _provider_option: OptionButton = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ProviderGrid/ProviderOption"
)
@onready var _model_edit: LineEdit = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ProviderGrid/ModelEdit"
)
@onready var _apikey_edit: LineEdit = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ProviderGrid/APIKeyEdit"
)
@onready var _custom_url_edit: LineEdit = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ProviderGrid/CustomURLEdit"
)
@onready var _chat_text: TextEdit = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/ChatText"
)
@onready var _prompt_edit: LineEdit = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/InputHBox/PromptEdit"
)
@onready var _send_btn: Button = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/InputHBox/SendBtn"
)
@onready var _clear_btn: Button = get_node(
	"ScrollContainer/MainVBox/ServerTabContainer/AI Assistant/InputHBox/ClearBtn"
)


func _ready() -> void:
	_setup_nodes()
	_populate_providers()
	_connect_signals()
	_adapt_layout_for_viewport()
	get_viewport().size_changed.connect(_adapt_layout_for_viewport)


func _setup_nodes() -> void:
	_mcp_server = MCPServer.new()
	add_child(_mcp_server)

	_ai_client = MCPAIClient.new()
	add_child(_ai_client)


func _populate_providers() -> void:
	_provider_option.clear()
	_provider_option.add_item("OpenAI (ChatGPT)", MCPAIClient.Provider.OPENAI)
	_provider_option.add_item("Anthropic (Claude)", MCPAIClient.Provider.ANTHROPIC)
	_provider_option.add_item("Ollama (Local AI)", MCPAIClient.Provider.OLLAMA)
	_provider_option.add_item("Custom / Local Endpoint", MCPAIClient.Provider.CUSTOM)
	_provider_option.select(0)


func _connect_signals() -> void:
	_server_toggle_btn.pressed.connect(_on_server_toggle_pressed)
	_mcp_server.log_message.connect(_on_server_log)
	_mcp_server.server_state_changed.connect(_on_server_state_changed)

	_send_btn.pressed.connect(_on_send_pressed)
	_prompt_edit.text_submitted.connect(_on_prompt_submitted)
	_clear_btn.pressed.connect(_on_clear_pressed)

	_provider_option.item_selected.connect(_on_provider_selected)

	_ai_client.response_received.connect(_on_ai_response)
	_ai_client.error_occurred.connect(_on_ai_error)
	_ai_client.tool_executed.connect(_on_ai_tool_executed)


func _adapt_layout_for_viewport() -> void:
	var screen_width := get_viewport_rect().size.x
	# Check if running in small screens or mobile editor view
	if screen_width < 450:
		_server_toggle_btn.custom_minimum_size = Vector2(0, 48)
		_send_btn.custom_minimum_size = Vector2(60, 48)
		_clear_btn.custom_minimum_size = Vector2(50, 48)
	else:
		_server_toggle_btn.custom_minimum_size = Vector2(0, 36)
		_send_btn.custom_minimum_size = Vector2(70, 36)
		_clear_btn.custom_minimum_size = Vector2(60, 36)


func _on_server_toggle_pressed() -> void:
	if _mcp_server.is_running():
		_mcp_server.stop_server()
	else:
		_mcp_server.auth_token = _auth_edit.text.strip_edges()
		var p := int(_port_spin.value)
		_mcp_server.start_server(p)


func _on_server_state_changed(is_running: bool) -> void:
	if is_running:
		_server_state_label.text = (
			"MCP Server Status: Running (Port " + str(_mcp_server.port) + ")"
		)
		_server_toggle_btn.text = "Stop MCP Server"
	else:
		_server_state_label.text = "MCP Server Status: Stopped"
		_server_toggle_btn.text = "Start MCP Server"


func _on_server_log(msg: String) -> void:
	_log_text.append_text("[" + Time.get_time_string_from_system() + "] " + msg + "\n")


func _on_provider_selected(idx: int) -> void:
	var prov_id: int = _provider_option.get_item_id(idx)
	_ai_client.provider = prov_id as MCPAIClient.Provider
	match prov_id:
		MCPAIClient.Provider.OPENAI:
			_model_edit.text = "gpt-4o-mini"
		MCPAIClient.Provider.ANTHROPIC:
			_model_edit.text = "claude-3-5-sonnet-20241022"
		MCPAIClient.Provider.OLLAMA:
			_model_edit.text = "llama3.2"


func _on_send_pressed() -> void:
	_submit_ai_prompt()


func _on_prompt_submitted(_text: String) -> void:
	_submit_ai_prompt()


func _submit_ai_prompt() -> void:
	var prompt := _prompt_edit.text.strip_edges()
	if prompt.is_empty():
		return

	_ai_client.api_key = _apikey_edit.text.strip_edges()
	_ai_client.model_name = _model_edit.text.strip_edges()
	_ai_client.custom_url = _custom_url_edit.text.strip_edges()

	_append_chat("User", prompt)
	_prompt_edit.clear()
	_ai_client.send_message(prompt)


func _on_clear_pressed() -> void:
	_chat_text.clear()
	_ai_client.clear_history()


func _on_ai_response(response_text: String) -> void:
	_append_chat("AI", response_text)


func _on_ai_error(error_msg: String) -> void:
	_append_chat("Error", error_msg)


func _on_ai_tool_executed(tool_name: String, _args: Dictionary, output: String) -> void:
	_append_chat("Tool (" + tool_name + ")", output)


func _append_chat(sender: String, text: String) -> void:
	_chat_text.append_text("[" + sender + "]\n" + text + "\n\n")

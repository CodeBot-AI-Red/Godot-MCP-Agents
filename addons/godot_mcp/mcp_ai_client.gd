@tool
class_name MCPAIClient
extends Node

## AI Client node for connecting Godot directly to ChatGPT, Claude, Ollama, etc.

signal response_received(response_text: String)
signal error_occurred(error_msg: String)
signal tool_executed(tool_name: String, args: Dictionary, output: String)

enum Provider {
	OPENAI,
	ANTHROPIC,
	OLLAMA,
	CUSTOM
}

@export var provider: Provider = Provider.OPENAI
@export var api_key: String = ""
@export var model_name: String = "gpt-4o-mini"
@export var custom_url: String = "http://localhost:11434/v1/chat/completions"

var _http_request: HTTPRequest = null
var _conversation_history: Array = []


func _ready() -> void:
	_ensure_http_request()


func _ensure_http_request() -> void:
	if not is_instance_valid(_http_request):
		_http_request = HTTPRequest.new()
		add_child(_http_request)
		if not _http_request.request_completed.is_connected(_on_request_completed):
			_http_request.request_completed.connect(_on_request_completed)


func clear_history() -> void:
	_conversation_history.clear()


func send_message(user_message: String) -> void:
	if user_message.strip_edges().is_empty():
		return

	_conversation_history.append({"role": "user", "content": user_message})
	_dispatch_api_request()


func _dispatch_api_request() -> void:
	_ensure_http_request()
	if not is_instance_valid(_http_request):
		emit_signal("error_occurred", "HTTPRequest node is missing.")
		return

	match provider:
		Provider.OPENAI, Provider.CUSTOM:
			_send_openai_style_request()
		Provider.ANTHROPIC:
			_send_anthropic_request()
		Provider.OLLAMA:
			_send_ollama_request()


func _send_openai_style_request() -> void:
	var url := "https://api.openai.com/v1/chat/completions"
	if provider == Provider.CUSTOM and not custom_url.is_empty():
		url = custom_url

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

	var messages := _build_messages_with_system()
	var payload := {
		"model": model_name,
		"messages": messages,
		"temperature": 0.7
	}

	var json_payload := JSON.stringify(payload)
	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, json_payload)
	if err != OK:
		emit_signal("error_occurred", "Failed to send HTTP request: " + str(err))


func _send_anthropic_request() -> void:
	var url := "https://api.anthropic.com/v1/messages"
	var headers := [
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01"
	]

	var system_prompt := _get_system_instructions()
	var anthropic_messages: Array = []
	for msg in _conversation_history:
		anthropic_messages.append({
			"role": msg["role"],
			"content": msg["content"]
		})

	var payload := {
		"model": model_name if not model_name.is_empty() else "claude-3-5-sonnet-20241022",
		"max_tokens": 2048,
		"system": system_prompt,
		"messages": anthropic_messages
	}

	var json_payload := JSON.stringify(payload)
	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, json_payload)
	if err != OK:
		emit_signal("error_occurred", "Failed to send Anthropic request: " + str(err))


func _send_ollama_request() -> void:
	var url := custom_url if not custom_url.is_empty() else "http://localhost:11434/api/chat"
	var headers := ["Content-Type: application/json"]

	var messages := _build_messages_with_system()
	var payload := {
		"model": model_name if not model_name.is_empty() else "llama3.2",
		"messages": messages,
		"stream": false
	}

	var json_payload := JSON.stringify(payload)
	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, json_payload)
	if err != OK:
		emit_signal("error_occurred", "Failed to send Ollama request: " + str(err))


func _build_messages_with_system() -> Array:
	var list: Array = []
	list.append({
		"role": "system",
		"content": _get_system_instructions()
	})
	for msg in _conversation_history:
		list.append(msg)
	return list


func _get_system_instructions() -> String:
	var tools := MCPTools.get_tool_definitions()
	var tools_json := JSON.stringify(tools)
	var sys := "You are an AI assistant integrated into the Godot Engine Editor.\n"
	sys += "You can perform file and project management using Godot MCP tools.\n"
	sys += "Available Tools Schema:\n" + tools_json + "\n\n"
	sys += "When you need to use a tool, format your response with JSON block:\n"
	sys += "```json\n{\"tool\": \"tool_name\", \"arguments\": {...}}\n```\n"
	return sys


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("error_occurred", "HTTP Request failed with result code: " + str(result))
		return

	if response_code < 200 or response_code >= 300:
		emit_signal(
			"error_occurred",
			"API returned HTTP " + str(response_code) + ": " + body.get_string_from_utf8()
		)
		return

	var response_text := body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(response_text) != OK:
		emit_signal("error_occurred", "Failed to parse API JSON response.")
		return

	var data: Dictionary = json.get_data()
	var assistant_reply := _extract_reply_text(data)

	if assistant_reply.is_empty():
		emit_signal("error_occurred", "Empty reply received from AI model.")
		return

	_conversation_history.append({"role": "assistant", "content": assistant_reply})
	emit_signal("response_received", assistant_reply)

	_check_and_execute_tool_call(assistant_reply)


func _extract_reply_text(data: Dictionary) -> String:
	# Anthropic format
	if data.has("content") and data["content"] is Array:
		var arr: Array = data["content"]
		var text_out := ""
		for item in arr:
			if item is Dictionary and item.get("type") == "text":
				text_out += item.get("text", "")
		return text_out

	# OpenAI format
	if data.has("choices") and data["choices"] is Array:
		var choices: Array = data["choices"]
		if choices.size() > 0 and choices[0] is Dictionary:
			var msg: Dictionary = choices[0].get("message", {})
			return msg.get("content", "")

	# Ollama format
	if data.has("message") and data["message"] is Dictionary:
		var msg_dict: Dictionary = data["message"]
		return msg_dict.get("content", "")

	return ""


func _check_and_execute_tool_call(reply: String) -> void:
	var start_idx := reply.find("```json")
	var block_offset := 7
	if start_idx == -1:
		start_idx = reply.find("```")
		block_offset = 3
		if start_idx == -1:
			return

	var end_idx := reply.find("```", start_idx + block_offset)
	if end_idx == -1:
		return

	var json_str := reply.substr(start_idx + block_offset, end_idx - (start_idx + block_offset)).strip_edges()
	var json := JSON.new()
	if json.parse(json_str) == OK and json.get_data() is Dictionary:
		var call_dict: Dictionary = json.get_data()
		if call_dict.has("tool"):
			var tool_name: String = call_dict["tool"]
			var tool_args: Dictionary = call_dict.get("arguments", {})
			var result := MCPTools.execute_tool(tool_name, tool_args)
			var output_str: String = result.get("output", "")
			emit_signal("tool_executed", tool_name, tool_args, output_str)

			# Auto reply tool execution back to AI
			_conversation_history.append({
				"role": "user",
				"content": "Tool Execution Output (" + tool_name + "):\n" + output_str
			})
			_dispatch_api_request()

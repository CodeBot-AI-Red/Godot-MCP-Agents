@tool
class_name MCPProtocol
extends RefCounted

## Handles JSON-RPC 2.0 formatting and MCP Protocol parsing/serialization.

# MCP Standard Version
const MCP_VERSION := "2024-11-05"

# Error Codes (JSON-RPC 2.0 & MCP Standard)
const PARSE_ERROR := -32700
const INVALID_REQUEST := -32600
const METHOD_NOT_FOUND := -32601
const INVALID_PARAMS := -32602
const INTERNAL_ERROR := -32603


static func make_response(id_val: Variant, result: Variant) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": id_val,
		"result": result
	}


static func make_error(
	id_val: Variant, code: int, message: String, data: Variant = null
) -> Dictionary:
	var err := {
		"code": code,
		"message": message
	}
	if data != null:
		err["data"] = data
	return {
		"jsonrpc": "2.0",
		"id": id_val,
		"error": err
	}


static func parse_json_request(json_text: String) -> Dictionary:
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		return {
			"error": make_error(
				null, PARSE_ERROR, "Invalid JSON string: " + json.get_error_message()
			)
		}

	var data: Variant = json.get_data()
	if not (data is Dictionary):
		return {
			"error": make_error(null, INVALID_REQUEST, "Request payload must be a JSON Object")
		}

	var req: Dictionary = data
	if not req.has("jsonrpc") or req["jsonrpc"] != "2.0":
		return {
			"error": make_error(
				req.get("id", null),
				INVALID_REQUEST,
				"Invalid or missing 'jsonrpc' field (expected '2.0')"
			)
		}

	if not req.has("method") or not (req["method"] is String):
		return {
			"error": make_error(req.get("id", null), INVALID_REQUEST, "Missing or invalid 'method'")
		}

	return {
		"request": req
	}


static func handle_initialize(id_val: Variant, params: Dictionary) -> Dictionary:
	var client_version: String = params.get("protocolVersion", MCP_VERSION)
	return make_response(id_val, {
		"protocolVersion": client_version,
		"capabilities": {
			"tools": {
				"listChanged": false
			},
			"resources": {
				"subscribe": false,
				"listChanged": false
			},
			"logging": {}
		},
		"serverInfo": {
			"name": "godot-mcp-server",
			"version": "1.0.0"
		}
	})


static func handle_tools_list(id_val: Variant, tools_definitions: Array) -> Dictionary:
	return make_response(id_val, {
		"tools": tools_definitions
	})


static func make_tool_result(
	id_val: Variant, text_content: String, is_error: bool = false
) -> Dictionary:
	return make_response(id_val, {
		"content": [
			{
				"type": "text",
				"text": text_content
			}
		],
		"isError": is_error
	})

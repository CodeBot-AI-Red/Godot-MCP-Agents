@tool
class_name MCPServer
extends Node

## Embedded HTTP/TCP Server handling JSON-RPC 2.0 MCP requests in Godot.

signal log_message(msg: String)
signal server_state_changed(is_running: bool)

@export var port: int = 8080
@export var auth_token: String = ""

var _tcp_server: TCPServer = null
var _is_running: bool = false
var _active_connections: Array = []


func _ready() -> void:
	_tcp_server = TCPServer.new()


func start_server(listen_port: int = 8080) -> bool:
	if _is_running:
		stop_server()

	port = listen_port
	var err := _tcp_server.listen(port, "127.0.0.1")
	if err == OK:
		_is_running = true
		emit_signal("server_state_changed", true)
		emit_signal("log_message", "MCP Server started on http://127.0.0.1:" + str(port))
		return true

	emit_signal("log_message", "Failed to start MCP Server on port " + str(port) + ": " + str(err))
	return false


func stop_server() -> void:
	for conn in _active_connections:
		var stream: StreamPeerTCP = conn.get("stream", null)
		if stream and stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			stream.disconnect_from_host()
	_active_connections.clear()

	if _tcp_server and _tcp_server.is_listening():
		_tcp_server.stop()
	_is_running = false
	emit_signal("server_state_changed", false)
	emit_signal("log_message", "MCP Server stopped.")


func is_running() -> bool:
	return _is_running


func _process(_delta: float) -> void:
	if not _is_running or not _tcp_server:
		return

	if _tcp_server.is_connection_available():
		var new_stream := _tcp_server.take_connection()
		if new_stream:
			_active_connections.append({
				"stream": new_stream,
				"buffer": "",
				"time_created": Time.get_ticks_msec()
			})

	_poll_connections()


func _poll_connections() -> void:
	var to_remove: Array = []
	var now := Time.get_ticks_msec()

	for conn in _active_connections:
		var stream: StreamPeerTCP = conn["stream"]
		stream.poll()
		var status := stream.get_status()

		if status != StreamPeerTCP.STATUS_CONNECTED:
			to_remove.append(conn)
			continue

		var bytes_avail := stream.get_available_bytes()
		if bytes_avail > 0:
			var chunk := stream.get_string(bytes_avail)
			conn["buffer"] += chunk

		var buf: String = conn["buffer"]
		if "\r\n\r\n" in buf or "\n\n" in buf:
			_handle_request_data(conn)
			to_remove.append(conn)
		elif now - int(conn["time_created"]) > 5000:
			to_remove.append(conn)

	for conn in to_remove:
		_active_connections.erase(conn)


func _handle_request_data(conn: Dictionary) -> void:
	var stream: StreamPeerTCP = conn["stream"]
	var request_data: String = conn["buffer"]
	var headers_and_body := request_data.split("\r\n\r\n", true, 1)

	var headers_text := headers_and_body[0]
	var body_text := headers_and_body[1] if headers_and_body.size() > 1 else ""

	# Check for OPTIONS preflight CORS
	if headers_text.begins_with("OPTIONS"):
		_send_http_response(stream, 200, "OK", "", "text/plain")
		return

	# Token validation if token is set
	if not auth_token.is_empty():
		if not ("Authorization: Bearer " + auth_token in headers_text):
			_send_http_response(
				stream, 401, "Unauthorized", "{\"error\": \"Unauthorized\"}", "application/json"
			)
			return

	if body_text.is_empty():
		_send_http_response(
			stream, 400, "Bad Request", "{\"error\": \"Empty Body\"}", "application/json"
		)
		return

	var parsed := MCPProtocol.parse_json_request(body_text)
	if parsed.has("error"):
		var err_dict: Dictionary = parsed["error"]
		_send_http_response(stream, 200, "OK", JSON.stringify(err_dict), "application/json")
		return

	var req: Dictionary = parsed["request"]
	var response := _process_mcp_request(req)
	var resp_str := JSON.stringify(response)

	_send_http_response(stream, 200, "OK", resp_str, "application/json")


func _process_mcp_request(req: Dictionary) -> Dictionary:
	var req_id: Variant = req.get("id", null)
	var method: String = req.get("method", "")
	var params: Dictionary = req.get("params", {})

	emit_signal("log_message", "Received MCP method: " + method)
	var response: Dictionary = {}

	match method:
		"initialize":
			response = MCPProtocol.handle_initialize(req_id, params)

		"ping":
			response = MCPProtocol.make_response(req_id, {})

		"tools/list":
			var tools_list := MCPTools.get_tool_definitions()
			response = MCPProtocol.handle_tools_list(req_id, tools_list)

		"tools/call":
			var tool_name: String = params.get("name", "")
			var tool_args: Dictionary = params.get("arguments", {})
			var result_dict := MCPTools.execute_tool(tool_name, tool_args)
			var output_str: String = result_dict.get("output", "")
			var is_err: bool = not result_dict.get("success", false)
			response = MCPProtocol.make_tool_result(req_id, output_str, is_err)

		"resources/list":
			response = MCPProtocol.make_response(req_id, {"resources": []})

		"resources/read":
			response = MCPProtocol.make_error(
				req_id, MCPProtocol.INVALID_PARAMS, "No resources registered"
			)

		_:
			response = MCPProtocol.make_error(
				req_id, MCPProtocol.METHOD_NOT_FOUND, "Method not supported: " + method
			)

	return response


func _send_http_response(
	stream: StreamPeerTCP,
	status_code: int,
	status_msg: String,
	body: String,
	content_type: String
) -> void:
	var response := "HTTP/1.1 " + str(status_code) + " " + status_msg + "\r\n"
	response += "Content-Type: " + content_type + "\r\n"
	response += "Content-Length: " + str(body.utf8().size()) + "\r\n"
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Access-Control-Allow-Headers: *\r\n"
	response += "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n"
	response += "Connection: close\r\n\r\n"
	response += body

	stream.put_data(response.utf8())

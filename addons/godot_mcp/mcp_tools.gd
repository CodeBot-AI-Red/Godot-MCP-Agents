@tool
class_name MCPTools
extends RefCounted

## Handles tool registrations and file/directory/editor operations for Godot MCP.


static func get_tool_definitions() -> Array:
	return [
		{
			"name": "read_file",
			"description": "Reads text content from a file in Godot project.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to file (e.g. res://scripts/player.gd)"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "write_file",
			"description": "Writes or overwrites text content to a file in Godot project.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to write (e.g. res://scripts/player.gd)"
					},
					"content": {
						"type": "string",
						"description": "Text content to write into the file"
					}
				},
				"required": ["path", "content"]
			}
		},
		{
			"name": "create_directory",
			"description": "Creates a directory path recursively in the project.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Directory path (e.g. res://scenes/ui)"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "delete_path",
			"description": "Deletes a file or directory from the project.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to file or directory to remove"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "list_directory",
			"description": "Lists files and subdirectories inside a directory.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Directory path (default: res://)"
					}
				}
			}
		},
		{
			"name": "get_project_structure",
			"description": "Returns a nested tree view of the Godot project directory.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"root_path": {
						"type": "string",
						"description": "Root path to start tree scan from (default: res://)"
					},
					"max_depth": {
						"type": "integer",
						"description": "Maximum recursion depth (default: 5)"
					}
				}
			}
		},
		{
			"name": "get_editor_info",
			"description": "Returns metadata about Godot engine version and project.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "reload_filesystem",
			"description": "Triggers FileSystem dock rescan so new assets appear instantly.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		}
	]


static func execute_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"read_file":
			var path: String = args.get("path", "")
			return _op_read_file(path)
		"write_file":
			var path: String = args.get("path", "")
			var content: String = args.get("content", "")
			return _op_write_file(path, content)
		"create_directory":
			var path: String = args.get("path", "")
			return _op_create_directory(path)
		"delete_path":
			var path: String = args.get("path", "")
			return _op_delete_path(path)
		"list_directory":
			var path: String = args.get("path", "res://")
			return _op_list_directory(path)
		"get_project_structure":
			var root_path: String = args.get("root_path", "res://")
			var max_depth: int = int(args.get("max_depth", 5))
			return _op_get_project_structure(root_path, max_depth)
		"get_editor_info":
			return _op_get_editor_info()
		"reload_filesystem":
			return _op_reload_filesystem()
		_:
			return {
				"success": false,
				"output": "Unknown tool method: " + tool_name
			}


static func _op_read_file(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "output": "Path parameter cannot be empty."}

	var global_p := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_p):
		return {"success": false, "output": "File does not exist: " + path}

	var file := FileAccess.open(global_p, FileAccess.READ)
	if not file:
		var err := FileAccess.get_open_error()
		return {"success": false, "output": "Failed to open file: " + str(err)}

	var text := file.get_as_text()
	file.close()
	return {"success": true, "output": text}


static func _op_write_file(path: String, content: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "output": "Path parameter cannot be empty."}

	var global_p := ProjectSettings.globalize_path(path)
	var dir_path := global_p.get_base_dir()

	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return {
				"success": false,
				"output": "Failed to create parent directory: " + str(err)
			}

	var file := FileAccess.open(global_p, FileAccess.WRITE)
	if not file:
		var err := FileAccess.get_open_error()
		return {"success": false, "output": "Failed to write file: " + str(err)}

	file.store_string(content)
	file.close()

	_notify_filesystem_scan()

	return {"success": true, "output": "Successfully wrote file: " + path}


static func _op_create_directory(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "output": "Path parameter cannot be empty."}

	var global_p := ProjectSettings.globalize_path(path)
	var err := DirAccess.make_dir_recursive_absolute(global_p)
	if err != OK:
		return {"success": false, "output": "Failed to create directory: " + str(err)}

	_notify_filesystem_scan()
	return {"success": true, "output": "Directory created successfully: " + path}


static func _op_delete_path(path: String) -> Dictionary:
	if path.is_empty():
		return {"success": false, "output": "Path parameter cannot be empty."}

	var global_p := ProjectSettings.globalize_path(path)

	if FileAccess.file_exists(global_p):
		var err := DirAccess.remove_absolute(global_p)
		if err != OK:
			return {"success": false, "output": "Failed to delete file: " + str(err)}
		_notify_filesystem_scan()
		return {"success": true, "output": "Deleted file: " + path}

	if DirAccess.dir_exists_absolute(global_p):
		var err := DirAccess.remove_absolute(global_p)
		if err != OK:
			return {
				"success": false,
				"output": "Failed to remove directory (must be empty first): " + str(err)
			}
		_notify_filesystem_scan()
		return {"success": true, "output": "Deleted directory: " + path}

	return {"success": false, "output": "Target path does not exist: " + path}


static func _op_list_directory(path: String) -> Dictionary:
	var global_p := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(global_p)
	if not dir:
		return {"success": false, "output": "Could not access directory: " + path}

	var files: Array = []
	var dirs: Array = []

	dir.list_dir_begin()
	var item_name := dir.get_next()
	while not item_name.is_empty():
		if item_name != "." and item_name != "..":
			if dir.current_is_dir():
				dirs.append(item_name + "/")
			else:
				files.append(item_name)
		item_name = dir.get_next()
	dir.list_dir_end()

	var result := {
		"path": path,
		"directories": dirs,
		"files": files
	}

	return {
		"success": true,
		"output": JSON.stringify(result, "  ")
	}


static func _op_get_project_structure(root_path: String, max_depth: int) -> Dictionary:
	var tree_dict := _scan_tree(root_path, 0, max_depth)
	return {
		"success": true,
		"output": JSON.stringify(tree_dict, "  ")
	}


static func _scan_tree(path: String, current_depth: int, max_depth: int) -> Dictionary:
	var result := {
		"name": path.get_file() if not path.get_file().is_empty() else path,
		"path": path,
		"type": "directory",
		"children": []
	}

	if current_depth >= max_depth:
		result["truncated"] = true
		return result

	var global_p := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(global_p)
	if not dir:
		result["error"] = "Access denied or directory missing"
		return result

	dir.list_dir_begin()
	var item_name := dir.get_next()
	while not item_name.is_empty():
		if item_name != "." and item_name != ".." and not item_name.begins_with(".import"):
			var child_path := path.path_join(item_name)
			if dir.current_is_dir():
				var child_dir := _scan_tree(child_path, current_depth + 1, max_depth)
				(result["children"] as Array).append(child_dir)
			else:
				(result["children"] as Array).append({
					"name": item_name,
					"path": child_path,
					"type": "file"
				})
		item_name = dir.get_next()
	dir.list_dir_end()

	return result


static func _op_get_editor_info() -> Dictionary:
	var info := {
		"engine_version": Engine.get_version_info(),
		"project_name": ProjectSettings.get_setting("application/config/name", "Godot Project"),
		"platform": OS.get_name(),
		"is_editor": Engine.is_editor_hint(),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", "")
	}
	return {
		"success": true,
		"output": JSON.stringify(info, "  ")
	}


static func _op_reload_filesystem() -> Dictionary:
	_notify_filesystem_scan()
	return {
		"success": true,
		"output": "Triggered FileSystem scan in Godot Editor."
	}


static func _notify_filesystem_scan() -> void:
	if Engine.is_editor_hint():
		var interface := Engine.get_singleton("EditorInterface")
		if interface and interface.has_method("get_resource_filesystem"):
			var fs = interface.call("get_resource_filesystem")
			if fs and fs.has_method("scan"):
				fs.call("scan")

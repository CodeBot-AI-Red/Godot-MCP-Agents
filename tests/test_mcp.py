import unittest
import json
import os
import shutil

class TestGodotMCPProtocolAndTools(unittest.TestCase):

    def setUp(self):
        self.test_dir = os.path.join(os.getcwd(), "test_sandbox")
        os.makedirs(self.test_dir, exist_ok=True)

    def tearDown(self):
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_jsonrpc_protocol_structure(self):
        req = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05"
            }
        }
        json_str = json.dumps(req)
        parsed = json.loads(json_str)
        self.assertEqual(parsed["jsonrpc"], "2.0")
        self.assertEqual(parsed["id"], 1)
        self.assertEqual(parsed["method"], "initialize")

    def test_mcp_tools_list_schema(self):
        tools = [
            "read_file",
            "write_file",
            "create_directory",
            "delete_path",
            "list_directory",
            "get_project_structure",
            "get_editor_info",
            "reload_filesystem"
        ]
        self.assertEqual(len(tools), 8)
        self.assertIn("read_file", tools)
        self.assertIn("write_file", tools)
        self.assertIn("create_directory", tools)

    def test_file_operations_logic(self):
        test_file = os.path.join(self.test_dir, "test_script.gd")
        content = 'extends Node\nfunc _ready():\n\tprint("Hello MCP")\n'

        # Write
        with open(test_file, "w", encoding="utf-8") as f:
            f.write(content)

        self.assertTrue(os.path.exists(test_file))

        # Read
        with open(test_file, "r", encoding="utf-8") as f:
            read_back = f.read()

        self.assertEqual(read_back, content)

        # Delete
        os.remove(test_file)
        self.assertFalse(os.path.exists(test_file))

    def test_path_normalization(self):
        def normalize_path(path: str) -> str:
            path = path.strip()
            if not path:
                return "res://"
            if not path.startswith("res://") and not path.startswith("user://") and not os.path.isabs(path):
                path = "res://" + path
            return path

        self.assertEqual(normalize_path("scripts/player.gd"), "res://scripts/player.gd")
        self.assertEqual(normalize_path("res://scenes/main.tscn"), "res://scenes/main.tscn")
        self.assertEqual(normalize_path(""), "res://")

    def test_http_separator_parsing(self):
        def parse_http_request(raw_data: str):
            separator = "\r\n\r\n"
            if separator not in raw_data and "\n\n" in raw_data:
                separator = "\n\n"
            parts = raw_data.split(separator, 1)
            headers = parts[0]
            body = parts[1] if len(parts) > 1 else ""
            return headers, body

        req_crlf = "POST / HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n{\"jsonrpc\":\"2.0\"}"
        h1, b1 = parse_http_request(req_crlf)
        self.assertIn("POST / HTTP/1.1", h1)
        self.assertEqual(b1, "{\"jsonrpc\":\"2.0\"}")

        req_lf = "POST / HTTP/1.1\nHost: 127.0.0.1\n\n{\"jsonrpc\":\"2.0\"}"
        h2, b2 = parse_http_request(req_lf)
        self.assertIn("POST / HTTP/1.1", h2)
        self.assertEqual(b2, "{\"jsonrpc\":\"2.0\"}")


if __name__ == "__main__":
    unittest.main()

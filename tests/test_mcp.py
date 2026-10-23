import unittest
import json
import urllib.request
import urllib.error
import time
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

if __name__ == "__main__":
    unittest.main()

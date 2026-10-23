# Godot MCP AI Agent Connection Plugin

[![Godot Engine](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Un plugin production-ready para **Godot Engine 4.x** que implementa o **Model Context Protocol (MCP)** e conecta Agentes de IA (Claude, ChatGPT, Ollama e endpoints customizados) diretamente ao Editor da Godot.

Com este plugin, IAs e assistentes virtuais conseguem navegar na estrutura do projeto, criar, ler, editar e excluir arquivos GDScript, criar pastas, atualizar a árvore de arquivos e manipular projetos tanto em telas **Desktop** quanto em **Mobile** (Godot Editor em tablets/celulares/Android).

---

## 🚀 Funcionalidades Principais

- **Servidor MCP HTTP Embeddable (JSON-RPC 2.0)**: Executa um servidor local em Godot para conectar com Claude Desktop, Cursor, Goose e qualquer cliente compatível com MCP.
- **Operações de Arquivos e Projeto**:
  - `read_file`: Lê conteúdo de arquivos do projeto (`res://`).
  - `write_file`: Cria e modifica arquivos (scripts GDScript, arquivos JSON, tscn, cfg, etc).
  - `create_directory`: Cria pastas e subpastas recursivamente.
  - `delete_path`: Exclui arquivos ou diretórios vazios.
  - `list_directory`: Lista diretórios e arquivos.
  - `get_project_structure`: Retorna a árvore completa do projeto em JSON.
  - `get_editor_info`: Retorna versão do engine, SO, cena principal e configurações.
  - `reload_filesystem`: Força o recarregamento instantâneo da dock de FileSystem da Godot.
- **Interface Flutuante Adaptável (Desktop & Mobile)**:
  - Layout responsivo usando `ScrollContainer`, `VBoxContainer` e `GridContainer`.
  - Ajuste automático de botões e touch-targets para telas menores ou modo mobile do editor.
- **Cliente Direct AI Integrado**:
  - Conecte diretamente no dock ao **Claude (Anthropic)**, **ChatGPT (OpenAI)**, **Ollama (IA Local)** ou qualquer API compatível com OpenAI.
  - Execução automática de ferramentas (*Tool Calls*).
- **Pronto para a Loja de Plugins da Godot (Asset Library)**:
  - Estruturação estrita (`addons/godot_mcp/`), `plugin.cfg`, `plugin.gd`, licença MIT e ícone SVG.

---

## 📦 Instalação

1. Baixe ou clone este repositório.
2. Copie a pasta `addons/godot_mcp` para dentro da pasta `addons/` do seu projeto Godot.
3. Abra o seu projeto no Godot Editor 4.x.
4. Vá em **Configurações do Projeto (Project Settings) -> Plugins** e ative o plugin **Godot MCP AI Agent**.
5. A aba **MCP AI** aparecerá no lado direito do Editor.

---

## 🔌 Como Conectar ao Claude Desktop

Adicione as configurações abaixo ao seu arquivo `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "godot": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "http://127.0.0.1:8080",
        "-H", "Content-Type: application/json",
        "-d"
      ]
    }
  }
}
```

*Nota: Certifique-se de que o servidor MCP esteja ativo na dock do Godot na porta `8080`.*

---

## 🧪 Testes e Qualidade de Código

Para rodar a verificação de sintaxe GDScript e os testes unitários do protocolo:

```bash
# Formatação e validação GDScript
gdlint addons/godot_mcp/*.gd

# Testes automatizados Python
python3 -m unittest tests/test_mcp.py
```

---

## 📄 Licença

Este projeto está licenciado sob a Licença [MIT](LICENSE).

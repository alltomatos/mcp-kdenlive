# mcp-kdenlive

Servidor MCP para o Kdenlive — encapsula a [kdenlive-api](https://github.com/alltomatos/kdenlive-api) para o Claude Code e outros agentes de LLM.

Dá a um agente de IA controle total de NLE (edição não-linear) sobre uma instância do Kdenlive em execução via D-Bus: importar mídia, montar timelines, adicionar transições, marcadores, efeitos e renderizar.

## Início rápido

### Instalação automática (Windows)

Execute no PowerShell:

```powershell
irm https://raw.githubusercontent.com/alltomatos/mcp-kdenlive/main/script.ps1 | iex
```

Um menu aparece com as opções:

1. Instalar o Kdenlive oficial (winget) — **sem** API de scripting D-Bus
2. Instalar o MCP (clona `mcp-kdenlive` + `kdenlive-api`, cria o virtualenv, gera o `.mcp.json`)
3. Instalar tudo (1 + 2)
4. Compilar o Kdenlive com suporte a D-Bus a partir do [fork alltomatos/kdenlive](https://github.com/alltomatos/kdenlive/tree/dbus-scripting-windows), via KDE Craft — processo longo (30-60+ min na primeira vez: instala Visual Studio Build Tools, KDE Craft, e compila), mas é o único jeito de o MCP controlar o Kdenlive de verdade no Windows
5. **Recomendado**: tudo com D-Bus (2 + 4)

Ver [script.ps1](script.ps1) para detalhes e parâmetros (`-Action`, `-InstallRoot`, `-McpRepo`, `-ApiRepo`, `-CraftRoot`, `-KdenliveForkRepo`, `-KdenliveForkBranch`, `-ProjectMcpJsonPath`).

### Manual

Adicione ao seu `.mcp.json`:

```json
{
  "mcpServers": {
    "kdenlive": {
      "command": "python",
      "args": ["-m", "mcp_kdenlive"]
    }
  }
}
```

## Requisitos

- Python 3.10+
- [kdenlive-api](https://github.com/alltomatos/kdenlive-api)
- [MCP SDK](https://pypi.org/project/mcp/) (`mcp>=1.0.0`)
- [Kdenlive (fork com patch)](https://github.com/alltomatos/kdenlive/tree/dbus-scripting-windows) em execução, com a API de scripting via D-Bus (no Windows, compilado pela opção 4/5 do `script.ps1`)

```bash
pip install -r requirements.txt
```

## Ferramentas

### Compostas (use estas primeiro)

| Ferramenta | Descrição |
|------|-------------|
| `build_timeline` | Montagem completa a partir dos clipes de cena (importação + sequência + transições + áudio + marcadores) |
| `replace_scene` | Troca um clipe de cena pelo número, mantendo posição e transições |
| `get_timeline_summary` | Tabela em texto com todos os clipes da timeline |
| `add_transitions_batch` | Adiciona dissolves cruzados em lote entre todos os clipes de uma trilha |
| `render_video` | Exporta a timeline para um arquivo de vídeo |

### Atômicas

| Domínio | Ferramentas |
|--------|-------|
| Projeto | `get_project_info`, `save_project`, `load_project` |
| Mídia | `get_media_pool`, `import_media`, `import_media_glob`, `create_bin_folder` |
| Timeline | `get_track_list`, `get_clip_info`, `insert_clip`, `append_clips`, `move_clip`, `delete_clip`, `add_track`, `trim_clip` |
| Transições | `add_transition`, `remove_transition` |
| Marcadores | `get_markers`, `add_marker`, `delete_marker`, `delete_markers_by_color` |
| Substituição | `replace_clip` |
| Checkpoints | `checkpoint_save`, `checkpoint_restore` |

## Repositórios relacionados

- [kdenlive-api](https://github.com/alltomatos/kdenlive-api) — API Python compatível com o DaVinci Resolve
- [alltomatos/kdenlive](https://github.com/alltomatos/kdenlive/tree/dbus-scripting-windows) — fork do Kdenlive (baseado em [D-Ogi/kdenlive](https://github.com/D-Ogi/kdenlive)) com API de scripting via D-Bus expandida e suporte a build no Windows/MSVC
</content>

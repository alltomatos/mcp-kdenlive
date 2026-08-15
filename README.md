# mcp-kdenlive

Servidor MCP para o Kdenlive — encapsula a [kdenlive-api](https://github.com/D-Ogi/kdenlive-api) para o Claude Code e outros agentes de LLM.

Dá a um agente de IA controle total de NLE (edição não-linear) sobre uma instância do Kdenlive em execução via D-Bus: importar mídia, montar timelines, adicionar transições, marcadores, efeitos e renderizar.

## Início rápido

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
- [kdenlive-api](https://github.com/D-Ogi/kdenlive-api)
- [MCP SDK](https://pypi.org/project/mcp/) (`mcp>=1.0.0`)
- [Kdenlive (fork com patch)](https://github.com/D-Ogi/kdenlive) em execução, com a API de scripting via D-Bus

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

- [kdenlive-api](https://github.com/D-Ogi/kdenlive-api) — API Python compatível com o DaVinci Resolve
- [D-Ogi/kdenlive](https://github.com/D-Ogi/kdenlive) — fork do Kdenlive com API de scripting via D-Bus
</content>

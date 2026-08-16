# mcp-kdenlive

Servidor MCP para o Kdenlive — encapsula a [kdenlive-api](https://github.com/alltomatos/kdenlive-api) para o Claude Code e outros agentes de LLM.

Dá a um agente de IA controle total de NLE (edição não-linear) sobre uma instância do Kdenlive em execução via D-Bus: importar mídia, montar timelines, adicionar transições, marcadores, efeitos e renderizar.

## Início rápido

### Instalação automática (Windows)

Execute no PowerShell:

```powershell
iex "& { $(irm https://raw.githubusercontent.com/alltomatos/mcp-kdenlive/main/script.ps1) }"
```

(O `& { ... }` isola o script num escopo próprio — sem isso, `irm | iex` roda o `param()` do script direto na sessão atual e pode falhar com `MetadataError` se já existir uma variável `$Action` no shell.)

Sem menu, sem opções — o script instala tudo como um pacote único:

1. Instala o MCP (clona `mcp-kdenlive` + `kdenlive-api`, cria o virtualenv, gera o `.mcp.json`)
2. Baixa o [Kdenlive portátil pré-compilado com D-Bus](https://github.com/alltomatos/kdenlive/releases) (fork [alltomatos/kdenlive](https://github.com/alltomatos/kdenlive/tree/dbus-scripting-windows)) e extrai — leva só alguns minutos. Se o download falhar por qualquer motivo, cai automaticamente para compilar do zero via KDE Craft (processo longo, 30-60+ min: instala Visual Studio Build Tools, KDE Craft, e compila)

Não existe opção para instalar o Kdenlive "oficial" (winget): esse pacote não tem a API de scripting via D-Bus, então seria inútil para o MCP.

Para pular direto para o build do zero (ex: para pegar patches mais recentes ainda não publicados como release), use `-ForceBuild`. Ver [script.ps1](script.ps1) para os demais parâmetros (`-InstallRoot`, `-McpRepo`, `-ApiRepo`, `-CraftRoot`, `-KdenliveForkRepo`, `-KdenliveForkBranch`, `-KdenlivePortableUrl`, `-KdenlivePortableRoot`, `-ProjectMcpJsonPath`).

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
- [Kdenlive (fork com patch)](https://github.com/alltomatos/kdenlive/tree/dbus-scripting-windows) em execução, com a API de scripting via D-Bus (no Windows, o `script.ps1` baixa o [build portátil](https://github.com/alltomatos/kdenlive/releases) automaticamente, ou compila via KDE Craft se preciso)

```bash
pip install -r requirements.txt
```

## Ferramentas

Modelo mental idêntico à API do DaVinci Resolve: `Resolve → ProjectManager → Project → MediaPool → Timeline → TimelineItem`.

### Compostas (use estas primeiro)

| Ferramenta | Descrição |
|------|-------------|
| `build_timeline` | Montagem completa a partir dos clipes de cena (importação + sequência + transições + áudio + marcadores) |
| `replace_scene` | Troca um clipe de cena pelo número, mantendo posição e transições |
| `detect_scenes` | Detecção de cenas via FFmpeg num clipe do bin, retorna os timestamps de corte |
| `get_timeline_summary` | Tabela em texto com todos os clipes da timeline |
| `add_transitions_batch` | Adiciona dissolves cruzados em lote entre todos os clipes de uma trilha |
| `render_video` | Exporta a timeline para um arquivo de vídeo |

### Preview (inspeção visual — retornam caminhos de arquivo JPEG)

| Ferramenta | Descrição |
|------|-------------|
| `render_frame` | Miniatura da timeline composta num frame específico |
| `render_bin_frame` | Um frame de um clipe do media pool |
| `render_contact_sheet` | Grade de frames igualmente espaçados de um clipe do bin (requer Pillow) |
| `render_crop` | Recorte 1:1 em pixels de um frame da timeline para QC (requer Pillow) |
| `screenshot_window` | Captura a janela do Kdenlive como JPEG + mapa de painéis em JSON |
| `screenshot_panel` | Recorta um painel nomeado da GUI (ex: `"timeline"`, `"effect_stack"`) |

### Atômicas

| Domínio | Ferramentas |
|--------|-------|
| Projeto | `get_project_info`, `new_project`, `open_project`, `save_project`, `load_project`, `set_project_profile`, `get_project_duration`, `get_project_color_space`, `set_project_color_space` |
| Mídia | `get_media_pool`, `import_media`, `import_media_glob`, `create_bin_folder` |
| Timeline | `get_track_list`, `get_clip_info`, `insert_clip`, `append_clips`, `move_clip`, `trim_clip`, `split_clip`, `slip_clip`, `delete_clip`, `add_track` |
| Transições | `add_transition`, `remove_transition` |
| Efeitos | `add_effect`, `remove_effect`, `get_clip_effects`, `set_clip_opacity`, `set_effect_param`, `get_effect_param`, `set_effect_expression`, `clear_effect_expression` |
| Keyframes de efeito | `get_effect_keyframes`, `add_effect_keyframe`, `remove_effect_keyframe`, `update_effect_keyframe` |
| Velocidade | `set_clip_speed` |
| Áudio | `set_clip_volume`, `get_clip_volume`, `set_audio_fade`, `set_track_mute`, `get_track_mute`, `get_audio_levels` |
| Marcadores | `get_markers`, `add_marker`, `delete_marker`, `delete_markers_by_color`, `add_clip_marker`, `get_clip_markers`, `delete_clip_marker`, `delete_clip_markers_by_color` |
| Substituição | `replace_clip`, `relink_clip` |
| Checkpoints | `checkpoint_save`, `checkpoint_restore`, `undo`, `redo`, `undo_status` |
| Zonas | `get_zone`, `set_zone`, `set_zone_in`, `set_zone_out`, `extract_zone` |
| Sequências | `get_sequences`, `get_active_sequence`, `set_active_sequence` |
| Títulos | `add_title` |
| Composições | `get_compositions`, `get_composition_info`, `move_composition`, `resize_composition`, `delete_composition`, `get_composition_types` |
| Proxy | `get_clip_proxy_status`, `set_clip_proxy`, `delete_clip_proxy`, `rebuild_clip_proxy` |
| Grupos | `group_clips`, `ungroup_clips`, `get_group_info`, `remove_from_group` |
| Legendas | `get_subtitles`, `add_subtitle`, `edit_subtitle`, `delete_subtitle`, `export_subtitles`, `get_subtitle_styles`, `set_subtitle_style`, `delete_subtitle_style`, `set_subtitle_style_name` |
| Seleção | `get_selection`, `set_selection`, `add_to_selection`, `clear_selection`, `select_all`, `select_current_track`, `select_items_in_range` |
| Playback | `seek_to`, `get_position`, `play`, `pause`, `get_playback_speed`, `set_playback_speed` |
| Render | `get_render_presets`, `get_render_jobs`, `abort_render_job` |

### Roadmap: API D-Bus expandida sem wrapper MCP ainda

O fork [alltomatos/kdenlive](https://github.com/alltomatos/kdenlive/tree/dbus-scripting-windows) já expõe estes métodos D-Bus adicionais, mas eles **ainda não têm ferramenta MCP correspondente** (só chamáveis via `dbus._call(...)` cru no `kdenlive-api`):

- Efeitos de trilha/master: `scriptAddTrackEffect`, `scriptRemoveTrackEffect`, `scriptAddMasterEffect`, `scriptRemoveMasterEffect`
- Presets de render customizados: `scriptCreateRenderPreset`, `scriptDeleteRenderPreset`
- Perfil de projeto customizado: `scriptCreateProjectProfile`
- Notas do projeto: `scriptGetProjectNotes`, `scriptSetProjectNotes`
- Backups: `scriptListBackups`, `scriptRestoreBackup`

Contribuições adicionando esses como ferramentas MCP em `mcp_kdenlive/tools/` são bem-vindas.

## Repositórios relacionados

- [kdenlive-api](https://github.com/alltomatos/kdenlive-api) — API Python compatível com o DaVinci Resolve
- [alltomatos/kdenlive](https://github.com/alltomatos/kdenlive/tree/dbus-scripting-windows) — fork do Kdenlive (baseado em [D-Ogi/kdenlive](https://github.com/D-Ogi/kdenlive)) com API de scripting via D-Bus expandida e suporte a build no Windows/MSVC
</content>

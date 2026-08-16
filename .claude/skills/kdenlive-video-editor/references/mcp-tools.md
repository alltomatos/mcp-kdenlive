# Referência completa das ferramentas do mcp-kdenlive

O servidor MCP `kdenlive` (repositório [alltomatos/mcp-kdenlive](https://github.com/alltomatos/mcp-kdenlive)) dá controle total de NLE (edição não-linear) sobre uma instância do Kdenlive em execução, via D-Bus. O modelo mental é idêntico à API do DaVinci Resolve:

```
Resolve → ProjectManager → Project → MediaPool → Timeline → TimelineItem
```

Pré-requisito: o Kdenlive precisa estar **rodando** (é controle ao vivo via D-Bus, não edição de arquivo `.kdenlive` offline). No Windows, isso significa o build portátil do fork `alltomatos/kdenlive` (instalado via `script.ps1`), não o Kdenlive oficial da Microsoft Store/winget — o oficial não tem a API de scripting.

## Regras de uso

- **Prefira as ferramentas compostas** — elas encapsulam fluxos completos numa chamada só, em vez de você orquestrar várias ferramentas atômicas manualmente.
- **Estado é texto E visual**: `get_timeline_summary` dá a visão em texto (barata, ~20 tokens/linha); as ferramentas de preview dão a visão visual (frames JPEG) — use as duas.
- **Frames na entrada, timecodes na saída.**
- Depois de `replace_scene` ou `build_timeline`: **sempre** rode `render_frame` pra verificar visualmente o resultado.
- Ao avaliar clipes antes de decidir algo: use `render_bin_frame` ou `render_contact_sheet` antes de tomar a decisão, não confie só no nome do arquivo.
- Quando em dúvida sobre o estado atual: chame `get_timeline_summary`.

## Ferramentas compostas (comece por aqui)

| Ferramenta | Quando usar |
|---|---|
| `build_timeline` | Montagem completa a partir de clipes de "cena" — importa, sequencia, adiciona transições, áudio e marcadores numa chamada só. Ideal pro passo inicial de montar um vídeo a partir de um conjunto de clipes. |
| `replace_scene` | Trocar um clipe de cena pelo número, mantendo posição e transições — útil quando o usuário pede "troca a cena 3 por esse outro clipe". |
| `detect_scenes` | Detecção de cenas via FFmpeg num clipe do bin, retorna os timestamps de corte — use antes de decidir onde cortar um vídeo longo (gravação de câmera fixa, por exemplo). |
| `get_timeline_summary` | Tabela em texto com todos os clipes da timeline. Chame isso sempre que precisar re-orientar sobre o estado atual. |
| `add_transitions_batch` | Adiciona dissolves cruzados em lote entre todos os clipes de uma trilha — mais rápido que adicionar um por um. |
| `render_video` | Exporta a timeline pra um arquivo de vídeo final. |

## Preview (inspeção visual — retornam caminhos de JPEG)

| Ferramenta | Quando usar |
|---|---|
| `render_frame` | Miniatura da timeline composta num frame específico — a ferramenta de verificação padrão depois de qualquer edição. |
| `render_bin_frame` | Um frame de um clipe do media pool — usar antes de decidir se um clipe serve pra um corte. |
| `render_contact_sheet` | Grade de frames igualmente espaçados de um clipe do bin — ótimo pra escanear um clipe longo rapidamente e achar o melhor momento sem assistir tudo. |
| `render_crop` | Recorte 1:1 em pixels de um frame da timeline, pra checagem de qualidade fina (texto, logo, etc). |
| `screenshot_window` | Captura a janela inteira do Kdenlive como JPEG + mapa de painéis em JSON — usar quando precisar ver o estado da UI (não só a timeline). |
| `screenshot_panel` | Recorta um painel nomeado da GUI (`"timeline"`, `"effect_stack"`, etc). |

## Atômicas, por domínio

### Projeto
`get_project_info`, `new_project`, `open_project`, `save_project`, `load_project`, `set_project_profile`, `get_project_duration`, `get_project_color_space`, `set_project_color_space`

### Mídia
`get_media_pool`, `import_media`, `import_media_glob`, `create_bin_folder`

### Timeline
`get_track_list`, `get_clip_info`, `insert_clip`, `append_clips`, `move_clip`, `trim_clip`, `split_clip`, `slip_clip`, `delete_clip`, `add_track`

### Transições
`add_transition`, `remove_transition`

### Efeitos
`add_effect`, `remove_effect`, `get_clip_effects`, `set_clip_opacity`, `set_effect_param`, `get_effect_param`, `set_effect_expression`, `clear_effect_expression`

### Keyframes de efeito
`get_effect_keyframes`, `add_effect_keyframe`, `remove_effect_keyframe`, `update_effect_keyframe` — essencial pra zoom/pan animado (Ken Burns), crop animado, opacidade animada.

### Velocidade
`set_clip_speed` — slow motion, speed ramps, time remap.

### Áudio
`set_clip_volume`, `get_clip_volume`, `set_audio_fade`, `set_track_mute`, `get_track_mute`, `get_audio_levels`

### Marcadores
`get_markers`, `add_marker`, `delete_marker`, `delete_markers_by_color`, `add_clip_marker`, `get_clip_markers`, `delete_clip_marker`, `delete_clip_markers_by_color` — use marcadores coloridos pra sinalizar "melhores momentos" candidatos a corte antes de fatiar um vídeo longo em clipes curtos.

### Substituição
`replace_clip`, `relink_clip`

### Checkpoints / desfazer
`checkpoint_save`, `checkpoint_restore`, `undo`, `redo`, `undo_status` — salve um checkpoint antes de uma sequência arriscada de edições (ex: antes de testar um corte agressivo).

### Zonas (in/out)
`get_zone`, `set_zone`, `set_zone_in`, `set_zone_out`, `extract_zone` — fundamental pra extrair um trecho específico de um vídeo longo (ex: isolar os 45s que vão virar um Reel).

### Sequências (multi-timeline)
`get_sequences`, `get_active_sequence`, `set_active_sequence` — útil quando o projeto tem várias versões/formatos do mesmo corte (ex: uma sequência 16:9 pro YouTube e outra 9:16 pro TikTok).

### Títulos
`add_title` — para textos na tela, legendas queimadas estilizadas, callouts.

### Composições
`get_compositions`, `get_composition_info`, `move_composition`, `resize_composition`, `delete_composition`, `get_composition_types` — blend modes, picture-in-picture, split screen.

### Proxy
`get_clip_proxy_status`, `set_clip_proxy`, `delete_clip_proxy`, `rebuild_clip_proxy` — gere proxies pra material 4K/pesado antes de editar, senão a timeline fica travando.

### Grupos
`group_clips`, `ungroup_clips`, `get_group_info`, `remove_from_group`

### Legendas
`get_subtitles`, `add_subtitle`, `edit_subtitle`, `delete_subtitle`, `export_subtitles`, `get_subtitle_styles`, `set_subtitle_style`, `delete_subtitle_style`, `set_subtitle_style_name` — cruciais pra short-form (a maioria assiste sem som).

### Seleção
`get_selection`, `set_selection`, `add_to_selection`, `clear_selection`, `select_all`, `select_current_track`, `select_items_in_range`

### Playback
`seek_to`, `get_position`, `play`, `pause`, `get_playback_speed`, `set_playback_speed`

### Render
`get_render_presets`, `get_render_jobs`, `abort_render_job`

## Métodos D-Bus expandidos (sem ferramenta MCP ainda)

O fork [alltomatos/kdenlive](https://github.com/alltomatos/kdenlive/tree/dbus-scripting-windows) já implementa estes métodos no lado do Kdenlive, mas eles ainda **não têm ferramenta MCP correspondente** — só chamáveis via `dbus._call(...)` cru no `kdenlive-api`, não pelo nome amigável do MCP. Se o usuário pedir algo que caia nessas categorias, explique que a funcionalidade existe no backend mas precisa ser exposta como ferramenta MCP primeiro (ou ofereça pra fazer isso).

- Efeitos de trilha/master: `scriptAddTrackEffect`, `scriptRemoveTrackEffect`, `scriptAddMasterEffect`, `scriptRemoveMasterEffect`
- Presets de render customizados: `scriptCreateRenderPreset`, `scriptDeleteRenderPreset`
- Perfil de projeto customizado: `scriptCreateProjectProfile`
- Notas do projeto: `scriptGetProjectNotes`, `scriptSetProjectNotes`
- Backups: `scriptListBackups`, `scriptRestoreBackup`

## Fluxos comuns

### Montar um vídeo do zero a partir de clipes de cena
1. `import_media_glob` pra trazer os arquivos pro bin
2. `render_contact_sheet` em cada clipe candidato pra avaliar sem assistir tudo
3. `build_timeline` pra montagem inicial (import + sequência + transições + áudio + marcadores)
4. `render_frame` em pontos-chave pra verificar
5. `add_transitions_batch` se precisar padronizar as transições
6. `render_video` pra exportar

### Cortar um vídeo longo (podcast/live) em clipes curtos
1. `detect_scenes` ou assistir/escanear via `render_contact_sheet` pra achar candidatos
2. `add_marker` colorido em cada momento forte (ver `references/short-form-clips.md` pros critérios de "momento forte")
3. Pra cada marcador aprovado: `set_zone_in`/`set_zone_out` (ou `set_zone`) delimitando o trecho, `extract_zone`
4. Nova sequência 9:16 (`get_sequences`/`set_active_sequence`) se o corte precisa virar vertical — reposicionar/crop o clipe com `add_effect`+`set_effect_param` (ou keyframes de posição/zoom) pra manter o assunto enquadrado
5. `add_subtitle`/legendas queimadas — quase obrigatório pra short-form
6. `render_video` com preset vertical

### Corrigir cor/áudio básico
- Cor: `add_effect` com um efeito de correção de cor, `set_effect_param` pra ajustar, `add_effect_keyframe` se precisar variar ao longo do clipe
- Áudio: `set_clip_volume`/`set_audio_fade` por clipe, `get_audio_levels` pra checar picos/clipping antes de exportar

# Kdenlive — dicas, truques e boas práticas

## 1. Fluxo de trabalho eficiente

**Project Bin / organização**
- Crie pastas (bins) por tipo: `01_Video`, `02_Audio`, `03_Imagens`, `04_Gráficos`, `05_Sequências`. O bin suporta ícones/lista, cores de tag e busca por nome — use `create_bin_folder` do MCP.
- Um item com "zonas" definidas mostra indicador de pasta no ícone do bin.
- **Subclipes**: no Clip Monitor, defina zona in/out (I/O) e clique em "add clip zone to Project Bin" — cria um clip filho reaproveitável sem duplicar o arquivo original. Via MCP: `set_zone_in`/`set_zone_out` no clipe do bin.
- Use **cores de clipe** e **tags** no bin para status (bruto, selecionado, aprovado).

**Proxy clips**
- Essenciais para material 4K/RAW pesado: ativar proxy, escolher codec (ProRes Proxy ou MPEG intra leve) e resolução reduzida (geralmente metade do original).
- O link ao arquivo original é mantido; a troca é transparente no render final.
- Fluxo recomendado: gerar proxies ao importar mídia pesada (`set_clip_proxy`) → editar com proxies ativos → **desativar antes do render final** (`delete_clip_proxy` ou desmarcar) — erro comum é esquecer isso e exportar em baixa resolução sem perceber.

**Marcadores (Markers)**
- "Bandeirinhas" coloridas dentro de um clipe ou no timeline, que se movem junto com o clipe — usadas para sincronizar pontos-chave (bater de palmas, corte de fala, batida musical).
- Podem ter categorias com cores diferentes (erro, ação, música) e comentário de texto.
- Via MCP: `add_marker`/`add_clip_marker` com cor — use isso ativamente para marcar "melhores momentos" antes de fatiar um vídeo longo em clipes curtos.

**Zonas (in/out)**
- Intervalo definido no Clip Monitor ou Project Monitor, usado para: extrair subclipe, inserir apenas o trecho selecionado no timeline (3-point edit), ou limitar render/preview a uma faixa.
- No timeline, zona também é usada por "Extract Timeline Zone" (ripple delete multi-track).
- Via MCP: `set_zone`/`set_zone_in`/`set_zone_out`/`extract_zone` — é o caminho mais direto pra isolar um trecho específico de um vídeo longo.

**Grupos**
- Selecionar múltiplos clipes e agrupar faz com que se movam juntos — útil pra manter áudio+vídeo sincronizados. Via MCP: `group_clips`/`ungroup_clips`.
- Erro comum: não agrupar áudio e vídeo relacionados, causando dessincronia acidental ao mover/cortar depois.

## 2. Efeitos e transições

**Crossfade / Dissolve**
- Sobrepor dois clipes na mesma faixa cria um "mix" automático (dissolve). Via MCP: `add_transition`, ou em lote com `add_transitions_batch`.
- Para fades simples de vídeo por clipe, use o efeito "Fade in/Fade out".

**Composite & Transform (posição/zoom/opacidade)**
- Efeito central pra animar posição, escala e opacidade em camadas, com múltiplos modos de composição (normal, adição, multiplicar).
- Keyframes: adicione pontos-chave na linha de keyframes do efeito; mova o playhead, altere valor → cria novo keyframe automaticamente. Via MCP: `add_effect_keyframe`/`update_effect_keyframe`.
- Interpolação: linear, discreta (hold), suave (curva) — a suave evita movimento robótico em zoom/pan (efeito Ken Burns).

**Chroma Key (green screen)**
- Duas variantes: **Simple** (um clique na cor) e **Advanced** (múltiplas amostras, mais controle).
- Processo: 1) selecionar a cor-chave, 2) ajustar tolerância/similaridade, 3) ajustar bordas ("Fat/Normal/Skinny" = quanto feathering).
- Combine com Composite & Transform (posicionar) e Blur/Despill (remover reflexo verde residual).

**Color grading**
- Efeitos básicos: Brightness/Contrast, Color Correction (curvas RGB), Lift/Gamma/Gain (roda de cores profissional), LUT.
- Fluxo recomendado: correção primária (exposição/whitebalance) em toda a cena → grading criativo (LUT/curvas) em efeito **separado** pra poder desabilitar individualmente depois.

**Blend modes**
- Controlados via propriedade "Blend mode" da faixa/clipe (Normal, Add, Multiply, Screen, Overlay), combináveis com opacidade via keyframe — útil pra picture-in-picture e composições em camadas.

## 3. Atalhos e técnicas de corte rápido

| Ação | Atalho |
|---|---|
| Ferramenta seleção | `S` |
| Ferramenta navalha (razor) | `X` |
| Cortar no playhead | `Shift+R` |
| Ferramenta espaçador (mover em bloco) | `M` |
| Extrair clipe (ripple delete) | `Shift+Del` |
| Remover espaço vazio (gap) | clique direito → Remove Space |
| Extrair zona do timeline (multi-track) | `Shift+X` |
| Marcar In / Out da zona | `I` / `O` |
| Agrupar clipes selecionados | `Ctrl+G` |

**Ripple delete**: cortar o trecho indesejado, "Extract Clip" — remove e desliza o restante pra preencher o vazio.

**Roll edit**: ajusta simultaneamente o ponto de saída de um clipe e entrada do adjacente (o corte "rola"), sem alterar a duração total.

**Slip**: altera os pontos IN/OUT internos do clipe (o que é mostrado) mantendo duração/posição fixas — não afeta vizinhos. Via MCP: `slip_clip`.

**Slide**: move um clipe entre vizinhos, ajustando os pontos out/in deles pra preencher o espaço.

## 4. Áudio

- **Normalize 2 Pass** é a versão recomendada pra faixa/arquivo inteiro (loudness consistente) — a versão "Normalize" padrão é otimizada pra streams ao vivo, sem lookahead, e dá resultado inconsistente em gravações.
- **Fades**: alças nos cantos superiores do clipe de áudio no timeline. Via MCP: `set_audio_fade`. Problema comum: fade-in muito lento por configuração padrão — ajustar curva/duração manualmente.
- **Audio Waveform Filter**: desenha a forma de onda sobre a imagem — útil pra vídeos de podcast/música.
- **Ducking**: não há efeito nativo dedicado; abordagem manual é usar keyframes de volume no efeito de volume da trilha de música de fundo pra baixar durante as falas. Via MCP: `add_effect_keyframe` no clipe de música com valores de volume automatizados.
- **Sincronização**: comparar waveforms manualmente ou usar marcadores em ambos os clipes como pontos de referência (bater de palmas).

## 5. Legendas

- Ferramenta nativa com faixa dedicada no timeline. Importa ASS/SRT/VTT/SBV, exporta ASS/SRT.
- Internamente armazenadas em `.ass` (permite estilos avançados: fonte, cor, posição, contorno).
- **Camadas/estilos**: cada "camada" de legenda pode ter um estilo padrão — todo texto novo nessa camada herda o estilo. Útil pra múltiplos falantes. Via MCP: `set_subtitle_style`/`set_subtitle_style_name`.
- Timing editado direto na faixa do timeline (arrastar bordas IN/OUT), com preview no monitor. Via MCP: `add_subtitle`/`edit_subtitle`.
- Legendas queimadas (burned-in) são quase obrigatórias em short-form — a maioria assiste sem som.

## 6. Presets de render

**YouTube (horizontal)**
- Preset **H.264** na resolução de origem (1080p ou 4K).
- Qualidade recomendada: CRF entre **18–22** (menor = mais qualidade/arquivo maior).
- Preset de velocidade padrão libx264 é "slow"; trocar pra "medium" dá ~2x mais velocidade com perda mínima perceptível.
- Para 4K/UHD, considerar **H.265 (HEVC)** — mais eficiente em bitrate. 10-bit (yuv420p10le) melhora qualidade percebida no mesmo bitrate.
- Two-pass rendering pra controlar melhor o tamanho final do arquivo.

**Redes sociais verticais (9:16)**
- Não há preset vertical pronto — a prática é criar/editar o **Project Profile** com resolução vertical (ex. 1080x1920) antes de começar, ou usar um preset custom salvo. Via MCP: `set_project_profile`.
- Aplicar o mesmo preset H.264 padrão (CRF 18-22) ajustado pra resolução vertical.
- Manter frame rate consistente com a origem — evitar conversões de fps desnecessárias (causam judder).

## 7. Erros comuns de iniciantes

- Editar direto em material 4K/RAW pesado sem proxy → timeline travando (ativar proxy resolve).
- Esquecer de desativar proxy antes do render final (exporta em baixa resolução por engano) — **sempre confira antes de exportar**.
- Não organizar o bin em pastas desde o início.
- Usar Normalize (1-pass) em vez de Normalize 2-Pass em áudio gravado.
- Superuso de transições chamativas em vez de crossfade simples, atrapalhando o ritmo.
- Não agrupar áudio e vídeo relacionados, causando dessincronia acidental.
- Renderizar sempre em "very slow"/CRF muito baixo sem necessidade pra entregas de rascunho.
- Não usar zonas (in/out) pra já recortar antes de inserir — mais lento que cortar depois no timeline.

## 8. Recursos avançados

**Keyframes com curvas**
- Interpolação suave (curva) entre pontos evita movimento robótico em zoom/pan/opacidade — "Smooth Keyframe Interpolation".
- Propriedades keyframable: opacidade, volume, crop, posição, escala, praticamente qualquer parâmetro numérico.

**Motion tracking**
- Efeito "Motion Tracker" usa OpenCV pra localizar e seguir um objeto em movimento.
- Boa prática: escolher área de **alto contraste** que permaneça visível durante todo o rastreamento — o algoritmo degrada se o alvo sai e volta à tela.
- Combinação típica: Motion Tracker + Composite/Transform pra "colar" um elemento (blur de rosto, sticker, texto) seguindo um objeto/pessoa — útil pra reenquadrar automaticamente um rosto em corte vertical.

**Composições / correção de cor em camadas**
- Aplicar efeitos de cor em faixas/clipes separados permite isolar ajustes (LUT geral numa camada + correção pontual em outra) sem afetar a hierarquia de composição.

## Fontes
- [Kdenlive Ultimate Guide: Professional Editing Workflow (2025/2026)](https://medium.com/@kernelcoffee/kdenlive-ultimate-guide-professional-editing-workflow-2025-2026-edition-a024065cdace)
- [Kdenlive 26.04.0 released](https://kdenlive.org/news/releases/26.04.0/)
- [Proxy Clips — Manual](https://docs.kdenlive.org/en/getting_started/configure_kdenlive/configuration_proxy_clips.html)
- [Markers — Manual](https://docs.kdenlive.org/en/cutting_and_assembling/markers.html)
- [Clip Monitor — Manual](https://docs.kdenlive.org/en/user_interface/monitors/clip_monitor.html)
- [Chroma Key: Advanced — Manual](https://docs.kdenlive.org/en/effects_and_filters/video_effects/alpha_mask_keying/chroma_key_advanced.html)
- [Kdenlive Transitions — Manual](https://docs.kdenlive.org/en/tips_and_tricks/useful_info/kdenlive_transitions.html)
- [Editing — Manual](https://docs.kdenlive.org/en/cutting_and_assembling/editing.html)
- [Keyboard Shortcuts — Manual](https://docs.kdenlive.org/en/user_interface/shortcuts.html)
- [Normalize — Manual](https://docs.kdenlive.org/en/effects_and_filters/audio_effects/volume_and_dynamics/normalize.html)
- [Fixing Unwanted Slow Audio Fade-Ins — Manual](https://docs.kdenlive.org/en/tips_and_tricks/useful_info/fixing_slow_audio_fade-ins.html)
- [Subtitles — Manual](https://docs.kdenlive.org/en/effects_and_filters/subtitles.html)
- [Render Profile Parameters Explained — Manual](https://docs.kdenlive.org/en/tips_and_tricks/useful_info/render_profile_parameters.html)
- [Blending Modes — Manual](https://docs.kdenlive.org/en/compositing/blending_modes.html)
- [Motion Tracker — Manual](https://docs.kdenlive.org/en/effects_and_filters/video_effects/alpha_mask_keying/motion_tracker.html)
- [Smooth Keyframe Interpolation — Manual](https://docs.kdenlive.org/en/tips_and_tricks/useful_info/smooth_keyframe_interpolation.html)

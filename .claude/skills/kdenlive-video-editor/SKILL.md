---
name: kdenlive-video-editor
description: Edição e criação de vídeo profissional no Kdenlive através do MCP kdenlive (controle ao vivo via D-Bus). Use esta skill sempre que o usuário pedir para editar, cortar, montar, exportar ou renderizar um vídeo no Kdenlive, mesmo que ele não cite o nome "Kdenlive" explicitamente — inclui pedidos como "monta esse vídeo", "corta os melhores momentos", "faz uns Reels/TikToks/Shorts a partir dessa live/podcast", "deixa esse vídeo pronto pro YouTube", "adiciona legenda", "corrige o áudio", "faz uma transição", "exporta em 9:16", ou qualquer tarefa de pós-produção de vídeo. Também use quando o usuário pedir dicas, técnicas ou melhores práticas de edição de vídeo, retenção no YouTube, ou como cortar vídeos longos para redes sociais (Instagram, TikTok, X), mesmo sem mencionar o Kdenlive — nesses casos a skill orienta a técnica e, se o usuário topar, executa via MCP.
---

# Editor de vídeo Kdenlive (via MCP)

Esta skill dá o conhecimento completo pra operar o Kdenlive como um editor de vídeo profissional através do MCP `kdenlive` — tanto o domínio técnico da ferramenta (quais chamadas fazer, em que ordem) quanto o domínio criativo (o que faz um corte funcionar, reter atenção, viralizar).

## Antes de qualquer coisa: confirme que o Kdenlive está rodando

O MCP controla uma instância **ao vivo** do Kdenlive via D-Bus — não edita arquivos `.kdenlive` offline. Se qualquer chamada ao MCP falhar por falta de conexão, ou se não houver contexto de que o Kdenlive já está aberto, pergunte ao usuário se ele já abriu o Kdenlive (via o atalho "Kdenlive (MCP)" gerado pelo `script.ps1`, no Windows) antes de prosseguir. Não tente instalar/compilar nada nessa hora — isso é escopo de setup, não de edição.

## As quatro camadas de conhecimento desta skill

1. **`references/mcp-tools.md`** — a referência completa de todas as ferramentas do MCP, organizadas por domínio, com os fluxos de trabalho mais comuns já desenhados (montar do zero, cortar clipes curtos, corrigir cor/áudio). **Leia isso primeiro** sempre que for operar o Kdenlive de verdade — é o mapa de "qual ferramenta chamar pra fazer X".
2. **`references/kdenlive-tips.md`** — dicas e truques específicos do Kdenlive: proxy, keyframes, chroma key, motion tracking, presets de render, erros comuns de iniciante. Consulte quando a dúvida for "como o Kdenlive faz X tecnicamente" (ex: como funciona keyframe suave, o que é ripple delete).
3. **`references/training-vs-viral.md`** — a decisão que vem *antes* das duas referências criativas abaixo: o vídeo é de treinamento/corporativo/educacional ou é viral/redes sociais? As técnicas de retenção agressiva (cortes a cada 2-3s, zoom punches, hook forte) que funcionam pra viral **prejudicam** vídeo de treinamento — aumentam a carga cognitiva e reduzem retenção de conhecimento. Consulte isso **primeiro**, sempre que o pedido envolver decisão criativa (não pra tarefas puramente mecânicas).
4. **`references/youtube-editing.md`** e **`references/short-form-clips.md`** — o conhecimento *criativo* pra conteúdo viral/social: o que faz um vídeo reter atenção (YouTube longo) e o que faz um corte curto (Reels/TikTok/Shorts/X) funcionar. Consulte depois de confirmar, via `training-vs-viral.md`, que o pedido é de fato viral/social e não treinamento — caso seja treinamento, siga a seção "Aplicação prática" de `training-vs-viral.md` em vez destas.

Não carregue os quatro arquivos de uma vez à toa — a maioria das tarefas só precisa de um ou dois. Uma edição técnica simples (ex: "muda o volume desse clipe") só precisa do `mcp-tools.md`. Uma tarefa de "corta essa live em clipes pro TikTok" precisa do `mcp-tools.md` (como executar) **e** do `short-form-clips.md` (o que escolher e como estruturar) — já um "grava um módulo de treinamento sobre onboarding" precisa do `mcp-tools.md` **e** do `training-vs-viral.md`.

## Como pensar sobre uma tarefa de edição

Trate toda tarefa de edição com decisão criativa como três perguntas separadas, nessa ordem:

0. **É treinamento/corporativo ou viral/social?** (pergunta de categoria — responda com os sinais de `training-vs-viral.md`; se ambíguo, trate como híbrido conforme a própria referência descreve. Essa resposta muda a resposta da pergunta 1 inteira — decidir isso depois de já ter planejado ritmo/cortes é retrabalho.)
1. **O que faz esse corte/vídeo funcionar pro objetivo do usuário, dado o que a pergunta 0 revelou?** (pergunta criativa — responda com `training-vs-viral.md` se for treinamento, ou `youtube-editing.md`/`short-form-clips.md` se for viral/social)
2. **Quais chamadas do MCP realizam isso no Kdenlive?** (pergunta técnica — responda com `mcp-tools.md`)

Só pular direto pra etapa 2 quando o pedido já for puramente mecânico (ex: "aumenta o volume em 20%", "adiciona uma transição aqui") — nesses casos não tem decisão criativa a tomar, é só executar.

## Fluxo recomendado por tipo de pedido

### "Monta esse vídeo a partir desses clipes"
1. `import_media_glob` pra trazer o material.
2. `render_contact_sheet` nos clipes candidatos pra avaliar sem assistir tudo.
3. `build_timeline` pra montagem inicial.
4. `render_frame` em pontos-chave pra verificar visualmente.
5. Se for pra YouTube: revise a estrutura contra `youtube-editing.md` (hook nos primeiros segundos, ritmo, pattern interrupts) antes de considerar pronto — não é só "colar os clipes em ordem".

### "Corta os melhores momentos dessa live/podcast em Reels/TikToks/Shorts"
1. Leia `short-form-clips.md` inteiro antes de começar — a seleção de momentos e a estrutura do clipe são o que decide se funciona, não a mecânica de corte em si.
2. Se houver transcrição disponível, use-a pra identificar candidatos (picos emocionais, quotable moments, insights, humor — critérios detalhados na referência). Sem transcrição, use `render_contact_sheet`/`detect_scenes` e assista trechos pra escanear.
3. Pra cada momento aprovado: `add_marker` colorido no ponto, depois `set_zone_in`/`set_zone_out`/`extract_zone` pra isolar o trecho.
4. Reframe pra 9:16 se o destino for vertical (nova sequência/perfil de projeto — ver `mcp-tools.md`), com o sujeito/rosto enquadrado (posição/zoom via keyframes, ou `add_effect` de motion tracking se o sujeito se move).
5. Legenda queimada é quase sempre necessária — `add_subtitle` com estilo de alto contraste (ver seção de legendas em `kdenlive-tips.md` e `short-form-clips.md`).
6. Confirme que o hook dos primeiros 1-3s está forte e que o clipe fecha o loop (ver `short-form-clips.md`) antes de considerar pronto.
7. Pergunte ao usuário qual(is) plataforma(s) é o alvo — a duração-alvo e a intensidade do hook mudam por plataforma.

### "Monta um vídeo de treinamento/curso/onboarding/aula"
1. Confirme que é treinamento pelos sinais em `training-vs-viral.md` (ou pergunte, se ambíguo) — isso muda tudo a seguir.
2. `import_media_glob` pra trazer o material, `build_timeline` pra montagem inicial.
3. Estruture por objetivo de aprendizagem: `add_marker` no início (objetivo), em checkpoints intermediários, e no resumo final — não trate isso como decoração, é a espinha dorsal pedagógica.
4. Ritmo de corte moderado (a cada 30-60s pra resetar atenção, não a cada 2-3s como em viral) — ver `training-vs-viral.md` pra critérios completos e a razão (Cognitive Load Theory).
5. Evite zoom punches e música alta competindo com a explicação — esses recursos servem ao entretenimento, não à retenção de conhecimento.
6. Legendas são reforço de compreensão, não necessariamente queimadas/abertas por padrão como em viral.
7. `render_frame` pra verificar visualmente antes de considerar pronto.

### "Corrige áudio/cor/adiciona efeito"
Tarefa mecânica — vá direto pro `mcp-tools.md`, seção do domínio relevante (Áudio, Efeitos). Só consulte `kdenlive-tips.md` se precisar entender um efeito específico do Kdenlive (ex: diferença entre Normalize e Normalize 2-Pass, como configurar chroma key).

### "Dá umas dicas de edição / como melhorar retenção / como viralizar clipes"
Pergunta puramente de conhecimento, sem execução necessária — responda com base em `youtube-editing.md` e/ou `short-form-clips.md` conforme o contexto (vídeo longo vs. corte curto). Não force uma resposta técnica de Kdenlive se o usuário só quer entender a teoria.

## Sempre verifique visualmente

Depois de qualquer edição que mude a composição visual (corte, efeito, transição, reframe), rode `render_frame` (ou `render_crop` pra checagem fina) antes de dizer que terminou. Não confie só no texto de `get_timeline_summary` pra confirmar que algo "ficou bom" — isso só confirma que existe, não que está certo visualmente.

## Limitações a ter em mente

- Não existe corte/split automático por IA embutido no MCP — a identificação de "melhores momentos" é um julgamento seu, guiado pelos critérios em `short-form-clips.md`, não uma chamada de ferramenta.
- Transcrição de áudio não é uma ferramenta do MCP — se precisar de transcrição pra identificar momentos, avise o usuário que isso é um passo separado (ou peça se ele já tem uma).

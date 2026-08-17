# Cortes de vídeos longos para short-form (Reels, TikTok, Shorts, X)

## 1. Identificação dos melhores momentos ("clip-worthiness")

**Sinais de alto potencial (procurar na transcrição/áudio/vídeo):**
- **Picos emocionais**: mudanças bruscas de pitch, ritmo de fala, volume e tom — entusiasmo, surpresa, indignação, riso.
- **Momentos polêmicos/controversos**: opiniões fortes ou surpreendentes, afirmações que contrariam senso comum, discordância entre convidados.
- **"Aha moments"/insights únicos**: quando alguém simplifica algo complexo, revela um dado surpreendente ou desafia uma crença comum — conteúdo educacional viraliza por fazer o espectador "se sentir mais esperto".
- **Momentos engraçados**: risadas espontâneas, timing cômico, quebra de expectativa.
- **"Quotable moments"**: frases fortes, autocontidas, que fazem sentido fora de contexto — em 5-10 palavras, sem precisar do resto do vídeo pra entender.
- **Problema relatable**: algo que a audiência reconhece na própria vida.

**Critério prático de seleção**: o clipe deve ser compreensível por alguém que nunca viu o vídeo original — self-contained. Se depende de contexto prévio, não é bom clipe.

**Workflow de detecção**: transcrição completa → análise de sentimento/prosódia → ranqueamento por "virality score" → curadoria humana final. A lógica pode ser replicada manualmente: ler a transcrição procurando marcadores de intensidade emocional, contradição, revelação, humor.

## 2. Duração ideal por plataforma (2026)

| Plataforma | Sweet spot | Máximo eficaz | Observação |
|---|---|---|---|
| TikTok | 21-34s (algumas fontes: 15-30s) | 60s | Maior taxa de conclusão nessa faixa; "decision window" de permanência é <1.5s |
| Instagram Reels | 20-30s | até 90s | Prioriza "sends per reach" (compartilhamento via DM) |
| YouTube Shorts | 30-45s | 60s | Sub-30s precisam de ~65% de watch duration média; 30-60s precisam de ~50% |
| X/Twitter | 15-30s (reações/dicas curtas) | 45-90s tutoriais, até 2-4min com hook forte | Vídeo nativo (não link) tem boost forte; completion é sinal direto de ranking |

**Princípio-chave**: a métrica que decide alcance é "average percentage viewed" — a duração certa é a mais longa que o material aguenta sustentar atenção, nem um segundo a mais.

## 3. Formato: reframe 9:16 (horizontal → vertical)

**Pipeline conceitual de reframe**: detecção de sujeito (rosto/falante ativo) → tracking do sujeito (via `add_effect` de motion tracking no Kdenlive) → cálculo dinâmico da janela de corte → suavização (smoothing) do movimento pra evitar jitter.

**Como decidir o que manter no frame:**
- Priorizar rosto do falante ativo — em entrevistas/podcasts, a janela de corte deve trocar de foco conforme o turno de fala muda.
- Em ação (esportes, demonstrações), seguir o objeto/movimento principal, não um ponto fixo.
- Corte fixo ("static crop") só funciona bem quando o enquadramento original já é bem centrado e estático.
- Casos difíceis que exigem ajuste manual: pans rápidos, múltiplos sujeitos na cena, ação nas bordas do frame, elementos de contexto importantes fora do centro (placar, tela compartilhada, texto na tela).
- Split-screen ou blur de fundo (fundo desfocado expandindo o 16:9 original) são alternativas quando não há um sujeito único claro pra seguir.

**No Kdenlive via MCP**: use `create_project_profile` (width=1080, height=1920, fps_num=30) pra criar um perfil vertical **sem mexer no perfil horizontal já em uso** — diferente de `set_project_profile`, que altera o perfil do projeto atual in-place e bagunça qualquer timeline 16:9 que já exista nele. Com o perfil criado, monte a sequência vertical (nova sequência via `get_sequences`/`set_active_sequence`) e reposicione o clipe original dentro dela com o efeito de posição/escala (`add_effect` + `set_effect_param`/`add_effect_keyframe` pra seguir o sujeito ao longo do tempo).

## 4. Hook nos primeiros 1-3 segundos (específico de short-form)

Diferente de vídeo longo (hook pode se desenrolar em 15-30s), no short-form a janela de decisão é brutal:
- TikTok: **"decision window" < 1.5 segundos**.
- Reels/Shorts: primeiros **3 segundos** são o sinal primário pro algoritmo.

**Framework de 4 estágios (em ~6s):**
1. **Pattern Interrupt** (0-1s): corte seco, whip-pan, snap-zoom, ou incongruência visual que quebra o padrão do feed.
2. **Micro-Commitment**: algo que faz o espectador pausar o polegar — texto/legenda de impacto.
3. **Relevance Proof**: sinal de "isso é pra você" (nicho, identificação).
4. **Payoff Promise**: promessa clara do que vem a seguir.

**Táticas concretas**: começar já no meio da ação/afirmação mais forte (não com introdução); usar texto na tela como "curiosity gap"; evitar qualquer segundo de "aquecimento".

## 5. Legendas queimadas (burned-in captions)

**Por que são essenciais**: ~70-85% do consumo de short-form é com som desligado (autoplay silencioso); a legenda precisa estar fisicamente nos pixels do vídeo, não como faixa opcional.

**Estilo dominante 2026**: legendas "word-by-word" animadas (estilo karaokê/"active-word captions") — cada palavra destacada em sincronia com a fala, geralmente 1 frase curta por vez. Esse movimento constante ajuda retenção porque mantém o olho na tela mesmo sem áudio.

**Boas práticas de estilo**: fonte bold, alto contraste, poucas palavras por vez (3-6), posicionamento seguro fora das áreas de UI da plataforma (evitar sobreposição com botões de like/comentar/perfil), emojis/ênfase de cor em palavras-chave.

**No Kdenlive via MCP**: `add_subtitle`/`edit_subtitle` com timing preciso por palavra ou frase curta; `set_subtitle_style` pra fonte bold/alto contraste; posicionar fora da área segura inferior/superior reservada pra UI das plataformas.

## 6. Loop-ability

- Desenhar o **último 0.5 segundo do clipe pra visualmente "casar" com o frame 1** — quando o vídeo reinicia automaticamente (loop nativo), a transição parece intencional em vez de um corte abrupto.
- Técnica de texto: última legenda como frase "circular" que remete de volta ao início (pergunta no início, resposta que reabre a pergunta no fim) — incentiva o replay.
- Loops bem-sucedidos aumentam watch time médio, métrica central de ranqueamento em todas as plataformas.

## 7. Ritmo de corte em short-form

- Muito mais agressivo que long-form: cortes a cada **1-2 segundos** em conteúdo de entretenimento.
- Ritmo recomendado: **Hook → Valor → Interrupção → Valor → Interrupção → CTA** — intercalar entrega de valor com novos "pattern interrupts" pra resetar a atenção periodicamente, não só na abertura.
- **"Hook stacking"**: empilhar múltiplos micro-hooks ao longo do clipe — a cada 5-10s reintroduzir um gancho novo (pergunta, dado, reviravolta) pra impedir que o espectador saia no meio.
- J-cuts/L-cuts, zoom-punch em momentos de ênfase, mudança de plano (close-up ↔ plano médio) mesmo em câmera única (via crop digital) simulam edição multi-câmera.

## 8. Workflow de produção em lote (podcast/live → N clipes)

1. **Transcrição** do vídeo longo completo (com timestamps).
2. **Curadoria por score**: identificar e ranquear candidatos a clipe pelos sinais da seção 1.
3. **Revisão rápida**: aprovar/descartar candidatos — tipicamente ~2/3 dos candidatos automáticos sobrevivem à curadoria.
4. **Edição fina de cada aprovado**: ajustar in/out points (`set_zone_in`/`set_zone_out`/`extract_zone`), reframe 9:16, legendas, hook de abertura.
5. **Exportar por plataforma**: cada clipe pode precisar de ajustes de duração/hook diferentes por plataforma-alvo (ver seção 9).

Referência de produtividade do mercado: um episódio de 45-60 min costuma gerar de 8 a 20 clipes publicáveis. Fontes conversacionais (podcasts, entrevistas) rendem mais clipes utilizáveis que vídeos já editados/roteirizados, por terem mais momentos espontâneos.

## 9. Diferenças de algoritmo entre plataformas (impacto na edição)

- **TikTok**: motor de descoberta agressivo, prioriza sinais comportamentais em tempo real (parar de rolar, assistir até o fim, interagir). Recompensa saves/shares mais que likes. Hook precisa ser instantâneo.
- **Instagram Reels**: valoriza "sends per reach" (compartilhamento via DM) — favorece conteúdo que gera vontade de mandar pra um amigo específico (humor, identificação). Penaliza reposts com marca d'água do TikTok — sempre exportar limpo por plataforma.
- **YouTube Shorts**: tem componente de busca/SEO (título, descrição, palavras-chave) que as outras não têm tanto. Cada Short é testado num pool pequeno antes de decidir empurrar mais; limiar de watch duration média é o gatilho. Tem "cauda longa" — pode continuar sendo descoberto semanas/meses depois.
- **X/Twitter**: vídeo nativo (upload direto) recebe boost forte. Completion rate é sinal direto. Bookmarks têm peso maior que likes. ~70% do consumo é sem som.

**Implicação prática**: mesmo clipe-base, mas variar (a) duração-alvo, (b) intensidade do hook, (c) presença/ausência de marca d'água, (d) metadata de título/descrição (importante pro YouTube Shorts especificamente), (e) call-to-action adaptado ao sinal que cada algoritmo mais valoriza.

## Fontes
- [How to Find the Best Moments to Clip: A Guide for Content Creators](https://clippie.ai/blog/how-to-find-the-best-moments-to-clip)
- [Viral Hooks for YouTube Shorts: 18 Ideas That Stop the Scroll in 2026](https://vidiq.com/blog/post/viral-video-hooks-youtube-shorts/)
- [Best TikTok Hooks 2026 | 5 Types That Go Viral (Data-Backed) - OpusClip Blog](https://www.opus.pro/blog/tiktok-hooks-that-go-viral-2026)
- [How to Find the Best Moments in a Video for Shorts, Reels, and TikToks](https://www.autocut.com/en/blogs/viral-moment/)
- [How to Optimize Short-Form Video in 2026 (TikTok, Reels, Shorts)](https://jetfuel.agency/how-to-optimize-short-form-video-content-for-success/)
- [Ideal Video Length for TikTok, Reels & YouTube Shorts in 2026 (Data Study) | Joyspace](https://joyspace.ai/ideal-video-length-social-platform-2026)
- [How Long Should a TikTok, Reel, or YouTube Short Be? | ScrollScript](https://scrollscript.ai/blog/how-long-should-a-tiktok-reel-youtube-short-be)
- [AI Video Reframe: Auto-Track Speakers in Every Clip | Vmaker AI](https://www.vmaker.com/tools/ai-reframe)
- [AI Video Cropping Tools 2026: Auto-Reframe for 9:16 & 16:9](https://loopdesk.ai/blog/ai-video-cropping-tools-2026)
- [Word-by-Word Animated Captions for TikTok, Reels, and Shorts (2026) | Voice Creator Pro](https://voicecreator.pro/blog/word-by-word-animated-captions)
- [What Are Burned-In Captions? (And When to Use Them) | FrameOS](https://frameos.studio/blog/what-are-burned-in-captions)
- [The Ultimate Opus Clip Workflow in 2026: Long Video to Viral Shorts on Autopilot | FrankX](https://www.frankx.ai/blog/ultimate-opus-clip-workflow-2026)
- [Pattern Interrupt Technique for Short-Form Video](https://www.capcut.com/create/pattern-interrupt-technique-short-form-video)
- [Short-Form Video Mastery: The 3-Second Hook Rule for 2026](https://cloudixdigital.com/short-form-video-mastery-how-the-3-second-hook-rule-drives-social-discovery-and-roi/)
- [Instagram Reels vs TikTok vs YouTube Shorts | TechWyse](https://www.techwyse.com/blog/infographic/best-short-video-platform-2026-instagram-reels-tiktok-youtube-shorts)
- [YouTube Shorts Algorithm 2026: What Pushes Views Now | Socialync](https://www.socialync.io/blog/youtube-shorts-algorithm-2026)
- [X (Twitter) Algorithm: Ranking Factors & Growth Tips (August 2026)](https://www.socialpilot.co/blog/twitter-algorithm)
- [How to Make Twitter/X Videos Go Viral: A Data-Backed Strategy for 2026](https://www.nemovideo.com/blog/how-to-make-twitter-x-videos-go-viral-2026)

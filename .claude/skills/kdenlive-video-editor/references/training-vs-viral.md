# Treinamento/corporativo vs. viral/redes sociais: dois mundos de edição diferentes

Este arquivo existe porque as técnicas de `youtube-editing.md` e `short-form-clips.md` (retenção agressiva, cortes constantes, zoom punches) **não se aplicam** — e frequentemente **prejudicam** — vídeos de treinamento, aula, onboarding ou apresentação corporativa. São dois objetivos diferentes: prender atenção vs. transmitir conhecimento aplicável. **Leia isto antes de aplicar qualquer técnica das outras referências**, e decida primeiro em qual categoria o pedido se encaixa.

## Como decidir a categoria a partir do pedido do usuário

**Sinais de TREINAMENTO/CORPORATIVO:**
- Palavras como "curso", "módulo", "onboarding", "tutorial interno", "treinamento de equipe", "compliance", "capacitação", "aula", "workshop gravado", "apresentação pra RH/stakeholders internos".
- Menção a "aprender", "entender processo", "aplicar depois", "certificação", "checkpoint", "quiz" — audiência é interna/corporativa/estudantes.
- Vídeo longo (>3 min) com conteúdo técnico ou processual, tom instrucional.

**Sinais de VIRAL/SOCIAL:**
- Menção a "Reels", "TikTok", "Shorts", "Instagram", "YouTube Shorts", "engajamento", "viralizar", "growth", "views", "audiência ampla/pública", "hook", "gancho".
- Pedido de vídeo curto (<90s), tom de entretenimento, foco em "prender atenção", "compartilhamento".
- Ausência de objetivo de aprendizagem explícito; presença de objetivo de alcance/conversão/awareness.

**Quando ambíguo** (ex: "vídeo pra redes sociais sobre como usar nosso produto"): trate como híbrido — hook forte nos primeiros segundos (padrão viral), mas ritmo mais didático no corpo do vídeo (padrão treinamento), já que é conteúdo educacional em ambiente de atenção curta.

## As diferenças, lado a lado

| Dimensão | Treinamento/corporativo | Viral/social |
|---|---|---|
| **Métrica de sucesso** | Compreensão, retenção de conhecimento, taxa de conclusão, aplicabilidade prática | Watch-time, retenção segundo a segundo, compartilhamentos, alcance do algoritmo |
| **Ritmo** | Estável e claro — tempo pro cérebro processar informação nova | Agressivo e constante |
| **Frequência de corte/estímulo novo** | A cada 30-60s, só pra "resetar" atenção — não mais que isso | A cada 2-3s em trechos de alta energia |
| **Cortes/jump cuts** | Servem à clareza, não ao estímulo — excesso prejudica compreensão | Sequenciamento fraco/lento é penalizado; cortes dinâmicos "vendem" no feed |
| **Duração ideal** | Módulos de 3-6min (até 10-18min pra tópicos complexos), um objetivo de aprendizagem por vídeo | 30-90s pra clipes; decisão de continuar assistindo em 1.5-3s |
| **Gráficos/texto na tela** | Diagramas, animações explicativas, callouts pedagógicos que reforçam conteúdo | Ganchos textuais e gatilhos emocionais |
| **Legendas** | Reforçam compreensão (vídeos legendados têm 80% mais taxa de conclusão), mas geralmente **opcionais** (closed captions) em e-learning | Essenciais e **abertas por padrão** (open/burned-in) — consumo é majoritariamente sem som |
| **Estrutura** | Objetivo de aprendizagem declarado no início → desenvolvimento lógico e escalonado (básico → complexo) → checkpoints de reflexão → repetição espaçada de conceitos-chave → resumo final | Hook (0-3s) → Value Drop/Body (4-15s) → Payoff (16-45s, entrega a promessa antes de pedir algo) → CTA curto (últimos segundos) |
| **Tom** | Profissional, direto, "reto ao ponto" | Energético, emocional, construído pra gerar reação |

## Por que microlearning funciona (números concretos)

Microlearning (módulos curtos de 3-6min, um objetivo por vídeo) atinge **83% de taxa de conclusão**, contra 20-30% de cursos tradicionais longos, e aumenta retenção de conhecimento em **50%**. Isso não é "vídeo curto porque short-form está na moda" — é um princípio pedagógico independente das redes sociais: dividir conteúdo complexo em unidades processáveis melhora a absorção.

## Cognitive Load Theory: por que técnicas virais prejudicam treinamento

Aprender conteúdo novo já exige carga cognitiva (o cérebro processando informação nova enquanto retém a anterior). Zoom punches, cortes agressivos, música alta e transições vistosas **competem por essa mesma capacidade cognitiva** — em vez de reforçar aprendizado, aumentam a "carga cognitiva extrínseca" e atrapalham a integração do conhecimento. O resultado é o oposto do desejado: mais estímulo visual, menos retenção de conteúdo (não confundir com retenção de audiência — aqui o problema é retenção de *conhecimento*).

Dados de referência: cortes a cada 2.8s com payoff visual em 0:02 elevam retenção de *audiência* de 41% para 58% em vídeo viral — mas esse mesmo ritmo aplicado a um módulo de treinamento reduz a taxa de conclusão do curso e a aplicabilidade prática depois, porque tira o tempo de processamento necessário.

## Erros comuns ao aplicar técnicas "virais" em treinamento

- Zoom punches e cortes a cada 2-3s: competem com a carga cognitiva já exigida pra aprender — o oposto do efeito desejado.
- Música de fundo alta/energética: distrai em vez de reforçar, especialmente em conteúdo técnico/processual.
- Excesso de estímulo visual (transições vistosas, texto piscando): desvia atenção do conteúdo didático central. Em vídeo viral isso É o conteúdo (entretenimento); em treinamento é ruído.
- Cortar todas as pausas/silêncios agressivamente (padrão vlog/viral): em treinamento, pausas dão tempo de processamento — não cortar tudo cegamente, avaliar se a pausa serve à compreensão.
- Não incluir checkpoints/resumos: vídeo de treinamento sem pontos de reforço de conceitos-chave tem retenção de conhecimento pior, mesmo que o "watch time" pareça bom.

## Aplicação prática no Kdenlive via MCP

**Pra treinamento:**
- Estruture a timeline com blocos de 3-6min por módulo/tópico (se o pedido for um curso completo, considere sugerir dividir em múltiplas sequências/exports, uma por módulo).
- Use `add_marker` pra marcar objetivo de aprendizagem (início), checkpoints (meio), e resumo (fim) — ajuda a não perder a estrutura pedagógica.
- Cortes de silêncio: seja mais conservador que em vlog/viral — prefira preservar pausas que dão tempo de processar uma explicação complexa.
- Gráficos/diagramas (via `add_title` ou clipes de imagem sobrepostos com `add_effect` de composição) devem ilustrar o conceito sendo explicado, não decorar.
- Legendas (`add_subtitle`) com foco em precisão terminológica — considere manter como faixa separada (não necessariamente queimada) se o vídeo for consumido em ambiente com som (sala de treinamento, plataforma de LMS).
- Ritmo de corte de plano: a cada 30-60s é suficiente, não a cada 2-3s.

**Pra viral/social**: use `youtube-editing.md` (vídeo longo) ou `short-form-clips.md` (clipe curto) normalmente.

**Pra híbrido** (ex: vídeo educacional pra redes sociais): hook forte nos primeiros 3s (técnica viral) seguido de corpo com ritmo mais pausado e checkpoints leves (técnica de treinamento) — não aplique o ritmo agressivo de corte do começo ao fim só porque o destino é uma rede social.

## Fontes
- [The Dos and Dont's of Corporate Video Production — Artlist](https://artlist.io/blog/corporate-video-production/)
- [7 Best Practices to Create Corporate Training Videos in 2026 — Disprz](https://disprz.ai/blog/corporate-training-video-content)
- [How to Edit Videos for Social Media and the Workplace — InFocus Workshops](https://www.infocusworkshops.com/post/how-to-edit-videos-for-social-media-and-the-workplace-beginner-guide-2026)
- [20 Microlearning Statistics to Guide Your Workplace Learning Strategy in 2025 — Engageli](https://www.engageli.com/blog/20-microlearning-statistics-in-2025)
- [Microlearning Statistics, Facts And Trends For 2025 — eLearning Industry](https://elearningindustry.com/microlearning-statistics-facts-and-trends)
- [Nine Ways to Reduce Cognitive Load in Multimedia Learning — Univ. of Kentucky](https://www.uky.edu/~gmswan3/544/9_ways_to_reduce_CL.pdf)
- [Cognitive Load Essentials for Effective Instructional Videos — NCSU](https://teaching-resources.delta.ncsu.edu/applying-cognitive-load-theory-to-multimedia-in-your-class/)
- [Three Examples of Effective Elearning Structures — Pukunui](https://pukunui.com/effective-elearning-structures/)
- [Hook, Payoff, CTA: Short Video Retention Framework — Faceless.so](https://faceless.so/blog/hook-payoff-cta-short-video-retention-framework)
- [Subtitles vs Closed Captions: What Actually Works on Social Media? — Reap Video](https://reap.video/blog/subtitles-vs-closed-captions)
- [The Difference Between Closed Captions and Open Captions for E-learning Courses — HappyScribe](https://www.happyscribe.com/blog/difference-closed-captions-open-captions-for-elearning-courses)

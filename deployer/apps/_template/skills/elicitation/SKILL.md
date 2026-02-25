# elicitation

## Description
Conduz entrevistas estruturadas via templates. Permite iniciar sessoes de
entrevista, processar respostas, acompanhar progresso e exportar resultados.

## Environment Variables
- `SUPABASE_URL` — URL do projeto Supabase (https://xxx.supabase.co)
- `SUPABASE_SERVICE_ROLE_KEY` — Service role key (acesso admin)

## LLM Tier
standard

## Tools
1. `start_session` — Inicia sessao de entrevista a partir de template_id
2. `process_message` — Processa resposta do usuario e avanca para proxima pergunta
3. `get_status` — Retorna progresso da sessao (% completo, campos preenchidos)
4. `export_results` — Exporta resultados em JSON estruturado

## Usage
```javascript
const elicitation = require('./elicitation');

// Start session
const session = await elicitation.tools.start_session('template-uuid');

// Process responses
const next = await elicitation.tools.process_message(session.session_id, 'Meu nome e Joao');

// Check progress
const status = await elicitation.tools.get_status(session.session_id);

// Export when done
const results = await elicitation.tools.export_results(session.session_id);

// Health check
const health = await elicitation.health();
```

## Notes
- Tabelas Supabase (elicitation_templates, elicitation_sessions, elicitation_results)
  devem ser criadas pela Story 4.3 antes do uso.
- Extracao de dados usa LLM Router (tier standard) quando disponivel.
- Fallback para extracao basica (regex) se LLM indisponivel.
- Resultados exportados para ~/.clawd/memory/elicitation/ (User.md, Company.md, TechStack.md).
- Emite evento elicitation.session.completed no Event Bus apos export.
- Pausar sessao: enviar \`__PAUSE__\` como mensagem.
- Retomar: enviar qualquer mensagem em sessao pausada.

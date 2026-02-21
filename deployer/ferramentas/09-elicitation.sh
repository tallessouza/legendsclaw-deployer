#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Legendsclaw Deployer — Ferramenta 09: Elicitation Skill
# Story 4.2: Skill Elicitation — Estrutura e Tools
# Story 4.4: Integração LLM Router e Memory
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libs
source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/hints.sh"
source "${LIB_DIR}/env-detect.sh"

# =============================================================================
# STEP 1: LOGGING + STEP INIT
# =============================================================================
log_init "elicitation"
setup_trap
step_init 12

# =============================================================================
# STEP 2: LOAD STATE + VERIFICAR DEPENDENCIAS
# =============================================================================
dados
if [[ ! -f "$STATE_DIR/dados_whitelabel" ]]; then
  step_fail "Whitelabel nao encontrado (~/dados_vps/dados_whitelabel ausente)"
  echo "  Execute primeiro: Ferramenta [07] Whitelabel — Identidade do Agente"
  exit 1
fi
nome_agente=$(grep "Agente:" "$STATE_DIR/dados_whitelabel" | awk -F': ' '{print $2}')
if [[ -z "$nome_agente" ]]; then
  step_fail "Nome do agente nao encontrado em dados_whitelabel"
  exit 1
fi

# Skills Base — opcional (WARNING, nao bloqueia)
if [[ -f "$STATE_DIR/dados_skills" ]]; then
  step_ok "Estado carregado — agente '${nome_agente}', Skills Base configurada"
else
  step_ok "Estado carregado — agente '${nome_agente}'"
  echo -e "  ${UI_YELLOW}WARNING: Skills Base nao configurada (Story 4.1) — prosseguindo mesmo assim${UI_NC}"
fi

# LLM Router — opcional (habilita extracao inteligente)
llm_extraction_enabled="false"
if [[ -f "$STATE_DIR/dados_llm_router" ]]; then
  llm_extraction_enabled="true"
  step_ok "LLM Router detectado — extracao inteligente habilitada"
else
  echo -e "  ${UI_YELLOW}WARNING: LLM Router nao configurado (Story 3.2) — extracao basica apenas${UI_NC}"
  step_ok "LLM Router nao encontrado — fallback para extracao basica (regex)"
fi

# =============================================================================
# STEP 3: CHECK DEPENDENCIES — skills/ existe
# =============================================================================
APPS_DIR="apps/${nome_agente}"
SKILLS_DIR="${APPS_DIR}/skills"
ELICIT_DIR="${SKILLS_DIR}/elicitation"

if [[ ! -d "$SKILLS_DIR" ]]; then
  step_fail "Diretorio skills nao encontrado: ${SKILLS_DIR}"
  echo "  Execute a Ferramenta [07] Whitelabel primeiro"
  exit 1
fi
step_ok "Dependencias verificadas — skills/ existe"

# =============================================================================
# STEP 4: CRIAR ESTRUTURA DE DIRETORIOS
# =============================================================================
if [[ -d "$ELICIT_DIR" ]]; then
  step_skip "elicitation/ ja existe — pulando criacao"
else
  mkdir -p "${ELICIT_DIR}/tools"
  mkdir -p "${ELICIT_DIR}/lib"
  step_ok "Estrutura elicitation/ criada (tools/, lib/)"
fi

# =============================================================================
# STEP 5: GERAR ARQUIVOS DA SKILL
# =============================================================================

# --- SKILL.md ---
cat > "${ELICIT_DIR}/SKILL.md" << 'MDEOF'
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
MDEOF

# --- lib/supabase-client.js ---
cat > "${ELICIT_DIR}/lib/supabase-client.js" << 'JSEOF'
// Supabase REST Client — Lightweight (fetch nativo, sem SDK)
// Generated by Legendsclaw Deployer (Story 4.2)

'use strict';

const config = (() => {
  try { return require('../../config'); } catch { return {}; }
})();

const SUPABASE_URL = process.env.SUPABASE_URL || config.SUPABASE_URL || '';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || config.SUPABASE_SERVICE_ROLE_KEY || '';

function getHeaders() {
  if (!SUPABASE_KEY) {
    throw new Error(
      'SUPABASE_SERVICE_ROLE_KEY nao configurada. ' +
      'Verifique .env ou execute Ferramenta [09] Skills com supabase-query.'
    );
  }
  return {
    'apikey': SUPABASE_KEY,
    'Authorization': `Bearer ${SUPABASE_KEY}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };
}

function buildUrl(table, filters) {
  if (!SUPABASE_URL) {
    throw new Error(
      'SUPABASE_URL nao configurada. ' +
      'Verifique .env ou execute Ferramenta [09] Skills com supabase-query.'
    );
  }
  let url = `${SUPABASE_URL}/rest/v1/${encodeURIComponent(table)}`;
  if (filters && typeof filters === 'object') {
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(filters)) {
      params.append(key, String(value));
    }
    const qs = params.toString();
    if (qs) url += `?${qs}`;
  }
  return url;
}

function sanitize(value) {
  if (value === null || value === undefined) return value;
  if (typeof value === 'string') {
    // Remove null bytes and trim excessive length
    return value.replace(/\0/g, '').slice(0, 10000);
  }
  if (typeof value === 'object') {
    if (Array.isArray(value)) return value.map(sanitize);
    const clean = {};
    for (const [k, v] of Object.entries(value)) {
      clean[sanitize(k)] = sanitize(v);
    }
    return clean;
  }
  return value;
}

async function request(url, method, body) {
  const opts = {
    method,
    headers: getHeaders(),
  };
  if (body !== undefined) {
    opts.body = JSON.stringify(sanitize(body));
  }

  let res;
  try {
    res = await fetch(url, opts);
  } catch (err) {
    throw new Error(
      `Supabase indisponivel (${err.message}). ` +
      `Verifique SUPABASE_URL: ${SUPABASE_URL}`
    );
  }

  const text = await res.text();
  if (!res.ok) {
    // Check for table not found
    if (text.includes('relation') && text.includes('does not exist')) {
      throw new Error(
        'Tabelas de elicitation nao encontradas — execute Story 4.3 ou aplique a migration SQL. ' +
        `Detalhe: ${text}`
      );
    }
    throw new Error(`Supabase error ${res.status}: ${text}`);
  }

  if (!text) return null;
  try { return JSON.parse(text); } catch { return text; }
}

async function select(table, filters) {
  const url = buildUrl(table, filters);
  return request(url, 'GET');
}

async function insert(table, data) {
  const url = buildUrl(table);
  return request(url, 'POST', data);
}

async function update(table, filters, data) {
  const url = buildUrl(table, filters);
  return request(url, 'PATCH', data);
}

async function query(table, method, params) {
  switch (method) {
    case 'GET': return select(table, params);
    case 'POST': return insert(table, params);
    case 'PATCH': return update(table, params.filters, params.data);
    default: throw new Error(`Metodo nao suportado: ${method}`);
  }
}

async function ping() {
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return { ok: false, error: 'SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY ausente' };
  }
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/`, { headers: getHeaders() });
    return { ok: res.status === 200, status: res.status };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

async function tablesExist() {
  try {
    await select('elicitation_templates', { 'select': 'id', 'limit': '1' });
    return { ok: true };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

module.exports = { select, insert, update, query, ping, tablesExist, sanitize };
JSEOF

# --- lib/llm-extractor.js (Story 4.4) ---
cat > "${ELICIT_DIR}/lib/llm-extractor.js" << 'JSEOF'
// LLM Extractor — Extracao inteligente via LLM Router
// Generated by Legendsclaw Deployer (Story 4.4)

'use strict';

const path = require('path');
const fs = require('fs');

// Mask API key for logging
function maskKey(key) {
  if (!key || key.length < 8) return '***';
  return key.slice(0, 6) + '...' + key.slice(-4);
}

// Load LLM Router config
function loadConfig(agentName) {
  const configPath = path.join('apps', agentName, 'config', 'llm-router-config.yaml');
  const defaults = {
    openrouter_api_key: process.env.OPENROUTER_API_KEY || '',
    standard_model: 'anthropic/claude-3.5-haiku',
    budget_model: 'deepseek/deepseek-chat',
    timeout_ms: 30000,
    max_tokens: 500,
    temperature: 0.1,
  };

  // Try to read timeout from config file if exists
  try {
    if (fs.existsSync(configPath)) {
      const content = fs.readFileSync(configPath, 'utf8');
      const timeoutMatch = content.match(/timeout_ms:\s*(\d+)/);
      if (timeoutMatch) defaults.timeout_ms = parseInt(timeoutMatch[1], 10);
    }
  } catch { /* use defaults */ }

  return defaults;
}

// Call OpenRouter API
async function callLLM(model, prompt, config) {
  if (!config.openrouter_api_key) {
    throw new Error('OPENROUTER_API_KEY nao configurada');
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.timeout_ms);

  try {
    const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${config.openrouter_api_key}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://legendsclaw.com',
        'X-Title': 'Legendsclaw Elicitation',
      },
      body: JSON.stringify({
        model,
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' },
        max_tokens: config.max_tokens,
        temperature: config.temperature,
      }),
      signal: controller.signal,
    });

    if (!res.ok) {
      const text = await res.text();
      throw new Error(`OpenRouter ${res.status}: ${text}`);
    }

    const data = await res.json();
    const content = data.choices && data.choices[0] && data.choices[0].message
      ? data.choices[0].message.content
      : null;

    if (!content) throw new Error('Resposta vazia do LLM');
    return JSON.parse(content);
  } finally {
    clearTimeout(timeout);
  }
}

// Extract structured data from user message
async function extractData(question, userMessage, expectedType, agentName) {
  const config = loadConfig(agentName || '');

  if (!config.openrouter_api_key) {
    console.warn('[LLM-EXTRACTOR] OPENROUTER_API_KEY ausente — usando extracao basica');
    return { extracted: false, fallback: true };
  }

  const prompt = `Dada a pergunta '${question.text}' e a resposta do usuario '${userMessage}', extraia o dado estruturado. Tipo esperado: ${expectedType}. Retorne JSON com { "value": <valor extraido>, "confidence": <0.0-1.0>, "reasoning": "<explicacao>" }`;

  try {
    const result = await callLLM(config.standard_model, prompt, config);

    const confidence = typeof result.confidence === 'number'
      ? Math.max(0, Math.min(1, result.confidence))
      : 0;

    if (confidence >= 0.7) {
      return { extracted: true, value: result.value, confidence, reasoning: result.reasoning || '' };
    }

    // Low confidence — generate follow-up
    const followUp = await generateFollowUp(question, userMessage, result.reasoning || '', agentName);
    return { extracted: false, followUp, confidence, reasoning: result.reasoning || '' };
  } catch (err) {
    console.warn(`[LLM-EXTRACTOR] LLM extraction failed (${err.message}), using basic extraction. Key: ${maskKey(config.openrouter_api_key)}`);
    return { extracted: false, fallback: true };
  }
}

// Generate clarification follow-up using budget tier
async function generateFollowUp(question, userMessage, reasoning, agentName) {
  const config = loadConfig(agentName || '');

  const prompt = `O usuario respondeu '${userMessage}' para a pergunta '${question.text}', mas a resposta nao foi clara o suficiente (razao: ${reasoning}). Gere uma pergunta de follow-up curta e direta para clarificar. Retorne JSON com { "text": "<pergunta de follow-up>" }`;

  try {
    const result = await callLLM(config.budget_model, prompt, {
      ...config,
      temperature: 0.3,
      max_tokens: 200,
    });
    return result.text || `Pode elaborar mais sobre: ${question.text}`;
  } catch {
    return `Pode elaborar mais sobre: ${question.text}`;
  }
}

module.exports = { extractData, generateFollowUp, maskKey, loadConfig };
JSEOF

# --- lib/memory-writer.js (Story 4.4) ---
cat > "${ELICIT_DIR}/lib/memory-writer.js" << 'JSEOF'
// Memory Writer — Grava resultados no Memory Manager
// Generated by Legendsclaw Deployer (Story 4.4)

'use strict';

const fs = require('fs');
const path = require('path');

const MEMORY_BASE = path.join(process.env.HOME || '~', '.clawd', 'memory', 'elicitation');

// Map section names to memory file types
const SECTION_MAP = {
  'founder & story': 'User',
  'founder': 'User',
  'fundador': 'User',
  'empresa & tecnico': 'Company',
  'empresa': 'Company',
  'company': 'Company',
  'techstack': 'TechStack',
  'tech': 'TechStack',
  'tecnico': 'TechStack',
  'technical': 'TechStack',
};

function classifySection(sectionName) {
  const lower = (sectionName || '').toLowerCase().trim();
  for (const [key, type] of Object.entries(SECTION_MAP)) {
    if (lower.includes(key)) return type;
  }
  // Default: if first section → User, second → Company, third+ → TechStack
  return null;
}

function formatField(question, answer) {
  if (answer === null || answer === undefined || answer === '') return null;
  return `- **${question}**: ${answer}`;
}

function generateMarkdown(title, sessionId, fields) {
  const lines = [
    `# ${title}`,
    `> Auto-generated by Elicitation Skill`,
    `> Session: ${sessionId}`,
    `> Date: ${new Date().toISOString()}`,
    '',
  ];

  for (const field of fields) {
    if (field) lines.push(field);
  }

  return lines.join('\n') + '\n';
}

async function writeMemoryFiles(sessionResults) {
  const sessionId = sessionResults.session_id || 'unknown';
  const sections = sessionResults.sections || [];
  const isPartial = sessionResults.partial === true;
  const suffix = isPartial ? '-partial' : '';

  // Ensure directory exists
  fs.mkdirSync(MEMORY_BASE, { recursive: true });

  const fileData = { User: [], Company: [], TechStack: [] };

  // Classify sections into memory file types
  sections.forEach((section, idx) => {
    let type = classifySection(section.name);
    if (!type) {
      // Fallback by index
      const types = ['User', 'Company', 'TechStack'];
      type = types[idx] || 'TechStack';
    }

    const fields = (section.fields || [])
      .map(f => formatField(f.question, f.answer))
      .filter(Boolean);

    if (fields.length > 0) {
      fileData[type].push(`## ${section.name}`);
      fileData[type].push(...fields);
      fileData[type].push('');
    }
  });

  const writtenFiles = [];

  for (const [type, fields] of Object.entries(fileData)) {
    if (fields.length === 0) continue;

    const filename = `${type}${suffix}.md`;
    const filepath = path.join(MEMORY_BASE, filename);

    // Backup existing file
    if (fs.existsSync(filepath)) {
      const bakPath = filepath + '.bak';
      fs.copyFileSync(filepath, bakPath);
      try { fs.chmodSync(bakPath, 0o600); } catch { /* ignore */ }
    }

    const content = generateMarkdown(type, sessionId, fields);
    fs.writeFileSync(filepath, content, { mode: 0o600 });
    writtenFiles.push(filename);
  }

  return {
    memory_files: writtenFiles,
    memory_path: MEMORY_BASE,
    partial: isPartial,
  };
}

module.exports = { writeMemoryFiles, MEMORY_BASE, classifySection };
JSEOF

# --- lib/event-bus.js (Story 4.4) ---
cat > "${ELICIT_DIR}/lib/event-bus.js" << 'JSEOF'
// Event Bus — Emissor de eventos basico
// Generated by Legendsclaw Deployer (Story 4.4)

'use strict';

const { EventEmitter } = require('events');

const bus = new EventEmitter();

function emit(eventName, payload) {
  const listeners = bus.listenerCount(eventName);
  if (listeners > 0) {
    console.log(`[EVENT] ${eventName} — session_id: ${payload.session_id || 'unknown'} (${listeners} listener(s))`);
    bus.emit(eventName, payload);
  } else {
    console.log(`[EVENT] No listeners for ${eventName} (event logged only)`);
  }
}

function on(eventName, handler) {
  bus.on(eventName, handler);
}

function off(eventName, handler) {
  bus.off(eventName, handler);
}

module.exports = { emit, on, off, bus };
JSEOF

# --- tools/start-session.js ---
cat > "${ELICIT_DIR}/tools/start-session.js" << 'JSEOF'
// Tool: start_session — Inicia sessao de entrevista
// Generated by Legendsclaw Deployer (Story 4.2)

'use strict';

const db = require('../lib/supabase-client');

async function startSession(templateId) {
  if (!templateId) {
    throw new Error('template_id e obrigatorio');
  }

  // Buscar template
  const templates = await db.select('elicitation_templates', {
    'id': `eq.${templateId}`,
    'select': '*',
  });

  if (!templates || templates.length === 0) {
    throw new Error(`Template nao encontrado: ${templateId}`);
  }

  const template = templates[0];
  const sections = template.sections || [];

  // Calcular total de perguntas
  let totalQuestions = 0;
  for (const section of sections) {
    totalQuestions += (section.questions || []).length;
  }

  // Criar sessao
  const sessionData = {
    template_id: templateId,
    status: 'in_progress',
    current_section: 0,
    current_question: 0,
    responses: {},
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  const result = await db.insert('elicitation_sessions', sessionData);
  const session = Array.isArray(result) ? result[0] : result;

  // Extrair primeira pergunta
  const firstQuestion = sections.length > 0 && sections[0].questions && sections[0].questions.length > 0
    ? sections[0].questions[0]
    : null;

  return {
    session_id: session.id,
    template_id: templateId,
    status: 'in_progress',
    current_question: firstQuestion ? {
      text: firstQuestion.text,
      type: firstQuestion.type || 'text',
      required: firstQuestion.required !== false,
      hints: firstQuestion.hints || null,
    } : null,
    total_questions: totalQuestions,
    progress: 0,
  };
}

module.exports = startSession;
JSEOF

# --- tools/process-message.js (Updated Story 4.4: LLM extraction + follow-ups) ---
cat > "${ELICIT_DIR}/tools/process-message.js" << 'JSEOF'
// Tool: process_message — Processa resposta e avanca
// Generated by Legendsclaw Deployer (Story 4.2, Updated Story 4.4)

'use strict';

const db = require('../lib/supabase-client');
const { extractData } = require('../lib/llm-extractor');

const MAX_FOLLOWUPS = 2;

async function processMessage(sessionId, userMessage, agentName) {
  if (!sessionId) throw new Error('session_id e obrigatorio');
  if (userMessage === undefined || userMessage === null) {
    throw new Error('user_message e obrigatorio');
  }

  // Buscar sessao
  const sessions = await db.select('elicitation_sessions', {
    'id': `eq.${sessionId}`,
    'select': '*',
  });

  if (!sessions || sessions.length === 0) {
    throw new Error(`Sessao nao encontrada: ${sessionId}`);
  }

  const session = sessions[0];

  // Pausar
  if (userMessage === '__PAUSE__') {
    if (session.status === 'completed') {
      throw new Error('Sessao ja esta completa, nao pode ser pausada');
    }
    await db.update('elicitation_sessions',
      { 'id': `eq.${sessionId}` },
      { status: 'paused', updated_at: new Date().toISOString() }
    );
    const pauseTemplates = await db.select('elicitation_templates', {
      'id': `eq.${session.template_id}`,
      'select': '*',
    });
    let pauseTotal = 0;
    if (pauseTemplates && pauseTemplates.length > 0) {
      for (const s of (pauseTemplates[0].sections || [])) {
        pauseTotal += (s.questions || []).length;
      }
    }
    const pauseAnswered = countAnswered(session.responses);
    return {
      session_id: sessionId,
      status: 'paused',
      next_question: null,
      progress_percent: pauseTotal > 0 ? Math.round((pauseAnswered / pauseTotal) * 100) : 0,
      questions_answered: pauseAnswered,
      questions_total: pauseTotal,
    };
  }

  // Retomar se pausada
  if (session.status === 'paused') {
    session.status = 'in_progress';
  }

  // Validar status
  if (session.status === 'completed') {
    throw new Error('Sessao ja esta completa');
  }
  if (session.status !== 'in_progress') {
    throw new Error(`Status invalido: ${session.status}`);
  }

  // Buscar template
  const templates = await db.select('elicitation_templates', {
    'id': `eq.${session.template_id}`,
    'select': '*',
  });

  if (!templates || templates.length === 0) {
    throw new Error(`Template nao encontrado: ${session.template_id}`);
  }

  const template = templates[0];
  const sections = template.sections || [];
  let sectionIdx = session.current_section || 0;
  let questionIdx = session.current_question || 0;

  // Calcular total de perguntas
  let totalQuestions = 0;
  for (const s of sections) {
    totalQuestions += (s.questions || []).length;
  }

  // Get current question
  const currentSection = sections[sectionIdx];
  const currentQuestions = currentSection ? (currentSection.questions || []) : [];
  const currentQuestion = currentQuestions[questionIdx] || { text: '', type: 'text' };

  // Track follow-ups per question
  const followups = session.followups || {};
  const followupKey = `${sectionIdx}_${questionIdx}`;
  const followupCount = followups[followupKey] || 0;

  // --- LLM Extraction (Story 4.4) ---
  let extractionResult;
  let extractionMethod = 'basic';
  let confidence = null;

  try {
    extractionResult = await extractData(currentQuestion, userMessage, currentQuestion.type || 'text', agentName);

    if (extractionResult.fallback) {
      // LLM unavailable — basic extraction
      extractionMethod = 'basic';
    } else if (extractionResult.extracted) {
      // High confidence
      extractionMethod = 'llm';
      confidence = extractionResult.confidence;
    } else if (followupCount >= MAX_FOLLOWUPS) {
      // Max follow-ups reached — accept as best_effort
      extractionMethod = 'best_effort';
      confidence = extractionResult.confidence;
    } else {
      // Low confidence — send follow-up
      followups[followupKey] = followupCount + 1;

      await db.update('elicitation_sessions',
        { 'id': `eq.${sessionId}` },
        { followups, updated_at: new Date().toISOString() }
      );

      const answered = countAnswered(session.responses || {});
      return {
        session_id: sessionId,
        status: 'in_progress',
        next_question: {
          text: extractionResult.followUp,
          type: currentQuestion.type || 'text',
          required: currentQuestion.required !== false,
          hints: currentQuestion.hints || null,
          is_followup: true,
        },
        progress_percent: totalQuestions > 0 ? Math.round((answered / totalQuestions) * 100) : 0,
        questions_answered: answered,
        questions_total: totalQuestions,
      };
    }
  } catch {
    // Fallback to basic on any error
    extractionMethod = 'basic';
  }

  // Salvar resposta
  const responses = session.responses || {};
  if (!responses[sectionIdx]) responses[sectionIdx] = {};

  const extractedValue = (extractionMethod === 'llm' || extractionMethod === 'best_effort')
    && extractionResult && extractionResult.value !== undefined
    ? extractionResult.value
    : db.sanitize(String(userMessage));

  responses[sectionIdx][questionIdx] = {
    value: extractedValue,
    raw_message: db.sanitize(String(userMessage)),
    extraction_method: extractionMethod,
    confidence: confidence,
    extracted_at: new Date().toISOString(),
  };

  // Avancar para proxima pergunta
  questionIdx++;
  if (questionIdx >= currentQuestions.length) {
    sectionIdx++;
    questionIdx = 0;
  }

  // Verificar se terminou
  let status = 'in_progress';
  let nextQuestion = null;

  if (sectionIdx >= sections.length) {
    status = 'completed';
  } else {
    const nextSection = sections[sectionIdx];
    const nextQuestions = nextSection ? (nextSection.questions || []) : [];
    if (questionIdx < nextQuestions.length) {
      const q = nextQuestions[questionIdx];
      nextQuestion = {
        text: q.text,
        type: q.type || 'text',
        required: q.required !== false,
        hints: q.hints || null,
      };
    } else {
      status = 'completed';
    }
  }

  // Atualizar sessao
  await db.update('elicitation_sessions',
    { 'id': `eq.${sessionId}` },
    {
      status,
      current_section: sectionIdx,
      current_question: questionIdx,
      responses,
      followups,
      updated_at: new Date().toISOString(),
    }
  );

  const answered = countAnswered(responses);

  return {
    session_id: sessionId,
    status,
    next_question: nextQuestion,
    progress_percent: totalQuestions > 0 ? Math.round((answered / totalQuestions) * 100) : 0,
    questions_answered: answered,
    questions_total: totalQuestions,
  };
}

function countAnswered(responses) {
  if (!responses || typeof responses !== 'object') return 0;
  let count = 0;
  for (const section of Object.values(responses)) {
    if (section && typeof section === 'object') {
      count += Object.keys(section).length;
    }
  }
  return count;
}

module.exports = processMessage;
JSEOF

# --- tools/get-status.js ---
cat > "${ELICIT_DIR}/tools/get-status.js" << 'JSEOF'
// Tool: get_status — Retorna progresso da sessao
// Generated by Legendsclaw Deployer (Story 4.2)

'use strict';

const db = require('../lib/supabase-client');

async function getStatus(sessionId) {
  if (!sessionId) throw new Error('session_id e obrigatorio');

  // Buscar sessao
  const sessions = await db.select('elicitation_sessions', {
    'id': `eq.${sessionId}`,
    'select': '*',
  });

  if (!sessions || sessions.length === 0) {
    throw new Error(`Sessao nao encontrada: ${sessionId}`);
  }

  const session = sessions[0];

  // Buscar template
  const templates = await db.select('elicitation_templates', {
    'id': `eq.${session.template_id}`,
    'select': '*',
  });

  const template = (templates && templates.length > 0) ? templates[0] : null;
  const sections = template ? (template.sections || []) : [];

  // Calcular progresso por secao
  const responses = session.responses || {};
  let totalQuestions = 0;
  let totalAnswered = 0;

  const sectionStatus = sections.map((section, sIdx) => {
    const questions = section.questions || [];
    const sectionResponses = responses[sIdx] || {};
    const answered = Object.keys(sectionResponses).length;
    totalQuestions += questions.length;
    totalAnswered += answered;

    return {
      name: section.name || `Secao ${sIdx + 1}`,
      questions_answered: answered,
      questions_total: questions.length,
      fields: questions.map((q, qIdx) => {
        const resp = sectionResponses[qIdx];
        return {
          question: q.text,
          answered: !!resp,
          value_preview: resp ? String(resp.value || '').slice(0, 50) : null,
        };
      }),
    };
  });

  return {
    session_id: sessionId,
    template_id: session.template_id,
    status: session.status,
    progress_percent: totalQuestions > 0 ? Math.round((totalAnswered / totalQuestions) * 100) : 0,
    sections: sectionStatus,
    created_at: session.created_at,
    updated_at: session.updated_at,
  };
}

module.exports = getStatus;
JSEOF

# --- tools/export-results.js (Updated Story 4.4: Memory + Event Bus) ---
cat > "${ELICIT_DIR}/tools/export-results.js" << 'JSEOF'
// Tool: export_results — Exporta resultados estruturados + Memory + Event Bus
// Generated by Legendsclaw Deployer (Story 4.2, Updated Story 4.4)

'use strict';

const db = require('../lib/supabase-client');
const { writeMemoryFiles } = require('../lib/memory-writer');
const eventBus = require('../lib/event-bus');

async function exportResults(sessionId, format) {
  if (!sessionId) throw new Error('session_id e obrigatorio');

  // Buscar sessao
  const sessions = await db.select('elicitation_sessions', {
    'id': `eq.${sessionId}`,
    'select': '*',
  });

  if (!sessions || sessions.length === 0) {
    throw new Error(`Sessao nao encontrada: ${sessionId}`);
  }

  const session = sessions[0];
  const isPartial = session.status !== 'completed';

  // Buscar template
  const templates = await db.select('elicitation_templates', {
    'id': `eq.${session.template_id}`,
    'select': '*',
  });

  const template = (templates && templates.length > 0) ? templates[0] : null;
  const sections = template ? (template.sections || []) : [];
  const responses = session.responses || {};

  // Montar JSON estruturado
  const result = {
    session_id: sessionId,
    template_id: session.template_id,
    template_name: template ? (template.name || 'unknown') : 'unknown',
    completed_at: session.status === 'completed' ? session.updated_at : null,
    partial: isPartial,
    sections: sections.map((section, sIdx) => {
      const sectionResponses = responses[sIdx] || {};
      return {
        name: section.name || `Secao ${sIdx + 1}`,
        fields: (section.questions || []).map((q, qIdx) => {
          const resp = sectionResponses[qIdx];
          return {
            question: q.text,
            answer: resp ? resp.value : null,
            type: q.type || 'text',
          };
        }),
      };
    }),
  };

  if (isPartial) {
    result.warning = 'Sessao nao completa — export parcial';
  }

  // Salvar em elicitation_results
  try {
    await db.insert('elicitation_results', {
      session_id: sessionId,
      template_id: session.template_id,
      data: result,
      exported_at: new Date().toISOString(),
    });
  } catch (err) {
    result.export_warning = `Nao foi possivel salvar em elicitation_results: ${err.message}`;
  }

  // Write Memory files (Story 4.4)
  try {
    const memoryResult = await writeMemoryFiles(result);
    result.memory_files = memoryResult.memory_files;
    result.memory_path = memoryResult.memory_path;
  } catch (err) {
    result.memory_warning = `Nao foi possivel gravar Memory files: ${err.message}`;
  }

  // Emit event (Story 4.4)
  try {
    eventBus.emit('elicitation.session.completed', {
      session_id: sessionId,
      template_id: session.template_id,
      template_name: result.template_name,
      completed_at: result.completed_at || new Date().toISOString(),
      memory_path: result.memory_path || null,
      memory_files: result.memory_files || [],
    });
  } catch (err) {
    result.event_warning = `Evento nao emitido: ${err.message}`;
  }

  return result;
}

module.exports = exportResults;
JSEOF

# --- index.js (skill entry point) ---
cat > "${ELICIT_DIR}/index.js" << 'JSEOF'
// Skill: elicitation — Entrevistas estruturadas via templates
// Generated by Legendsclaw Deployer (Story 4.2)

'use strict';

const startSession = require('./tools/start-session');
const processMessage = require('./tools/process-message');
const getStatus = require('./tools/get-status');
const exportResults = require('./tools/export-results');
const db = require('./lib/supabase-client');

module.exports = {
  name: 'elicitation',
  description: 'Conduz entrevistas estruturadas via templates',
  tier: 'standard',

  tools: {
    start_session: startSession,
    process_message: processMessage,
    get_status: getStatus,
    export_results: exportResults,
  },

  handler: async (action, params) => {
    switch (action) {
      case 'start_session':
        return startSession(params.template_id);
      case 'process_message':
        return processMessage(params.session_id, params.user_message);
      case 'get_status':
        return getStatus(params.session_id);
      case 'export_results':
        return exportResults(params.session_id, params.format);
      default:
        throw new Error(`Acao desconhecida: ${action}. Acoes validas: start_session, process_message, get_status, export_results`);
    }
  },

  health: async () => {
    const connectivity = await db.ping();
    if (!connectivity.ok) {
      return { ok: false, error: connectivity.error, hint: 'Verifique SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY' };
    }
    const tables = await db.tablesExist();
    if (!tables.ok) {
      return {
        ok: true,
        warning: 'Supabase acessivel mas tabelas de elicitation nao encontradas — execute Story 4.3',
        connectivity: 'ok',
        tables: 'missing',
      };
    }
    return { ok: true, connectivity: 'ok', tables: 'ok' };
  },
};
JSEOF

step_ok "Arquivos da skill gerados (index.js, SKILL.md, tools/, lib/)"

# =============================================================================
# STEP 5b: CRIAR DIRETORIO MEMORY (Story 4.4)
# =============================================================================
MEMORY_DIR="$HOME/.clawd/memory/elicitation"
if [[ -d "$MEMORY_DIR" ]]; then
  step_skip "Diretorio Memory ja existe: ${MEMORY_DIR}"
else
  mkdir -p "$MEMORY_DIR"
  chmod 700 "$HOME/.clawd/memory"
  step_ok "Diretorio Memory criado: ${MEMORY_DIR}"
fi

# =============================================================================
# STEP 6: REGISTRAR NO SKILLS/INDEX.JS PRINCIPAL
# =============================================================================
INDEX_FILE="${SKILLS_DIR}/index.js"

if [[ -f "$INDEX_FILE" ]]; then
  # Verificar se ja registrada
  if grep -q "elicitation" "$INDEX_FILE" 2>/dev/null; then
    step_skip "elicitation ja registrada em index.js"
  else
    cp -p "$INDEX_FILE" "${INDEX_FILE}.bak"

    # Adicionar require no topo (apos ultimos requires)
    # Adicionar ao array skills
    {
      echo "// Skills Registry — Updated by Legendsclaw Deployer (Story 4.2)"
      echo "// Date: $(date '+%Y-%m-%d %H:%M:%S')"
      echo ""

      # Preservar requires existentes
      grep "^const " "${INDEX_FILE}.bak" 2>/dev/null || true
      echo "const elicitation = require('./elicitation');"
      echo ""

      # Preservar array existente e adicionar elicitation
      echo "const skills = ["
      # Extrair skills existentes do array
      sed -n '/^const skills = \[/,/^\];/p' "${INDEX_FILE}.bak" | grep -E '^\s+\w' | grep -v 'elicitation' || true
      echo "  elicitation,"
      echo "];"
      echo ""
      echo "module.exports = {"
      echo "  skills,"
      echo "  getSkill: (name) => skills.find((s) => s.name === name) || null,"
      echo "};"
    } > "$INDEX_FILE"

    step_ok "elicitation registrada em index.js (backup em .bak)"
  fi
else
  # Criar index.js do zero
  cat > "$INDEX_FILE" << 'JSEOF'
// Skills Registry
// Generated by Legendsclaw Deployer (Story 4.2)

const elicitation = require('./elicitation');

const skills = [
  elicitation,
];

module.exports = {
  skills,
  getSkill: (name) => skills.find((s) => s.name === name) || null,
};
JSEOF
  step_ok "index.js criado com elicitation"
fi

# =============================================================================
# STEP 7: HEALTH CHECK — CONECTIVIDADE SUPABASE
# =============================================================================
echo ""
echo "  Testando conectividade Supabase..."

# Ler SUPABASE_URL do .env se existir
OPENCLAW_DIR=$(grep "Install Path:" "$STATE_DIR/dados_openclaw" 2>/dev/null | awk -F': ' '{print $2}')
OPENCLAW_DIR="${OPENCLAW_DIR:-/opt/openclaw}"
ENV_FILE="${OPENCLAW_DIR}/.env"

supabase_url=""
supabase_key=""
if [[ -f "$ENV_FILE" ]]; then
  supabase_url=$(grep "^SUPABASE_URL=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2-)
  supabase_key=$(grep "^SUPABASE_SERVICE_ROLE_KEY=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2-)
fi

health_connectivity="UNKNOWN"
health_tables="UNKNOWN"

if [[ -z "$supabase_url" || -z "$supabase_key" ]]; then
  health_connectivity="FAIL"
  echo -e "    ${UI_YELLOW}SKIP${UI_NC} Supabase: SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY nao encontradas no .env"
  echo "    Hint: Execute Ferramenta [09] Skills com supabase-query para configurar"
else
  # Teste 1: Conectividade REST generica
  rest_response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -H "apikey: ${supabase_key}" \
    "${supabase_url}/rest/v1/" 2>/dev/null) || rest_response="000"

  if [[ "$rest_response" == "200" ]]; then
    health_connectivity="OK"
    echo -e "    ${UI_GREEN}OK${UI_NC} Supabase conectividade (HTTP ${rest_response})"

    # Teste 2: Verificar se tabelas de elicitation existem
    tables_response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
      -H "apikey: ${supabase_key}" \
      -H "Authorization: Bearer ${supabase_key}" \
      "${supabase_url}/rest/v1/elicitation_templates?select=id&limit=1" 2>/dev/null) || tables_response="000"

    if [[ "$tables_response" == "200" ]]; then
      health_tables="OK"
      echo -e "    ${UI_GREEN}OK${UI_NC} Tabelas elicitation encontradas"
    else
      health_tables="MISSING"
      echo -e "    ${UI_YELLOW}WARNING${UI_NC} Tabelas elicitation nao encontradas (HTTP ${tables_response})"
      echo "    Execute Story 4.3 para criar as tabelas"
    fi
  else
    health_connectivity="FAIL"
    echo -e "    ${UI_RED}FAIL${UI_NC} Supabase conectividade (HTTP ${rest_response})"
  fi
fi

step_ok "Health check concluido (conectividade: ${health_connectivity}, tabelas: ${health_tables})"

# =============================================================================
# STEP 8: SAVE STATE
# =============================================================================
mkdir -p "$STATE_DIR"

cat > "$STATE_DIR/dados_elicitation" << EOF
Agente: ${nome_agente}
Skill: elicitation
Tools: start_session, process_message, get_status, export_results
Supabase Conectividade: ${health_connectivity}
Supabase Tabelas: ${health_tables}
Health Check: ${health_connectivity}
Skill Path: ${ELICIT_DIR}
LLM Extraction: $(if [[ "$llm_extraction_enabled" == "true" ]]; then echo "habilitado"; else echo "desabilitado"; fi)
Memory Path: ~/.clawd/memory/elicitation/
Event Bus: ativo
Data Configuracao: $(date '+%Y-%m-%d %H:%M:%S')
EOF
chmod 600 "$STATE_DIR/dados_elicitation"

step_ok "Estado salvo em ~/dados_vps/dados_elicitation"

# =============================================================================
# STEP 9: RESUMO FINAL + HINTS
# =============================================================================
resumo_final

echo -e "${UI_BOLD}  Elicitation Skill — ${nome_agente}${UI_NC}"
echo ""
echo "  Agente:           ${nome_agente}"
echo "  Skill:            elicitation"
echo "  Tools:            start_session, process_message, get_status, export_results"
echo "  Conectividade:    ${health_connectivity}"
echo "  Tabelas:          ${health_tables}"
echo "  LLM Extraction:   $(if [[ "$llm_extraction_enabled" == "true" ]]; then echo "habilitado (tier standard)"; else echo "desabilitado (fallback regex)"; fi)"
echo "  Memory Path:      ~/.clawd/memory/elicitation/"
echo "  Event Bus:        ativo"
echo ""
echo "  Skill Path:       ${ELICIT_DIR}"
echo "  Index:            ${INDEX_FILE}"
echo "  Estado:           ~/dados_vps/dados_elicitation"
echo "  Log:              ${LOG_FILE}"
echo ""

hint_elicitation "${nome_agente}" "${health_tables}" "${llm_extraction_enabled}"

log_finish

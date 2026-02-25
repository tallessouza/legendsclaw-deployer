// LLM Router — 4-Tier Intelligent Routing Runtime
// See: docs/LLM-ROUTER.md for architecture overview

'use strict';

const fs = require('fs');
const path = require('path');

// --- State ---
let config = null;
let initialized = false;

// --- YAML Parser (minimal, handles the config format) ---
function parseYaml(content) {
  const result = {};
  const lines = content.split('\n');
  const stack = [{ indent: -1, obj: result }];

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    if (!raw.trim() || raw.trim().startsWith('#')) continue;

    const indent = raw.search(/\S/);
    const line = raw.trim();

    // Pop stack to find parent
    while (stack.length > 1 && stack[stack.length - 1].indent >= indent) {
      stack.pop();
    }
    const parent = stack[stack.length - 1].obj;

    // Inline array: key: [a, b, c]
    const inlineArrayMatch = line.match(/^(\w[\w-]*):\s*\[([^\]]*)\]$/);
    if (inlineArrayMatch) {
      const key = inlineArrayMatch[1];
      const items = inlineArrayMatch[2].split(',').map(s => {
        const v = s.trim().replace(/^["']|["']$/g, '');
        if (v === 'true') return true;
        if (v === 'false') return false;
        if (v === 'null') return null;
        if (/^-?\d+(\.\d+)?$/.test(v)) return Number(v);
        return v;
      });
      parent[key] = items;
      continue;
    }

    // Key: value
    const kvMatch = line.match(/^(\w[\w-]*):\s+(.+)$/);
    if (kvMatch) {
      const key = kvMatch[1];
      let val = kvMatch[2].replace(/^["']|["']$/g, '');
      if (val === 'true') val = true;
      else if (val === 'false') val = false;
      else if (val === 'null') val = null;
      else if (/^-?\d+(\.\d+)?$/.test(val)) val = Number(val);
      parent[key] = val;
      continue;
    }

    // Key: (nested object, value on next indented lines)
    const nestedMatch = line.match(/^(\w[\w-]*):$/);
    if (nestedMatch) {
      const key = nestedMatch[1];
      const child = {};
      parent[key] = child;
      stack.push({ indent, obj: child });
      continue;
    }

    // Array item: - value
    const arrayItem = line.match(/^-\s+(.+)$/);
    if (arrayItem) {
      if (!Array.isArray(parent)) {
        // Convert last key of grandparent to array
        const grandparent = stack.length > 1 ? stack[stack.length - 2].obj : null;
        if (grandparent) {
          const keys = Object.keys(grandparent);
          const lastKey = keys[keys.length - 1];
          if (!Array.isArray(grandparent[lastKey])) {
            grandparent[lastKey] = [];
            stack[stack.length - 1].obj = grandparent[lastKey];
          }
          grandparent[lastKey].push(arrayItem[1].replace(/^["']|["']$/g, ''));
        }
      } else {
        parent.push(arrayItem[1].replace(/^["']|["']$/g, ''));
      }
    }
  }

  return result;
}

// --- Init ---
function init(opts = {}) {
  const configPath = opts.configPath || 'config/llm-router-config.yaml';
  const resolved = path.isAbsolute(configPath) ? configPath : path.resolve(configPath);

  if (!fs.existsSync(resolved)) {
    throw new Error(`LLM Router config not found: ${resolved}`);
  }

  const content = fs.readFileSync(resolved, 'utf8');
  config = parseYaml(content);
  initialized = true;

  return config;
}

// --- Tier Classification ---
function classifyTier(request) {
  // 1. Explicit tier
  if (request.tier && config.tiers && config.tiers[request.tier]) {
    return request.tier;
  }

  // 2. Skill mapping
  if (request.skill && config.skill_mapping && config.skill_mapping[request.skill]) {
    return config.skill_mapping[request.skill];
  }

  // 3. Keyword analysis
  if (request.messages && request.messages.length > 0 && config.keywords) {
    const text = request.messages
      .map(m => (typeof m.content === 'string' ? m.content : ''))
      .join(' ')
      .toLowerCase();

    const tier = analyzeKeywords(text);
    if (tier) return tier;
  }

  // 4. Default
  return (config.defaults && config.defaults.tier) || 'standard';
}

function analyzeKeywords(text) {
  if (!config.keywords) return null;

  let bestTier = null;
  let bestScore = 0;

  const tierOrder = ['budget', 'standard', 'quality', 'premium'];

  for (const tier of tierOrder) {
    const kw = config.keywords[tier];
    if (!kw || !kw.words) continue;

    const words = Array.isArray(kw.words) ? kw.words : [];
    const weight = typeof kw.weight === 'number' ? kw.weight : 0.5;

    let matches = 0;
    for (const word of words) {
      if (text.includes(word.toLowerCase())) matches++;
    }

    const score = matches * weight;
    if (score > bestScore) {
      bestScore = score;
      bestTier = tier;
    }
  }

  return bestTier;
}

// --- Model Selection ---
function selectModel(tier) {
  if (!config.tiers || !config.tiers[tier]) {
    throw new Error(`Tier desconhecido: ${tier}`);
  }

  const tierConfig = config.tiers[tier];
  const modelNames = tierConfig.models || [];

  // Filter enabled models, sort by priority (lower = higher priority)
  const candidates = modelNames
    .map(name => {
      const model = config.models && config.models[name];
      if (!model) return null;
      return { name, ...model };
    })
    .filter(m => m && m.enabled !== false)
    .sort((a, b) => (a.priority || 99) - (b.priority || 99));

  if (candidates.length === 0) {
    return null;
  }

  return candidates;
}

// --- API Execution ---
async function execute(model, request) {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    throw new Error('OPENROUTER_API_KEY nao configurada');
  }

  const timeout = (request.timeout_ms || (config.defaults && config.defaults.timeout_ms) || 30000);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);

  try {
    const body = {
      model: model.id,
      messages: request.messages,
      max_tokens: request.maxTokens || 1024,
      temperature: request.temperature != null ? request.temperature : 0.7,
    };

    if (request.responseFormat === 'json') {
      body.response_format = { type: 'json_object' };
    }

    const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://legendsclaw.com',
        'X-Title': 'Legendsclaw LLM Router',
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    if (!res.ok) {
      const text = await res.text();
      const error = new Error(`OpenRouter ${res.status}: ${text}`);
      error.status = res.status;
      error.type = classifyError(res.status, text);
      throw error;
    }

    const data = await res.json();
    const content = data.choices && data.choices[0] && data.choices[0].message
      ? data.choices[0].message.content
      : null;

    return {
      content,
      model: model.id,
      usage: data.usage || null,
    };
  } finally {
    clearTimeout(timer);
  }
}

async function executeAnthropicDirect(request) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    throw new Error('ANTHROPIC_API_KEY nao configurada para fallback direto');
  }

  const timeout = (config.fallback && config.fallback.timeout_ms) || 30000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);

  try {
    const body = {
      model: 'claude-sonnet-4-20250514',
      max_tokens: request.maxTokens || 1024,
      messages: request.messages,
    };

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'content-type': 'application/json',
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    if (!res.ok) {
      const text = await res.text();
      throw new Error(`Anthropic Direct ${res.status}: ${text}`);
    }

    const data = await res.json();
    const content = data.content && data.content[0] ? data.content[0].text : null;

    return {
      content,
      model: 'anthropic-direct/claude-sonnet-4',
      usage: data.usage || null,
    };
  } finally {
    clearTimeout(timer);
  }
}

// --- Error Classification ---
function classifyError(status, body) {
  if (status === 429) return 'rate_limit';
  if (status === 408 || (body && body.includes('timeout'))) return 'timeout';
  if (status >= 500) return 'server_error';
  if (status === 400 && body && body.includes('context_length')) return 'context_length';
  if (status === 400) return 'invalid_request';
  return 'unknown';
}

// --- Error Handling & Retry ---
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function getRetryDelay(attempt) {
  // Exponential backoff: 1s, 2s, 4s...
  return Math.min(1000 * Math.pow(2, attempt), 8000);
}

// --- Main Route Function ---
async function route(request) {
  if (!initialized) {
    throw new Error('LLM Router nao inicializado. Chame init() primeiro.');
  }

  const tier = classifyTier(request);
  const fallbackConfig = config.fallback || {};
  const maxTotalRetries = fallbackConfig.max_total_retries || 5;
  const maxRetriesPerModel = fallbackConfig.max_retries_per_model || 2;
  const tierEscalation = fallbackConfig.tier_escalation !== false;

  let currentTier = tier;
  let totalRetries = 0;
  const errors = [];

  while (currentTier && totalRetries < maxTotalRetries) {
    const models = selectModel(currentTier);

    if (!models || models.length === 0) {
      // No models available in this tier, escalate
      if (tierEscalation && config.tiers[currentTier]) {
        currentTier = config.tiers[currentTier].fallback_tier;
        continue;
      }
      break;
    }

    for (const model of models) {
      let modelRetries = 0;

      while (modelRetries < maxRetriesPerModel && totalRetries < maxTotalRetries) {
        try {
          const result = await execute(model, request);
          result.tier = currentTier;
          result.routedFrom = tier;
          return result;
        } catch (err) {
          totalRetries++;
          modelRetries++;
          errors.push({ model: model.id, error: err.message, type: err.type });

          const errorType = err.type || 'unknown';
          const strategy = (fallbackConfig.on_error && fallbackConfig.on_error[errorType]) || 'try_next_model';

          if (strategy === 'exponential_backoff' && modelRetries < maxRetriesPerModel) {
            await sleep(getRetryDelay(modelRetries - 1));
            continue; // Retry same model
          }

          // try_next_model or try_faster_model → break to next model
          break;
        }
      }
    }

    // All models in tier failed, escalate
    if (tierEscalation && config.tiers[currentTier]) {
      currentTier = config.tiers[currentTier].fallback_tier;
    } else {
      break;
    }
  }

  // Final fallback: Anthropic Direct API
  if (fallbackConfig.anthropic_direct_fallback && process.env.ANTHROPIC_API_KEY) {
    try {
      const result = await executeAnthropicDirect(request);
      result.tier = 'anthropic-direct';
      result.routedFrom = tier;
      return result;
    } catch (err) {
      errors.push({ model: 'anthropic-direct', error: err.message });
    }
  }

  // All retries exhausted
  const error = new Error(
    `LLM Router: todos os modelos falharam apos ${totalRetries} tentativas. ` +
    `Tier inicial: ${tier}. Erros: ${errors.map(e => `${e.model}(${e.error})`).join(', ')}`
  );
  error.errors = errors;
  error.tier = tier;
  throw error;
}

module.exports = { init, route, classifyTier, analyzeKeywords, selectModel };

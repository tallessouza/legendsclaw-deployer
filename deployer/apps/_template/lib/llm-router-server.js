#!/usr/bin/env node
// LLM Router HTTP Server — OpenAI-compatible API
// Exposes llm-router.js as HTTP service for external consumers
// Port: LLM_ROUTER_PORT env or 55119

'use strict';

const http = require('http');
const router = require('./llm-router');

const PORT = parseInt(process.env.LLM_ROUTER_PORT, 10) || 55119;
const CONFIG_PATH = process.env.LLM_ROUTER_CONFIG_PATH || 'config/llm-router-config.yaml';

// --- Init router ---
let routerConfig;
try {
  routerConfig = router.init({ configPath: CONFIG_PATH });
  console.log(`[llm-router-server] Router initialized (config: ${CONFIG_PATH})`);
} catch (err) {
  console.error(`[llm-router-server] Failed to init router: ${err.message}`);
  process.exit(1);
}

// --- Helpers ---
function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString()));
    req.on('error', reject);
  });
}

function json(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body)
  });
  res.end(body);
}

// --- Build model list from config ---
function getModelList() {
  if (!routerConfig || !routerConfig.models) return [];
  return Object.entries(routerConfig.models).map(([name, m]) => ({
    id: m.id || name,
    object: 'model',
    owned_by: 'llm-router',
    permission: [],
    _tier: m.tier,
    _enabled: m.enabled !== false
  }));
}

// --- Request handler ---
const server = http.createServer(async (req, res) => {
  const url = req.url.split('?')[0];
  const method = req.method;

  // CORS preflight
  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    });
    return res.end();
  }

  // GET /health
  if (method === 'GET' && url === '/health') {
    return json(res, 200, { status: 'ok', port: PORT });
  }

  // GET /v1/models
  if (method === 'GET' && url === '/v1/models') {
    return json(res, 200, { object: 'list', data: getModelList() });
  }

  // POST /v1/chat/completions
  if (method === 'POST' && url === '/v1/chat/completions') {
    let body;
    try {
      const raw = await readBody(req);
      body = JSON.parse(raw);
    } catch (err) {
      return json(res, 400, { error: { message: 'Invalid JSON body', type: 'invalid_request_error' } });
    }

    const routeRequest = {
      messages: body.messages || [],
      tier: body.tier || undefined,
      skill: body.skill || undefined,
      max_tokens: body.max_tokens,
      temperature: body.temperature,
      stream: body.stream || false
    };

    // Extract tier hint from model field (e.g. "router-budget", "router-auto")
    if (body.model && body.model.startsWith('router-')) {
      const tierHint = body.model.replace('router-', '');
      if (tierHint !== 'auto') {
        routeRequest.tier = tierHint;
      }
    }

    try {
      const result = await router.route(routeRequest);
      return json(res, 200, result);
    } catch (err) {
      const status = err.type === 'rate_limit' ? 429 : 502;
      return json(res, status, {
        error: {
          message: err.message,
          type: err.type || 'router_error',
          tier: err.tier,
          errors: err.errors
        }
      });
    }
  }

  // 404
  json(res, 404, { error: { message: 'Not found', type: 'invalid_request_error' } });
});

server.listen(PORT, () => {
  console.log(`[llm-router-server] Listening on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[llm-router-server] SIGTERM received, shutting down...');
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  console.log('[llm-router-server] SIGINT received, shutting down...');
  server.close(() => process.exit(0));
});

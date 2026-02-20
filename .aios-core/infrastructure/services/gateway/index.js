'use strict';

// =============================================================================
// Legendsclaw Bridge Service — OpenClaw Gateway Health Check
// Story 5.3: Bridge Integration
//
// This is the default gateway service. The deployer (13-bridge.sh) creates
// an agent-specific copy with the correct GATEWAY_URL from dados_openclaw.
// =============================================================================

const http = require('http');
const https = require('https');

const GATEWAY_URL = process.env.OPENCLAW_GATEWAY_URL
  || process.env.AGENT_GATEWAY_URL
  || 'http://localhost:18789';

const DEGRADED_THRESHOLD_MS = 2000;

module.exports = {
  name: 'openclaw-gateway',
  description: 'OpenClaw Gateway health via Tailscale',

  health: async () => {
    const url = new URL(GATEWAY_URL + '/health');
    const mod = url.protocol === 'https:' ? https : http;

    const start = Date.now();

    return new Promise((resolve) => {
      const req = mod.get(url, { timeout: 5000 }, (res) => {
        const latency_ms = Date.now() - start;
        let body = '';
        res.on('data', (chunk) => { body += chunk; });
        res.on('end', () => {
          if (res.statusCode === 200) {
            const status = latency_ms > DEGRADED_THRESHOLD_MS ? 'degraded' : 'ok';
            resolve({ status, latency_ms, details: body.slice(0, 100) });
          } else {
            resolve({ status: 'down', latency_ms, details: `HTTP ${res.statusCode}` });
          }
        });
      });

      req.on('error', (err) => {
        const latency_ms = Date.now() - start;
        resolve({ status: 'down', latency_ms, error: err.message });
      });

      req.on('timeout', () => {
        req.destroy();
        const latency_ms = Date.now() - start;
        resolve({ status: 'down', latency_ms, error: 'timeout' });
      });
    });
  },
};

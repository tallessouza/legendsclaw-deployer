#!/usr/bin/env node
'use strict';

// =============================================================================
// Legendsclaw Bridge.js — Auto-Discovery Service Manager
// Story 5.3: Claude Code Integration
// =============================================================================

const fs = require('fs');
const path = require('path');

const SERVICES_DIR = path.dirname(__filename);
const BLOCKLIST_GLOB = 'apps/*/skills/lib/blocklist.yaml';
const AUDIT_LOG = '/var/log/legendsclaw/bridge-audit.log';

// =============================================================================
// AUTO-DISCOVERY
// =============================================================================

function discoverServices() {
  const services = [];
  const entries = fs.readdirSync(SERVICES_DIR, { withFileTypes: true });

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;

    const indexPath = path.join(SERVICES_DIR, entry.name, 'index.js');
    if (!fs.existsSync(indexPath)) continue;

    try {
      const svc = require(indexPath);
      if (svc.name && svc.health) {
        services.push({
          name: svc.name,
          description: svc.description || '',
          health: svc.health,
          dir: entry.name,
        });
      }
    } catch (err) {
      services.push({
        name: entry.name,
        description: `Error loading: ${err.message}`,
        health: async () => ({ status: 'down', error: err.message }),
        dir: entry.name,
      });
    }
  }

  return services;
}

// =============================================================================
// COMMANDS
// =============================================================================

async function cmdStatus() {
  const services = discoverServices();

  if (services.length === 0) {
    console.log('[Bridge] No services discovered.');
    return;
  }

  console.log('');
  console.log('==============================================');
  console.log('  BRIDGE STATUS');
  console.log('==============================================');
  console.log('');

  const pad = (s, n) => String(s).padEnd(n);

  console.log(`  ${pad('Service', 20)} ${pad('Status', 14)} ${pad('Latency', 10)} Details`);
  console.log(`  ${pad('-------', 20)} ${pad('------', 14)} ${pad('-------', 10)} -------`);

  for (const svc of services) {
    const start = Date.now();
    let result;
    try {
      result = await Promise.race([
        svc.health(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 5000)),
      ]);
    } catch (err) {
      result = { status: 'down', error: err.message };
    }
    const latency = Date.now() - start;

    const status = result.status || (result.ok ? 'ok' : 'down');
    const statusLabel = status === 'ok' ? '\x1b[32mOK\x1b[0m'
      : status === 'degraded' ? '\x1b[33mDEGRADED\x1b[0m'
      : '\x1b[31mFAIL\x1b[0m';

    const details = result.error || result.details || '';
    console.log(`  ${pad(svc.name, 20)} ${pad(statusLabel, 23)} ${pad(latency + 'ms', 10)} ${details}`);
  }

  console.log('');
  console.log('==============================================');
  console.log('');
}

async function cmdList() {
  const services = discoverServices();

  if (services.length === 0) {
    console.log('[Bridge] No services discovered.');
    return;
  }

  console.log('');
  console.log('==============================================');
  console.log('  BRIDGE SERVICES');
  console.log('==============================================');
  console.log('');

  const pad = (s, n) => String(s).padEnd(n);

  console.log(`  ${pad('Service', 20)} ${pad('Description', 50)}`);
  console.log(`  ${pad('-------', 20)} ${pad('-----------', 50)}`);

  for (const svc of services) {
    console.log(`  ${pad(svc.name, 20)} ${pad(svc.description, 50)}`);
  }

  console.log('');
  console.log(`  Total: ${services.length} service(s)`);
  console.log('');
  console.log('==============================================');
  console.log('');
}

function cmdValidateCall() {
  // Find blocklist — try each agent dir
  const projectRoot = path.resolve(SERVICES_DIR, '..', '..', '..');
  const appsDir = path.join(projectRoot, 'apps');
  let blocklistPath = null;

  if (fs.existsSync(appsDir)) {
    const agents = fs.readdirSync(appsDir, { withFileTypes: true });
    for (const agent of agents) {
      if (!agent.isDirectory()) continue;
      const candidate = path.join(appsDir, agent.name, 'skills', 'lib', 'blocklist.yaml');
      if (fs.existsSync(candidate)) {
        blocklistPath = candidate;
        break;
      }
    }
  }

  if (!blocklistPath) {
    // Story 5.2 not implemented — skip gracefully
    return;
  }

  // Simple regex-based blocklist check
  try {
    const content = fs.readFileSync(blocklistPath, 'utf8');
    const patterns = [];

    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (trimmed.startsWith('-') && trimmed.includes('pattern:')) {
        const match = trimmed.match(/pattern:\s*['"]?(.+?)['"]?\s*$/);
        if (match) patterns.push(new RegExp(match[1], 'i'));
      } else if (trimmed.startsWith('- ') && !trimmed.includes(':')) {
        const pat = trimmed.substring(2).trim().replace(/^['"]|['"]$/g, '');
        if (pat) patterns.push(new RegExp(pat, 'i'));
      }
    }

    // Read command from stdin or args
    const command = process.argv.slice(3).join(' ') || '';
    if (!command) return;

    for (const pattern of patterns) {
      if (pattern.test(command)) {
        console.error(`[Bridge] BLOCKED: Command matches blocklist pattern: ${pattern}`);
        process.exit(1);
      }
    }
  } catch (err) {
    // Blocklist read error — don't block execution
    console.error(`[Bridge] Warning: Could not read blocklist: ${err.message}`);
  }
}

function cmdLogExecution() {
  const command = process.argv.slice(3).join(' ') || 'unknown';
  const timestamp = new Date().toISOString();
  const entry = `${timestamp} | ${process.env.USER || 'unknown'} | ${command}\n`;

  try {
    const logDir = path.dirname(AUDIT_LOG);
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }
    fs.appendFileSync(AUDIT_LOG, entry);
  } catch (err) {
    // Audit log write failure — don't block execution
    // May not have permission to write to /var/log/legendsclaw/
    // Fallback: write to home dir
    try {
      const fallbackLog = path.join(
        process.env.HOME || '/tmp',
        'legendsclaw-logs',
        'bridge-audit.log'
      );
      const fallbackDir = path.dirname(fallbackLog);
      if (!fs.existsSync(fallbackDir)) {
        fs.mkdirSync(fallbackDir, { recursive: true });
      }
      fs.appendFileSync(fallbackLog, entry);
    } catch (_) {
      // Silent fail — audit is best-effort
    }
  }
}

// =============================================================================
// MAIN
// =============================================================================

async function main() {
  const command = process.argv[2];

  switch (command) {
    case 'status':
      await cmdStatus();
      break;
    case 'list':
      await cmdList();
      break;
    case 'validate-call':
      cmdValidateCall();
      break;
    case 'log-execution':
      cmdLogExecution();
      break;
    default:
      console.log('Usage: bridge.js <command>');
      console.log('');
      console.log('Commands:');
      console.log('  status         Show health of all discovered services');
      console.log('  list           List all discovered services');
      console.log('  validate-call  Validate a bash command against blocklist');
      console.log('  log-execution  Log a bash command execution to audit trail');
      process.exit(1);
  }
}

main().catch((err) => {
  console.error(`[Bridge] Error: ${err.message}`);
  process.exit(1);
});

#!/usr/bin/env node

/**
 * @module bridge
 * @description Service Bridge — Auto-discovery registry and CLI for infrastructure services.
 * Provides unified interface to discover, validate, and interact with services.
 */

const fs = require('fs');
const path = require('path');

const SERVICES_DIR = process.env.SERVICES_DIR || __dirname;
const LOG_DIR = path.join(SERVICES_DIR, '.bridge-logs');

/**
 * Discover services by scanning subdirectories for index.js
 */
function discoverServices() {
  const entries = fs.readdirSync(SERVICES_DIR, { withFileTypes: true });
  const services = [];

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;

    const indexPath = path.join(SERVICES_DIR, entry.name, 'index.js');
    if (!fs.existsSync(indexPath)) continue;

    let hasHealthCheck = false;
    try {
      const content = fs.readFileSync(indexPath, 'utf-8');
      hasHealthCheck = content.includes('healthCheck') || content.includes('health_check');
    } catch {
      // ignore read errors
    }

    services.push({
      name: entry.name,
      path: path.join(SERVICES_DIR, entry.name),
      hasHealthCheck,
    });
  }

  return services;
}

function getStatus() {
  const services = discoverServices();
  return {
    bridge_version: '1.0.0',
    services_dir: SERVICES_DIR,
    discovered_at: new Date().toISOString(),
    total: services.length,
    services: services.map(s => ({
      name: s.name,
      path: s.path,
      has_health_check: s.hasHealthCheck,
    })),
  };
}

async function healthCheck(serviceName) {
  const services = discoverServices();
  const service = services.find(s => s.name === serviceName);

  if (!service) {
    return {
      service: serviceName,
      status: 'not_found',
      error: `Service '${serviceName}' not found. Available: ${services.map(s => s.name).join(', ')}`,
      timestamp: new Date().toISOString(),
    };
  }

  if (!service.hasHealthCheck) {
    return {
      service: serviceName,
      status: 'no_health_check',
      message: `Service '${serviceName}' exists but has no healthCheck method.`,
      path: service.path,
      timestamp: new Date().toISOString(),
    };
  }

  try {
    const svc = require(path.join(service.path, 'index.js'));
    const healthFn = svc.healthCheck || svc.health_check;
    if (typeof healthFn === 'function') {
      const result = await healthFn.call(svc);
      return { service: serviceName, status: 'healthy', result, timestamp: new Date().toISOString() };
    }
    return { service: serviceName, status: 'no_health_check', message: 'Not a function.', timestamp: new Date().toISOString() };
  } catch (error) {
    return { service: serviceName, status: 'unhealthy', error: error.message, timestamp: new Date().toISOString() };
  }
}

function listServices() {
  return discoverServices().map(s => s.name);
}

function validateCall(input) {
  const knownServices = listServices();
  const normalizedInput = input.replace(/\\/g, '/');

  if (!normalizedInput.includes('infrastructure/services/')) {
    return { valid: true, is_service_call: false };
  }

  const match = normalizedInput.match(/infrastructure\/services\/([^/\s]+)/);
  if (!match) return { valid: true, is_service_call: false };

  const serviceName = match[1];
  if (serviceName === 'bridge.js') return { valid: true, is_service_call: true, service: 'bridge' };
  if (knownServices.includes(serviceName)) return { valid: true, is_service_call: true, service: serviceName };

  return {
    valid: false, is_service_call: true, service: serviceName,
    error: `Service '${serviceName}' not found. Available: ${knownServices.join(', ')}`,
  };
}

function logExecution(input) {
  try {
    if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
    const logEntry = { timestamp: new Date().toISOString(), input: input.trim().substring(0, 500) };
    const today = new Date().toISOString().split('T')[0];
    const logFile = path.join(LOG_DIR, `${today}.jsonl`);
    fs.appendFileSync(logFile, JSON.stringify(logEntry) + '\n');
    return { logged: true, file: logFile };
  } catch (error) {
    return { logged: false, error: error.message };
  }
}

function readStdin() {
  return new Promise((resolve) => {
    if (process.stdin.isTTY) { resolve(''); return; }
    let data = '';
    process.stdin.setEncoding('utf-8');
    process.stdin.on('data', chunk => { data += chunk; });
    process.stdin.on('end', () => resolve(data));
    setTimeout(() => resolve(data), 2000);
  });
}

async function main() {
  const [command, ...args] = process.argv.slice(2);

  switch (command) {
    case 'status':
      console.log(JSON.stringify(getStatus(), null, 2));
      break;
    case 'health': {
      const name = args[0];
      if (!name) { console.error('Usage: bridge.js health <service-name>'); process.exit(1); }
      const result = await healthCheck(name);
      console.log(JSON.stringify(result, null, 2));
      process.exit(result.status === 'healthy' ? 0 : 1);
      break;
    }
    case 'list':
      console.log(JSON.stringify(listServices()));
      break;
    case 'validate-call': {
      const input = await readStdin();
      if (!input.trim()) { console.log(JSON.stringify({ valid: true, is_service_call: false, note: 'No input' })); break; }
      const result = validateCall(input);
      console.log(JSON.stringify(result));
      if (!result.valid) process.exit(1);
      break;
    }
    case 'log-execution': {
      const input = await readStdin();
      if (!input.trim()) { console.log(JSON.stringify({ logged: false, note: 'No input' })); break; }
      console.log(JSON.stringify(logExecution(input)));
      break;
    }
    default:
      console.log(`
Service Bridge — Infrastructure Services Registry

Usage: node bridge.js <command> [args]

Commands:
  status              Show all registered services (JSON)
  health <name>       Health check for a specific service
  list                List service names (JSON array)
  validate-call       Validate Bash command references known service (stdin)
  log-execution       Log service execution for audit (stdin)
  help                Show this help
      `.trim());
      break;
  }
}

if (require.main === module) {
  main().catch(error => { console.error('Bridge error:', error.message); process.exit(1); });
}

module.exports = { discoverServices, getStatus, healthCheck, listServices, validateCall, logExecution };

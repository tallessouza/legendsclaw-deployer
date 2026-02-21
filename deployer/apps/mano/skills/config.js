// Mano — Skills Configuration
// Updated by Legendsclaw Deployer (Story 4.1)
// Date: 2026-02-21 04:25:25
//
// Credentials loaded from environment variables

module.exports = {
  // Agent Identity
  AGENT_NAME: 'mano',
  DISPLAY_NAME: 'Mano',
  ICON: '🤖',
  LANGUAGE: 'pt-BR',

  // Memory
  MEMORY_BASE_PATH: process.env.MEMORY_PATH || '~/.mano/',

  // Services
  SERVICES: {
    API: process.env.API_URL,
    N8N: process.env.N8N_URL,
    WORKER: process.env.WORKER_URL,
  },

  // WhatsApp
  WHATSAPP_JID: process.env.WHATSAPP_JID,
};

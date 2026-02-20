-- =============================================================================
-- Legendsclaw — Seed 001: Template "onboarding-founder"
-- Story 4.3: Skill Elicitation — Templates e Schema Supabase
-- Transacional, Idempotente (ON CONFLICT DO UPDATE)
-- =============================================================================

BEGIN;

-- UUID fixo para idempotencia (re-execucao segura)
INSERT INTO elicitation_templates (id, name, description, sections, version, active)
VALUES (
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::UUID,
  'onboarding-founder',
  'Entrevista de onboarding para fundadores — coleta dados do fundador, empresa e stack tecnico',
  '[
    {
      "name": "Founder & Story",
      "questions": [
        {
          "text": "Qual e o seu nome completo?",
          "type": "text",
          "required": true,
          "hints": "Nome do fundador principal"
        },
        {
          "text": "Qual e o nome da sua empresa ou projeto?",
          "type": "text",
          "required": true,
          "hints": "Nome oficial ou nome fantasia"
        },
        {
          "text": "O que te motivou a criar este projeto?",
          "type": "text",
          "required": true,
          "hints": "Historia de origem — o problema que encontrou ou a oportunidade que viu"
        },
        {
          "text": "Qual e a sua visao para o projeto em 1-2 anos?",
          "type": "text",
          "required": true,
          "hints": "Objetivo de medio prazo — onde quer chegar"
        },
        {
          "text": "Voce tem co-fundadores ou socios?",
          "type": "select",
          "required": false,
          "hints": "Sim / Nao / Em busca — ajuda a entender a estrutura da equipe"
        }
      ]
    },
    {
      "name": "Empresa & Tecnico",
      "questions": [
        {
          "text": "Em que estagio esta o projeto? (ideia, MVP, produto, escala)",
          "type": "select",
          "required": true,
          "hints": "Estagio atual — determina complexidade e prioridades"
        },
        {
          "text": "Qual e o publico-alvo principal?",
          "type": "text",
          "required": true,
          "hints": "Quem sao os usuarios finais — perfil demografico ou profissional"
        },
        {
          "text": "Quais tecnologias voce ja usa ou prefere? (ex: React, Node.js, Python)",
          "type": "text",
          "required": true,
          "hints": "Stack tecnico atual ou desejado"
        },
        {
          "text": "Voce ja tem infraestrutura de hospedagem? (VPS, cloud, nenhuma)",
          "type": "select",
          "required": true,
          "hints": "AWS, Hetzner, Vercel, VPS propria, nenhuma"
        },
        {
          "text": "Qual e o maior desafio tecnico que voce enfrenta agora?",
          "type": "text",
          "required": false,
          "hints": "Dor principal — ajuda a priorizar as primeiras acoes do agente"
        }
      ]
    }
  ]'::JSONB,
  1,
  true
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  sections = EXCLUDED.sections,
  version = EXCLUDED.version,
  active = EXCLUDED.active,
  updated_at = NOW();

-- Post-seed verification
DO $$
BEGIN
  ASSERT (
    SELECT COUNT(*) FROM elicitation_templates WHERE name = 'onboarding-founder'
  ) = 1, 'Seed verification failed: onboarding-founder template not found';
END;
$$;

COMMIT;

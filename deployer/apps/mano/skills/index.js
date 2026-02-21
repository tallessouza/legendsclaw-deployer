// Skills Registry — Updated by Legendsclaw Deployer (Story 4.2)
// Date: 2026-02-21 04:26:14

const memory = require('./memory');
const skills = [
const elicitation = require('./elicitation');

const skills = [
  memory,
  elicitation,
];

module.exports = {
  skills,
  getSkill: (name) => skills.find((s) => s.name === name) || null,
};

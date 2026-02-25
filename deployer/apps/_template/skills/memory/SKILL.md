# memory

## Description
Context persistence — local filesystem memory

## Environment Variables
None (uses ~/.clawd/memory/)

## LLM Tier
budget

## Usage
```javascript
const skill = require('./memory');
const result = await skill.handler({ /* input */ });
const health = await skill.health();
```

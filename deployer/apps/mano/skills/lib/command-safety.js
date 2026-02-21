// TODO: Implement command safety validation
// See: docs/architecture/legendsclaw-architecture.md#10
module.exports = {
  validate: (command) => ({ safe: true, reason: null }),
};

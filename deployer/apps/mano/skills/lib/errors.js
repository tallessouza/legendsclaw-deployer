// TODO: Implement error handling utilities
module.exports = {
  SkillError: class SkillError extends Error {
    constructor(message, code) {
      super(message);
      this.code = code;
    }
  },
};

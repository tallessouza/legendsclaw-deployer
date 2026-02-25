// TODO: Implement skill logger
module.exports = {
  log: (level, message) => console.log(`[${level}] ${message}`),
  info: (message) => console.log(`[INFO] ${message}`),
  error: (message) => console.error(`[ERROR] ${message}`),
};

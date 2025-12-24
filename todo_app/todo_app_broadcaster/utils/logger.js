const winston = require("winston");

const logger = winston.createLogger({
  level: "info",
  defaultMeta: { service: "todo-broadcaster" },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss" }),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
    }),
  ],
});

const logError = (message, error = null, metadata = {}) => {
  logger.error(message, {
    error: error
      ? { name: error.name, message: error.message, stack: error.stack }
      : null,
    ...metadata,
  });
};

const logInfo = (message, metadata = {}) => logger.info(message, metadata);
const logWarn = (message, metadata = {}) => logger.warn(message, metadata);

module.exports = { logger, logError, logInfo, logWarn };

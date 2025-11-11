const winston = require("winston");

// Create a logger instance
const logger = winston.createLogger({
  level: "info",
  defaultMeta: { service: "todo-backend" },
  transports: [
    // Write all logs to console (stdout/stderr) in JSON format
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp({
          format: "YYYY-MM-DD HH:mm:ss",
        }),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
    }),
  ],
});

// Add request logging middleware
const requestLogger = (req, res, next) => {
  const start = Date.now();

  // Log the incoming request
  logger.info("Incoming request", {
    method: req.method,
    url: req.url,
    body: req.body,
    userAgent: req.get("User-Agent"),
    ip: req.ip || req.connection.remoteAddress,
    timestamp: new Date().toISOString(),
  });

  // Override res.end to log the response
  const originalEnd = res.end;
  res.end = function (chunk, encoding) {
    const duration = Date.now() - start;

    logger.info("Request completed", {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString(),
    });

    originalEnd.call(this, chunk, encoding);
  };

  next();
};

// Helper methods for different log levels
const logError = (message, error = null, metadata = {}) => {
  logger.error(message, {
    error: error
      ? {
          name: error.name,
          message: error.message,
          stack: error.stack,
        }
      : null,
    ...metadata,
  });
};

const logInfo = (message, metadata = {}) => {
  logger.info(message, metadata);
};

const logWarn = (message, metadata = {}) => {
  logger.warn(message, metadata);
};

const logDebug = (message, metadata = {}) => {
  logger.debug(message, metadata);
};

module.exports = {
  logger,
  requestLogger,
  logError,
  logInfo,
  logWarn,
  logDebug,
};

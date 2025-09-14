const RequestCounter = require("../utils/request-counter");

const requestCounter = new RequestCounter();

const requestCounterMiddleware = (req, res, next) => {
  requestCounter.increaseCount();
  req.count = requestCounter.getCount();
  next()
};

module.exports = {
  requestCounterMiddleware,
};

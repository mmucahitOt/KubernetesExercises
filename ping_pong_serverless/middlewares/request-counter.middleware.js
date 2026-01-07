const RequestCounter = require("../utils/request-counter");

const requestCounter = new RequestCounter();

const requestCounterMiddleware = async (req, res, next) => {
  const count = await requestCounter.increaseCount();
  console.log(count);
  req.count = count;
  next();
};

module.exports = {
  requestCounterMiddleware,
  requestCounter,
};

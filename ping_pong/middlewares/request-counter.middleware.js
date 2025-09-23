const FileManager = require("../utils/file-manager");
const RequestCounter = require("../utils/request-counter");

const requestCounter = new RequestCounter();

const requestCounterMiddleware = (req, res, next) => {
  requestCounter.increaseCount();
  const count = requestCounter.getCount();
  console.log(count);
  req.count = count;
  next();
};

module.exports = {
  requestCounterMiddleware,
  requestCounter,
};

const config = require("../utils/config");
const FileManager = require("../utils/file-manager");
const RequestCounter = require("../utils/request-counter");

const requestCounter = new RequestCounter();
const fileManager = new FileManager();

const requestCounterMiddleware = (req, res, next) => {
  requestCounter.increaseCount();
  const count = requestCounter.getCount();
  console.log(count);
  fileManager.writeFile(config.requestCounterFilePath, `${count}`, () => {
    console.log("The request total is written to the count file");
  });
  req.count = count;
  next();
};

module.exports = {
  requestCounterMiddleware,
};

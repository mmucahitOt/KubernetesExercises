const config = require("../utils/config");

const pingPong = async () => {
  const url = config.pingPortServiceUrl + "/pingpong-count";
  console.log(url);
  const response = await fetch(url);

  return response.text();
};

module.exports = {
  pingPong,
};

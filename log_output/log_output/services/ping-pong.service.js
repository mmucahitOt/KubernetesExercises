const config = require("../utils/config");

const pingPong = async () => {
  const url = config.pingPortServiceUrl + "/pings";
  const response = await fetch(url);

  return response.text();
};

module.exports = {
  pingPong,
};

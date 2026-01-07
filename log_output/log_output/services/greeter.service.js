const config = require("../utils/config");

const getGreeting = async () => {
  const url = config.greeterUrl || "http://greeter-svc:3000";
  const response = await fetch(url);
  return response.text();
};

module.exports = {
  getGreeting,
};

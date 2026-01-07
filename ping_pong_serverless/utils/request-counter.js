const { CountRepository } = require("../repository/count-repository");

class RequestCounter {
  countRepository;
  constructor() {
    this.countRepository = new CountRepository();
  }

  async findAll() {
    return await this.countRepository.findAll();
  }

  async increaseCount() {
    const result = await this.countRepository.incrementCountByOne();
    return result.dataValues.count;
  }

  async getCount() {
    const result = await this.countRepository.getCurrentCount();
    console.log("data", result.dataValues);
    return result.dataValues.count;
  }
}

module.exports = RequestCounter;

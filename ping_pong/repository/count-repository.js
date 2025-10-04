const { PingCount } = require("../models/ping-count");

class CountRepository {
  counter_id;
  constructor() {
    this.counter_id = 1;
  }
  async getCurrentCount() {
    return await PingCount.findByPk(this.counter_id);
  }

  async incrementCountByOne() {
    const [row] = await PingCount.findOrCreate({
      where: { id: this.counter_id },
      defaults: { id: this.counter_id, count: 0 },
    });
    row.count = (row.count || 0) + 1;
    await row.save();
    return row;
  }
}

module.exports = {
  CountRepository,
};

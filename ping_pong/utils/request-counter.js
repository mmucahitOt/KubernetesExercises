class RequestCounter {
  count;
  constructor() {
    this.count = 0;
  }

  increaseCount() {
    this.count++;
  }

  getCount() {
    return this.count;
  }
}

module.exports = RequestCounter;

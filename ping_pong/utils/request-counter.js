class RequestCounter {
  count = 0;

  increaseCount() {
    this.count++;
  }

  getCount() {
    return this.count;
  }
}

module.exports = RequestCounter;

class Timer {
  constructor(duration = 10 * 60 * 1000) {
    this.duration = duration;
    this.remainingTime = duration;
    this.intervalId = null;
    this.isFinished = false;
    this.onTick = null;
    this.onComplete = null;
  }

  start() {
    if (this.intervalId) return;

    this.intervalId = setInterval(() => {
      this.remainingTime -= 1000;

      if (this.onTick) {
        this.onTick(this.getFormattedTime());
      }

      if (this.remainingTime <= 0) {
        this.isFinished = true;
        this.stop();
        if (this.onComplete) {
          this.onComplete();
        }
      }
    }, 1000);
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  reset() {
    this.stop();
    this.remainingTime = this.duration;
    this.isFinished = false;
  }

  restart() {
    this.reset();
    this.start();
  }

  getFormattedTime() {
    const minutes = Math.floor(this.remainingTime / 60000);
    const seconds = Math.floor((this.remainingTime % 60000) / 1000);
    return `${minutes.toString().padStart(2, "0")}:${seconds
      .toString()
      .padStart(2, "0")}`;
  }
}

module.exports = Timer;

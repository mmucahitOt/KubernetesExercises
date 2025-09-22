const config = require("./config");
const FileManager = require("./file-manager");
const { getRandomJpegImage } = require("./random-image-service");
const Timer = require("./timer");

class ImageRequestManager {
  timer;
  fileManager;
  image;
  servedOldOnce = false;
  refreshPromise = null;
  constructor() {
    this.timer = new Timer(10 * 60 * 1000);
    this.fileManager = new FileManager();
    this.initialize();
  }

  initialize() {
    this.fileManager.readFile(config.randomImagePath, (error, data) => {
      if (error) {
        this.randomImage()
          .then((data) => {
            this.image = data;
            this.fileManager.writeJpeg(config.randomImagePath, data, () => {
              console.log("image is saved");
            });
          })
          .catch((error) => {
            throw error;
          });
      }
      if (data) {
        this.image = data;
      } else {
        this.randomImage()
          .then((data) => {
            this.image = data;
            this.fileManager.writeJpeg(config.randomImagePath, data, () => {
              console.log("image is saved");
            });
          })
          .catch((error) => {
            throw error;
          });
      }
      this.timer.start();
    });
  }

  async randomImage() {
    return getRandomJpegImage();
  }

  async getImage() {
    // If timer not finished, always return current image
    console.log(this.timer.getFormattedTime());
    if (!this.timer.isFinished) {
      return this.image;
    }

    // Timer finished: serve old image ONCE, then refresh in background for next call
    if (!this.servedOldOnce) {
      this.servedOldOnce = true;
      // kick off background refresh
      if (!this.refreshPromise) {
        this.refreshPromise = this.refreshImageInBackground();
      }
      return this.image;
    }

    // After serving old once, wait for refresh to complete, then serve new image
    if (this.refreshPromise) {
      await this.refreshPromise;
      this.refreshPromise = null;
      this.servedOldOnce = false; // window resets after new image is available
      return this.image;
    }
    // If no refresh in flight (edge case), fetch now
    await this.refreshImageInBackground();
    this.refreshPromise = null;
    this.servedOldOnce = false;
    return this.image;
  }

  async refreshImageInBackground() {
    try {
      const newImage = await this.randomImage();
      this.image = newImage;
      this.fileManager.writeJpeg(config.randomImagePath, newImage, () => {
        // image written
      });
      // restart the timer for next 10 minutes window
      this.timer.restart();
    } catch (error) {
      // keep old image if fetch fails; next request can try again
      console.error("Failed to refresh image:", error);
    }
  }
}

module.exports = ImageRequestManager;

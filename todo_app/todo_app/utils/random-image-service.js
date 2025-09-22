const getRandomJpegImage = async () => {
  const res = await fetch("https://picsum.photos/1200");
  return streamToBuffer(res.body);
};

const streamToBuffer = async (readableStream) => {
  const reader = readableStream.getReader();
  const chunks = [];

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  return Buffer.concat(chunks);
};


module.exports = {
  getRandomJpegImage
}
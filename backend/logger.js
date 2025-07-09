const pino = require('pino');

let streams = [{ stream: process.stdout }];

if (process.env.DATADOG_API_KEY && process.env.NODE_ENV === 'production') {
  streams.push({
    stream: require('pino-datadog')({
      apiKey: process.env.DATADOG_API_KEY,
      ddsource: 'nodejs',
      service: 'unified-smart-home-api',
      ddtags: 'env:production'
    })
  });
}

module.exports = pino(
  { level: process.env.LOG_LEVEL || 'info' },
  pino.multistream(streams)
); 
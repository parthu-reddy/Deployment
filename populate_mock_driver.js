const Redis = require('ioredis');
const redis = new Redis({
  host: '127.0.0.1',
  port: 6379,
});

async function main() {
  const cityId = '1';
  const driverId = '11111111-2222-3333-4444-555555555555';
  
  // Set location (lat: 12.9716, lng: 77.5946 - roughly Bangalore center)
  // Redis GEOADD key longitude latitude member
  await redis.geoadd(`drivers:geo:${cityId}`, 77.5946, 12.9716, driverId);
  
  // Set availability
  await redis.sadd(`drivers:available:${cityId}`, driverId);
  
  console.log(`Mock driver ${driverId} added to Redis successfully.`);
  process.exit(0);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});

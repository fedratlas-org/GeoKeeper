const path = require('path');

let grpc;
let protoLoader;
let client = null;
let isGrpcAvailable = false;

try {
  grpc = require('@grpc/grpc-js');
  protoLoader = require('@grpc/proto-loader');
  isGrpcAvailable = true;
} catch (e) {
  console.warn('⚠️ @grpc/grpc-js or @grpc/proto-loader not available. Prototype sync will run in log-only mode.');
}

const PROTO_PATH = path.join(__dirname, 'proto', 'fedratlas.proto');
const GRPC_HOST = process.env.SYNC_ENGINE_GRPC_HOST || 'localhost:50051';

function initGrpcClient() {
  if (!isGrpcAvailable) return null;
  if (client) return client;

  try {
    const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
      keepCase: true,
      longs: String,
      enums: String,
      defaults: true,
      oneofs: true,
    });

    const fedratlasProto = grpc.loadPackageDefinition(packageDefinition).fedratlas;
    client = new fedratlasProto.FedratlasService(
      GRPC_HOST,
      grpc.credentials.createInsecure()
    );

    console.log(`🔗 Initialized gRPC client for Fedratlas Prototype backend at ${GRPC_HOST}`);
    return client;
  } catch (err) {
    console.error('❌ Failed to initialize gRPC client:', err.message);
    return null;
  }
}

function numericFeatureId(id) {
  if (!id) return Date.now();
  const digitsOnly = String(id).replace(/\D/g, '');
  if (digitsOnly.length > 0 && digitsOnly.length <= 15) {
    return parseInt(digitsOnly, 10);
  }
  let hash = 0;
  const str = String(id);
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash |= 0;
  }
  return Math.abs(hash);
}

function placeToGeoJSON(place) {
  return {
    type: 'Feature',
    id: place.id,
    geometry: {
      type: 'Point',
      coordinates: [
        parseFloat(place.longitude) || 0,
        parseFloat(place.latitude) || 0,
      ],
    },
    properties: {
      name: place.name || '',
      description: place.description || '',
      category: place.category || 'pois',
      rating: parseFloat(place.rating) || 5.0,
      isFavorite: Boolean(place.isFavorite),
      address: place.address || '',
      imagePath: place.imagePath || '',
      createdAt: place.createdAt || new Date().toISOString(),
    },
  };
}

async function onFeatureChange(activityType, place) {
  const geoJson = placeToGeoJSON(place);
  const featureBytes = Buffer.from(JSON.stringify(geoJson), 'utf8');

  const requestPayload = {
    feature_id: numericFeatureId(place.id),
    activity_type: activityType,
    feature_data: featureBytes,
    version: 1,
    collection_id: place.category || 'pois',
  };

  console.log(`📡 [Fedratlas Sync Engine] Triggering OnFeatureChange (${activityType}) for place: "${place.name || place.id}"`);

  const grpcClient = initGrpcClient();
  if (!grpcClient) {
    console.log(`ℹ️ [Fedratlas Log Mode] Feature change payload prepared:`, {
      feature_id: requestPayload.feature_id,
      activity_type: activityType,
      collection_id: requestPayload.collection_id,
    });
    return { success: true, mode: 'log_fallback', message: 'gRPC client unavailable' };
  }

  return new Promise((resolve) => {
    const deadline = new Date(Date.now() + 3000);
    grpcClient.OnFeatureChange(requestPayload, { deadline }, (err, response) => {
      if (err) {
        console.warn(`⚠️ [Fedratlas Sync Engine] gRPC RPC OnFeatureChange warning (${GRPC_HOST}):`, err.message);
        resolve({ success: false, error: err.message });
      } else {
        console.log(`✅ [Fedratlas Sync Engine] OnFeatureChange synced successfully! Response:`, response);
        resolve(response);
      }
    });
  });
}

function getPeers() {
  const grpcClient = initGrpcClient();
  if (!grpcClient) return Promise.reject(new Error('gRPC client not initialized'));

  return new Promise((resolve, reject) => {
    grpcClient.GetPeers({}, { deadline: new Date(Date.now() + 3000) }, (err, response) => {
      if (err) reject(err);
      else resolve(response);
    });
  });
}

function getServerID() {
  const grpcClient = initGrpcClient();
  if (!grpcClient) return Promise.reject(new Error('gRPC client not initialized'));

  return new Promise((resolve, reject) => {
    grpcClient.GetServerID({}, { deadline: new Date(Date.now() + 3000) }, (err, response) => {
      if (err) reject(err);
      else resolve(response);
    });
  });
}

function getManifest() {
  const grpcClient = initGrpcClient();
  if (!grpcClient) return Promise.reject(new Error('gRPC client not initialized'));

  return new Promise((resolve, reject) => {
    grpcClient.GetManifest({}, { deadline: new Date(Date.now() + 3000) }, (err, response) => {
      if (err) reject(err);
      else resolve(response);
    });
  });
}

module.exports = {
  onFeatureChange,
  getPeers,
  getServerID,
  getManifest,
  placeToGeoJSON,
  numericFeatureId,
};

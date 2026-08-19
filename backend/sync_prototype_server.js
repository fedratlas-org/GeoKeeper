const path = require('path');
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');

const PROTO_PATH = path.join(__dirname, 'proto', 'fedratlas.proto');
const PORT = process.env.SYNC_ENGINE_PORT || '50051';

const SERVER_ID = 'fedratlas-prototype-node-001';
const PUBLIC_KEY = 'ed25519-public-key-prototype-mock-xyz789';

const peersStore = [
  {
    server_id: 'fedratlas-peer-002',
    public_key: 'peer-public-key-456',
    trust_score: 0.95,
    endpoint_url: 'http://localhost:50052',
    status: 'ACTIVE',
    last_seen: Date.now(),
    created_at: Date.now() - 86400000,
  },
];

const featureChangesStore = [];

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

const fedratlasProto = grpc.loadPackageDefinition(packageDefinition).fedratlas;

const serviceImpl = {
  OnFeatureChange: (call, callback) => {
    try {
      const { feature_id, activity_type, feature_data, version, collection_id } = call.request;

      let geoJson = null;
      if (feature_data) {
        try {
          const jsonString = Buffer.isBuffer(feature_data)
            ? feature_data.toString('utf8')
            : String(feature_data);
          geoJson = JSON.parse(jsonString);
        } catch (e) {
          geoJson = { raw: String(feature_data) };
        }
      }

      const changeRecord = {
        feature_id,
        activity_type,
        collection_id,
        version,
        geoJson,
        received_at: new Date().toISOString(),
      };

      featureChangesStore.push(changeRecord);

      console.log(`=================================================`);
      console.log(`📥 [Fedratlas Prototype Server] Received OnFeatureChange gRPC event!`);
      console.log(`   - Activity Type : ${activity_type}`);
      console.log(`   - Feature ID    : ${feature_id}`);
      console.log(`   - Collection    : ${collection_id}`);
      console.log(`   - Version       : ${version}`);
      if (geoJson && geoJson.properties) {
        console.log(`   - Place Name    : ${geoJson.properties.name}`);
        console.log(`   - Category      : ${geoJson.properties.category}`);
        console.log(`   - Coordinates   : [${geoJson.geometry?.coordinates?.join(', ')}]`);
      }
      console.log(`=================================================`);

      callback(null, {
        success: true,
        error: '',
      });
    } catch (err) {
      console.error('❌ Error handling OnFeatureChange in prototype server:', err.message);
      callback(null, {
        success: false,
        error: err.message,
      });
    }
  },

  AddPeer: (call, callback) => {
    const { peer } = call.request;
    if (peer && peer.server_id) {
      peersStore.push(peer);
      console.log(`🤝 [Fedratlas Prototype Server] Peer added: ${peer.server_id}`);
      callback(null, { success: true, error: '' });
    } else {
      callback(null, { success: false, error: 'Invalid peer data' });
    }
  },

  GetPeers: (call, callback) => {
    callback(null, { peers: peersStore });
  },

  GetServerID: (call, callback) => {
    callback(null, { server_id: SERVER_ID });
  },

  GetManifest: (call, callback) => {
    callback(null, {
      protocol_version: 'v1.0.0-prototype',
      server_id: SERVER_ID,
      status: 'ONLINE',
      public_key: PUBLIC_KEY,
      endpoints: {
        inbox_url: `http://localhost:${PORT}/fedmap/v1/inbox`,
        outbox_url: `http://localhost:${PORT}/fedmap/v1/outbox`,
        manifest_url: `http://localhost:${PORT}/manifest`,
      },
      datasets: [
        {
          id: 'pois',
          name: 'Points of Interest',
          description: 'Synchronized POIs and saved places',
          feature_count: featureChangesStore.length,
        },
      ],
    });
  },
};

function startServer() {
  const server = new grpc.Server();
  server.addService(fedratlasProto.FedratlasService.service, serviceImpl);

  const bindAddr = `0.0.0.0:${PORT}`;
  server.bindAsync(bindAddr, grpc.ServerCredentials.createInsecure(), (err, port) => {
    if (err) {
      console.error('❌ Failed to bind gRPC server:', err.message);
      return;
    }
    console.log(`=================================================`);
    console.log(`🚀 Fedratlas Prototype gRPC Server running on 0.0.0.0:${port}`);
    console.log(`   - Protobuf Schema : ${PROTO_PATH}`);
    console.log(`   - Server ID       : ${SERVER_ID}`);
    console.log(`   - Listening for   : OnFeatureChange, AddPeer, GetPeers, GetServerID, GetManifest`);
    console.log(`=================================================`);
  });
}

startServer();

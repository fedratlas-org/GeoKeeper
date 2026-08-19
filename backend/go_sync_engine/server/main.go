package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"time"

	pb "github.com/fedratlas/sync-engine/proto"
	_ "github.com/lib/pq"
	"google.golang.org/grpc"
)

type server struct {
	pb.FedratlasServiceServer
	db         *sql.DB
	serverID   string
	publicKey  string
	peers      []*pb.Peer
	changeLogs []string
}

func main() {
	port := os.Getenv("SYNC_ENGINE_PORT")
	if port == "" {
		port = "50051"
	}

	dbURL := os.Getenv("DATABASE_URL")
	var db *sql.DB
	var err error

	if dbURL != "" {
		db, err = sql.Open("postgres", dbURL)
		if err != nil {
			log.Printf("⚠️ PostgreSQL connection warning: %v", err)
		} else {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			if err := db.PingContext(ctx); err != nil {
				log.Printf("⚠️ PostgreSQL ping warning: %v", err)
			} else {
				log.Println("✅ Go Sync Engine connected to PostgreSQL database successfully!")
			}
		}
	} else {
		log.Println("ℹ️ DATABASE_URL not set. Running Go Sync Engine with in-memory persistence.")
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("❌ Failed to listen on port %s: %v", port, err)
	}

	s := grpc.NewServer()
	srv := &server{
		db:        db,
		serverID:  "fedratlas-go-sync-001",
		publicKey: "ed25519-public-key-go-backend-mock-999",
		peers: []*pb.Peer{
			{
				ServerId:    "fedratlas-node-002",
				PublicKey:   "peer-pubkey-002",
				TrustScore:  0.98,
				EndpointUrl: "http://localhost:50052",
				Status:      "ACTIVE",
				LastSeen:    time.Now().Unix(),
				CreatedAt:   time.Now().Add(-24 * time.Hour).Unix(),
			},
		},
	}

	pb.RegisterFedratlasServiceServer(s, srv)

	log.Println("=================================================")
	log.Printf("🚀 Fedratlas Go Sync Engine Server running on port :%s", port)
	log.Printf("   - Protocol       : gRPC (RPC Over TCP)")
	log.Printf("   - Server ID      : %s", srv.serverID)
	log.Printf("   - Database       : PostgreSQL")
	log.Println("=================================================")

	if err := s.Serve(lis); err != nil {
		log.Fatalf("❌ Server exited with error: %v", err)
	}
}

func (s *server) OnFeatureChange(ctx context.Context, req *pb.FeatureChangeRequest) (*pb.FeatureChangeResponse, error) {
	log.Printf("📥 [gRPC OnFeatureChange] Received Activity: %s | FeatureID: %d | Collection: %s",
		req.ActivityType, req.FeatureId, req.CollectionId)

	var geoJSON map[string]interface{}
	if len(req.FeatureData) > 0 {
		if err := json.Unmarshal(req.FeatureData, &geoJSON); err == nil {
			if props, ok := geoJSON["properties"].(map[string]interface{}); ok {
				log.Printf("   - Place Name  : %v", props["name"])
				log.Printf("   - Category    : %v", props["category"])
			}
			if geom, ok := geoJSON["geometry"].(map[string]interface{}); ok {
				log.Printf("   - Geometry    : %v | Coordinates: %v", geom["type"], geom["coordinates"])
			}
		}
	}

	// Persist to PostgreSQL if database connection is available
	if s.db != nil {
		go func() {
			_, err := s.db.Exec(`
				CREATE TABLE IF NOT EXISTS public.sync_feature_changes (
					id SERIAL PRIMARY KEY,
					feature_id BIGINT,
					activity_type VARCHAR(50),
					collection_id VARCHAR(100),
					feature_data JSONB,
					created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
				);
			`)
			if err == nil {
				s.db.Exec(`
					INSERT INTO public.sync_feature_changes (feature_id, activity_type, collection_id, feature_data)
					VALUES ($1, $2, $3, $4);
				`, req.FeatureId, req.ActivityType, req.CollectionId, string(req.FeatureData))
				log.Printf("✅ Feature mutation logged to PostgreSQL table sync_feature_changes")
			}
		}()
	}

	s.changeLogs = append(s.changeLogs, fmt.Sprintf("%s:%d", req.ActivityType, req.FeatureId))

	return &pb.FeatureChangeResponse{
		Success: true,
		Error:   "",
	}, nil
}

func (s *server) AddPeer(ctx context.Context, req *pb.AddPeerRequest) (*pb.AddPeerResponse, error) {
	if req.Peer != nil {
		s.peers = append(s.peers, req.Peer)
		log.Printf("🤝 Peer added to registry: %s", req.Peer.ServerId)
		return &pb.AddPeerResponse{Success: true}, nil
	}
	return &pb.AddPeerResponse{Success: false, Error: "Invalid peer"}, nil
}

func (s *server) GetPeers(ctx context.Context, req *pb.GetPeersRequest) (*pb.GetPeersResponse, error) {
	return &pb.GetPeersResponse{Peers: s.peers}, nil
}

func (s *server) GetServerID(ctx context.Context, req *pb.GetServerIDRequest) (*pb.GetServerIDResponse, error) {
	return &pb.GetServerIDResponse{ServerId: s.serverID}, nil
}

func (s *server) GetManifest(ctx context.Context, req *pb.GetManifestRequest) (*pb.Manifest, error) {
	return &pb.Manifest{
		ProtocolVersion: "v1.0.0-go-grpc",
		ServerId:        s.serverID,
		Status:          "ONLINE",
		PublicKey:       s.publicKey,
		Endpoints: &pb.Manifest_EndpointConfig{
			InboxUrl:    "http://localhost:50051/fedmap/v1/inbox",
			OutboxUrl:   "http://localhost:50051/fedmap/v1/outbox",
			ManifestUrl: "http://localhost:50051/manifest",
		},
		Datasets: []*pb.Manifest_DatasetInfo{
			{
				Id:           "pois",
				Name:         "Points of Interest",
				Description:  "Go Sync Engine Federated POIs",
				FeatureCount: int64(len(s.changeLogs)),
			},
		},
	}, nil
}

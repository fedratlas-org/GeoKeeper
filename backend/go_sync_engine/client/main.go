package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	pb "github.com/fedratlas/sync-engine/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	target := os.Getenv("SYNC_ENGINE_GRPC_HOST")
	if target == "" {
		target = "localhost:50051"
	}

	log.Printf("🔗 Connecting Go gRPC Client to Sync Engine at %s...", target)

	conn, err := grpc.Dial(target, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("❌ Failed to connect to gRPC target: %v", err)
	}
	defer conn.Close()

	client := pb.NewFedratlasServiceClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// 1. Call GetServerID
	serverIDResp, err := client.GetServerID(ctx, &pb.GetServerIDRequest{})
	if err != nil {
		log.Fatalf("❌ GetServerID RPC failed: %v", err)
	}
	fmt.Printf("✅ [GetServerID] Response Server ID: %s\n", serverIDResp.ServerId)

	// 2. Call GetManifest
	manifestResp, err := client.GetManifest(ctx, &pb.GetManifestRequest{})
	if err != nil {
		log.Fatalf("❌ GetManifest RPC failed: %v", err)
	}
	fmt.Printf("✅ [GetManifest] Version: %s | Status: %s | Inbox URL: %s\n",
		manifestResp.ProtocolVersion, manifestResp.Status, manifestResp.Endpoints.InboxUrl)

	// 3. Call GetPeers
	peersResp, err := client.GetPeers(ctx, &pb.GetPeersRequest{})
	if err != nil {
		log.Fatalf("❌ GetPeers RPC failed: %v", err)
	}
	fmt.Printf("✅ [GetPeers] Active Peers Count: %d\n", len(peersResp.Peers))
	for i, peer := range peersResp.Peers {
		fmt.Printf("   [%d] ServerID: %s | Endpoint: %s | Trust: %.2f\n",
			i+1, peer.ServerId, peer.EndpointUrl, peer.TrustScore)
	}

	// 4. Send OnFeatureChange RPC
	geoJSON := map[string]interface{}{
		"type": "Feature",
		"id":   "ella_rock_001",
		"geometry": map[string]interface{}{
			"type":        "Point",
			"coordinates": []float64{81.0465, 6.8667},
		},
		"properties": map[string]interface{}{
			"name":        "Ella Rock Viewpoint",
			"description": "Scenic hiking peak in Ella, Sri Lanka",
			"category":    "Nature",
			"rating":      4.9,
			"isFavorite":  true,
		},
	}

	geoJSONBytes, _ := json.Marshal(geoJSON)

	featureReq := &pb.FeatureChangeRequest{
		FeatureId:    2001,
		ActivityType: "Create",
		FeatureData:  geoJSONBytes,
		Version:      1,
		CollectionId: "pois",
	}

	fmt.Println("\n📡 Executing OnFeatureChange gRPC RPC call...")
	changeResp, err := client.OnFeatureChange(ctx, featureReq)
	if err != nil {
		log.Fatalf("❌ OnFeatureChange RPC failed: %v", err)
	}

	fmt.Printf("✅ [OnFeatureChange] RPC Result -> Success: %t | Error: %s\n",
		changeResp.Success, changeResp.Error)
	fmt.Println("=================================================")
	fmt.Println("🎉 Go Backend -> Sync Engine gRPC RPC Connection Verified Successfully!")
	fmt.Println("=================================================")
}

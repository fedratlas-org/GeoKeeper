# 🗺️ Fedratlas Map — Prototype & Multi-Server Synchronization Technical Documentation

**Project Name**: Fedratlas Map (Federated Protocol for Secure Geospatial Data Sharing and Synchronization)  
**Academic Institution**: Sabaragamuwa University of Sri Lanka — Department of Computing & Information Systems (Group 12)  
**Document Purpose**: Comprehensive technical reference, protocol design, architecture overview, and deployment guide for the multi-map synchronization prototype.

---

## 📋 Table of Contents
1. [Executive Summary & Problem Statement](#1-executive-summary--problem-statement)
2. [Protocol Conceptual Architecture](#2-protocol-conceptual-architecture)
3. [System Architecture & Prototype Components](#3-system-architecture--prototype-components)
4. [Multi-Server Map Synchronization Mechanics](#4-multi-server-map-synchronization-mechanics)
5. [Database Schema & Data Models](#5-database-schema--data-models)
6. [API & Protocol Endpoints Reference](#6-api--protocol-endpoints-reference)
7. [Cryptographic Verification & Trust Architecture](#7-cryptographic-verification--trust-architecture)
8. [Module Breakdowns & Functional Requirements](#8-module-breakdowns--functional-requirements)
9. [Step-by-Step Multi-Node Prototype Execution Guide](#9-step-by-step-multi-node-prototype-execution-guide)
10. [Future Scope & Production Roadmap](#10-future-scope--production-roadmap)

---

## 1. Executive Summary & Problem Statement

### 1.1 The Challenge: Siloed Geospatial Ecosystems
Modern digital mapping platforms (Google Maps, Apple Maps, OpenStreetMap) operate as isolated data silos. Map updates created on one server or platform are inaccessible to others. This leads to:
- **Data Redundancy**: Multiple entities independently digitizing identical roads, POIs, or terrain features.
- **Inconsistent Datasets**: Mismatched geospatial data between public infrastructure databases and commercial mapping services.
- **Lack of Sovereign Federation**: No standard peer-to-peer protocol exists to allow sovereign mapping nodes to subscribe to geospatial mutations while maintaining data ownership.

### 1.2 The Solution: Fedratlas Protocol
The **Fedratlas Protocol** bridges the **OGC API - Features** standard with decentralized ActivityStreams principles (inspired by ActivityPub and AT Protocol). 

Fedratlas empowers independent map servers to act simultaneously as **geospatial data providers** and **federated data consumers**. When a feature is added, updated, or deleted on Server A (e.g. `server-001`), an immutable Activity object is generated, signed cryptographically, and propagated asynchronously to all subscribed peer map servers (e.g. `server-002`, `server-003`).

```mermaid
graph LR
    subgraph Node A ["Map Server A (server-001)"]
        DB1[(PostGIS Spatial DB)]
        OB1[Federation Outbox]
        ENG1[Sync Engine Workers]
    end

    subgraph Node B ["Map Server B (server-002)"]
        IB2[Inbox Endpoint]
        DB2[(PostGIS Spatial DB)]
    end

    subgraph Node C ["Map Server C (server-003)"]
        IB3[Inbox Endpoint]
        DB3[(PostGIS Spatial DB)]
    end

    DB1 -->|Local Mutation| OB1
    OB1 -->|Poll & Sign| ENG1
    ENG1 -->|HTTPS POST Activity| IB2
    ENG1 -->|HTTPS POST Activity| IB3
    IB2 -->|Verify & Apply| DB2
    IB3 -->|Verify & Apply| DB3
```

---

## 2. Protocol Conceptual Architecture

Fedratlas separates the system into two distinct operational layers:
1. **OGC Data Layer**: Serves standard client-to-server (C/S) geospatial feature requests following OGC API - Features standards (`/fedmap/v1/collections/{id}/items`).
2. **Federation Layer**: Manages peer-to-peer server-to-server (S2S) discovery (`/manifest`), cryptographic authorization, change log tracking (`outbox`), and activity delivery (`inbox`).

```mermaid
flowchart TD
    Client[Mobile/Web Client] -->|OGC API Features C/S| Gate[P1: OGC API Gateway]
    Gate --> Engine[P4: Spatial Data Engine]
    Engine --> DB[(PostGIS Database)]
    
    Engine -->|Trigger Change| Outbox[Outbox Log]
    Outbox --> FedMgr[P2: Federation Manager Sync Engine]
    FedMgr -->|Signed Activity payload| Peers[Peer Server Inboxes]
    Peers -->|Inbound Activity| Inbox[P2: Inbox Handler]
    Inbox -->|Cryptographic Verification| Engine
```

---

## 3. System Architecture & Prototype Components

The prototype consists of two core software repositories:

### 3.1 Backend Server Engine (`fedratlas-sync-with-go`)
A high-performance Go backend utilizing:
- **HTTP Routing**: `chi` lightweight router
- **Database Driver**: `pgx/v5` PostgreSQL driver with PostGIS spatial query support
- **Asynchronous Synchronization Engine**: Concurrent goroutine workers polling outbox queues
- **Cryptographic Subsystem**: Ed25519/RSA SHA-256 payload signing and verification

#### Directory Layout (`fedratlas-sync-with-go`):
```
fedratlas-sync-with-go/
├── cmd/
│   └── server/
│       └── main.go           # Server startup, route definitions, worker initialization
├── internal/
│   ├── api/                  # HTTP Handlers (Inbox, Manifest, Peers, Features, Health)
│   ├── crypto/               # RSA/Ed25519 Key generation, SHA-256 signing & verification
│   ├── storage/              # PostGIS connection, SQL migrations, Repository pattern
│   └── sync/                 # Outbox poller, Inbox message application, Worker pools
└── pkg/                      # Shared protocol types and data structures
```

### 3.2 Mobile Client Interface (`maptwo_app`)
A cross-platform Flutter application for visualizing map data, managing saved places, and submitting feature edits:
- **Map View**: Interactive Google Maps renderer displaying local and federated POIs
- **Dual Persistence**: REST sync with cloud backend (`pg`), offline fallback via `SharedPreferences`
- **Moderation Interface**: UI for submitting place edits and viewing real-time sync status

---

## 4. Multi-Server Map Synchronization Mechanics

The core value of the prototype is synchronizing two or more map servers in real time. The process follows a strict 5-step lifecycle:

```mermaid
sequenceDiagram
    autonumber
    participant U as User / Client
    participant A as Server 1 (Outbox)
    participant E as Server 1 Sync Engine
    participant B as Server 2 (Inbox)
    participant DB as Server 2 PostGIS DB

    U->>A: POST /fedmap/v1/collections/default/items (Create Feature)
    A->>A: Insert into geo_features (Version 1)
    A->>A: Insert Signed Activity into federation_outbox
    A-->>U: 201 Created (Feature ID)

    loop Worker Poll (Every 5s)
        E->>A: Fetch PENDING items from federation_outbox
        E->>E: Sign payload with Server 1 Private Key
        E->>B: POST /fedmap/v1/inbox (Activity JSON + SHA-256 Checksum + Signature)
        B->>B: Look up Server 1 Public Key in peer_registry
        B->>B: Verify Signature & SHA-256 Payload Checksum
        B->>DB: Upsert Feature into geo_features & update version
        B-->>E: 200 OK (Processed)
        E->>A: Update outbox_delivery status to DELIVERED
    end
```

### Step-by-Step Flow:
1. **Mutation Trigger**: A client creates or edits a geospatial feature on Server 1.
2. **Outbox Immutable Logging**: Server 1 writes the feature to `geo_features` and simultaneously inserts a JSON-LD formatted Activity into `federation_outbox`.
3. **Asynchronous Engine Polling**: Server 1's background sync engine picks up pending outbox items and generates delivery tasks for all active peers in `peer_registry` with `status = 'FOLLOWING'`.
4. **Cryptographic Dispatch**: Server 1 computes SHA-256 payload checksums, signs the request with its RSA private key, and POSTs the activity to Server 2's `/fedmap/v1/inbox`.
5. **Atomic Inbox Application**: Server 2 retrieves Server 1's public key, verifies the digital signature, validates the feature payload, and atomically upserts the geometry and metadata into its local PostGIS database.

---

## 5. Database Schema & Data Models

The PostGIS database consists of 7 core tables optimized with spatial (GiST) and composite B-Tree indexes:

```mermaid
erDiagram
    PEER_REGISTRY ||--o{ FEDERATION_LOG : logs
    PEER_REGISTRY ||--o{ OUTBOX_DELIVERY : target
    FEDERATION_OUTBOX ||--o{ OUTBOX_DELIVERY : delivers
    GEO_FEATURES ||--o{ MODERATION_QUEUE : target_feature
    GEO_FEATURES ||--o{ PLACE_REVIEWS : has_review

    PEER_REGISTRY {
        varchar server_id PK
        text public_key
        numeric trust_score
        text endpoint_url
        varchar status
    }

    GEO_FEATURES {
        bigserial feature_id PK
        geometry geom
        integer version
        numeric trust_score
        jsonb feature_data
        timestamp last_edited_timestamp
    }

    FEDERATION_OUTBOX {
        bigserial id PK
        jsonb activity
        varchar status
        timestamp created_at
    }

    OUTBOX_DELIVERY {
        bigint outbox_id FK
        varchar peer_id FK
        int retry_count
        timestamp next_retry
        timestamp delivered_at
    }

    MODERATION_QUEUE {
        bigserial task_id PK
        varchar user_id
        bigint feature_id FK
        jsonb submission_data
        varchar status
    }

    PLACE_REVIEWS {
        bigserial review_id PK
        varchar user_id
        bigint feature_id FK
        integer rating
        text review_text
    }
```

### Table Definitions:

#### 1. `peer_registry` (Federation Peer State)
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `server_id` | `VARCHAR(100)` | `PRIMARY KEY` | Unique ID of remote federated peer (e.g. `server-002`) |
| `public_key` | `TEXT` | `NOT NULL` | Base64-encoded RSA/Ed25519 public key |
| `trust_score` | `NUMERIC(3,2)` | Default: `0.50` | Peer trustworthiness score (0.00 to 1.00) |
| `endpoint_url` | `TEXT` | `NOT NULL` | Peer Base URL (e.g. `https://node2.fedratlas.org`) |
| `status` | `VARCHAR(20)` | `CHECK IN ('FOLLOWING', 'BLOCKED', 'PENDING')` | Handshake subscription state |

#### 2. `geo_features` (Spatial Database)
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `feature_id` | `BIGSERIAL` | `PRIMARY KEY` | Unique geospatial feature ID |
| `geom` | `GEOMETRY(Geometry, 4326)` | `Spatial Index (GiST)` | WGS84 point, linestring, or polygon geometry |
| `version` | `INTEGER` | Default: `1` | Incremental version counter for conflict resolution |
| `trust_score` | `NUMERIC(3,2)` | Default: `0.50` | Evaluated quality score of the feature |
| `feature_data` | `JSONB` | — | Metadata properties (name, category, tags, attributes) |
| `last_edited_timestamp` | `TIMESTAMPTZ` | Default: `NOW()` | Timestamp of last modification |

#### 3. `federation_outbox` (Change Log Outbox)
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | `PRIMARY KEY` | Immutable sequential log identifier |
| `activity` | `JSONB` | `NOT NULL` | Fedratlas Activity object payload |
| `status` | `VARCHAR(20)` | `CHECK IN ('PENDING', 'PROCESSING', 'DELIVERED', 'FAILED')` | Queue processing status |

#### 4. `outbox_delivery` (Per-Peer Worker Queue Tracker)
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `outbox_id` | `BIGINT` | `FK -> federation_outbox(id)` | Linked outbox record |
| `peer_id` | `VARCHAR(100)` | `FK -> peer_registry(server_id)` | Target peer server |
| `retry_count` | `INT` | Default: `0` | Exponential backoff retry attempts |
| `next_retry` | `TIMESTAMPTZ` | — | Scheduled time for next delivery attempt |
| `delivered_at` | `TIMESTAMPTZ` | Nullable | Timestamp of successful HTTP 200 delivery |

---

## 6. API & Protocol Endpoints Reference

### 6.1 Server Manifest & Peer Discovery
- `GET /fedmap/v1/manifest`
  - **Description**: Returns server identity, public key, supported protocol version, and endpoints.
  - **Response `200 OK`**:
```json
{
  "server_id": "server-001",
  "version": "1.0.0",
  "public_key": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQE...",
  "endpoints": {
    "inbox": "/fedmap/v1/inbox",
    "collections": "/fedmap/v1/collections",
    "peers": "/fedmap/v1/peers"
  }
}
```

### 6.2 Peer Management
- `GET /fedmap/v1/peers` — List all registered peer nodes and trust scores.
- `POST /fedmap/v1/peers` — Register a new peer server to federate with.
  - **Payload**:
```json
{
  "server_id": "server-002",
  "endpoint_url": "http://localhost:8081",
  "public_key": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ...",
  "status": "FOLLOWING"
}
```

### 6.3 Inbox (Data Synchronization Endpoint)
- `POST /fedmap/v1/inbox`
  - **Description**: Receives incoming signed Activity items from peer nodes.
  - **Payload**:
```json
{
  "activity_id": "act_987654321",
  "type": "CreateFeature",
  "sender_server_id": "server-001",
  "timestamp": "2026-08-12T20:20:00Z",
  "payload_checksum": "a3f5b71c29e...",
  "sender_signature": "d6e8f01a...",
  "target_object_data": {
    "type": "Feature",
    "geometry": {
      "type": "Point",
      "coordinates": [80.7718, 6.7146]
    },
    "properties": {
      "name": "Sabaragamuwa University Main Library",
      "category": "Education",
      "version": 1
    }
  }
}
```

### 6.4 OGC Feature Operations
- `GET /fedmap/v1/collections/{collectionId}/items` — Query spatial features (supports bbox filtering).
- `POST /fedmap/v1/collections/{collectionId}/items` — Insert feature & trigger federation outbox.
- `PUT /fedmap/v1/collections/{collectionId}/items/{featureId}` — Update feature & trigger outbox update.
- `DELETE /fedmap/v1/collections/{collectionId}/items/{featureId}` — Delete feature & trigger deletion activity.

---

## 7. Cryptographic Verification & Trust Architecture

Security and authenticity are critical to prevent unauthorized data injection into map databases.

### 7.1 Payload Signing & Verification Pipeline
1. **Sender Side**:
   - SHA-256 hash calculated over `target_object_data` JSON string (`payload_checksum`).
   - The checksum string + timestamp + sender ID is signed using the sender server's private key (`sender_signature`).
2. **Receiver Side**:
   - Receiver retrieves the sender's public key from `peer_registry`.
   - Verifies that `sender_signature` matches the sender's public key.
   - Recomputes SHA-256 hash over `target_object_data` and asserts equality with `payload_checksum`.

### 7.2 Dynamic Peer Trust Scoring
Each peer retains a dynamic `trust_score` between `0.00` and `1.00`:
$$\text{Trust Score}_{\text{new}} = \text{Trust Score}_{\text{current}} \times (1 - \alpha) + \text{Feedback} \times \alpha$$
- Successful verified sync activities increase peer trust.
- Rejected moderation edits or cryptographically invalid messages reduce peer trust.

---

## 8. Module Breakdowns & Functional Requirements

| Module ID | Module Name | Core Responsibilities | Implementation Status |
| :--- | :--- | :--- | :--- |
| **P1** | **OGC API Gateway** | Serves client feature queries, handles spatial BBOX filtering | Completed in Go (`internal/api/features.go`) |
| **P2** | **Federation Manager** | Manages peer handshakes, sign/verify crypto, sync engine workers | Completed in Go (`internal/sync/`) |
| **P3** | **Content Moderation** | Verifies user contributions, handles report queues | Completed schema & endpoints (`moderation_queue`) |
| **P4** | **Spatial Data Engine** | Direct PostGIS geometry reads/writes, spatial indexing | Completed using `pgx` + PostGIS extension |
| **P5** | **Real-Time Data Processor** | Real-time traffic & transient location processing | Defined in architecture |
| **P6** | **Route Engine** | Network graph route calculations | Standardized interface |

### Satisfied Functional Requirements:
- **FR-01 (Manifest Exposure)**: Public discoverability endpoint available at `/fedmap/v1/manifest`.
- **FR-02 (Secure Authorization)**: Inter-server authentication using public key verification and SHA-256 payloads.
- **FR-03 (Outbox Change Log)**: Immutable mutation logging in `federation_outbox`.
- **FR-04 (Activity Propagation Engine)**: Concurrent background workers with exponential backoff retries.
- **FR-05 (Atomic Inbox Application)**: Transactional database application preventing partial states.

---

## 9. Step-by-Step Multi-Node Prototype Execution Guide

To test real-time map synchronization locally between **two autonomous server instances** (`server-001` on port `8080` and `server-002` on port `8081`):

### Prerequisites
- Go 1.21+ installed
- PostgreSQL with PostGIS extension running on `localhost:5432`

### Step 1: Initialize Databases for Node 1 and Node 2
```sql
CREATE DATABASE fedratlas_node1;
CREATE DATABASE fedratlas_node2;
```

### Step 2: Start Server 1 (`server-001` on Port 8080)
Open Terminal 1:
```bash
cd fedratlas-sync-with-go
export FEDRATLAS_SERVER_ID=server-001
export HTTP_PORT=8080
export DATABASE_URL="postgres://postgres:password@localhost:5432/fedratlas_node1?sslmode=disable"
go run cmd/server/main.go
```

### Step 3: Start Server 2 (`server-002` on Port 8081)
Open Terminal 2:
```bash
cd fedratlas-sync-with-go
export FEDRATLAS_SERVER_ID=server-002
export HTTP_PORT=8081
export DATABASE_URL="postgres://postgres:password@localhost:5432/fedratlas_node2?sslmode=disable"
go run cmd/server/main.go
```

### Step 4: Register Server 2 as a Peer on Server 1
```bash
curl -X POST http://localhost:8080/fedmap/v1/peers \
  -H "Content-Type: application/json" \
  -d '{
    "server_id": "server-002",
    "endpoint_url": "http://localhost:8081",
    "public_key": "<SERVER_2_PUBLIC_KEY>",
    "status": "FOLLOWING"
  }'
```

### Step 5: Add a New Feature to Server 1 & Observe Instant Sync to Server 2!
```bash
curl -X POST http://localhost:8080/fedmap/v1/collections/default/items \
  -H "Content-Type: application/json" \
  -d '{
    "type": "Feature",
    "geometry": {
      "type": "Point",
      "coordinates": [80.7718, 6.7146]
    },
    "properties": {
      "name": "Faculty of Computing - SUSL",
      "category": "University"
    }
  }'
```

**Verification**:
Query Server 2 (`http://localhost:8081/fedmap/v1/collections/default/items`).  
*The new map feature automatically appears on Server 2 within 5 seconds!* 🚀

---

## 10. Future Scope & Production Roadmap

1. **CRDT / Conflict Resolution Engine**: Implement Conflict-Free Replicated Data Types for simultaneous offline map editing across multiple mobile clients.
2. **Vector Tile Server Integration**: Expose Mapbox Vector Tiles (MVT) directly from PostGIS for smooth UI rendering in Flutter (`maptwo_app`).
3. **Decentralized Identity (DID)**: Upgrade public key exchange to W3C Decentralized Identifiers (DIDs) and ActivityPub Actor objects.

---
*Documentation prepared by Capstone Group 12 (IS4110 Capstone Project — Sabaragamuwa University of Sri Lanka).*

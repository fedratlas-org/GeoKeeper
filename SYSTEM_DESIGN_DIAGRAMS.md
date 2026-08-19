# 🎨 Fedratlas Map — System Design & Architecture Diagrams

This document contains the complete, high-resolution **UML and ER Diagrams** for the **Fedratlas Federated Map Data Sharing and Synchronization System**, designed for Sabaragamuwa University Capstone Final Report documentation (IS 4110 / SE5104).

---

## 1. 🗄️ Entity-Relationship (ER) Diagram

The ER Diagram details the entities, attributes, primary keys (`PK`), foreign keys (`FK`), and cardinalities across the PostGIS spatial database and federation state tables.

```mermaid
erDiagram
    USER {
        string user_id PK
        string username
        string email
        string role
        string status
        timestamp joined_data
    }

    PEER_SERVER {
        string server_id PK
        text public_key
        numeric trust_score
        string endpoint_url
        string status
    }

    GEO_FEATURE {
        bigint feature_id PK
        geometry geom
        integer version
        numeric trust_score
        jsonb feature_data
        timestamp last_edited_timestamp
    }

    FEDERATION_LOG {
        bigint log_id PK
        string server_id FK
        string activity_type
        timestamp timestamp
        jsonb details
    }

    MODERATION_TASK {
        bigint task_id PK
        string user_id FK
        bigint feature_id FK
        jsonb submission_data
        string status
    }

    PLACE_REVIEW {
        bigint review_id PK
        string user_id FK
        bigint feature_id FK
        integer rating
        text review_text
    }

    PEER_SERVER ||--o{ GEO_FEATURE : "Authenticates & Serves (1:N)"
    PEER_SERVER ||--o{ FEDERATION_LOG : "Generates Audit Logs (1:N)"
    USER ||--o{ MODERATION_TASK : "Submits Edits (1:N)"
    USER ||--o{ PLACE_REVIEW : "Writes Reviews (1:N)"
    GEO_FEATURE ||--o{ MODERATION_TASK : "Is Affected By (1:N)"
    GEO_FEATURE ||--o{ PLACE_REVIEW : "Has Reviews (1:N)"
```

---

## 2. 👥 Use Case Diagram

The Use Case Diagram illustrates the interactions between three primary system actors (**Client User**, **Other Map Server**, and **Content Moderator**) and the core functional modules of the Fedratlas protocol.

```mermaid
graph TD
    User(("👤 Client User"))
    PeerServer(("🖥️ Other Map Server"))
    Moderator(("🛡️ Content Moderator"))

    subgraph Fedratlas ["System Boundary: Fedratlas Protocol"]
        UC1("View Map Tiles & POIs")
        UC2("Search for Places")
        UC3("Rate & Review Places")
        UC4("Save Favorite Places")
        UC5("Submit Data Edits (POIs / Roads)")
        UC6("Report Incorrect Information")

        UC7("Discover Server Manifest")
        UC8("Follow / Unfollow Peer Servers")
        UC9("Exchange Map Data Activities")
        UC10("Synchronize User Contributions")
        UC11("Verify Data Integrity & Signatures")
        UC12("Resolve Data Conflicts")

        UC13("Review Incorrect Info Reports")
        UC14("Verify & Approve Contributions")
        UC15("Approve / Reject Data Edits")
        UC16("Maintain Data Quality & Trust")
    end

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5
    User --> UC6

    PeerServer --> UC7
    PeerServer --> UC8
    PeerServer --> UC9
    PeerServer --> UC10
    PeerServer --> UC11
    PeerServer --> UC12

    Moderator --> UC13
    Moderator --> UC14
    Moderator --> UC15
    Moderator --> UC16

    UC3 -.->|"<<extend>>"| UC2
    UC5 -.->|"<<include>>"| UC14
    UC6 -.->|"<<include>>"| UC13
    UC9 -.->|"<<include>>"| UC11
    UC10 -.->|"<<include>>"| UC12
```

---

## 3. 🔄 Activity Diagram (Multi-Server Synchronization Workflow)

The Activity Diagram depicts the step-by-step operational decision flow for creating a map feature on Node 1, queueing it in the outbox, delivering it asynchronously over HTTPS, and applying it to Node 2's PostGIS database.

```mermaid
stateDiagram-v2
    direction TB

    [*] --> UserAction: Client Creates / Modifies Spatial Feature

    state "Node 1 (Origin Server)" as Node1 {
        UserAction --> ValidateLocal: Validate GeoJSON & Permissions
        ValidateLocal --> InsertPostGIS: Insert into geo_features Table
        InsertPostGIS --> WriteOutbox: Create Activity in federation_outbox
        WriteOutbox --> ReturnClient: Return 201 Created to Client
    }

    state "Sync Engine (Background Worker)" as SyncWorker {
        ReturnClient --> PollOutbox: Poll Outbox (Every 5 Seconds)
        PollOutbox --> FetchPeers: Fetch Active Peers (status = 'FOLLOWING')
        FetchPeers --> SignPayload: Compute SHA-256 & Sign with Private Key
        SignPayload --> HTTPPost: Send HTTPS POST /fedmap/v1/inbox to Node 2
    }

    state "Node 2 (Receiving Peer Server)" as Node2 {
        HTTPPost --> ReceiveInbox: Receive Payload at /fedmap/v1/inbox
        ReceiveInbox --> LookupKey: Fetch Node 1 Public Key from peer_registry
        LookupKey --> CheckSignature: Verify RSA Signature & SHA-256 Checksum

        state SignatureCheck <<choice>>
        CheckSignature --> SignatureCheck

        SignatureCheck --> RejectActivity: [Signature / Checksum Invalid]
        RejectActivity --> LogError: Record Error in federation_log
        LogError --> ReduceTrust: Decrease Node 1 Trust Score
        ReduceTrust --> Return400: Return 400/401 HTTP Error

        SignatureCheck --> ApplyMutation: [Signature & Checksum Valid]
        ApplyMutation --> PostGISUpsert: Atomic Upsert to geo_features (PostGIS)
        PostGISUpsert --> Return200: Return 200 OK (Success)
    }

    Return200 --> UpdateOutbox: Mark outbox_delivery as 'DELIVERED'
    Return400 --> ScheduleRetry: Increment Retry Count & Exponential Backoff
    UpdateOutbox --> [*]
    ScheduleRetry --> [*]
```

---

## 4. ⏱️ Sequence Diagram (Real-Time Inter-Server Sync Lifecycle)

The Sequence Diagram details the exact message passing lifecycle and HTTP request/response flow between the client application, local backend server, outbox sync workers, peer inbox endpoints, and PostGIS databases.

```mermaid
sequenceDiagram
    autonumber
    actor Client as 📱 Mobile / Web Client
    participant Node1_API as 🟢 Node 1 API Gateway
    participant Node1_DB as 🗄️ Node 1 PostGIS DB
    participant Node1_Worker as ⚙️ Node 1 Sync Engine
    participant Node2_Inbox as 🔵 Node 2 Inbox Endpoint
    participant Node2_DB as 🗄️ Node 2 PostGIS DB

    Client->>Node1_API: POST /fedmap/v1/collections/default/items (Create Feature)
    activate Node1_API
    Node1_API->>Node1_DB: INSERT INTO geo_features (Feature ID, Geom, Version=1)
    Node1_API->>Node1_DB: INSERT INTO federation_outbox (Activity JSON, Status='PENDING')
    Node1_API-->>Client: 201 Created (Feature JSON, ID)
    deactivate Node1_API

    loop Background Outbox Poller (Every 5s)
        Node1_Worker->>Node1_DB: SELECT * FROM federation_outbox WHERE status='PENDING'
        activate Node1_Worker
        Node1_DB-->>Node1_Worker: Return Pending Outbox Items
        Node1_Worker->>Node1_Worker: Compute SHA-256 Checksum of Payload
        Node1_Worker->>Node1_Worker: Sign (ActivityID + Checksum) with Node 1 Private Key
        
        Node1_Worker->>Node2_Inbox: POST /fedmap/v1/inbox (Activity JSON + SHA-256 + Signature)
        activate Node2_Inbox
        
        Node2_Inbox->>Node2_DB: SELECT public_key, trust_score FROM peer_registry WHERE server_id='server-001'
        Node2_DB-->>Node2_Inbox: Return Node 1 Public Key
        
        Node2_Inbox->>Node2_Inbox: Verify RSA-SHA256 Signature against Public Key
        Node2_Inbox->>Node2_Inbox: Assert SHA-256 Checksum == Payload Hash

        alt Verification Successful
            Node2_Inbox->>Node2_DB: INSERT/UPDATE geo_features (ST_GeomFromGeoJSON, Version=1)
            Node2_Inbox-->>Node1_Worker: 200 OK (Processed Successfully)
            Node1_Worker->>Node1_DB: UPDATE outbox_delivery SET status='DELIVERED'
        else Verification Failed
            Node2_Inbox-->>Node1_Worker: 401 Unauthorized / 400 Bad Request
            Node1_Worker->>Node1_DB: UPDATE outbox_delivery SET retry_count=retry_count+1, next_retry=NOW()+backoff
        end
        deactivate Node2_Inbox
        deactivate Node1_Worker
    end
```

---
*Diagrams prepared for Sabaragamuwa University Capstone Project Final Report (IS 4110 / SE5104).*

# GeoKeeper (`maptwo_app`) — Technical & Architectural Documentation

GeoKeeper is a full-stack location-bookmarking application designed for bookmarking, rating, categorizing, and managing places on interactive maps. The system features a **Flutter cross-platform mobile app** and a **Node.js/Express REST API backend** with seamless dual-database capabilities (PostgreSQL for cloud deployments such as Vercel/Supabase and SQLite for local development).

---

## 📋 Table of Contents
1. [Architecture & System Overview](#1-architecture--system-overview)
2. [Technology Stack](#2-technology-stack)
3. [Database Design & Schemas](#3-database-design--schemas)
4. [Backend REST API Reference](#4-backend-rest-api-reference)
5. [Flutter Mobile App Structure](#5-flutter-mobile-app-structure)
6. [Local Development Setup](#6-local-development-setup)
7. [Cloud Deployment Guide (Vercel)](#7-cloud-deployment-guide-vercel)
8. [Offline Fallback & Synchronization](#8-offline-fallback--synchronization)

---

## 1. Architecture & System Overview

GeoKeeper uses a decoupled architecture. The Flutter mobile app communicates over HTTP with the Node.js/Express backend, which serves as the data persistence and media storage layer.

```mermaid
graph TD
    A[Flutter App - Android/iOS/Web] -->|HTTP REST Requests| B[Express REST API - server.js]
    A -->|Offline Cache| C[SharedPreferences]
    B -->|Vercel / Cloud Env| D[(PostgreSQL Database)]
    B -->|Local Dev Env| E[(SQLite Database - places.db)]
    B -->|Device Photo Uploads| F[Local / Cloud File Storage]
```

### Key Architectural Concepts:
- **Dual Database Provider**: Dynamically selects PostgreSQL (via `pg`) if `DATABASE_URL` or `VERCEL` env variables are present; otherwise defaults to local SQLite (`places.db`).
- **Resilient Mobile Offline Support**: The Flutter app attempts to fetch and post data to the remote cloud server; if offline or unreachable, it seamlessly falls back to device local storage using `SharedPreferences`.
- **Media Upload Pipeline**: Supports device camera photo selection and local file upload via `multer` middleware.

---

## 2. Technology Stack

### Mobile Frontend (`/lib`)
- **Framework**: Flutter 3.12+ (Dart SDK `^3.12.2`)
- **Map Renderer**: `google_maps_flutter: ^2.10.0`
- **Networking**: `http: ^1.2.2`
- **Local Persistence**: `shared_preferences: ^2.5.2`
- **Media Picker**: `image_picker: ^1.1.2`
- **ID Generator**: `uuid: ^4.5.1`

### Backend (`/backend`)
- **Runtime**: Node.js v18+
- **Framework**: Express.js
- **Database Adapters**: `pg` (PostgreSQL), `sqlite3` (SQLite)
- **File Upload Handler**: `multer`
- **Cross-Origin Resource Sharing**: `cors`
- **Configuration**: `dotenv`
- **Deployment Platform**: Vercel Serverless Functions (`vercel.json`)

---

## 3. Database Design & Schemas

The database schema stores user-saved geographical places, custom notes, ratings, image references, and favorite flags.

### Table Name: `saved_places` (or `public.saved_places`)

| Column Name | SQL Data Type (Postgres / SQLite) | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(255)` / `TEXT` | `PRIMARY KEY` | Unique identifier (UUID or custom string) |
| `name` | `VARCHAR(255)` / `TEXT` | `NOT NULL` | Name of the location |
| `description` | `TEXT` | Default: `''` | Detailed notes or place description |
| `latitude` | `DOUBLE PRECISION` / `REAL` | `NOT NULL` | WGS84 Latitude coordinates |
| `longitude` | `DOUBLE PRECISION` / `REAL` | `NOT NULL` | WGS84 Longitude coordinates |
| `category` | `VARCHAR(100)` / `TEXT` | `NOT NULL` | Category tag (e.g. Restaurant, Park, Hotel, Custom) |
| `rating` | `DOUBLE PRECISION` / `REAL` | Default: `5.0` | User rating from 1.0 to 5.0 |
| `isFavorite` | `BOOLEAN` / `INTEGER` | Default: `FALSE` / `0` | Flag indicating favorite status |
| `address` | `TEXT` | Nullable | Formatted address string |
| `imagePath` | `TEXT` | Nullable | URL or local file path to place image |
| `createdAt` | `TIMESTAMPTZ` / `TEXT` | Default: `CURRENT_TIMESTAMP` | Timestamp when record was created |

---

## 4. Backend REST API Reference

The backend exposes a standard JSON REST API.

**Base URL (Production)**: `https://geo-keeper-theta.vercel.app/api`  
**Base URL (Local)**: `http://localhost:5000/api`

### Endpoints Overview

#### 1. System Health Check
- **Endpoint**: `GET /api/health`
- **Description**: Returns backend status and database connection details.
- **Response `200 OK`**:
```json
{
  "status": "OK",
  "message": "GeoKeeper Backend API Server is running smoothly!",
  "database": {
    "connected": true,
    "provider": "PostgreSQL",
    "timestamp": "2026-08-12T14:30:00.000Z"
  },
  "timestamp": "2026-08-12T14:30:00.000Z"
}
```

#### 2. Fetch All Saved Places
- **Endpoint**: `GET /api/places`
- **Description**: Returns array of all saved places sorted by `createdAt` descending.
- **Response `200 OK`**:
```json
[
  {
    "id": "place_1723471200_abc",
    "name": "Central Park Café",
    "description": "Great spot for coffee near the fountain.",
    "latitude": 40.785091,
    "longitude": -73.968285,
    "category": "Café",
    "rating": 4.8,
    "isFavorite": true,
    "address": "Central Park West, New York, NY",
    "imagePath": "/uploads/photo-1723471200.jpg",
    "createdAt": "2026-08-12T14:00:00.000Z"
  }
]
```

#### 3. Fetch Single Place Details
- **Endpoint**: `GET /api/places/:id`
- **Description**: Retrieve details for a specific place by ID.

#### 4. Save New Place
- **Endpoint**: `POST /api/places`
- **Headers**: `Content-Type: application/json`
- **Request Body**:
```json
{
  "id": "place_123456",
  "name": "Beach Sunset View",
  "description": "Scenic coastline spot.",
  "latitude": 34.0195,
  "longitude": -118.4912,
  "category": "Tourist",
  "rating": 5.0,
  "isFavorite": false,
  "address": "Santa Monica Pier, CA",
  "imagePath": null
}
```
- **Response `201 Created`**: Returns inserted place object.

#### 5. Update Place Details
- **Endpoint**: `PUT /api/places/:id`
- **Headers**: `Content-Type: application/json`
- **Description**: Updates existing place metadata.

#### 6. Toggle Favorite Status
- **Endpoint**: `PATCH /api/places/:id/favorite`
- **Description**: Toggles `isFavorite` boolean flag for the specified place.

#### 7. Delete Place
- **Endpoint**: `DELETE /api/places/:id`
- **Description**: Removes place from the database.

#### 8. Upload Place Image
- **Endpoint**: `POST /api/upload`
- **Content-Type**: `multipart/form-data`
- **Form Field**: `image` (file)
- **Response `201 Created`**:
```json
{
  "message": "Image uploaded successfully",
  "filename": "photo-1723471200-987654321.jpg",
  "url": "/uploads/photo-1723471200-987654321.jpg"
}
```

---

## 5. Flutter Mobile App Structure

```
lib/
├── config/           # App constants and configuration
├── models/           # Data models (SavedPlace)
├── screens/          # Application screens (HomeScreen)
├── services/         # ApiService (REST HTTP) & StorageService (SharedPreferences)
├── widgets/          # Map controls, place detail dialogs, search bars, sheets
└── main.dart         # Main entry point & MaterialApp configuration
```

### Primary Components:
- [main.dart](file:///c:/Users/HP/maptwo_app/lib/main.dart): Sets up Material 3 theme, dark theme, and mounts `HomeScreen`.
- [home_screen.dart](file:///c:/Users/HP/maptwo_app/lib/screens/home_screen.dart): Interactive Google Maps interface with custom markers, search filters, category selectors, and place creation dialogs.
- [api_service.dart](file:///c:/Users/HP/maptwo_app/lib/services/api_service.dart): Manages HTTP GET/POST/PUT/DELETE requests to the cloud backend.
- [storage_service.dart](file:///c:/Users/HP/maptwo_app/lib/services/storage_service.dart): Handles offline caching using `SharedPreferences`.

---

## 6. Local Development Setup

### Prerequisites
- Flutter SDK 3.12 or higher installed
- Node.js v18+ and `npm` installed

### Step 1: Start Backend Server
```bash
# Navigate to backend directory
cd backend

# Install Node dependencies
npm install

# Start local server (uses local SQLite database)
npm start
```
The server will start on `http://localhost:5000`.

### Step 2: Configure Environment Variables (Optional)
Copy `.env.example` to `.env` inside `backend/`:
```env
PORT=5000
DB_PROVIDER=sqlite
DATABASE_URL=postgresql://postgres:password@localhost:5432/geokeeper
```

### Step 3: Run Flutter Application
```bash
# Return to root directory
cd ..

# Get Dart packages
flutter pub get

# Run application on emulator or connected device
flutter run
```

---

## 7. Cloud Deployment Guide (Vercel)

The backend is configured for direct deployment as a Serverless Function on **Vercel**.

### Configuration Files
- [vercel.json](file:///c:/Users/HP/maptwo_app/vercel.json): Routes all incoming API traffic (`/api/(.*)`) to `backend/server.js`.
- [backend/db_postgres.js](file:///c:/Users/HP/maptwo_app/backend/db_postgres.js): Establishes a pooled connection with PostgreSQL / Supabase when deployed on Vercel.

### Vercel Deployment Steps:
1. Push project repository to GitHub/GitLab.
2. Import project into Vercel dashboard.
3. Add Environment Variable in Vercel settings:
   - `DATABASE_URL`: `postgresql://<user>:<password>@<host>:5432/<dbname>?sslmode=require`
4. Deploy project. Vercel automatically deploys the serverless REST API functions.

---

## 8. Offline Fallback & Synchronization

GeoKeeper ensures zero data loss during network disruptions:
1. When user saves a new place, `ApiService` attempts a network request to the backend.
2. If network request fails or times out, `StorageService` immediately saves the place to `SharedPreferences` locally.
3. Upon network reconnection or app relaunch, local cached places are synchronized with the backend.

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const isProduction = process.env.VERCEL || process.env.NODE_ENV === 'production';
const useSsl = process.env.PG_SSL === 'true' || isProduction;
const hasDbUrl = Boolean(process.env.DATABASE_URL);

// File fallback storage location
const fallbackFilePath = process.env.VERCEL
  ? path.join('/tmp', 'geokeeper_places_store.json')
  : path.join(__dirname, 'places_fallback.json');

// Read fallback places from disk
function loadFallbackPlaces() {
  try {
    if (fs.existsSync(fallbackFilePath)) {
      const data = fs.readFileSync(fallbackFilePath, 'utf8');
      return JSON.parse(data) || [];
    }
  } catch (e) {
    console.error('Error reading fallback storage file:', e.message);
  }
  return [];
}

// Save fallback places to disk
function saveFallbackPlaces(places) {
  try {
    fs.writeFileSync(fallbackFilePath, JSON.stringify(places, null, 2), 'utf8');
  } catch (e) {
    console.error('Error writing fallback storage file:', e.message);
  }
}

let fallbackPlaces = loadFallbackPlaces();

// Create a PostgreSQL connection pool if DATABASE_URL is provided, or default pool
const poolConfig = hasDbUrl
  ? {
      connectionString: process.env.DATABASE_URL,
      ssl: useSsl ? { rejectUnauthorized: false } : false,
      connectionTimeoutMillis: 5000
    }
  : {
      host: process.env.PG_HOST || '127.0.0.1',
      port: process.env.PG_PORT || 5432,
      database: process.env.PG_DATABASE || 'geokeeper_db',
      user: process.env.PG_USER || 'postgres',
      password: process.env.PG_PASSWORD || 'postgres',
      ssl: useSsl ? { rejectUnauthorized: false } : false,
      connectionTimeoutMillis: 3000
    };

const pool = new Pool(poolConfig);

// Test connection and auto-create table safely
let isTableInitialized = false;
let isPgAvailable = false;

async function ensureTableCreated() {
  if (isTableInitialized && isPgAvailable) return true;
  if (!hasDbUrl && !process.env.PG_HOST) {
    isPgAvailable = false;
    return false;
  }
  try {
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS saved_places (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        latitude DOUBLE PRECISION NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        category VARCHAR(100) NOT NULL,
        rating DOUBLE PRECISION DEFAULT 5.0,
        "isFavorite" BOOLEAN DEFAULT FALSE,
        address TEXT,
        "imagePath" TEXT,
        "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `;
    await pool.query(createTableQuery);
    isTableInitialized = true;
    isPgAvailable = true;
    console.log('✅ PostgreSQL table "saved_places" ready.');
    return true;
  } catch (err) {
    isPgAvailable = false;
    console.warn('ℹ️ PostgreSQL not available, using fallback storage store:', err.message);
    return false;
  }
}

// Trigger initial table check
ensureTableCreated().catch(() => {});

// Database query helpers with fallback support
const getAllPlaces = async () => {
  const pgReady = await ensureTableCreated();
  if (pgReady) {
    try {
      const res = await pool.query('SELECT * FROM saved_places ORDER BY "createdAt" DESC');
      return res.rows || [];
    } catch (err) {
      console.error('Error in getAllPlaces (PG):', err.message);
    }
  }
  return fallbackPlaces;
};

const getPlaceById = async (id) => {
  const pgReady = await ensureTableCreated();
  if (pgReady) {
    try {
      const res = await pool.query('SELECT * FROM saved_places WHERE id = $1', [id]);
      if (res.rows[0]) return res.rows[0];
    } catch (err) {
      console.error('Error in getPlaceById (PG):', err.message);
    }
  }
  return fallbackPlaces.find(p => p.id === id) || null;
};

const insertPlace = async (place) => {
  // Always update fallback store
  const existingIdx = fallbackPlaces.findIndex(p => p.id === place.id);
  if (existingIdx !== -1) {
    fallbackPlaces[existingIdx] = place;
  } else {
    fallbackPlaces.unshift(place);
  }
  saveFallbackPlaces(fallbackPlaces);

  const pgReady = await ensureTableCreated();
  if (pgReady) {
    try {
      const query = `
        INSERT INTO saved_places 
        (id, name, description, latitude, longitude, category, rating, "isFavorite", address, "imagePath", "createdAt")
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name,
          description = EXCLUDED.description,
          latitude = EXCLUDED.latitude,
          longitude = EXCLUDED.longitude,
          category = EXCLUDED.category,
          rating = EXCLUDED.rating,
          "isFavorite" = EXCLUDED."isFavorite",
          address = EXCLUDED.address,
          "imagePath" = EXCLUDED."imagePath"
        RETURNING *;
      `;
      const values = [
        place.id,
        place.name,
        place.description || '',
        place.latitude,
        place.longitude,
        place.category,
        place.rating || 5.0,
        place.isFavorite || false,
        place.address || null,
        place.imagePath || null,
        place.createdAt || new Date().toISOString()
      ];
      const res = await pool.query(query, values);
      return res.rows[0];
    } catch (err) {
      console.error('Error in insertPlace (PG):', err.message);
    }
  }
  return place;
};

const updatePlace = async (id, place) => {
  const index = fallbackPlaces.findIndex(p => p.id === id);
  if (index !== -1) {
    fallbackPlaces[index] = { ...fallbackPlaces[index], ...place };
    saveFallbackPlaces(fallbackPlaces);
  }

  const pgReady = await ensureTableCreated();
  if (pgReady) {
    try {
      const query = `
        UPDATE saved_places 
        SET name = $1, description = $2, latitude = $3, longitude = $4, category = $5, 
            rating = $6, "isFavorite" = $7, address = $8, "imagePath" = $9
        WHERE id = $10
        RETURNING *;
      `;
      const values = [
        place.name,
        place.description || '',
        place.latitude,
        place.longitude,
        place.category,
        place.rating || 5.0,
        place.isFavorite || false,
        place.address || null,
        place.imagePath || null,
        id
      ];
      const res = await pool.query(query, values);
      if (res.rows[0]) return res.rows[0];
    } catch (err) {
      console.error('Error in updatePlace (PG):', err.message);
    }
  }
  return place;
};

const toggleFavorite = async (id) => {
  let newFavStatus = false;
  const place = fallbackPlaces.find(p => p.id === id);
  if (place) {
    place.isFavorite = !place.isFavorite;
    newFavStatus = place.isFavorite;
    saveFallbackPlaces(fallbackPlaces);
  }

  const pgReady = await ensureTableCreated();
  if (pgReady) {
    try {
      const query = `
        UPDATE saved_places 
        SET "isFavorite" = NOT "isFavorite"
        WHERE id = $1
        RETURNING id, "isFavorite";
      `;
      const res = await pool.query(query, [id]);
      if (res.rows[0]) return res.rows[0];
    } catch (err) {
      console.error('Error in toggleFavorite (PG):', err.message);
    }
  }
  return { id, isFavorite: newFavStatus };
};

const deletePlace = async (id) => {
  fallbackPlaces = fallbackPlaces.filter(p => p.id !== id);
  saveFallbackPlaces(fallbackPlaces);

  const pgReady = await ensureTableCreated();
  if (pgReady) {
    try {
      const res = await pool.query('DELETE FROM saved_places WHERE id = $1', [id]);
      return { id, deleted: res.rowCount > 0 };
    } catch (err) {
      console.error('Error in deletePlace (PG):', err.message);
    }
  }
  return { id, deleted: true };
};

const checkDbConnection = async () => {
  try {
    const res = await pool.query('SELECT NOW()');
    return { connected: true, provider: 'PostgreSQL', time: res.rows[0].now };
  } catch (err) {
    return { connected: false, provider: 'Fallback File/Memory Store', error: err.message };
  }
};

module.exports = {
  pool,
  getAllPlaces,
  getPlaceById,
  insertPlace,
  updatePlace,
  toggleFavorite,
  deletePlace,
  checkDbConnection
};

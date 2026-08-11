const { Pool } = require('pg');
require('dotenv').config();

const isProduction = process.env.VERCEL || process.env.NODE_ENV === 'production';
const useSsl = process.env.PG_SSL === 'true' || isProduction;

// Create a PostgreSQL connection pool using DATABASE_URL (Supabase) or individual variables
const poolConfig = process.env.DATABASE_URL
  ? {
      connectionString: process.env.DATABASE_URL,
      ssl: useSsl ? { rejectUnauthorized: false } : false,
      connectionTimeoutMillis: 10000
    }
  : {
      host: process.env.PG_HOST || 'localhost',
      port: process.env.PG_PORT || 5432,
      database: process.env.PG_DATABASE || 'geokeeper_db',
      user: process.env.PG_USER || 'postgres',
      password: process.env.PG_PASSWORD || 'postgres',
      ssl: useSsl ? { rejectUnauthorized: false } : false,
      connectionTimeoutMillis: 10000
    };

const pool = new Pool(poolConfig);

// Test connection and auto-create table safely
let isTableInitialized = false;
async function ensureTableCreated() {
  if (isTableInitialized) return;
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
    console.log('✅ PostgreSQL table "saved_places" ready.');
  } catch (err) {
    console.error('⚠️ PostgreSQL table init warning:', err.message);
  }
}

// Trigger initial table check
ensureTableCreated();

// PostgreSQL promise helper functions
const getAllPlaces = async () => {
  const res = await pool.query('SELECT * FROM saved_places ORDER BY "createdAt" DESC');
  return res.rows;
};

const getPlaceById = async (id) => {
  const res = await pool.query('SELECT * FROM saved_places WHERE id = $1', [id]);
  return res.rows[0] || null;
};

const insertPlace = async (place) => {
  const query = `
    INSERT INTO saved_places 
    (id, name, description, latitude, longitude, category, rating, "isFavorite", address, "imagePath", "createdAt")
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
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
};

const updatePlace = async (id, place) => {
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
  return res.rows[0];
};

const toggleFavorite = async (id) => {
  const query = `
    UPDATE saved_places 
    SET "isFavorite" = NOT "isFavorite"
    WHERE id = $1
    RETURNING id, "isFavorite";
  `;
  const res = await pool.query(query, [id]);
  return res.rows[0];
};

const deletePlace = async (id) => {
  const res = await pool.query('DELETE FROM saved_places WHERE id = $1', [id]);
  return { id, deleted: res.rowCount > 0 };
};

module.exports = {
  pool,
  getAllPlaces,
  getPlaceById,
  insertPlace,
  updatePlace,
  toggleFavorite,
  deletePlace
};

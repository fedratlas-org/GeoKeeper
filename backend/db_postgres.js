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
  if (isTableInitialized) return true;
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
    return true;
  } catch (err) {
    console.error('⚠️ PostgreSQL table init warning:', err.message);
    return false;
  }
}

// Trigger initial table check
ensureTableCreated().catch(() => {});

// PostgreSQL query helpers with safe error handling
const getAllPlaces = async () => {
  try {
    await ensureTableCreated();
    const res = await pool.query('SELECT * FROM saved_places ORDER BY "createdAt" DESC');
    return res.rows || [];
  } catch (err) {
    console.error('Error in getAllPlaces:', err.message);
    return [];
  }
};

const getPlaceById = async (id) => {
  try {
    await ensureTableCreated();
    const res = await pool.query('SELECT * FROM saved_places WHERE id = $1', [id]);
    return res.rows[0] || null;
  } catch (err) {
    console.error('Error in getPlaceById:', err.message);
    return null;
  }
};

const insertPlace = async (place) => {
  try {
    await ensureTableCreated();
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
  } catch (err) {
    console.error('Error in insertPlace:', err.message);
    return place;
  }
};

const updatePlace = async (id, place) => {
  try {
    await ensureTableCreated();
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
  } catch (err) {
    console.error('Error in updatePlace:', err.message);
    return place;
  }
};

const toggleFavorite = async (id) => {
  try {
    await ensureTableCreated();
    const query = `
      UPDATE saved_places 
      SET "isFavorite" = NOT "isFavorite"
      WHERE id = $1
      RETURNING id, "isFavorite";
    `;
    const res = await pool.query(query, [id]);
    return res.rows[0];
  } catch (err) {
    console.error('Error in toggleFavorite:', err.message);
    return { id, isFavorite: false };
  }
};

const deletePlace = async (id) => {
  try {
    await ensureTableCreated();
    const res = await pool.query('DELETE FROM saved_places WHERE id = $1', [id]);
    return { id, deleted: res.rowCount > 0 };
  } catch (err) {
    console.error('Error in deletePlace:', err.message);
    return { id, deleted: false };
  }
};

const checkDbConnection = async () => {
  try {
    const res = await pool.query('SELECT NOW()');
    return { connected: true, time: res.rows[0].now };
  } catch (err) {
    return { connected: false, error: err.message };
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

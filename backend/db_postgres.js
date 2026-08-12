const { Pool } = require('pg');
require('dotenv').config();

const isProduction =
  process.env.VERCEL === '1' ||
  process.env.VERCEL === 'true' ||
  process.env.NODE_ENV === 'production';

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  console.error('❌ DATABASE_URL is not configured.');
}

const pool = new Pool({
  connectionString: databaseUrl,

  // Supabase/Vercel PostgreSQL normally requires SSL.
  ssl: isProduction
    ? { rejectUnauthorized: false }
    : process.env.PG_SSL === 'true'
      ? { rejectUnauthorized: false }
      : false,

  connectionTimeoutMillis: 10000,

  // Keep the pool small for serverless environments.
  max: 5,

  idleTimeoutMillis: 10000,
});

let databaseReady = false;

/**
 * Check PostgreSQL connection.
 */
async function checkDatabase() {
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is missing');
  }

  const result = await pool.query('SELECT NOW() AS now');

  console.log(
    `✅ PostgreSQL connected successfully at ${result.rows[0].now}`
  );

  return true;
}

/**
 * Ensure the GeoKeeper table exists.
 *
 * NOTE:
 * We use public.saved_places explicitly.
 */
async function ensureTableCreated() {
  if (databaseReady) {
    return true;
  }

  try {
    await checkDatabase();

    await pool.query(`
      CREATE TABLE IF NOT EXISTS public.saved_places (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT DEFAULT '',
        latitude DOUBLE PRECISION NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        category VARCHAR(100) NOT NULL,
        rating DOUBLE PRECISION DEFAULT 5.0,
        "isFavorite" BOOLEAN DEFAULT FALSE,
        address TEXT,
        "imagePath" TEXT,
        "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
    `);

    databaseReady = true;

    console.log('✅ PostgreSQL table public.saved_places is ready.');

    return true;
  } catch (error) {
    databaseReady = false;

    console.error(
      '❌ PostgreSQL initialization failed:',
      error.message
    );

    throw error;
  }
}

/**
 * GET ALL PLACES
 */
async function getAllPlaces() {
  await ensureTableCreated();

  try {
    const result = await pool.query(`
      SELECT
        id,
        name,
        description,
        latitude,
        longitude,
        category,
        rating,
        "isFavorite",
        address,
        "imagePath",
        "createdAt"
      FROM public.saved_places
      ORDER BY "createdAt" DESC;
    `);

    console.log(
      `📥 GET /api/places → ${result.rows.length} places`
    );

    return result.rows;
  } catch (error) {
    console.error(
      '❌ Error fetching places:',
      error.message
    );

    throw error;
  }
}

/**
 * GET ONE PLACE
 */
async function getPlaceById(id) {
  await ensureTableCreated();

  try {
    const result = await pool.query(
      `
      SELECT
        id,
        name,
        description,
        latitude,
        longitude,
        category,
        rating,
        "isFavorite",
        address,
        "imagePath",
        "createdAt"
      FROM public.saved_places
      WHERE id = $1
      `,
      [id]
    );

    return result.rows[0] || null;
  } catch (error) {
    console.error(
      '❌ Error fetching place by ID:',
      error.message
    );

    throw error;
  }
}

/**
 * INSERT PLACE
 */
async function insertPlace(place) {
  await ensureTableCreated();

  try {
    const query = `
      INSERT INTO public.saved_places (
        id,
        name,
        description,
        latitude,
        longitude,
        category,
        rating,
        "isFavorite",
        address,
        "imagePath",
        "createdAt"
      )
      VALUES (
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11
      )
      ON CONFLICT (id)
      DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        category = EXCLUDED.category,
        rating = EXCLUDED.rating,
        "isFavorite" = EXCLUDED."isFavorite",
        address = EXCLUDED.address,
        "imagePath" = EXCLUDED."imagePath"
      RETURNING
        id,
        name,
        description,
        latitude,
        longitude,
        category,
        rating,
        "isFavorite",
        address,
        "imagePath",
        "createdAt";
    `;

    const values = [
      place.id,
      place.name,
      place.description || '',
      Number(place.latitude),
      Number(place.longitude),
      place.category,
      Number(place.rating ?? 5.0),
      Boolean(place.isFavorite),
      place.address || null,
      place.imagePath || null,
      place.createdAt || new Date().toISOString(),
    ];

    console.log('📤 INSERTING PLACE INTO POSTGRESQL');
    console.log('ID:', place.id);
    console.log('Name:', place.name);

    const result = await pool.query(query, values);

    console.log('✅ PLACE INSERTED INTO POSTGRESQL');

    return result.rows[0];
  } catch (error) {
    console.error(
      '❌ PostgreSQL INSERT FAILED:',
      error.message
    );

    throw error;
  }
}

/**
 * UPDATE PLACE
 */
async function updatePlace(id, place) {
  await ensureTableCreated();

  try {
    const query = `
      UPDATE public.saved_places
      SET
        name = $1,
        description = $2,
        latitude = $3,
        longitude = $4,
        category = $5,
        rating = $6,
        "isFavorite" = $7,
        address = $8,
        "imagePath" = $9
      WHERE id = $10
      RETURNING
        id,
        name,
        description,
        latitude,
        longitude,
        category,
        rating,
        "isFavorite",
        address,
        "imagePath",
        "createdAt";
    `;

    const values = [
      place.name,
      place.description || '',
      Number(place.latitude),
      Number(place.longitude),
      place.category,
      Number(place.rating ?? 5.0),
      Boolean(place.isFavorite),
      place.address || null,
      place.imagePath || null,
      id,
    ];

    const result = await pool.query(query, values);

    if (!result.rows[0]) {
      throw new Error(`Place not found: ${id}`);
    }

    console.log(`✅ PLACE UPDATED: ${id}`);

    return result.rows[0];
  } catch (error) {
    console.error(
      '❌ PostgreSQL UPDATE FAILED:',
      error.message
    );

    throw error;
  }
}

/**
 * TOGGLE FAVORITE
 */
async function toggleFavorite(id) {
  await ensureTableCreated();

  try {
    const result = await pool.query(
      `
      UPDATE public.saved_places
      SET "isFavorite" = NOT "isFavorite"
      WHERE id = $1
      RETURNING
        id,
        "isFavorite";
      `,
      [id]
    );

    if (!result.rows[0]) {
      throw new Error(`Place not found: ${id}`);
    }

    console.log(
      `❤️ FAVORITE UPDATED: ${id} → ${result.rows[0].isFavorite}`
    );

    return result.rows[0];
  } catch (error) {
    console.error(
      '❌ PostgreSQL FAVORITE UPDATE FAILED:',
      error.message
    );

    throw error;
  }
}

/**
 * DELETE PLACE
 */
async function deletePlace(id) {
  await ensureTableCreated();

  try {
    const result = await pool.query(
      `
      DELETE FROM public.saved_places
      WHERE id = $1
      `,
      [id]
    );

    console.log(
      `🗑️ PLACE DELETED: ${id}`
    );

    return {
      id,
      deleted: result.rowCount > 0,
    };
  } catch (error) {
    console.error(
      '❌ PostgreSQL DELETE FAILED:',
      error.message
    );

    throw error;
  }
}

/**
 * DATABASE HEALTH CHECK
 */
async function checkDbConnection() {
  try {
    await ensureTableCreated();

    return {
      connected: true,
      provider: 'PostgreSQL',
    };
  } catch (error) {
    return {
      connected: false,
      provider: 'PostgreSQL',
      error: error.message,
    };
  }
}

/**
 * Export functions
 */
module.exports = {
  pool,
  getAllPlaces,
  getPlaceById,
  insertPlace,
  updatePlace,
  toggleFavorite,
  deletePlace,
  checkDbConnection,
};
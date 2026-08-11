const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const fs = require('fs');

// Select database provider: PostgreSQL for Vercel/Supabase, or SQLite for local dev
const usePostgres = process.env.VERCEL || process.env.DB_PROVIDER === 'postgres' || Boolean(process.env.DATABASE_URL);
console.log(`ℹ️ Database Provider: ${usePostgres ? 'PostgreSQL' : 'SQLite'}`);

let dbModule;
try {
  dbModule = usePostgres ? require('./db_postgres') : require('./database');
} catch (e) {
  console.error('Database module loading fallback:', e.message);
  dbModule = require('./db_postgres');
}

const {
  getAllPlaces,
  getPlaceById,
  insertPlace,
  updatePlace,
  toggleFavorite,
  deletePlace
} = dbModule;

const app = express();
const PORT = process.env.PORT || 5000;

// Enable CORS and JSON body parsing
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Serve uploaded images statically
app.use('/uploads', express.static(uploadsDir));

// Multer storage config for device photo uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, 'photo-' + uniqueSuffix + ext);
  }
});
const upload = multer({ storage });

// Root endpoint for Vercel server status
app.get('/', (req, res) => {
  res.json({
    status: 'OK',
    message: 'GeoKeeper Backend REST API Server is running on Vercel!',
    endpoints: {
      health: '/api/health',
      places: '/api/places'
    },
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint
app.get('/api/health', async (req, res) => {
  let dbStatus = { connected: false };
  if (usePostgres) {
    try {
      const dbModule = require('./db_postgres');
      if (dbModule.checkDbConnection) {
        dbStatus = await dbModule.checkDbConnection();
      }
    } catch (e) {
      dbStatus = { connected: false, error: e.message };
    }
  }
  res.json({
    status: 'OK',
    message: 'GeoKeeper Backend API Server is running smoothly!',
    provider: usePostgres ? 'PostgreSQL' : 'SQLite',
    database: dbStatus,
    timestamp: new Date().toISOString()
  });
});

// GET /api/places - Fetch all saved places
app.get('/api/places', async (req, res) => {
  try {
    const places = await getAllPlaces();
    res.json(places);
  } catch (err) {
    console.error('Error fetching places:', err);
    res.status(500).json({ error: 'Failed to fetch saved places' });
  }
});

// GET /api/places/:id - Fetch single place details
app.get('/api/places/:id', async (req, res) => {
  try {
    const place = await getPlaceById(req.params.id);
    if (!place) {
      return res.status(404).json({ error: 'Place not found' });
    }
    res.json(place);
  } catch (err) {
    console.error('Error fetching place:', err);
    res.status(500).json({ error: 'Failed to fetch place' });
  }
});

// POST /api/places - Save a new place
app.post('/api/places', async (req, res) => {
  try {
    const { id, name, description, latitude, longitude, category, rating, isFavorite, address, imagePath, createdAt } = req.body;

    if (!name || latitude === undefined || longitude === undefined || !category) {
      return res.status(400).json({ error: 'Missing required fields: name, latitude, longitude, category' });
    }

    const newPlace = {
      id: id || Date.now().toString() + '_' + Math.random().toString(36).substring(2, 7),
      name,
      description: description || '',
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      category,
      rating: rating ? parseFloat(rating) : 5.0,
      isFavorite: Boolean(isFavorite),
      address: address || null,
      imagePath: imagePath || null,
      createdAt: createdAt || new Date().toISOString()
    };

    const saved = await insertPlace(newPlace);
    res.status(201).json(saved);
  } catch (err) {
    console.error('Error inserting place:', err);
    res.status(500).json({ error: 'Failed to save place' });
  }
});

// PUT /api/places/:id - Update place details
app.put('/api/places/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const existing = await getPlaceById(id);
    if (!existing) {
      return res.status(404).json({ error: 'Place not found' });
    }

    const updatedPlace = {
      id,
      name: req.body.name || existing.name,
      description: req.body.description !== undefined ? req.body.description : existing.description,
      latitude: req.body.latitude !== undefined ? parseFloat(req.body.latitude) : existing.latitude,
      longitude: req.body.longitude !== undefined ? parseFloat(req.body.longitude) : existing.longitude,
      category: req.body.category || existing.category,
      rating: req.body.rating !== undefined ? parseFloat(req.body.rating) : existing.rating,
      isFavorite: req.body.isFavorite !== undefined ? Boolean(req.body.isFavorite) : existing.isFavorite,
      address: req.body.address !== undefined ? req.body.address : existing.address,
      imagePath: req.body.imagePath !== undefined ? req.body.imagePath : existing.imagePath,
      createdAt: existing.createdAt
    };

    await updatePlace(id, updatedPlace);
    res.json(updatedPlace);
  } catch (err) {
    console.error('Error updating place:', err);
    res.status(500).json({ error: 'Failed to update place' });
  }
});

// PATCH /api/places/:id/favorite - Toggle favorite status
app.patch('/api/places/:id/favorite', async (req, res) => {
  try {
    const result = await toggleFavorite(req.params.id);
    res.json(result);
  } catch (err) {
    console.error('Error toggling favorite:', err);
    res.status(500).json({ error: 'Failed to toggle favorite status' });
  }
});

// DELETE /api/places/:id - Delete a place
app.delete('/api/places/:id', async (req, res) => {
  try {
    const result = await deletePlace(req.params.id);
    res.json(result);
  } catch (err) {
    console.error('Error deleting place:', err);
    res.status(500).json({ error: 'Failed to delete place' });
  }
});

// POST /api/upload - Handle image file upload
app.post('/api/upload', upload.single('image'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image file provided' });
  }
  const imageUrl = `/uploads/${req.file.filename}`;
  res.status(201).json({
    message: 'Image uploaded successfully',
    filename: req.file.filename,
    url: imageUrl
  });
});

// Global Express Error Handler Middleware for Vercel
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message || 'An unexpected error occurred'
  });
});

// Start Express Server locally (skipped in Vercel Serverless environment)
if (!process.env.VERCEL) {
  const server = app.listen(PORT, () => {
    console.log(`=================================================`);
    console.log(`🚀 GeoKeeper Backend Server running at http://localhost:${PORT}`);
    console.log(`   - Health check: http://localhost:${PORT}/api/health`);
    console.log(`   - REST Endpoints: http://localhost:${PORT}/api/places`);
    console.log(`=================================================`);
  });

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.log(`⚠️ Port ${PORT} is already in use — the GeoKeeper Backend Server is ALREADY running!`);
    } else {
      console.error('Server error:', err);
    }
  });
}

// Export Express app for Vercel Serverless Functions
module.exports = app;

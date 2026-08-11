const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'places.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening SQLite database:', err.message);
  } else {
    console.log('Connected to SQLite database at:', dbPath);
    initDatabase();
  }
});

function initDatabase() {
  const createTableQuery = `
    CREATE TABLE IF NOT EXISTS saved_places (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      category TEXT NOT NULL,
      rating REAL DEFAULT 5.0,
      isFavorite INTEGER DEFAULT 0,
      address TEXT,
      imagePath TEXT,
      createdAt TEXT NOT NULL
    );
  `;

  db.run(createTableQuery, (err) => {
    if (err) {
      console.error('Error creating saved_places table:', err.message);
    } else {
      console.log('Database table "saved_places" is ready.');
    }
  });
}

// Database helper functions using Promises
const getAllPlaces = () => {
  return new Promise((resolve, reject) => {
    db.all('SELECT * FROM saved_places ORDER BY createdAt DESC', [], (err, rows) => {
      if (err) reject(err);
      else {
        // Convert integer boolean isFavorite to boolean
        const places = rows.map(r => ({
          ...r,
          isFavorite: Boolean(r.isFavorite)
        }));
        resolve(places);
      }
    });
  });
};

const getPlaceById = (id) => {
  return new Promise((resolve, reject) => {
    db.get('SELECT * FROM saved_places WHERE id = ?', [id], (err, row) => {
      if (err) reject(err);
      else if (!row) resolve(null);
      else {
        resolve({
          ...row,
          isFavorite: Boolean(row.isFavorite)
        });
      }
    });
  });
};

const insertPlace = (place) => {
  return new Promise((resolve, reject) => {
    const query = `
      INSERT INTO saved_places 
      (id, name, description, latitude, longitude, category, rating, isFavorite, address, imagePath, createdAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    const params = [
      place.id,
      place.name,
      place.description || '',
      place.latitude,
      place.longitude,
      place.category,
      place.rating || 5.0,
      place.isFavorite ? 1 : 0,
      place.address || null,
      place.imagePath || null,
      place.createdAt || new Date().toISOString()
    ];

    db.run(query, params, function (err) {
      if (err) reject(err);
      else resolve(place);
    });
  });
};

const updatePlace = (id, place) => {
  return new Promise((resolve, reject) => {
    const query = `
      UPDATE saved_places 
      SET name = ?, description = ?, latitude = ?, longitude = ?, category = ?, 
          rating = ?, isFavorite = ?, address = ?, imagePath = ?
      WHERE id = ?
    `;
    const params = [
      place.name,
      place.description || '',
      place.latitude,
      place.longitude,
      place.category,
      place.rating || 5.0,
      place.isFavorite ? 1 : 0,
      place.address || null,
      place.imagePath || null,
      id
    ];

    db.run(query, params, function (err) {
      if (err) reject(err);
      else resolve(place);
    });
  });
};

const toggleFavorite = (id) => {
  return new Promise((resolve, reject) => {
    db.get('SELECT isFavorite FROM saved_places WHERE id = ?', [id], (err, row) => {
      if (err || !row) return reject(err || new Error('Place not found'));
      const newFavStatus = row.isFavorite ? 0 : 1;
      db.run('UPDATE saved_places SET isFavorite = ? WHERE id = ?', [newFavStatus, id], (uErr) => {
        if (uErr) reject(uErr);
        else resolve({ id, isFavorite: Boolean(newFavStatus) });
      });
    });
  });
};

const deletePlace = (id) => {
  return new Promise((resolve, reject) => {
    db.run('DELETE FROM saved_places WHERE id = ?', [id], function (err) {
      if (err) reject(err);
      else resolve({ id, deleted: this.changes > 0 });
    });
  });
};

module.exports = {
  db,
  getAllPlaces,
  getPlaceById,
  insertPlace,
  updatePlace,
  toggleFavorite,
  deletePlace
};

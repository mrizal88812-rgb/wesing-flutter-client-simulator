import { Pool } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

// Create a pool for PostgreSQL connection
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:arday@localhost:5432/wesing',
});

// Run this once to initialize tables
export async function initDb() {
  let client;
  try {
    client = await pool.connect();
  } catch (e) {
    console.error("Failed to connect to PostgreSQL database. Please make sure the DATABASE_URL secret is set and the database is running.", e.message);
    return;
  }

  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(255) PRIMARY KEY,
        username VARCHAR(255) NOT NULL,
        avatar VARCHAR(255),
        followers_count INT DEFAULT 0,
        level INT DEFAULT 1,
        coins INT DEFAULT 0
      );
      
      CREATE TABLE IF NOT EXISTS songs (
        id VARCHAR(255) PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        artist VARCHAR(255) NOT NULL,
        cover_url VARCHAR(255),
        audio_url VARCHAR(255) NOT NULL,
        play_count INT DEFAULT 0,
        tags JSONB,
        lyrics JSONB
      );

      CREATE TABLE IF NOT EXISTS recordings (
        id VARCHAR(255) PRIMARY KEY,
        user_id VARCHAR(255) REFERENCES users(id),
        song_id VARCHAR(255) REFERENCES songs(id),
        audio_url VARCHAR(255) NOT NULL,
        cover_url VARCHAR(255),
        caption TEXT,
        visibility VARCHAR(50) DEFAULT 'Public',
        score INT DEFAULT 0,
        likes_count INT DEFAULT 0,
        comments_count INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      ALTER TABLE recordings ADD COLUMN IF NOT EXISTS cover_url VARCHAR(255);
      ALTER TABLE recordings ADD COLUMN IF NOT EXISTS caption TEXT;
      ALTER TABLE recordings ADD COLUMN IF NOT EXISTS visibility VARCHAR(50) DEFAULT 'Public';
      ALTER TABLE recordings ADD COLUMN IF NOT EXISTS song_start FLOAT DEFAULT 0.0;
      ALTER TABLE recordings ADD COLUMN IF NOT EXISTS song_end FLOAT DEFAULT 0.0;
      ALTER TABLE recordings ADD COLUMN IF NOT EXISTS duration FLOAT DEFAULT 0.0;

      CREATE TABLE IF NOT EXISTS presets (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        icon VARCHAR(255),
        description TEXT,
        enabled BOOLEAN DEFAULT true,
        dsp JSONB
      );
    `);
    console.log("PostgreSQL database tables initialized successfully.");

    // Check if we need to seed
    const res = await client.query('SELECT count(*) FROM users');
    if (parseInt(res.rows[0].count) === 0) {
      await client.query(`
        INSERT INTO users (id, username, avatar, followers_count, level, coins)
        VALUES ('user_1', 'Nafisa', 'https://i.pravatar.cc/150?u=nafisa', 120, 5, 1000);
      `);

      await client.query(`
        INSERT INTO songs (id, title, artist, cover_url, audio_url, play_count, tags, lyrics)
        VALUES 
        ('song-001', 'Shape of You', 'Ed Sheeran', '/storage/songs/song-001/cover.webp', '/storage/songs/song-001/instrumental.m4a', 12500, '["Pop", "Acoustic"]', '[{"time": 0, "text": "The club isn''t the best place to find a lover"}, {"time": 4, "text": "So the bar is where I go"}]'),
        ('song-002', 'Song 2', 'Unknown Artist', '/storage/songs/song-002/cover.webp', '/storage/songs/song-002/instrumental.m4a', 500, '["Live"]', '[]')
      `);

      await client.query(`
        INSERT INTO recordings (id, user_id, song_id, audio_url, score, likes_count, comments_count)
        VALUES ('feed_1', 'user_1', 'song-001', '/storage/songs/song-001/instrumental.m4a', 92, 245, 12);
      `);
      console.log("Database seeded with initial data.");
    }
  } catch (e) {
    console.error("Error initializing database:", e);
  } finally {
    client.release();
  }
}

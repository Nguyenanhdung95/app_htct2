const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:1@localhost:5432/app_flutter_htct',
});

async function initDatabase() {
  try {
    console.log('Initializing database...');

    // Create tables
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        user_id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        full_name VARCHAR(100) NOT NULL,
        role VARCHAR(20) DEFAULT 'user',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS questions (
        question_id SERIAL PRIMARY KEY,
        question_text TEXT NOT NULL,
        correct_answer VARCHAR(10) NOT NULL,
        created_by INTEGER REFERENCES users(user_id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS answers (
        answer_id SERIAL PRIMARY KEY,
        question_id INTEGER REFERENCES questions(question_id) ON DELETE CASCADE,
        label VARCHAR(10) NOT NULL,
        answer_text TEXT NOT NULL
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_answers (
        user_answer_id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(user_id),
        question_id INTEGER REFERENCES questions(question_id),
        chosen_answer VARCHAR(10) NOT NULL,
        is_correct BOOLEAN NOT NULL,
        answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('Tables created successfully');

    // Create default admin user
    const hashedPassword = await bcrypt.hash('admin123', 10);
    await pool.query(`
      INSERT INTO users (username, password, full_name, role)
      VALUES ('admin', $1, 'Administrator', 'admin')
      ON CONFLICT (username) DO NOTHING
    `, [hashedPassword]);

    // Create default user
    const userPassword = await bcrypt.hash('user123', 10);
    await pool.query(`
      INSERT INTO users (username, password, full_name, role)
      VALUES ('user', $1, 'Test User', 'user')
      ON CONFLICT (username) DO NOTHING
    `, [userPassword]);

    console.log('Default users created');
    console.log('Admin login: admin/admin123');
    console.log('User login: user/user123');

    // Insert sample questions if none exist
    const questionCount = await pool.query('SELECT COUNT(*) FROM questions');
    if (parseInt(questionCount.rows[0].count) === 0) {
      console.log('Inserting sample questions...');

      const questions = [
        {
          text: 'Thủ đô của Việt Nam là gì?',
          correct: 'A',
          answers: [
            { label: 'A', text: 'Hà Nội' },
            { label: 'B', text: 'TP.HCM' },
            { label: 'C', text: 'Đà Nẵng' },
            { label: 'D', text: 'Cần Thơ' }
          ]
        },
        {
          text: '2 + 2 = ?',
          correct: 'B',
          answers: [
            { label: 'A', text: '3' },
            { label: 'B', text: '4' },
            { label: 'C', text: '5' },
            { label: 'D', text: '6' }
          ]
        },
        {
          text: 'Màu của lá cây là gì?',
          correct: 'C',
          answers: [
            { label: 'A', text: 'Đỏ' },
            { label: 'B', text: 'Xanh dương' },
            { label: 'C', text: 'Xanh lá' },
            { label: 'D', text: 'Vàng' }
          ]
        }
      ];

      for (const q of questions) {
        const questionResult = await pool.query(
          'INSERT INTO questions (question_text, correct_answer, created_by) VALUES ($1, $2, 1) RETURNING question_id',
          [q.text, q.correct]
        );
        const questionId = questionResult.rows[0].question_id;

        for (const answer of q.answers) {
          await pool.query(
            'INSERT INTO answers (question_id, label, answer_text) VALUES ($1, $2, $3)',
            [questionId, answer.label, answer.text]
          );
        }
      }

      console.log('Sample questions inserted');
    }

    console.log('Database initialization completed!');
  } catch (error) {
    console.error('Error initializing database:', error);
  } finally {
    await pool.end();
  }
}

initDatabase();
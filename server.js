const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// PostgreSQL connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:1@localhost:5432/app_flutter_htct',
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// JWT Secret
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

// Middleware to verify JWT
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid token' });
    }
    req.user = user;
    next();
  });
};

// Routes

// Login
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const isValidPassword = await bcrypt.compare(password, user.password);

    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { userId: user.user_id, username: user.username, role: user.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      token,
      user: {
        id: user.user_id,
        username: user.username,
        fullName: user.full_name,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get questions
app.get('/api/questions', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT q.*, json_agg(
        json_build_object(
          'id', a.answer_id,
          'questionId', a.question_id,
          'label', a.label,
          'text', a.answer_text
        )
      ) as answers
      FROM questions q
      LEFT JOIN answers a ON q.question_id = a.question_id
      GROUP BY q.question_id
      ORDER BY q.question_id
    `);

    const questions = result.rows.map(row => ({
      id: row.question_id,
      text: row.question_text,
      correctAnswer: row.correct_answer,
      createdBy: row.created_by,
      createdAt: row.created_at,
      answers: row.answers || []
    }));

    res.json(questions);
  } catch (error) {
    console.error('Get questions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Submit answer
app.post('/api/answers', authenticateToken, async (req, res) => {
  try {
    const { questionId, chosenAnswer } = req.body;
    const userId = req.user.userId;

    // Get correct answer
    const questionResult = await pool.query(
      'SELECT correct_answer FROM questions WHERE question_id = $1',
      [questionId]
    );

    if (questionResult.rows.length === 0) {
      return res.status(404).json({ error: 'Question not found' });
    }

    const correctAnswer = questionResult.rows[0].correct_answer;
    const isCorrect = chosenAnswer === correctAnswer;

    await pool.query(
      'INSERT INTO user_answers (user_id, question_id, chosen_answer, is_correct) VALUES ($1, $2, $3, $4)',
      [userId, questionId, chosenAnswer, isCorrect]
    );

    res.json({ isCorrect });
  } catch (error) {
    console.error('Submit answer error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user results
app.get('/api/results', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    const result = await pool.query(`
      SELECT
        COUNT(*) as total_questions,
        COUNT(CASE WHEN is_correct THEN 1 END) as correct_answers,
        COUNT(CASE WHEN NOT is_correct THEN 1 END) as wrong_answers
      FROM user_answers
      WHERE user_id = $1
    `, [userId]);

    const stats = result.rows[0];
    const percentage = stats.total_questions > 0
      ? (stats.correct_answers / stats.total_questions) * 100
      : 0;

    res.json({
      totalQuestions: parseInt(stats.total_questions),
      correctAnswers: parseInt(stats.correct_answers),
      wrongAnswers: parseInt(stats.wrong_answers),
      percentage: Math.round(percentage * 100) / 100
    });
  } catch (error) {
    console.error('Get results error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Admin routes
app.get('/api/admin/questions', authenticateToken, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }

  try {
    const result = await pool.query('SELECT * FROM questions ORDER BY question_id');
    res.json(result.rows);
  } catch (error) {
    console.error('Get admin questions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/admin/questions', authenticateToken, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }

  try {
    const { questionText, correctAnswer, answers } = req.body;

    const questionResult = await pool.query(
      'INSERT INTO questions (question_text, correct_answer, created_by) VALUES ($1, $2, $3) RETURNING question_id',
      [questionText, correctAnswer, req.user.userId]
    );

    const questionId = questionResult.rows[0].question_id;

    for (const answer of answers) {
      await pool.query(
        'INSERT INTO answers (question_id, label, answer_text) VALUES ($1, $2, $3)',
        [questionId, answer.label, answer.text]
      );
    }

    res.status(201).json({ message: 'Question created successfully' });
  } catch (error) {
    console.error('Create question error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.put('/api/admin/questions/:id', authenticateToken, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }

  try {
    const { id } = req.params;
    const { questionText, correctAnswer, answers } = req.body;

    await pool.query(
      'UPDATE questions SET question_text = $1, correct_answer = $2 WHERE question_id = $3',
      [questionText, correctAnswer, id]
    );

    // Delete existing answers
    await pool.query('DELETE FROM answers WHERE question_id = $1', [id]);

    // Insert new answers
    for (const answer of answers) {
      await pool.query(
        'INSERT INTO answers (question_id, label, answer_text) VALUES ($1, $2, $3)',
        [id, answer.label, answer.text]
      );
    }

    res.json({ message: 'Question updated successfully' });
  } catch (error) {
    console.error('Update question error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/api/admin/questions/:id', authenticateToken, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }

  try {
    const { id } = req.params;

    await pool.query('DELETE FROM answers WHERE question_id = $1', [id]);
    await pool.query('DELETE FROM questions WHERE question_id = $1', [id]);

    res.json({ message: 'Question deleted successfully' });
  } catch (error) {
    console.error('Delete question error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
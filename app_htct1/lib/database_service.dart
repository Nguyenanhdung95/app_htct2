import 'package:postgres/postgres.dart';
import 'models.dart';

class DatabaseService {
  late Connection connection;

  Future<void> connect() async {
    // For Android emulator, use 10.0.2.2 to connect to host machine
    // For iOS simulator, use localhost
    // For physical devices, use your computer's IP address
    const host = String.fromEnvironment('DB_HOST', defaultValue: '10.0.2.2');

    connection = await Connection.open(
      Endpoint(
        host: host,
        port: 5432,
        database: 'app_flutter_htct',
        username: 'postgres',
        password: '1',
      ),
      settings: ConnectionSettings(
        sslMode: SslMode.disable, // Disable SSL for local development
      ),
    );

    print('Connected to PostgreSQL database at $host:5432');
  }

  Future<void> disconnect() async {
    await connection.close();
    print('Disconnected from PostgreSQL database');
  }

  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? parameters]) async {
    try {
      final results = await connection.execute(sql, parameters: parameters ?? []);
      return results.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Query failed: $e');
      rethrow;
    }
  }

  Future<bool> authenticate(String username, String password) async {
    try {
      print('Attempting to authenticate user: $username');
      final results = await connection.execute(
        "SELECT * FROM users WHERE username = '$username' AND password = '$password'",
      );
      print('Query results: ${results.length} rows found');
      return results.isNotEmpty;
    } catch (e) {
      print('Authentication failed: $e');
      return false;
    }
  }

  Future<List<Question>> getQuestions() async {
    try {
      print('=== GETTING QUESTIONS ===');
      print('Connection state: ${connection.isOpen ? "Open" : "Closed"}');

      // Test basic connection first
      final testResult = await connection.execute('SELECT 1 as test');
      print('Connection test result: ${testResult.first.toColumnMap()}');

      print('Executing query: SELECT * FROM questions ORDER BY question_id');

      final questionResults = await connection.execute('SELECT * FROM questions ORDER BY question_id');
      print('Raw question results count: ${questionResults.length}');

      // Debug: print all rows
      for (int i = 0; i < questionResults.length; i++) {
        print('Row $i: ${questionResults[i].toColumnMap()}');
      }

      if (questionResults.isEmpty) {
        print('❌ No questions found in database');
        return [];
      }

      final List<Question> questions = [];

      for (int i = 0; i < questionResults.length; i++) {
        final questionRow = questionResults[i];
        final questionMap = questionRow.toColumnMap();
        print('Question row $i data: $questionMap');

        final questionId = questionMap['question_id'];
        print('Processing question ID: $questionId');

        // Get answers for this question from answers table
        final answerQuery = 'SELECT * FROM answers WHERE question_id = $questionId ORDER BY label';
        print('Executing answer query: $answerQuery');

        final answerResults = await connection.execute(answerQuery);
        print('Found ${answerResults.length} answers for question $questionId');

        if (answerResults.isEmpty) {
          print('⚠️ Warning: No answers found for question $questionId');
          continue;
        }

        // Debug: print all answer rows
        for (int j = 0; j < answerResults.length; j++) {
          print('Answer row $j: ${answerResults[j].toColumnMap()}');
        }

        final answers = answerResults.map((row) {
          final answerMap = row.toColumnMap();
          print('Processing answer: $answerMap');
          return Answer.fromMap(answerMap);
        }).toList();

        final question = Question.fromMap(questionMap, answers);
        questions.add(question);
        print('✅ Added question ${question.id} with ${question.answers.length} answers');
      }

      print('🎉 Successfully loaded ${questions.length} complete questions');
      return questions;
    } catch (e) {
      print('❌ Error fetching questions: $e');
      print('Stack trace: ${StackTrace.current}');
      print('Error type: ${e.runtimeType}');
      // Try to get more details about the error
      if (e is TypeError) {
        print('TypeError details: $e');
      }
      return [];
    }
  }

  Future<List<UserAnswer>> getUserAnswers(int userId) async {
    try {
      final results = await connection.execute(
        'SELECT * FROM user_answers WHERE user_id = $userId ORDER BY answered_at DESC'
      );
      return results.map((row) => UserAnswer.fromMap(row.toColumnMap())).toList();
    } catch (e) {
      print('Error fetching user answers: $e');
      return [];
    }
  }

  Future<QuizResult> getUserQuizResult(int userId) async {
    try {
      final userAnswers = await getUserAnswers(userId);
      final totalQuestions = userAnswers.length;
      final correctAnswers = userAnswers.where((answer) => answer.isCorrect).length;
      final wrongAnswers = totalQuestions - correctAnswers;
      final percentage = totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0.0;

      return QuizResult(
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        wrongAnswers: wrongAnswers,
        percentage: percentage,
      );
    } catch (e) {
      print('Error calculating quiz result: $e');
      return QuizResult(
        totalQuestions: 0,
        correctAnswers: 0,
        wrongAnswers: 0,
        percentage: 0.0,
      );
    }
  }

  Future<void> submitAnswer(int userId, int questionId, String chosenAnswer, bool isCorrect) async {
    try {
      await connection.execute(
        "INSERT INTO user_answers (user_id, question_id, chosen_answer, is_correct) VALUES ($userId, $questionId, '$chosenAnswer', $isCorrect)"
      );
    } catch (e) {
      print('Error submitting answer: $e');
      rethrow;
    }
  }

  Future<int> getCurrentUserId(String username) async {
    try {
      final results = await connection.execute(
        "SELECT user_id FROM users WHERE username = '$username'"
      );
      if (results.isNotEmpty) {
        return results.first.toColumnMap()['user_id'];
      }
      return -1;
    } catch (e) {
      print('Error getting user ID: $e');
      return -1;
    }
  }

  Future<User?> getCurrentUser(String username) async {
    try {
      final results = await connection.execute(
        "SELECT * FROM users WHERE username = '$username'"
      );
      if (results.isNotEmpty) {
        return User.fromMap(results.first.toColumnMap());
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<void> addQuestion(String questionText, String correctAnswer, int createdBy) async {
    try {
      await connection.execute(
        "INSERT INTO questions (question_text, correct_answer, created_by) VALUES ('$questionText', '$correctAnswer', $createdBy)"
      );
      print('Question added successfully');
    } catch (e) {
      print('Error adding question: $e');
      rethrow;
    }
  }

  Future<void> updateQuestion(int questionId, String questionText, String correctAnswer) async {
    try {
      await connection.execute(
        "UPDATE questions SET question_text = '$questionText', correct_answer = '$correctAnswer' WHERE question_id = $questionId"
      );
      print('Question updated successfully');
    } catch (e) {
      print('Error updating question: $e');
      rethrow;
    }
  }

  Future<void> deleteQuestion(int questionId) async {
    try {
      await connection.execute(
        "DELETE FROM questions WHERE question_id = $questionId"
      );
      print('Question deleted successfully');
    } catch (e) {
      print('Error deleting question: $e');
      rethrow;
    }
  }

  Future<int> getLastInsertedQuestionId() async {
    try {
      final results = await connection.execute(
        "SELECT LASTVAL() as id"
      );
      if (results.isNotEmpty) {
        return results.first.toColumnMap()['id'];
      }
      return -1;
    } catch (e) {
      print('Error getting last inserted ID: $e');
      return -1;
    }
  }

  Future<void> addAnswer(int questionId, String label, String answerText) async {
    try {
      await connection.execute(
        "INSERT INTO answers (question_id, label, answer_text) VALUES ($questionId, '$label', '$answerText')"
      );
      print('Answer added successfully');
    } catch (e) {
      print('Error adding answer: $e');
      rethrow;
    }
  }

  Future<void> updateAnswer(int answerId, String answerText) async {
    try {
      await connection.execute(
        "UPDATE answers SET answer_text = '$answerText' WHERE answer_id = $answerId"
      );
      print('Answer updated successfully');
    } catch (e) {
      print('Error updating answer: $e');
      rethrow;
    }
  }

  Future<void> deleteAnswersByQuestionId(int questionId) async {
    try {
      await connection.execute(
        "DELETE FROM answers WHERE question_id = $questionId"
      );
      print('Answers deleted successfully');
    } catch (e) {
      print('Error deleting answers: $e');
      rethrow;
    }
  }

  Future<void> checkUsersTable() async {
    try {
      final results = await connection.execute('SELECT * FROM users LIMIT 5');
      print('Users table structure:');
      for (var row in results) {
        print('Row: ${row.toColumnMap()}');
      }
    } catch (e) {
      print('Error checking users table: $e');
    }
  }

  Future<void> checkQuestionsAndAnswers() async {
    try {
      print('Checking database connection and tables...');

      // Test basic connection
      final testResult = await connection.execute('SELECT 1 as test');
      print('Database connection test: ${testResult.first.toColumnMap()}');

      print('Checking questions table...');
      final questionResults = await connection.execute('SELECT COUNT(*) as count FROM questions');
      final questionCount = questionResults.first.toColumnMap()['count'];
      print('Questions table has $questionCount records');

      if (questionCount > 0) {
        print('Sample questions:');
        final sampleQuestions = await connection.execute('SELECT question_id, question_text FROM questions LIMIT 3');
        for (var row in sampleQuestions) {
          final data = row.toColumnMap();
          print('  ID ${data['question_id']}: ${data['question_text']}');
        }
      }

      print('Checking answers table...');
      final answerResults = await connection.execute('SELECT COUNT(*) as count FROM answers');
      final answerCount = answerResults.first.toColumnMap()['count'];
      print('Answers table has $answerCount records');

      if (answerCount > 0) {
        print('Sample answers:');
        final sampleAnswers = await connection.execute('SELECT question_id, label, answer_text FROM answers LIMIT 6');
        for (var row in sampleAnswers) {
          final data = row.toColumnMap();
          print('  Q${data['question_id']} ${data['label']}: ${data['answer_text']}');
        }
      }

      print('Checking user_answers table...');
      final userAnswerResults = await connection.execute('SELECT COUNT(*) as count FROM user_answers');
      final userAnswerCount = userAnswerResults.first.toColumnMap()['count'];
      print('User_answers table has $userAnswerCount records');

    } catch (e) {
      print('Error checking tables: $e');
      print('Error type: ${e.runtimeType}');
    }
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:3000'; // For Android emulator
  // static const String baseUrl = 'http://localhost:3000'; // For iOS simulator
  // static const String baseUrl = 'https://your-server-url.com'; // For production

  String? _token;

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        return data;
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<Question>> getQuestions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/questions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Question.fromMap(json, json['answers'] ?? [])).toList();
      } else {
        throw Exception('Failed to load questions: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> submitAnswer(int questionId, String chosenAnswer) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/answers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'questionId': questionId,
          'chosenAnswer': chosenAnswer,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isCorrect'] ?? false;
      } else {
        throw Exception('Failed to submit answer: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<QuizResult> getUserResults() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/results'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return QuizResult(
          totalQuestions: data['totalQuestions'] ?? 0,
          correctAnswers: data['correctAnswers'] ?? 0,
          wrongAnswers: data['wrongAnswers'] ?? 0,
          percentage: data['percentage'] ?? 0.0,
        );
      } else {
        throw Exception('Failed to load results: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Admin methods
  Future<List<Question>> getAdminQuestions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/questions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Question.fromMap(json, [])).toList();
      } else {
        throw Exception('Failed to load questions: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> createQuestion(String questionText, String correctAnswer, List<Map<String, String>> answers) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/questions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'questionText': questionText,
          'correctAnswer': correctAnswer,
          'answers': answers,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create question: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> updateQuestion(int id, String questionText, String correctAnswer, List<Map<String, String>> answers) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/questions/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'questionText': questionText,
          'correctAnswer': correctAnswer,
          'answers': answers,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update question: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> deleteQuestion(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/questions/$id'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete question: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  void logout() {
    _token = null;
  }
}
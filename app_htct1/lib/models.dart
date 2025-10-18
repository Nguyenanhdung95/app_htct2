class Question {
  final int id;
  final String text;
  final String correctAnswer; // A, B, C, D
  final int? createdBy;
  final DateTime? createdAt;
  final List<Answer> answers;

  Question({
    required this.id,
    required this.text,
    required this.correctAnswer,
    this.createdBy,
    this.createdAt,
    required this.answers,
  });

  factory Question.fromMap(Map<String, dynamic> map, List<Answer> answers) {
    return Question(
      id: map['question_id'],
      text: map['question_text'],
      correctAnswer: map['correct_answer'],
      createdBy: map['created_by'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : null,
      answers: answers,
    );
  }
}

class Answer {
  final int id;
  final int questionId;
  final String label; // A, B, C, D
  final String text;

  Answer({
    required this.id,
    required this.questionId,
    required this.label,
    required this.text,
  });

  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      id: map['answer_id'],
      questionId: map['question_id'],
      label: map['label'],
      text: map['answer_text'],
    );
  }
}

class UserAnswer {
  final int id;
  final int userId;
  final int questionId;
  final String chosenAnswer; // A, B, C, D
  final bool isCorrect;
  final DateTime answeredAt;

  UserAnswer({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.chosenAnswer,
    required this.isCorrect,
    required this.answeredAt,
  });

  factory UserAnswer.fromMap(Map<String, dynamic> map) {
    return UserAnswer(
      id: map['user_answer_id'],
      userId: map['user_id'],
      questionId: map['question_id'],
      chosenAnswer: map['chosen_answer'],
      isCorrect: map['is_correct'],
      answeredAt: DateTime.parse(map['answered_at'].toString()),
    );
  }
}

class QuizResult {
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final double percentage;

  QuizResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.percentage,
  });
}

class User {
  final int id;
  final String username;
  final String password;
  final String fullName;
  final String role; // 'admin' or 'user'
  final DateTime? createdAt;

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    this.createdAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    print('User.fromMap called with: $map');
    print('created_at type: ${map['created_at']?.runtimeType}');
    print('created_at value: ${map['created_at']}');

    return User(
      id: map['user_id'],
      username: map['username'],
      password: map['password'],
      fullName: map['full_name'],
      role: map['role'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'].toString()) : null,
    );
  }
}
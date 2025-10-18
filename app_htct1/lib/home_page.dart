import 'package:flutter/material.dart';
import 'database_service.dart';
import 'models.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  bool _isConnected = false;
  bool _isLoading = true;
  List<Question> _questions = [];
  QuizResult _quizResult = QuizResult(totalQuestions: 0, correctAnswers: 0, wrongAnswers: 0, percentage: 0.0);
  int _currentUserId = -1;
  late TabController _tabController;
  Map<int, String> _userAnswers = {}; // questionId -> selectedAnswer

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      print('Initializing HomePage data...');
      await _dbService.connect();
      print('Database connected successfully');
      setState(() => _isConnected = true);

      // Check table data
      await _dbService.checkQuestionsAndAnswers();

      // Get current user ID (assuming we store username somewhere, for now use a default)
      // In a real app, you'd pass the username from login
      _currentUserId = await _dbService.getCurrentUserId('user1'); // Default to user1 for demo
      print('Current user ID: $_currentUserId');

      await _loadQuestions();
      await _loadQuizResult();
      await _loadUserAnswers(); // Load existing answers
      print('Data initialization completed');
    } catch (e) {
      print('Error initializing data: $e');
      print('Stack trace: ${StackTrace.current}');
      print('Error type: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khởi tạo: $e\nKiểm tra console để biết chi tiết')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadQuestions() async {
    try {
      print('Loading questions...');
      print('Database service connection state: ${_dbService.connection?.isOpen ?? false ? "Open" : "Closed"}');

      final questions = await _dbService.getQuestions();
      print('Loaded ${questions.length} questions');

      if (questions.isEmpty) {
        print('⚠️ No questions loaded from database');
        // Try to check if tables exist
        try {
          final tableCheck = await _dbService.connection.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'");
          print('Available tables: ${tableCheck.map((row) => row.toColumnMap()['table_name']).toList()}');
        } catch (e) {
          print('Error checking tables: $e');
        }
      }

      for (var q in questions) {
        print('Question ${q.id}: ${q.text}');
        print('Correct answer: ${q.correctAnswer}');
        print('Answers: ${q.answers.length}');
        for (var a in q.answers) {
          print('  ${a.label}: ${a.text}');
        }
      }
      if (mounted) {
        setState(() => _questions = questions);
        print('Questions state updated: ${_questions.length} questions');
      }
    } catch (e) {
      print('Error loading questions: $e');
      print('Stack trace: ${StackTrace.current}');
      print('Error type: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải câu hỏi: $e\nKiểm tra console')),
        );
      }
    }
  }

  Future<void> _loadQuizResult() async {
    if (_currentUserId != -1) {
      try {
        final userAnswers = await _dbService.getUserAnswers(_currentUserId);
        final totalQuestions = _questions.length; // Tổng số câu hỏi trong database
        final correctAnswers = userAnswers.where((answer) => answer.isCorrect).length;
        final wrongAnswers = totalQuestions - correctAnswers; // Sai = Tổng - Đúng
        final percentage = totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0.0;

        final result = QuizResult(
          totalQuestions: totalQuestions,
          correctAnswers: correctAnswers,
          wrongAnswers: wrongAnswers,
          percentage: percentage,
        );

        if (mounted) {
          setState(() => _quizResult = result);
        }
      } catch (e) {
        print('Error loading quiz result: $e');
      }
    }
  }

  Future<void> _loadUserAnswers() async {
    if (_currentUserId != -1) {
      try {
        final userAnswers = await _dbService.getUserAnswers(_currentUserId);
        if (mounted) {
          setState(() {
            _userAnswers = {
              for (var answer in userAnswers)
                answer.questionId: answer.chosenAnswer
            };
          });
          print('Loaded ${userAnswers.length} user answers');
        }
      } catch (e) {
        print('Error loading user answers: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ứng dụng Trắc nghiệm'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _dbService.disconnect();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Câu hỏi', icon: Icon(Icons.question_answer)),
            Tab(text: 'Kết quả', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuestionsTab(),
          _buildResultsTab(),
        ],
      ),
    );
  }

  Widget _buildQuestionsTab() {
    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Không có câu hỏi nào'),
            const SizedBox(height: 16),
            Text(
              'Trạng thái kết nối: ${_isConnected ? "Đã kết nối" : "Chưa kết nối"}',
              style: TextStyle(
                color: _isConnected ? Colors.green : Colors.red,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadQuestions,
              child: const Text('Tải lại câu hỏi'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final question = _questions[index];
              final selectedAnswer = _userAnswers[question.id];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu ${index + 1}: ${question.text}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...question.answers.map((answer) {
                        final isSelected = selectedAnswer == answer.label;
                        final isCorrect = answer.label == question.correctAnswer;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isCorrect ? Colors.green.shade50 : Colors.red.shade50)
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? (isCorrect ? Colors.green.shade300 : Colors.red.shade300)
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: RadioListTile<String>(
                            value: answer.label,
                            groupValue: selectedAnswer,
                            onChanged: (value) async {
                              if (value != null) {
                                setState(() {
                                  _userAnswers[question.id] = value;
                                });

                                // Submit answer to database
                                final isCorrect = value == question.correctAnswer;
                                try {
                                  await _dbService.submitAnswer(_currentUserId, question.id, value, isCorrect);
                                  await _loadQuizResult(); // Refresh results
                                } catch (e) {
                                  print('Error submitting answer: $e');
                                }
                              }
                            },
                            title: Text(
                              answer.text,
                              style: TextStyle(
                                fontSize: 16,
                                color: isSelected
                                    ? (isCorrect ? Colors.green.shade800 : Colors.red.shade800)
                                    : Colors.black87,
                              ),
                            ),
                            secondary: CircleAvatar(
                              backgroundColor: isSelected
                                  ? (isCorrect ? Colors.green : Colors.red)
                                  : Colors.blue.shade600,
                              child: Text(
                                answer.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_questions.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đã trả lời: ${_userAnswers.length}/${_questions.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _loadQuizResult();
                    if (mounted) {
                      _tabController.animateTo(1); // Switch to results tab
                    }
                  },
                  child: const Text('Xem kết quả'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResultsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Thống kê kết quả',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Tổng câu',
                        _quizResult.totalQuestions.toString(),
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Đúng',
                        _quizResult.correctAnswers.toString(),
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Sai',
                        _quizResult.wrongAnswers.toString(),
                        Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Tỷ lệ đúng: ${_quizResult.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _quizResult.percentage >= 70
                            ? Colors.green.shade700
                            : _quizResult.percentage >= 50
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dbService.disconnect();
    super.dispose();
  }
}
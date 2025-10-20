import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';

class AdminPage extends StatefulWidget {
  final User currentUser;

  const AdminPage({super.key, required this.currentUser});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isConnected = true; // API is always connected
  bool _isLoading = true;
  List<Question> _questions = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      print('Initializing AdminPage data...');

      await _loadQuestions();
      print('AdminPage data initialization completed');
    } catch (e) {
      print('Error initializing admin data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khởi tạo: $e')),
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
      print('Loading questions for admin...');
      final questions = await _apiService.getAdminQuestions();
      print('Loaded ${questions.length} questions for admin');
      if (mounted) {
        setState(() => _questions = questions);
      }
    } catch (e) {
      print('Error loading questions for admin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải câu hỏi: $e')),
        );
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
        title: const Text('Quản lý câu hỏi'),
        backgroundColor: Colors.red.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _apiService.logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Danh sách', icon: Icon(Icons.list)),
            Tab(text: 'Thêm mới', icon: Icon(Icons.add)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuestionsListTab(),
          _buildAddQuestionTab(),
        ],
      ),
    );
  }

  Widget _buildQuestionsListTab() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text('Chưa có câu hỏi nào'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final question = _questions[index];
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Câu ${index + 1}: ${question.text}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditQuestionDialog(question);
                        } else if (value == 'delete') {
                          _showDeleteConfirmationDialog(question);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Sửa'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Xóa'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...question.answers.map((answer) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: answer.label == question.correctAnswer
                          ? Colors.green.shade50
                          : Colors.white,
                      border: Border.all(
                        color: answer.label == question.correctAnswer
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: answer.label == question.correctAnswer
                              ? Colors.green
                              : Colors.blue.shade600,
                          child: Text(
                            answer.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            answer.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: answer.label == question.correctAnswer
                                  ? Colors.green.shade800
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (answer.label == question.correctAnswer)
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddQuestionTab() {
    return AddQuestionForm(
      apiService: _apiService,
      onQuestionAdded: _loadQuestions,
    );
  }

  void _showEditQuestionDialog(Question question) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditQuestionDialog(
          question: question,
          onSave: (updatedQuestion) async {
            try {
              // Convert answers to API format
              final answers = updatedQuestion.answers.map((answer) => {
                'label': answer.label,
                'text': answer.text,
              }).toList();

              await _apiService.updateQuestion(
                updatedQuestion.id,
                updatedQuestion.text,
                updatedQuestion.correctAnswer,
                answers,
              );

              await _loadQuestions();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cập nhật câu hỏi thành công')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi cập nhật: $e')),
                );
              }
            }
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(Question question) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc muốn xóa câu hỏi "${question.text}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _apiService.deleteQuestion(question.id);
                  await _loadQuestions();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Xóa câu hỏi thành công')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi xóa: $e')),
                    );
                  }
                }
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiService.logout();
    super.dispose();
  }
}

class AddQuestionForm extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onQuestionAdded;

  const AddQuestionForm({
    super.key,
    required this.apiService,
    required this.onQuestionAdded,
  });

  @override
  State<AddQuestionForm> createState() => _AddQuestionFormState();
}

class _AddQuestionFormState extends State<AddQuestionForm> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  String _correctAnswer = 'A';

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Prepare answers for API
      const labels = ['A', 'B', 'C', 'D'];
      final answers = _answerControllers.asMap().entries.map((entry) => {
        'label': labels[entry.key],
        'text': entry.value.text,
      }).toList();

      // Add question via API
      await widget.apiService.createQuestion(
        _questionController.text,
        _correctAnswer,
        answers,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm câu hỏi thành công')),
        );
        _clearForm();
        widget.onQuestionAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thêm câu hỏi: $e')),
        );
      }
    }
  }

  void _clearForm() {
    _questionController.clear();
    for (var controller in _answerControllers) {
      controller.clear();
    }
    setState(() => _correctAnswer = 'A');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thêm câu hỏi mới',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Question text
            TextFormField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Nội dung câu hỏi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập nội dung câu hỏi';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Answers
            const Text(
              'Các đáp án:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...List.generate(4, (index) {
              final labels = ['A', 'B', 'C', 'D'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Radio<String>(
                      value: labels[index],
                      groupValue: _correctAnswer,
                      onChanged: (value) {
                        setState(() => _correctAnswer = value!);
                      },
                    ),
                    Text('${labels[index]}.'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _answerControllers[index],
                        decoration: InputDecoration(
                          hintText: 'Nhập đáp án ${labels[index]}',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập đáp án ${labels[index]}';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // Correct answer selector
            Row(
              children: [
                const Text('Đáp án đúng: '),
                DropdownButton<String>(
                  value: _correctAnswer,
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('A')),
                    DropdownMenuItem(value: 'B', child: Text('B')),
                    DropdownMenuItem(value: 'C', child: Text('C')),
                    DropdownMenuItem(value: 'D', child: Text('D')),
                  ],
                  onChanged: (value) {
                    setState(() => _correctAnswer = value!);
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Lưu câu hỏi',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditQuestionDialog extends StatefulWidget {
  final Question question;
  final Function(Question) onSave;

  const EditQuestionDialog({
    super.key,
    required this.question,
    required this.onSave,
  });

  @override
  State<EditQuestionDialog> createState() => _EditQuestionDialogState();
}

class _EditQuestionDialogState extends State<EditQuestionDialog> {
  late TextEditingController _questionController;
  late List<TextEditingController> _answerControllers;
  late String _correctAnswer;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.question.text);
    _correctAnswer = widget.question.correctAnswer;
    _answerControllers = widget.question.answers
        .map((answer) => TextEditingController(text: answer.text))
        .toList();
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final updatedQuestion = Question(
      id: widget.question.id,
      text: _questionController.text,
      correctAnswer: _correctAnswer,
      createdBy: widget.question.createdBy,
      createdAt: widget.question.createdAt,
      answers: List.generate(4, (index) {
        final labels = ['A', 'B', 'C', 'D'];
        return Answer(
          id: widget.question.answers[index].id,
          questionId: widget.question.id,
          label: labels[index],
          text: _answerControllers[index].text,
        );
      }),
    );

    widget.onSave(updatedQuestion);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa câu hỏi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Nội dung câu hỏi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            ...List.generate(4, (index) {
              final labels = ['A', 'B', 'C', 'D'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Radio<String>(
                      value: labels[index],
                      groupValue: _correctAnswer,
                      onChanged: (value) {
                        setState(() => _correctAnswer = value!);
                      },
                    ),
                    Text('${labels[index]}.'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _answerControllers[index],
                        decoration: InputDecoration(
                          hintText: 'Đáp án ${labels[index]}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
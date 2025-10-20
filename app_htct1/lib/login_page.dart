import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';
import 'admin_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _isConnected = true; // API is always "connected" for now
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _connectToDatabase();
  }

  Future<void> _connectToDatabase() async {
    // API connection check - for now just set as connected
    setState(() => _isConnected = true);
  }

  Future<void> _login() async {
    print('=== LOGIN ATTEMPT ===');
    print('Username: ${_usernameController.text}');
    print('Password: ${_passwordController.text}');

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      print('Empty fields detected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng nhập đầy đủ thông tin'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (!_isConnected) {
      print('Database not connected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chưa kết nối được database'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('Calling API login...');
      final loginData = await _apiService.login(
        _usernameController.text,
        _passwordController.text,
      );
      print('Login result: $loginData');

      if (loginData['token'] != null) {
        print('Login successful, parsing user info...');
        // Parse user information from API response
        final userData = loginData['user'];
        _currentUser = User(
          id: userData['id'],
          username: userData['username'],
          password: '', // Not returned from API for security
          fullName: userData['fullName'],
          role: userData['role'],
        );
        print('User info: $_currentUser');

        if (mounted && _currentUser != null) {
          print('User role: ${_currentUser!.role}');
          if (_currentUser!.role == 'admin') {
            print('Navigating to AdminPage...');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => AdminPage(currentUser: _currentUser!),
              ),
            );
          } else {
            print('Navigating to HomePage...');
            Navigator.of(context).pushReplacementNamed('/home');
          }
        } else {
          print('User is null or not mounted');
        }
      } else {
        print('Authentication failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tên đăng nhập hoặc mật khẩu không đúng'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng nhập: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFF093FB),
              Color(0xFFF5576C),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  const Text(
                    'Chào mừng',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập để tiếp tục',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Username field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Tên đăng nhập',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(
                          Icons.person,
                          color: Colors.grey.shade700,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        hintText: 'Mật khẩu',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(
                          Icons.lock,
                          color: Colors.grey.shade700,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      obscureText: true,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Login button
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        colors: _isConnected
                            ? [Colors.white, Colors.white.withOpacity(0.9)]
                            : [Colors.grey.shade400, Colors.grey.shade500],
                      ),
                      boxShadow: _isConnected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_isConnected) ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            )
                          : Text(
                              _isConnected ? 'Đăng nhập' : 'Đang kết nối...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _isConnected ? Colors.blue.shade700 : Colors.grey.shade700,
                              ),
                            ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _apiService.logout();
    super.dispose();
  }
}
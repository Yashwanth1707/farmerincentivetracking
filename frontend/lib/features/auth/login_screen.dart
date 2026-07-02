import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fims_frontend/core/network/api_endpoints.dart';
import 'package:fims_frontend/core/network/dio_client.dart';
import 'package:fims_frontend/core/theme/app_theme.dart';
import 'package:dio/dio.dart';

// Auth state providers
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: clearUser ? null : user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final DioClient _client = DioClient();

  Future<void> login(
    String identifier,
    String password, {
    bool rememberMe = false,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      final response = await _client.post(
        ApiEndpoints.login,
        data: {
          'identifier': identifier,
          'password': password,
          'rememberMe': rememberMe,
        },
      );

      debugPrint('Status: ${response.statusCode}');
      debugPrint('Response: ${response.data}');

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: _extractUser(response.data),
      );
    } on DioException catch (e) {
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');

      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? e.message ?? 'Login failed',
      );
    } catch (e) {
      debugPrint(e.toString());

      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    try {
      await _client.post(ApiEndpoints.logout);
      state = state.copyWith(isAuthenticated: false, clearUser: true);
    } catch (e) {
      // Logout error handling
    }
  }

  Map<String, dynamic> _extractUser(dynamic responseData) {
    if (responseData is! Map) return {};

    final data = responseData['data'];
    if (data is Map) {
      final user = data['user'];
      if (user is Map) {
        return Map<String, dynamic>.from(user);
      }
      return Map<String, dynamic>.from(data);
    }

    final user = responseData['user'];
    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }

    return {};
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController identifierController;
  late final TextEditingController passwordController;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    identifierController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  void dispose() {
    identifierController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final authNotifier = ref.read(authStateProvider.notifier);

    // Listen to auth state changes and navigate to dashboard
    ref.listen(authStateProvider, (previous, next) {
      if (next.isAuthenticated) {
        context.goNamed('dashboard');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 680 : 480),
                child: Card(
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    AppColors.accent,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.agriculture_rounded,
                                size: 38,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome back to FIMS',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage payments, farmers, and reports in one easy dashboard.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                        const SizedBox(height: 26),
                        if (authState.error != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 18),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    authState.error!,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (authState.error != null) const SizedBox(height: 20),
                        TextField(
                          controller: identifierController,
                          decoration: const InputDecoration(
                            labelText: 'Username or Email',
                            hintText: 'admin or admin@example.com',
                            prefixIcon: Icon(Icons.person),
                          ),
                          enabled: !authState.isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          enabled: !authState.isLoading,
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: rememberMe,
                          onChanged: authState.isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    rememberMe = value ?? false;
                                  });
                                },
                          title: const Text('Remember me'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: authState.isLoading
                                ? null
                                : () {
                                    if (identifierController.text.isEmpty ||
                                        passwordController.text.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          content:
                                              Text('Please fill all fields'),
                                        ),
                                      );
                                      return;
                                    }
                                    authNotifier.login(
                                      identifierController.text,
                                      passwordController.text,
                                      rememberMe: rememberMe,
                                    );
                                  },
                            child: authState.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.textOnPrimary),
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.goNamed('forgot-password'),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Demo credentials: admin / password123',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
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
        },
      ),
    );
  }
}

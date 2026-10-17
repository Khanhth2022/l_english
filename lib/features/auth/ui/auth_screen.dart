import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../state/auth_controller.dart';

/// Màn hình đăng nhập và đăng ký tài khoản theo đúng tài liệu thiết kế (act-01, act-02).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  final _loginUsernameController = TextEditingController(text: 'user1');
  final _loginPasswordController = TextEditingController(text: 'password123');

  final _registerUsernameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirmPassword = true;

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Cấu hình Base URL',
            icon: const Icon(Icons.tune_rounded, color: AppTheme.textMuted),
            onPressed: () => _showBaseUrlDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Brand Header
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryDark, AppTheme.primaryBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LEnglish',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Học từ vựng thông minh & Luyện viết cùng AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Message notifications
                  if (authController.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.errorBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authController.errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (authController.errorMessage == 'Đăng nhập thất bại') ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Nếu bạn chưa có tài khoản trên máy chủ này, vui lòng chuyển qua tab "Đăng ký".',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (authController.successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.successBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authController.successMessage!,
                              style: const TextStyle(
                                color: AppTheme.successGreen,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Card Form
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          // Tab Bar
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              onTap: (_) => authController.clearMessages(),
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicator: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              labelColor: AppTheme.primaryBlue,
                              unselectedLabelColor: AppTheme.textMuted,
                              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              tabs: const [
                                Tab(text: 'Đăng nhập'),
                                Tab(text: 'Tạo tài khoản'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Form content
                          SizedBox(
                            height: 270,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildLoginForm(authController),
                                _buildRegisterForm(authController),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Chuẩn bảo mật JWT Bearer • Refresh Token Rotation',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => _showBaseUrlDialog(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.successGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Máy chủ: ${AppConfig.apiBaseUrl}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primaryBlue),
                        ],
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

  Widget _buildLoginForm(AuthController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginUsernameController,
          decoration: const InputDecoration(
            labelText: 'Tên đăng nhập',
            prefixIcon: Icon(Icons.person_outline),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          decoration: InputDecoration(
            labelText: 'Mật khẩu',
            prefixIcon: const Icon(Icons.lock_outline),
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: controller.isLoading ? null : _handleLogin,
          child: controller.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Đăng nhập'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(AuthController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _registerUsernameController,
          decoration: const InputDecoration(
            labelText: 'Tên đăng nhập',
            hintText: '3–50 ký tự',
            prefixIcon: Icon(Icons.person_add_outlined),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _registerPasswordController,
          obscureText: _obscureRegisterPassword,
          decoration: InputDecoration(
            labelText: 'Mật khẩu (≥ 8 ký tự)',
            prefixIcon: const Icon(Icons.lock_outline),
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRegisterPassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _registerConfirmPasswordController,
          obscureText: _obscureRegisterConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Xác nhận lại mật khẩu',
            prefixIcon: const Icon(Icons.lock_clock_outlined),
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRegisterConfirmPassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureRegisterConfirmPassword = !_obscureRegisterConfirmPassword),
            ),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: controller.isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
          ),
          child: controller.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Tạo tài khoản'),
                    SizedBox(width: 8),
                    Icon(Icons.person_add_rounded, size: 18),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên đăng nhập và mật khẩu.')),
      );
      return;
    }
    final success = await context.read<AuthController>().login(username, password);
    if (success && mounted) {
      widget.onLoginSuccess?.call();
    }
  }

  Future<void> _handleRegister() async {
    final username = _registerUsernameController.text.trim();
    final password = _registerPasswordController.text;
    final confirm = _registerConfirmPasswordController.text;

    if (username.length < 3 || username.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên đăng nhập phải từ 3–50 ký tự.')),
      );
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu phải có tối thiểu 8 ký tự.')),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu xác nhận không khớp.')),
      );
      return;
    }

    final success = await context.read<AuthController>().register(username, password);
    if (success && mounted) {
      _tabController.animateTo(0);
      _loginUsernameController.text = username;
      _loginPasswordController.text = password;
    }
  }

  void _showBaseUrlDialog(BuildContext context) {
    final dio = Provider.of<Dio?>(context, listen: false);
    final urlController = TextEditingController(text: AppConfig.apiBaseUrl);
    ConnectionTestResult? testResult;
    bool isTesting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dns_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cấu hình Base URL',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhập địa chỉ máy chủ backend Spring Boot (Cloudflare tunnel hoặc IP máy tính trong mạng LAN):',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlController,
                  autofocus: false,
                  keyboardType: TextInputType.url,
                  onChanged: (_) {
                    if (testResult != null) {
                      setDialogState(() {
                        testResult = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Backend Base URL',
                    hintText: 'https://...trycloudflare.com',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        urlController.clear();
                        setDialogState(() {
                          testResult = null;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chọn nhanh (Presets):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.cloud_queue_rounded, size: 16),
                      label: const Text('Cloudflare Tunnel', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        urlController.text = AppConfig.defaultApiBaseUrl;
                        setDialogState(() => testResult = null);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.phone_android_rounded, size: 16),
                      label: const Text('Máy ảo (10.0.2.2)', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        urlController.text = 'http://10.0.2.2:8080';
                        setDialogState(() => testResult = null);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.computer_rounded, size: 16),
                      label: const Text('Localhost (8080)', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        urlController.text = 'http://localhost:8080';
                        setDialogState(() => testResult = null);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Nút kiểm tra kết nối trực tiếp
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isTesting
                        ? null
                        : () async {
                            final raw = urlController.text.trim();
                            if (raw.isEmpty) return;
                            final normalized = AppConfig.normalizeUrl(raw);
                            urlController.text = normalized;
                            setDialogState(() {
                              isTesting = true;
                              testResult = null;
                            });
                            final result = await AppConfig.testConnection(normalized);
                            setDialogState(() {
                              isTesting = false;
                              testResult = result;
                            });
                          },
                    icon: isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check_rounded, size: 20),
                    label: Text(
                      isTesting ? 'Đang kiểm tra kết nối...' : 'Kiểm tra kết nối tới máy chủ',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                // Thẻ thông báo kết quả kiểm tra
                if (testResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: testResult!.isSuccess
                          ? AppTheme.successGreen.withValues(alpha: 0.1)
                          : AppTheme.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: testResult!.isSuccess
                            ? AppTheme.successGreen.withValues(alpha: 0.3)
                            : AppTheme.errorRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          testResult!.isSuccess
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: testResult!.isSuccess
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            testResult!.message,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: testResult!.isSuccess
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  '💡 Gợi ý: Nếu dùng máy chủ mới chưa có dữ liệu, hãy sang tab "Đăng ký" để tạo tài khoản mới.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final normalized = AppConfig.normalizeUrl(urlController.text);
                if (normalized.isEmpty ||
                    (!normalized.startsWith('http://') && !normalized.startsWith('https://'))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('URL phải bắt đầu bằng http:// hoặc https://'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                  return;
                }
                AppConfig.setApiBaseUrl(normalized, dio);
                Navigator.of(ctx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã cập nhật máy chủ: $normalized'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              },
              child: const Text('Lưu & Áp dụng'),
            ),
          ],
        ),
      ),
    );
  }
}

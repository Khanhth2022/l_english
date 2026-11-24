import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../state/auth_controller.dart';

/// Màn hình đổi mật khẩu — API §2.5 `POST /api/auth/change-password`.
///
/// Backend lấy tài khoản từ Bearer token nên màn hình chỉ gửi mật khẩu hiện tại
/// và mật khẩu mới. Đổi thành công thì toàn bộ refresh token của tài khoản bị
/// thu hồi: phiên đang dùng vẫn sống tới khi access token hết hạn, các phiên
/// khác không gia hạn được nữa.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  /// BCrypt chỉ dùng 72 byte đầu: backend từ chối mật khẩu dài hơn.
  static const int _maxPasswordBytes = 72;

  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const _SessionNotice(),
            const SizedBox(height: 14),
            if (authController.errorMessage != null) ...[
              _MessageBanner(
                icon: Icons.error_outline,
                color: AppTheme.errorRed,
                background: AppTheme.errorBg,
                message: authController.errorMessage!,
              ),
              const SizedBox(height: 14),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        enabled: !authController.isLoading,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu hiện tại',
                          prefixIcon: const Icon(Icons.lock_outline),
                          isDense: true,
                          suffixIcon: _VisibilityToggle(
                            obscure: _obscureCurrent,
                            onPressed: () => setState(
                              () => _obscureCurrent = !_obscureCurrent,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nhập mật khẩu hiện tại.';
                          }
                          if (_utf8Length(value) > _maxPasswordBytes) {
                            return 'Mật khẩu không được vượt quá '
                                '$_maxPasswordBytes byte.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        enabled: !authController.isLoading,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới (≥ 8 ký tự)',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          isDense: true,
                          suffixIcon: _VisibilityToggle(
                            obscure: _obscureNew,
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                        validator: (value) {
                          final next = value ?? '';
                          if (next.isEmpty) return 'Nhập mật khẩu mới.';
                          if (next.length < 8) {
                            return 'Mật khẩu mới phải có ít nhất 8 ký tự.';
                          }
                          if (_utf8Length(next) > _maxPasswordBytes) {
                            return 'Mật khẩu không được vượt quá '
                                '$_maxPasswordBytes byte.';
                          }
                          if (next == _currentPasswordController.text) {
                            return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        enabled: !authController.isLoading,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(authController),
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Nhập lại mật khẩu mới',
                          prefixIcon: const Icon(Icons.lock_clock_outlined),
                          isDense: true,
                          suffixIcon: _VisibilityToggle(
                            obscure: _obscureConfirm,
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nhập lại mật khẩu mới.';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Mật khẩu xác nhận không khớp.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: authController.isLoading
                            ? null
                            : () => _submit(authController),
                        child: authController.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Cập nhật mật khẩu'),
                                  SizedBox(width: 8),
                                  Icon(Icons.check_rounded, size: 18),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(AuthController authController) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await authController.changePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );
    if (!mounted || !success) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            authController.successMessage ?? 'Đổi mật khẩu thành công',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    Navigator.of(context).pop(true);
  }
}

/// Nút ẩn/hiện mật khẩu dùng chung cho ba ô nhập.
class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.obscure, required this.onPressed});

  final bool obscure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      icon: Icon(
        obscure ? Icons.visibility_off : Icons.visibility,
        size: 20,
      ),
      onPressed: onPressed,
    );
  }
}

/// Nhắc người dùng hệ quả của việc đổi mật khẩu trước khi họ bấm nút.
class _SessionNotice extends StatelessWidget {
  const _SessionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.aiBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentIndigo.withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.accentIndigo),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đổi mật khẩu sẽ đăng xuất mọi phiên khác của tài khoản. '
              'Phiên hiện tại vẫn dùng tiếp được tới khi access token hết hạn.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.textMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung thông báo lỗi lấy nguyên văn từ backend.
class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.icon,
    required this.color,
    required this.background,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Đếm byte UTF-8 như ràng buộc `@MaxUtf8Bytes(72)` của backend.
int _utf8Length(String value) => utf8.encode(value).length;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../state/auth_controller.dart';
import 'reset_password_screen.dart';
import 'widgets/auth_form_widgets.dart';

/// Quên mật khẩu — bước 1 của API §2.6 `POST /api/auth/forgot-password`.
///
/// Tài khoản được tra theo email chứ không phải username. Backend luôn trả 200
/// với cùng một câu thông báo dù email có đăng ký hay không (và cả khi SMTP
/// lỗi), nên màn hình này không được suy ra email có tồn tại hay không: cứ
/// chuyển sang bước nhập mã.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /// Cùng giới hạn với `ForgotPasswordForm` của backend (`@Email`, ≤ 254 ký tự).
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final isLoading = authController.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const _EmailRecoveryNotice(),
            const SizedBox(height: 14),
            if (authController.errorMessage != null) ...[
              AuthMessageBanner(
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
                        controller: _emailController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) => _requestCode(authController),
                        decoration: const InputDecoration(
                          labelText: 'Email đã đăng ký',
                          hintText: 'vidu@email.com',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                          isDense: true,
                        ),
                        validator: (value) => _validateEmail(value ?? ''),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => _requestCode(authController),
                        child: isLoading
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
                                  Text('Gửi mã xác thực'),
                                  SizedBox(width: 8),
                                  Icon(Icons.send_rounded, size: 18),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Đăng nhập bằng tên đăng nhập — email chỉ dùng để khôi phục '
              'mật khẩu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestCode(AuthController authController) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final success = await authController.forgotPassword(email);
    if (!mounted || !success) return;

    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          email: email,
          notice: authController.successMessage,
        ),
      ),
    );
    if (!mounted || completed != true) return;

    // Đặt lại thành công: đóng cả màn quên mật khẩu để về Đăng nhập.
    Navigator.of(context).pop(true);
  }

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Nhập email của tài khoản.';
    if (email.length > 254) {
      return 'Email không được vượt quá 254 ký tự.';
    }
    if (!_emailPattern.hasMatch(email)) return 'Email không hợp lệ.';
    return null;
  }
}

/// Giải thích trước khi người dùng gửi yêu cầu: mã sống bao lâu và vì sao
/// thông báo thành công không xác nhận email có tồn tại.
class _EmailRecoveryNotice extends StatelessWidget {
  const _EmailRecoveryNotice();

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
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppTheme.accentIndigo,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mã xác thực gồm 6 số, có hiệu lực 15 phút. Gửi lại bất cứ lúc '
              'nào sẽ huỷ mã cũ. Vì lý do bảo mật, hệ thống báo đã gửi kể cả '
              'khi email chưa đăng ký.',
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

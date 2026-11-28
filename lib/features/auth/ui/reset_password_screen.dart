import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../state/auth_controller.dart';
import 'widgets/auth_form_widgets.dart';

/// Quên mật khẩu — bước 2 của API §2.6 `POST /api/auth/reset-password`.
///
/// Gửi email + mã 6 số + mật khẩu mới. Thành công thì backend đổi hash, thu
/// hồi toàn bộ refresh token và xoá mã đã dùng trong cùng transaction; không
/// cấp token mới nên màn hình chỉ đóng lại để người dùng đăng nhập lại.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email, this.notice});

  /// Email đã dùng ở bước 1; gửi lại nguyên văn để backend tra đúng tài khoản.
  final String email;

  /// Thông báo bước 1 trả về, hiển thị lại cho người dùng biết mã đã được gửi.
  final String? notice;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  /// BCrypt chỉ dùng 72 byte đầu: backend từ chối mật khẩu dài hơn.
  static const int _maxPasswordBytes = 72;

  static final RegExp _codePattern = RegExp(r'^[0-9]{6}$');

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final isLoading = authController.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lại mật khẩu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _EmailChip(email: widget.email),
            const SizedBox(height: 12),
            if (widget.notice != null) ...[
              AuthMessageBanner(
                icon: Icons.mark_email_read_outlined,
                color: AppTheme.successGreen,
                background: AppTheme.successBg,
                message: widget.notice!,
              ),
              const SizedBox(height: 14),
            ],
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
                        controller: _codeController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 6,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Mã xác thực',
                          hintText: '123456',
                          prefixIcon: Icon(Icons.pin_outlined),
                          counterText: '',
                          isDense: true,
                        ),
                        validator: (value) {
                          final code = (value ?? '').trim();
                          if (code.isEmpty) return 'Nhập mã xác thực.';
                          if (!_codePattern.hasMatch(code)) {
                            return 'Mã xác thực phải gồm 6 chữ số.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới (≥ 8 ký tự)',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          isDense: true,
                          suffixIcon: PasswordVisibilityToggle(
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
                          if (utf8ByteLength(next) > _maxPasswordBytes) {
                            return 'Mật khẩu không được vượt quá '
                                '$_maxPasswordBytes byte.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(authController),
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Nhập lại mật khẩu mới',
                          prefixIcon: const Icon(Icons.lock_clock_outlined),
                          isDense: true,
                          suffixIcon: PasswordVisibilityToggle(
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
                        onPressed: isLoading
                            ? null
                            : () => _submit(authController),
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
                                  Text('Đặt lại mật khẩu'),
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
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Không nhận được mã?',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                TextButton(
                  onPressed: isLoading ? null : () => _resend(authController),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Gửi lại mã'),
                ),
              ],
            ),
            const Text(
              'Mã dùng một lần. Đặt lại thành công sẽ thu hồi mọi phiên đăng '
              'nhập cũ — bạn cần đăng nhập lại bằng mật khẩu mới.',
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

  Future<void> _submit(AuthController authController) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await authController.resetPassword(
      widget.email,
      _codeController.text.trim(),
      _newPasswordController.text,
    );
    if (!mounted || !success) return;

    // AuthScreen hiển thị successMessage của controller khi quay về, nên không
    // cần snackbar riêng ở đây.
    Navigator.of(context).pop(true);
  }

  Future<void> _resend(AuthController authController) async {
    FocusScope.of(context).unfocus();
    final success = await authController.forgotPassword(widget.email);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Đã gửi lại mã tới ${widget.email}.'
                : (authController.errorMessage ?? 'Không gửi lại được mã.'),
          ),
          backgroundColor: success ? AppTheme.successGreen : null,
        ),
      );
  }
}

/// Email đang khôi phục + lối thoát về bước 1 nếu người dùng gõ nhầm.
class _EmailChip extends StatelessWidget {
  const _EmailChip({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.alternate_email_rounded,
            size: 18,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              email,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đổi email'),
          ),
        ],
      ),
    );
  }
}

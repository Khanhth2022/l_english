import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../state/auth_controller.dart';
import 'widgets/auth_form_widgets.dart';

/// Đăng ký — bước 2 của API §5.1 `POST /api/auth/register/confirm`.
///
/// Backend chỉ tạo dòng `users` khi mã 6 số khớp với bản nháp
/// `pending_registrations`; mã sống 10 phút, dùng một lần, sai 5 lần thì bản
/// nháp bị xoá và người dùng phải đăng ký lại từ bước 1. Thành công không cấp
/// token nên màn hình chỉ đóng lại để quay về màn Đăng nhập.
///
/// Nhận lại toàn bộ form của bước 1 để nút "Gửi lại mã" gọi đúng endpoint
/// register: backend không có route gửi lại riêng, gọi lại chính là gửi lại.
class RegisterConfirmScreen extends StatefulWidget {
  const RegisterConfirmScreen({
    super.key,
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    this.notice,
  });

  final String name;
  final String username;
  final String email;
  final String password;

  /// Câu bước 1 trả về, hiển thị lại để người dùng biết mã đã được gửi.
  final String? notice;

  @override
  State<RegisterConfirmScreen> createState() => _RegisterConfirmScreenState();
}

class _RegisterConfirmScreenState extends State<RegisterConfirmScreen> {
  static final RegExp _codePattern = RegExp(r'^[0-9]{6}$');

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final isLoading = authController.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực email')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _EmailChip(email: widget.email),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 20,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.notice ??
                          'Mã xác thực đã được gửi tới ${widget.email}. '
                              'Mã gồm 6 số, sống 10 phút và chỉ dùng một lần.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textMain,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (authController.errorMessage != null) ...[
              const SizedBox(height: 12),
              AuthMessageBanner(
                icon: Icons.error_outline,
                color: AppTheme.errorRed,
                background: AppTheme.errorBg,
                message: authController.errorMessage!,
              ),
            ],
            const SizedBox(height: 14),
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
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        onFieldSubmitted: (_) => _submit(authController),
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
                      const SizedBox(height: 18),
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
                                  Text('Xác thực & tạo tài khoản'),
                                  SizedBox(width: 8),
                                  Icon(Icons.verified_rounded, size: 18),
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
              'Sai mã 5 lần, bản nháp đăng ký bị huỷ và bạn phải đăng ký lại '
              'từ đầu. Sau khi xác thực, đăng nhập bằng tên đăng nhập — không '
              'phải email.',
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

    final success = await authController.confirmRegistration(
      widget.email,
      _codeController.text.trim(),
    );
    if (!mounted || !success) return;

    // AuthScreen đọc `successMessage` của controller để hiện banner xanh, nên
    // ở đây chỉ cần đóng màn hình.
    Navigator.of(context).pop(true);
  }

  /// Gửi lại mã = gọi lại endpoint register với đúng form bước 1; backend phát
  /// mã mới và huỷ mã cũ ngay.
  Future<void> _resend(AuthController authController) async {
    FocusScope.of(context).unfocus();
    final success = await authController.register(
      name: widget.name,
      username: widget.username,
      email: widget.email,
      password: widget.password,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (authController.successMessage ??
                      'Đã gửi lại mã tới ${widget.email}.')
                : (authController.errorMessage ?? 'Không gửi lại được mã.'),
          ),
          backgroundColor: success ? AppTheme.successGreen : null,
        ),
      );
  }
}

/// Email đang xác thực + lối thoát về bước 1 nếu người dùng gõ nhầm.
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

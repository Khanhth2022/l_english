import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/services/reminder/reminder_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../users/state/user_profile_controller.dart';
import '../state/auth_controller.dart';
import 'change_password_screen.dart';

/// Màn hình thông tin tài khoản và cấu hình hệ thống (act-03).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Tải hồ sơ sau frame đầu: load() gọi notifyListeners nên không được chạy
    // ngay trong lúc cây widget đang build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<UserProfileController>();
      // Đồng bộ tên hiển thị vào thông báo nhắc ôn tập sau khi hồ sơ tải xong.
      controller.load().then((_) {
        if (mounted) ReminderService.updateUserName(controller.displayName);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final tokenStore = context.watch<TokenStore>();
    final userProfile = context.watch<UserProfileController>();

    final username = tokenStore.currentUsername ?? 'Người dùng';
    final displayName = userProfile.displayName ?? username;
    final hasTokens = tokenStore.hasSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản & Cài đặt'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primaryBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasTokens ? 'Đang đăng nhập • Phiên hợp lệ' : 'Chưa có phiên',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: AppTheme.primaryBlue),
                  title: const Text('Đổi tên hiển thị', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    userProfile.profile?.name ?? 'Chưa đặt tên — đang dùng tên đăng nhập',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: userProfile.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  onTap: userProfile.isLoading
                      ? null
                      : () => _openRenameDialog(userProfile),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryBlue),
                  title: const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Mọi phiên đăng nhập khác sẽ bị đăng xuất'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  onTap: () => _openChangePassword(context, authController),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
                  title: const Text('Đăng xuất tài khoản', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
                  onTap: () => _confirmLogout(context, authController),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hộp thoại đổi tên hiển thị — chỉ gửi `name`, đúng hợp đồng `PUT /api/users/me`.
  Future<void> _openRenameDialog(UserProfileController controller) async {
    // Dùng initialValue + onChanged thay vì TextEditingController để không
    // phải quản lý vòng đời controller qua animation đóng dialog.
    var draft = controller.profile?.name ?? '';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên hiển thị'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tên hiển thị chỉ dùng trong ứng dụng; tên đăng nhập và mật khẩu giữ nguyên.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.35),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: draft,
                autofocus: true,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  prefixIcon: Icon(Icons.badge_outlined),
                  isDense: true,
                ),
                onChanged: (value) => draft = value,
                validator: (value) {
                  final name = (value ?? '').trim();
                  if (name.isEmpty) return 'Tên hiển thị không được để trống.';
                  if (name.length > 100) {
                    return 'Tên hiển thị không được vượt quá 100 ký tự.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(ctx).pop(true);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await controller.updateName(draft);
    if (!mounted) return;

    if (success) {
      // Tên mới phải xuất hiện trong thông báo nhắc ôn tập.
      ReminderService.updateUserName(controller.displayName);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (controller.successMessage ?? 'Cập nhật tên thành công')
                : (controller.errorMessage ?? 'Đổi tên không thành công.'),
          ),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      );
  }

  Future<void> _openChangePassword(BuildContext context, AuthController authController) {
    // Thông báo của lần đăng nhập trước không được rò sang màn đổi mật khẩu.
    authController.clearMessages();
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AuthController authController) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi phiên làm việc hiện tại không?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authController.logout();
    }
  }
}

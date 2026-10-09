import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../words/ui/connection_settings_screen.dart';
import '../state/auth_controller.dart';

/// Màn hình thông tin tài khoản và cấu hình hệ thống (act-03).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final tokenStore = context.watch<TokenStore>();
    final username = tokenStore.currentUsername ?? 'Người dùng';
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
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
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
                        username,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
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

          // Environment info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Môi trường hoạt động',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Chế độ API:', AppConfig.useMockApi ? 'API giả lập (Bộ nhớ)' : 'Backend Spring Boot thật'),
                  const Divider(height: 18),
                  _buildInfoRow('Địa chỉ máy chủ:', AppConfig.apiBaseUrl),
                  const Divider(height: 18),
                  _buildInfoRow('Thuật toán ôn tập:', 'Spaced Repetition (1, 2, 4, 7, 15, 30 ngày)'),
                  const Divider(height: 18),
                  _buildInfoRow('Cơ chế token:', 'JWT HS256 + Refresh Token Rotation'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_ethernet_rounded, color: AppTheme.primaryBlue),
                  title: const Text('Cấu hình kết nối Backend'),
                  subtitle: const Text('Đổi URL API máy chủ hoặc dán token thủ công', style: TextStyle(fontSize: 12.5)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ConnectionSettingsScreen()),
                    );
                  },
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
          const SizedBox(height: 24),

          Center(
            child: Text(
              'LEnglish App v1.0.0 • Bám sát tài liệu thiết kế',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain),
          ),
        ),
      ],
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

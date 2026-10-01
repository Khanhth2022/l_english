import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/config/app_config.dart';

/// Màn hình tạm để xem cấu hình và dán token khi thử với backend thật.
///
/// Khi nhánh `feature/auth` hoàn thành, màn hình này sẽ được thay bằng màn hình
/// Đăng nhập thật (token do backend cấp sau khi đăng nhập).
class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final TextEditingController _accessController = TextEditingController();
  final TextEditingController _refreshController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final tokens = context.read<TokenStore>().tokens;
    _accessController.text = tokens?.accessToken ?? '';
    _refreshController.text = tokens?.refreshToken ?? '';
  }

  @override
  void dispose() {
    _accessController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _saveSession() async {
    final accessToken = _accessController.text.trim();
    if (accessToken.isEmpty) {
      _showMessage('Cần ít nhất access token.');
      return;
    }
    await context.read<TokenStore>().save(
      TokenPair(
        accessToken: accessToken,
        refreshToken: _refreshController.text.trim(),
      ),
    );
    if (!mounted) return;
    _showMessage('Đã lưu token cho phiên hiện tại.');
  }

  Future<void> _clearSession() async {
    await context.read<TokenStore>().clear();
    if (!mounted) return;
    setState(() {
      _accessController.clear();
      _refreshController.clear();
    });
    _showMessage('Đã xoá token của phiên.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMock = AppConfig.useMockApi;

    return Scaffold(
      appBar: AppBar(title: const Text('Cấu hình kết nối')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoRow(label: 'Địa chỉ API', value: AppConfig.apiBaseUrl),
          _InfoRow(
            label: 'Nguồn dữ liệu',
            value: isMock ? 'API giả chạy trong app' : 'Backend thật',
          ),
          const Divider(height: 32),
          if (isMock)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'App đang chạy bằng API giả nên không cần token.\n'
                  'Muốn nối backend thật, chạy lại app với:\n\n'
                  'flutter run --dart-define=USE_MOCK_API=false \\\n'
                  '  --dart-define=API_BASE_URL=http://<IP-máy-tính>:8080',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            )
          else ...[
            Text(
              'Dán token lấy từ backend (ví dụ sau khi gọi '
              'POST /api/auth/login bằng Postman).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _accessController,
              decoration: const InputDecoration(
                labelText: 'Access token',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _refreshController,
              decoration: const InputDecoration(
                labelText: 'Refresh token',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _saveSession,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Lưu phiên'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _clearSession,
                  icon: const Icon(Icons.logout),
                  label: const Text('Xoá phiên'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

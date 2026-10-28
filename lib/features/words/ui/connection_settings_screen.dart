import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/widget/widget_service.dart';

/// Màn hình cấu hình kết nối backend khi thử nghiệm.
///
/// Cho phép đổi Base URL, dán token và username, rồi đồng bộ ngay xuống
/// Widget Android để widget dùng đúng máy chủ và token mới.
class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  late final TextEditingController _baseUrlController;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _accessController = TextEditingController();
  final TextEditingController _refreshController = TextEditingController();

  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<TokenStore>();
    _baseUrlController = TextEditingController(text: AppConfig.apiBaseUrl);
    _usernameController.text = store.currentUsername ?? '';
    _accessController.text = store.tokens?.accessToken ?? '';
    _refreshController.text = store.tokens?.refreshToken ?? '';
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _accessController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_saving) return;

    final rawBaseUrl = _baseUrlController.text.trim();
    final baseUrl = AppConfig.normalizeUrl(rawBaseUrl);
    if (baseUrl.isEmpty ||
        (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://'))) {
      _showMessage('Base URL không hợp lệ. Ví dụ: https://api.example.com');
      return;
    }

    final accessToken = _accessController.text.trim();
    final refreshToken = _refreshController.text.trim();
    final username = _usernameController.text.trim();

    // Token lưu trong secure storage cần đủ cặp access + refresh; thiếu một
    // trong hai thì không thể làm mới phiên sau này.
    if (accessToken.isEmpty != refreshToken.isEmpty) {
      _showMessage('Cần nhập đủ cả access token và refresh token.');
      return;
    }

    setState(() {
      _saving = true;
    });

    final store = context.read<TokenStore>();
    final dio = context.read<Dio?>();

    try {
      AppConfig.setApiBaseUrl(baseUrl, dio);
      _baseUrlController.text = AppConfig.apiBaseUrl;

      if (accessToken.isNotEmpty) {
        await store.save(
          TokenPair(accessToken: accessToken, refreshToken: refreshToken),
          username: username.isEmpty ? null : username,
        );
        await WidgetService.syncWidget(
          accessToken: accessToken,
          baseUrl: AppConfig.apiBaseUrl,
        );
      }

      if (!mounted) return;
      _showMessage(
        accessToken.isEmpty
            ? 'Đã lưu Base URL. Chưa có token nên widget chưa được đồng bộ.'
            : 'Đã lưu cấu hình và đồng bộ xuống widget.',
      );
    } catch (error) {
      debugPrint('ConnectionSettingsScreen: không lưu được cấu hình ($error).');
      if (!mounted) return;
      _showMessage(
        'Không lưu được cấu hình. Vui lòng kiểm tra lại Base URL và token.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    setState(() {
      _testing = true;
    });
    final result = await AppConfig.testConnection(_baseUrlController.text);
    if (!mounted) return;
    setState(() {
      _testing = false;
    });
    _showMessage(result.message);
  }

  Future<void> _clearSession() async {
    await context.read<TokenStore>().clear();
    if (!mounted) return;
    setState(() {
      _usernameController.clear();
      _accessController.clear();
      _refreshController.clear();
    });
    await WidgetService.syncWidget(accessToken: '');
    if (!mounted) return;
    _showMessage('Đã xoá token của phiên.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
          _InfoRow(
            label: 'Nguồn dữ liệu',
            value: isMock ? 'API giả chạy trong app' : 'Backend thật',
          ),
          const Divider(height: 32),
          TextField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              helperText: 'Ví dụ: http://10.0.2.2:8080',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: const Text('Kiểm tra kết nối'),
            ),
          ),
          const SizedBox(height: 16),
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
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Tên đăng nhập',
                border: OutlineInputBorder(),
              ),
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
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Lưu phiên'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _clearSession,
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

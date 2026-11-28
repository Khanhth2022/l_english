import 'dart:convert';

import 'package:flutter/material.dart';

/// Khung thông báo dùng chung cho các màn xác thực.
///
/// Màu và icon do nơi gọi quyết định để lỗi (đỏ) và thành công (xanh) dùng
/// cùng một bố cục, đúng ngôn ngữ thị giác của `AuthScreen`.
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    super.key,
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

/// Nút ẩn/hiện mật khẩu cho các ô nhập `obscureText`.
class PasswordVisibilityToggle extends StatelessWidget {
  const PasswordVisibilityToggle({
    super.key,
    required this.obscure,
    required this.onPressed,
  });

  final bool obscure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20),
      onPressed: onPressed,
    );
  }
}

/// Đếm byte UTF-8 đúng như ràng buộc `@MaxUtf8Bytes(72)` của backend.
///
/// BCrypt chỉ dùng 72 byte đầu nên backend từ chối mật khẩu dài hơn thay vì
/// âm thầm cắt bớt.
int utf8ByteLength(String value) => utf8.encode(value).length;

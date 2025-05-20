import 'package:flutter/material.dart';

class ViewProfileScreen extends StatelessWidget {
  const ViewProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Avatar
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 24),
            // Thông tin người dùng
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Tên hiển thị'),
              subtitle: const Text('Nguyễn Văn A'), // Placeholder
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Số điện thoại'),
              subtitle: const Text('+84 123 456 789'), // Placeholder
            ),
            const SizedBox(height: 24),
            // Nút Đổi mật khẩu
            ElevatedButton(
              onPressed: () {}, // Placeholder
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Đổi mật khẩu'),
            ),
            const SizedBox(height: 16),
            // Nút Đăng xuất
            OutlinedButton(
              onPressed: () {}, // Placeholder
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }
}

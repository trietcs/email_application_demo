import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // File được tạo bởi flutterfire configure

void main() async {
  // Đảm bảo các binding của Flutter đã được khởi tạo trước khi chạy code native
  WidgetsFlutterBinding.ensureInitialized(); // Quan trọng!

  // Khởi tạo Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Chạy ứng dụng Flutter
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Constructor của MyApp
  const MyApp({super.key}); // Thêm const và super.key là good practice

  @override
  Widget build(BuildContext context) {
    // MaterialApp là widget gốc cho hầu hết các ứng dụng Flutter
    // Nó cung cấp các chức năng điều hướng, theme, v.v.
    return MaterialApp(
      // Tắt banner "DEBUG" ở góc trên bên phải
      debugShowCheckedModeBanner: false,
      // Trang chủ của ứng dụng
      home: Scaffold(
        // Scaffold cung cấp cấu trúc cơ bản cho một màn hình (AppBar, Body, v.v.)
        appBar: AppBar(
          // Tiêu đề cho AppBar
          title: const Text('Kiểm tra Flutter & Firebase'),
          backgroundColor: Colors.blue, // Bạn có thể đổi màu
        ),
        // Phần thân của màn hình
        body: Center(
          // Center dùng để căn giữa widget con của nó
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Căn giữa theo chiều dọc
            children: <Widget>[
              const Text(
                'Flutter đã chạy thành công!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10), // Một chút khoảng cách
              FutureBuilder(
                future:
                    Firebase.app().options.apiKey.isNotEmpty
                        ? Future.value(true)
                        : Future.value(false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasData && snapshot.data == true) {
                    return const Text(
                      'Firebase đã kết nối (có API Key)!',
                      style: TextStyle(fontSize: 18, color: Colors.green),
                      textAlign: TextAlign.center,
                    );
                  } else {
                    return const Text(
                      'Firebase có vẻ chưa kết nối đúng (thiếu API Key hoặc lỗi).',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                      textAlign: TextAlign.center,
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Nếu bạn thấy màn hình này trên máy ảo/thiết bị Android, xin chúc mừng!',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

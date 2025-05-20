import 'package:flutter/material.dart';

class ComposeEmailScreen extends StatelessWidget {
  const ComposeEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soạn thư'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {}, // Placeholder
            tooltip: 'Gửi',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {}, // Placeholder
            tooltip: 'Lưu nháp',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Đến',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Chủ đề',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  border: OutlineInputBorder(),
                ),
                maxLines: null, // Cho phép mở rộng
                minLines: 10,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

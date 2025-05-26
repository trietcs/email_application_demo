import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:email_application/config/app_colors.dart';

enum AttachmentType { image, pdf, text, unsupported }

class AttachmentViewerScreen extends StatefulWidget {
  final String attachmentUrl;
  final String attachmentName;
  final String? attachmentMimeType;

  const AttachmentViewerScreen({
    super.key,
    required this.attachmentUrl,
    required this.attachmentName,
    this.attachmentMimeType,
  });

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  AttachmentType _type = AttachmentType.unsupported;
  String? _textContent;
  bool _isLoading = true;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _determineAttachmentTypeAndLoad();
  }

  Future<void> _determineAttachmentTypeAndLoad() async {
    setState(() {
      _isLoading = true;
      _loadingError = null;
    });

    String mime = widget.attachmentMimeType?.toLowerCase() ?? '';
    String urlLower = widget.attachmentUrl.toLowerCase();

    if (mime.startsWith('image/')) {
      _type = AttachmentType.image;
    } else if (mime == 'application/pdf' || urlLower.endsWith('.pdf')) {
      _type = AttachmentType.pdf;
    } else if (mime.startsWith('text/') ||
        urlLower.endsWith('.txt') ||
        urlLower.endsWith('.csv') ||
        urlLower.endsWith('.log')) {
      _type = AttachmentType.text;
      try {
        final response = await http.get(Uri.parse(widget.attachmentUrl));
        if (response.statusCode == 200) {
          _textContent = response.body;
        } else {
          throw Exception(
            'Failed to load text content: ${response.statusCode}',
          );
        }
      } catch (e) {
        _loadingError = 'Error loading text file: ${e.toString()}';
        _type = AttachmentType.unsupported;
      }
    } else {
      _type = AttachmentType.unsupported;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _launchUrl() async {
    if (!await launchUrl(
      Uri.parse(widget.attachmentUrl),
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch ${widget.attachmentName}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.attachmentName,
          style: TextStyle(color: AppColors.appBarForeground),
        ),
        backgroundColor: AppColors.appBarBackground,
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : _loadingError != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Could not display attachment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      Text(
                        _loadingError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Try Opening Externally'),
                        onPressed: _launchUrl,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : _buildContentView(),
    );
  }

  Widget _buildContentView() {
    switch (_type) {
      case AttachmentType.image:
        return PhotoView(
          imageProvider: NetworkImage(widget.attachmentUrl),
          loadingBuilder:
              (context, event) => Center(
                child: CircularProgressIndicator(
                  value:
                      event == null || event.expectedTotalBytes == null
                          ? null
                          : event.cumulativeBytesLoaded /
                              event.expectedTotalBytes!,
                  color: AppColors.primary,
                ),
              ),
          errorBuilder:
              (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 48,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Error loading image",
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
        );
      case AttachmentType.pdf:
        return FutureBuilder<String>(
          future: _downloadFile(
            widget.attachmentUrl,
            "${widget.attachmentName}.pdf",
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Text(
                  'Error loading PDF: ${snapshot.error ?? "File not found"}',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              );
            }
            return PDFView(
              filePath: snapshot.data!,
              onError: (error) {
                print(error.toString());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error displaying PDF: $error')),
                );
              },
            );
          },
        );

      case AttachmentType.text:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Text(_textContent ?? 'No content or failed to load.'),
        );
      case AttachmentType.unsupported:
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 48,
                color: AppColors.secondaryText,
              ),
              const SizedBox(height: 16),
              Text(
                'Unsupported attachment type: ${widget.attachmentMimeType ?? widget.attachmentName.split('.').last}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Try Opening Externally'),
                onPressed: _launchUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        );
    }
  }

  Future<String> _downloadFile(String url, String filename) async {
    final http.Response response = await http.get(Uri.parse(url));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }
}

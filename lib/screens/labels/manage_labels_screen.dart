import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/label_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/config/app_colors.dart';

class ManageLabelsScreen extends StatefulWidget {
  const ManageLabelsScreen({super.key});

  @override
  State<ManageLabelsScreen> createState() => _ManageLabelsScreenState();
}

class _ManageLabelsScreenState extends State<ManageLabelsScreen> {
  late FirestoreService _firestoreService;
  late AuthService _authService;
  List<LabelData> _labels = [];
  bool _isLoading = true;
  String? _userId;

  final List<Color> _predefinedLabelColors = [
    Colors.red.shade300,
    Colors.orange.shade400,
    Colors.yellow.shade600,
    Colors.green.shade400,
    Colors.blue.shade400,
    Colors.indigo.shade300,
    Colors.purple.shade300,
    Colors.pink.shade300,
    Colors.teal.shade300,
    Colors.brown.shade400,
    Colors.blueGrey.shade400,
    Colors.grey.shade500,
  ];

  @override
  void initState() {
    super.initState();
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    _userId = _authService.currentUser?.uid;
    _fetchLabels();
  }

  Future<void> _fetchLabels() async {
    if (_userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final labels = await _firestoreService.getLabelsForUser(_userId!);
      if (mounted) {
        setState(() {
          _labels = labels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error fetching labels: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching labels: ${e.toString()}")),
      );
    }
  }

  Future<void> _showLabelDialog({LabelData? existingLabel}) async {
    final _labelNameController = TextEditingController(
      text: existingLabel?.name ?? '',
    );
    Color _selectedColor =
        existingLabel?.color ??
        _predefinedLabelColors.first;
    final _formKey = GlobalKey<FormState>();

    Color? pickedColor = await showDialog<Color?>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existingLabel == null ? 'Create New Label' : 'Edit Label',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: _labelNameController,
                        decoration: const InputDecoration(
                          labelText: 'Label Name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a label name.';
                          }
                          if (_labels.any(
                            (label) =>
                                label.name.toLowerCase() ==
                                    value.trim().toLowerCase() &&
                                (existingLabel == null ||
                                    label.id != existingLabel.id),
                          )) {
                            return 'This label name already exists.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Select Color:',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children:
                            _predefinedLabelColors.map((color) {
                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    _selectedColor = color;
                                  });
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          _selectedColor == color
                                              ? Theme.of(
                                                context,
                                              ).primaryColorDark
                                              : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 20,
                        width: 100,
                        color: _selectedColor,
                      ), // Simple preview
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    existingLabel == null ? 'Create' : 'Save',
                    style: TextStyle(color: AppColors.onPrimary),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.of(
                        context,
                      ).pop(_selectedColor);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedColor != null && _userId != null) {
      final String labelName = _labelNameController.text.trim();
      setState(() => _isLoading = true);
      try {
        if (existingLabel == null) {
          await _firestoreService.createLabel(_userId!, labelName, pickedColor);
        } else {
          await _firestoreService.updateLabel(
            _userId!,
            existingLabel.id,
            newName: labelName,
            newColor: pickedColor,
          );
        }
        await _fetchLabels();
      } catch (e) {
        print("Error saving label: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving label: ${e.toString()}")),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDeleteLabel(LabelData label) async {
    if (_userId == null) return;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Label'),
          content: Text(
            'Are you sure you want to delete the label "${label.name}"? This will remove it from all associated emails.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _firestoreService.deleteLabel(_userId!, label.id);
        await _fetchLabels();
      } catch (e) {
        print("Error deleting label: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting label: ${e.toString()}")),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Labels',
          style: TextStyle(color: AppColors.appBarForeground),
        ),
        backgroundColor: AppColors.appBarBackground,
        iconTheme: IconThemeData(color: AppColors.primary),
        elevation: 1,
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : _userId == null
              ? const Center(child: Text("Please log in to manage labels."))
              : RefreshIndicator(
                onRefresh: _fetchLabels,
                child:
                    _labels.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.label_off_outlined,
                                size: 60,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No labels created yet.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Create First Label'),
                                onPressed: () => _showLabelDialog(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.separated(
                          itemCount: _labels.length,
                          separatorBuilder:
                              (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final label = _labels[index];
                            return ListTile(
                              leading: Icon(
                                Icons.label,
                                color: label.color,
                                size: 28,
                              ),
                              title: Text(
                                label.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: AppColors.secondaryIcon,
                                    ),
                                    tooltip: 'Edit Label',
                                    onPressed:
                                        () => _showLabelDialog(
                                          existingLabel: label,
                                        ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: AppColors.error.withOpacity(0.8),
                                    ),
                                    tooltip: 'Delete Label',
                                    onPressed: () => _confirmDeleteLabel(label),
                                  ),
                                ],
                              ),
                              onTap:
                                  () => _showLabelDialog(
                                    existingLabel: label,
                                  ),
                            );
                          },
                        ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLabelDialog(),
        backgroundColor: AppColors.primary,
        tooltip: 'Create New Label',
        child: Icon(Icons.add, color: AppColors.onPrimary),
      ),
    );
  }
}

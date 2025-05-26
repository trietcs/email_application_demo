// lib/models/email_folder.dart

/// Represents the different folders an email can be in.
enum EmailFolder {
  inbox,
  sent,
  drafts,
  trash;

  /// Returns the string representation of the folder name, suitable for storage or display.
  String get folderName {
    return name;
  }

  /// Creates an EmailFolder from a string name.
  /// Throws an ArgumentError if the name is not a valid folder.
  static EmailFolder fromName(String? name) {
    if (name == null) {
      // Default to inbox or handle as an error if a folder name is always expected
      print('Warning: Null folder name encountered. Defaulting to inbox.');
      return EmailFolder.inbox;
    }
    for (var folder in values) {
      if (folder.name == name) {
        return folder;
      }
    }
    // Fallback or default, though ideally originalFolder should always be valid if set
    print(
      'Warning: Unknown folder name "$name" encountered. Defaulting to inbox.',
    );
    return EmailFolder
        .inbox; // Or throw ArgumentError('Invalid folder name: $name');
  }
}

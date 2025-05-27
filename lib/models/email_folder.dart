enum EmailFolder {
  inbox,
  sent,
  drafts,
  trash;

  String get folderName {
    return name;
  }

  static EmailFolder fromName(String? name) {
    if (name == null) {
      print('Warning: Null folder name encountered. Defaulting to inbox.');
      return EmailFolder.inbox;
    }
    for (var folder in values) {
      if (folder.name == name) {
        return folder;
      }
    }
    print(
      'Warning: Unknown folder name "$name" encountered. Defaulting to inbox.',
    );
    return EmailFolder
        .inbox;
  }
}

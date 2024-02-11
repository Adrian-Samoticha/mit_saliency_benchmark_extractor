extension Sanitize on String {
  String sanitize() {
    return replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-');
  }
}

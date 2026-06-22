// class ChatMessage {
//   final String text;
//   final bool isUser;
//   final bool isError;
//   final bool isLanguageSelector;
//   final String? query;
//   final int? messageIndex;
//   final DateTime timestamp;
//
//   ChatMessage({
//     required this.text,
//     required this.isUser,
//     this.isError = false,
//     this.isLanguageSelector = false,
//     this.query,
//     this.messageIndex,
//     DateTime? timestamp,
//   }) : timestamp = timestamp ?? DateTime.now();
// }

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isLanguageSelector;

  // FIX: Flag the "→ 🇵🇰 اردو" bubble so screen can hide it cleanly
  final bool isLanguageConfirmation;

  final String? query;
  final int? messageIndex;
  final DateTime timestamp;

  // Related follow-up suggestions shown below a bot response
  final List<String>? suggestions;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.isLanguageSelector = false,
    this.isLanguageConfirmation = false,
    this.query,
    this.messageIndex,
    this.suggestions,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
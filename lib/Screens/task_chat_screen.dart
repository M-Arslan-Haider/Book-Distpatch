// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:record/record.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:open_file/open_file.dart';
//
// import '../AppColors.dart';
// import '../Models/task_model.dart';
//
// // ── Voice note streaming URL ─────────────────────────────────
// const _kVoiceNoteBase =
//     'http://oracle.metaxperts.net/ords/gps_workforce/voicenotes/note/';
//
// // ── Voice note upload URL ─────────────────────────────────────
// const _kVoiceSendUrl =
//     'http://oracle.metaxperts.net/ords/gps_workforce/task-voice/send';
//
// // ── File attachment GET (view / download) URL ──────────────────
// // Serves the raw BLOB (with correct mime + Content-Disposition) for
// // both images (inline preview) and documents (download-then-open).
// const _kFileGetBase =
//     'http://oracle.metaxperts.net/ords/gps_workforce/task-file/get/';
//
// // ═══════════════════════════════════════════════════════════════
// //  MODEL
// // ═══════════════════════════════════════════════════════════════
//
// class _ChatMsg {
//   final String id;
//   final String senderName;
//   final String text;
//   final DateTime time;
//   final bool isMe;
//   final bool isAdmin;
//   final bool isAudio;      // voice note
//   final bool isAttachment; // file attachment
//   final String fileName;   // original file name
//   final String mimeType;   // mime type
//   final String fileId;     // TM_TASK_CHAT_FILES.FILE_ID (used for task-file/get/:id)
//
//   const _ChatMsg({
//     required this.id,
//     required this.senderName,
//     required this.text,
//     required this.time,
//     required this.isMe,
//     this.isAdmin = false,
//     this.isAudio = false,
//     this.isAttachment = false,
//     this.fileName = '',
//     this.mimeType = '',
//     this.fileId = '',
//   });
//
//   /// Strip Oracle's "[File: report.pdf]" / "[Photo]" style placeholder text
//   /// down to a clean filename with a valid extension. Without this the
//   /// trailing "]" breaks extension-based image detection and corrupts the
//   /// filename used when saving/opening the file.
//   static String _cleanFileName(String raw) {
//     var s = raw.trim();
//     if (s.isEmpty) return s;
//
//     // "[File: name.ext]" → "name.ext"
//     final match = RegExp(r'^\[\s*File\s*:\s*(.+?)\s*\]$', caseSensitive: false)
//         .firstMatch(s);
//     if (match != null) {
//       s = match.group(1)!.trim();
//     } else {
//       // Generic bracket strip: "[Photo]", "[Image]", trailing/leading "[" "]"
//       s = s.replaceAll(RegExp(r'^\[+'), '').replaceAll(RegExp(r'\]+$'), '').trim();
//     }
//     return s;
//   }
//
//   /// Parse from ORDS JSON row
//   factory _ChatMsg.fromJson(Map<String, dynamic> json, String currentEmpId) {
//     // ORDS returns lowercase column names
//     final loggedBy = json['logged_by']?.toString() ?? '';
//     final loggedType = json['logged_type'] as String?;
//     final isAdmin = loggedType != null &&
//         loggedType.toUpperCase() == 'ADMIN';
//
//     // isMe: current employee sent this (not admin, same ID)
//     final isMe = !isAdmin && loggedBy == currentEmpId;
//
//     // Parse timestamp  (e.g. "2025-06-30T10:30:00" or "2025-06-30T10:30:00+05:00")
//     DateTime time = DateTime.now();
//     final rawTime = json['logged_at'] as String? ?? json['log_date'] as String? ?? '';
//     if (rawTime.isNotEmpty) {
//       try {
//         time = DateTime.parse(rawTime);
//       } catch (_) {}
//     }
//
//     final name = json['employee_name'] as String? ?? (isAdmin ? 'Admin' : 'Unknown');
//
//     // detect voice note – by msg_type / logged_type field OR by note placeholder text
//     final msgType = (json['msg_type'] ?? json['note_type'] ??
//         json['message_type'] ?? '')
//         .toString()
//         .toUpperCase()
//         .trim();
//     final noteText = (json['note'] as String? ?? '').trim().toLowerCase();
//     final isAudio = msgType == 'AUDIO' ||
//         loggedType?.toUpperCase() == 'AUDIO' ||
//         noteText == 'voice message'   ||
//         noteText == '[voice message]' ||
//         noteText == 'voice note'      ||
//         noteText == 'voicenote'       ||
//         noteText == 'audio';
//
//     // detect file attachment – Oracle uses logged_type field
//     final isAttachment = msgType == 'FILE' ||
//         msgType == 'ATTACHMENT' ||
//         msgType == 'DOCUMENT' ||
//         loggedType?.toUpperCase() == 'FILE' ||
//         loggedType?.toUpperCase() == 'ATTACHMENT' ||
//         loggedType?.toUpperCase() == 'DOCUMENT';
//
//     // fileName: prefer explicit field, fallback to note (Oracle often puts a
//     // placeholder like "[File: report.pdf]" in the note column instead of a
//     // clean file_name column). Strip that wrapper so we get a real filename
//     // with a valid extension (needed for image-detection + opening the file).
//     final rawFileName = (json['file_name'] as String? ??
//         json['filename'] as String? ??
//         json['original_name'] as String? ??
//         (isAttachment ? (json['note'] as String? ?? '') : ''));
//     final fileName = _cleanFileName(rawFileName);
//
//     final mimeType = (json['mime_type'] as String? ??
//         json['mimetype'] as String? ??
//         '');
//
//     // fileId: the TM_TASK_CHAT_FILES.FILE_ID needed for task-file/get/:id.
//     // Backend may expose this under a few different keys depending on the
//     // endpoint version — try the likely ones, else fall back to log_id
//     // (older rows / single-table setups where log_id == file_id).
//     final fileId = (json['file_id']?.toString() ??
//         json['fileid']?.toString() ??
//         json['fileId']?.toString() ??
//         json['attachment_id']?.toString() ??
//         json['attachmentid']?.toString() ??
//         json['task_file_id']?.toString() ??
//         json['taskfileid']?.toString() ??
//         json['file_no']?.toString() ??
//         json['doc_id']?.toString() ??
//         json['docid']?.toString() ??
//         json['log_id']?.toString() ??
//         '');
//
//     // TEMP DEBUG: while wiring up the file-id, print the raw row for every
//     // attachment so we can see in `flutter logs` / logcat exactly which key
//     // the backend actually uses for the file id. Remove once confirmed.
//     if (isAttachment) {
//       debugPrint('📎 RAW attachment row → $json');
//       debugPrint('📎 Resolved fileId=$fileId  fileName=$fileName  mime=$mimeType');
//     }
//
//     return _ChatMsg(
//       id: json['log_id']?.toString() ?? '',
//       senderName: name,
//       text: json['note'] as String? ?? '',
//       time: time,
//       isMe: isMe,
//       isAdmin: isAdmin,
//       isAudio: isAudio,
//       isAttachment: isAttachment,
//       fileName: fileName,
//       mimeType: mimeType,
//       fileId: fileId,
//     );
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════
// //  SCREEN
// // ═══════════════════════════════════════════════════════════════
//
// class TaskChatScreen extends StatefulWidget {
//   final TaskModel task;
//   const TaskChatScreen({super.key, required this.task});
//
//   @override
//   State<TaskChatScreen> createState() => _TaskChatScreenState();
// }
//
// class _TaskChatScreenState extends State<TaskChatScreen>
//     with TickerProviderStateMixin {
//   // ── Controllers ──────────────────────────────────────────────
//   final _msgCtrl   = TextEditingController();
//   final _scrollCtrl = ScrollController();
//   final _focusNode  = FocusNode();
//
//   // ── State ────────────────────────────────────────────────────
//   final List<_ChatMsg> _msgs = [];
//   bool _isLoading = true;
//   bool _hasError  = false;
//   String _errorMsg = '';
//
//   // ── Session ──────────────────────────────────────────────────
//   String _currentEmpId  = '';
//   String _companyCode   = '';
//   String _currentName   = '';
//   String _username      = '';   // login username for file API
//
//   // ── Animations ───────────────────────────────────────────────
//   late final AnimationController _headerAnim;
//   late final AnimationController _inputAnim;
//   late final Animation<double>   _headerFade;
//   late final Animation<Offset>   _inputSlide;
//
//   static const _baseUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/chatdetail/get/';
//
//   static const _postUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/chatposting/post/';
//
//   static const _fileUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/task-files/send';
//
//   bool _isSending = false;
//   bool _showEmojiPicker = false;
//   bool _isSendingAttachment = false;
//
//   // ── Voice recording ───────────────────────────────────────────
//   final _recorder   = AudioRecorder();
//   bool     _isRecording = false;
//   bool     _isSendingVoice = false;
//   Duration _recDur  = Duration.zero;
//   Timer?   _recTimer;
//   String?  _recPath;
//
//   Timer? _autoRefreshTimer;
//
//   // ── Lifecycle ────────────────────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//
//     _headerAnim = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 500));
//     _headerFade =
//         CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
//
//     _inputAnim = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 400));
//     _inputSlide = Tween<Offset>(
//         begin: const Offset(0, 1), end: Offset.zero)
//         .animate(CurvedAnimation(parent: _inputAnim, curve: Curves.easeOut));
//
//     _headerAnim.forward();
//     _inputAnim.forward();
//
//     _initAndFetch();
//
//     // Rebuild send↔mic button when text changes
//     _msgCtrl.addListener(() { if (mounted) setState(() {}); });
//
//     // Auto-refresh chat every 5 seconds (silent, no loading spinner)
//     _autoRefreshTimer = Timer.periodic(
//       const Duration(seconds: 5),
//           (_) => _fetchMessages(silent: true),
//     );
//   }
//
//   @override
//   void dispose() {
//     _autoRefreshTimer?.cancel();
//     _recTimer?.cancel();
//     _recorder.dispose();
//     _msgCtrl.dispose();
//     _scrollCtrl.dispose();
//     _focusNode.dispose();
//     _headerAnim.dispose();
//     _inputAnim.dispose();
//     super.dispose();
//   }
//
//   // ── Init + Fetch ─────────────────────────────────────────────
//   Future<void> _initAndFetch() async {
//     await _loadSession();
//     await _fetchMessages();
//   }
//
//   Future<void> _loadSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _currentEmpId = (prefs.get('empId') ?? prefs.get('employeeId') ?? prefs.get('emp_id') ?? '')
//           .toString();
//       _companyCode = prefs.getString('companyCode') ??
//           prefs.getString('company_code') ??
//           '';
//       _currentName = prefs.getString('userName') ?? 'Me';
//       _username    = prefs.getString('emp_name') ??
//           prefs.getString('username') ??
//           prefs.getString('userName') ??
//           '';
//     });
//   }
//
//   Future<void> _fetchMessages({bool silent = false}) async {
//     if (!silent) {
//       setState(() {
//         _isLoading = true;
//         _hasError  = false;
//       });
//     }
//
//     try {
//       final uri = Uri.parse(_baseUrl).replace(queryParameters: {
//         'task_id'     : widget.task.id.toString(),
//         'company_code': _companyCode,
//       });
//
//       debugPrint('📨 Chat API ▶ $uri');
//
//       final response =
//       await http.get(uri).timeout(const Duration(seconds: 15));
//
//       debugPrint('📨 Chat API ◀ ${response.statusCode}');
//       debugPrint('📨 Body: ${response.body}');
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body) as Map<String, dynamic>;
//         // ORDS wraps rows in "items"
//         final items = (data['items'] as List?) ?? [];
//
//         final parsed = items
//             .map((e) => _ChatMsg.fromJson(
//             Map<String, dynamic>.from(e as Map), _currentEmpId))
//             .where((m) => m.text.isNotEmpty || m.isAudio || m.isAttachment)
//             .toList()
//           ..sort((a, b) => a.time.compareTo(b.time));
//
//         final hadFewerMsgs = parsed.length > _msgs.length;
//
//         setState(() {
//           _msgs
//             ..clear()
//             ..addAll(parsed);
//           _isLoading = false;
//         });
//
//         if (!silent || hadFewerMsgs) {
//           WidgetsBinding.instance
//               .addPostFrameCallback((_) => _scrollToBottom(animate: silent));
//         }
//       } else {
//         if (!silent) {
//           setState(() {
//             _isLoading = false;
//             _hasError  = true;
//             _errorMsg  = 'Server error: ${response.statusCode}';
//           });
//         }
//       }
//     } catch (e) {
//       if (!silent) {
//         setState(() {
//           _isLoading = false;
//           _hasError  = true;
//           _errorMsg  = 'Connection failed';
//         });
//       }
//       debugPrint('📨 Chat fetch error: $e');
//     }
//   }
//
//   // ── Send ─────────────────────────────────────────────────────
//   Future<void> _sendMessage() async {
//     final text = _msgCtrl.text.trim();
//     if (text.isEmpty || _isSending) return;
//
//     setState(() => _isSending = true);
//
//     try {
//       final uri = Uri.parse(_postUrl);
//
//       debugPrint('📨 Chat POST ▶ $uri');
//
//       final response = await http.post(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'task_id'     : widget.task.id.toString(),
//           'note'        : text,
//           'emp_id'      : _currentEmpId,
//           'company_code': _companyCode,
//         }),
//       ).timeout(const Duration(seconds: 15));
//
//       debugPrint('📨 Chat POST ◀ ${response.statusCode}');
//       debugPrint('📨 Body: ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         _msgCtrl.clear();
//         FocusScope.of(context).unfocus();
//         await _fetchMessages(silent: true);
//         WidgetsBinding.instance
//             .addPostFrameCallback((_) => _scrollToBottom(animate: true));
//       } else {
//         Get.showSnackbar(GetSnackBar(
//           message: 'Failed to send: ${response.statusCode}',
//           duration: const Duration(seconds: 2),
//           backgroundColor: AppColors.error,
//           borderRadius: 10,
//           margin: const EdgeInsets.all(12),
//           icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
//         ));
//       }
//     } catch (e) {
//       debugPrint('📨 Chat send error: $e');
//       Get.showSnackbar(const GetSnackBar(
//         message: 'Connection failed',
//         duration: Duration(seconds: 2),
//         backgroundColor: AppColors.error,
//         borderRadius: 10,
//         margin: EdgeInsets.all(12),
//         icon: Icon(Icons.error_outline_rounded, color: Colors.white),
//       ));
//     } finally {
//       if (mounted) setState(() => _isSending = false);
//     }
//   }
//
//   // ── Send Attachment ──────────────────────────────────────────
//   Future<void> _sendAttachment() async {
//     if (_isSendingAttachment) return;
//
//     FilePickerResult? result;
//     try {
//       result = await FilePicker.platform.pickFiles(withData: true);
//     } catch (e) {
//       debugPrint('📎 File picker error: $e');
//       return;
//     }
//
//     if (result == null || result.files.isEmpty) return;
//
//     final file = result.files.first;
//     if (file.bytes == null) return;
//
//     setState(() => _isSendingAttachment = true);
//
//     try {
//       final base64Data = base64Encode(file.bytes!);
//       final mimeType   = _getMimeType(file.extension ?? '');
//
//       final uri = Uri.parse(_fileUrl);
//
//       debugPrint('📎 File POST ▶ $uri');
//
//       final response = await http.post(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'taskId'     : widget.task.id,
//           'username'   : _username,
//           'companyCode': _companyCode,
//           'fileName'   : file.name,
//           'mimeType'   : mimeType,
//           'fileBase64' : base64Data,
//         }),
//       ).timeout(const Duration(seconds: 60));
//
//       debugPrint('📎 File POST ◀ ${response.statusCode}');
//       debugPrint('📎 Body: ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final data = jsonDecode(response.body) as Map<String, dynamic>;
//         if (data['success'] == 'Y') {
//           await _fetchMessages(silent: true);
//           WidgetsBinding.instance
//               .addPostFrameCallback((_) => _scrollToBottom(animate: true));
//         } else {
//           Get.showSnackbar(GetSnackBar(
//             message: data['error'] as String? ?? 'Failed to send file',
//             duration: const Duration(seconds: 2),
//             backgroundColor: AppColors.error,
//             borderRadius: 10,
//             margin: const EdgeInsets.all(12),
//             icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
//           ));
//         }
//       } else {
//         Get.showSnackbar(GetSnackBar(
//           message: 'Failed to send: ${response.statusCode}',
//           duration: const Duration(seconds: 2),
//           backgroundColor: AppColors.error,
//           borderRadius: 10,
//           margin: const EdgeInsets.all(12),
//           icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
//         ));
//       }
//     } catch (e) {
//       debugPrint('📎 Attachment send error: $e');
//       Get.showSnackbar(const GetSnackBar(
//         message: 'Connection failed',
//         duration: Duration(seconds: 2),
//         backgroundColor: AppColors.error,
//         borderRadius: 10,
//         margin: EdgeInsets.all(12),
//         icon: Icon(Icons.error_outline_rounded, color: Colors.white),
//       ));
//     } finally {
//       if (mounted) setState(() => _isSendingAttachment = false);
//     }
//   }
//
//   String _getMimeType(String extension) {
//     switch (extension.toLowerCase()) {
//       case 'jpg':
//       case 'jpeg': return 'image/jpeg';
//       case 'png':  return 'image/png';
//       case 'gif':  return 'image/gif';
//       case 'webp': return 'image/webp';
//       case 'pdf':  return 'application/pdf';
//       case 'doc':  return 'application/msword';
//       case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
//       case 'xls':  return 'application/vnd.ms-excel';
//       case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
//       case 'ppt':  return 'application/vnd.ms-powerpoint';
//       case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
//       case 'txt':  return 'text/plain';
//       case 'csv':  return 'text/csv';
//       case 'mp4':  return 'video/mp4';
//       case 'mp3':  return 'audio/mpeg';
//       case 'zip':  return 'application/zip';
//       default:     return 'application/octet-stream';
//     }
//   }
//
//   // ── Voice Recording ──────────────────────────────────────────
//   String _fmtRecDur(Duration d) {
//     final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
//     final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }
//
//   Future<void> _startRecording() async {
//     try {
//       final hasPermission = await _recorder.hasPermission();
//       if (!hasPermission) {
//         Get.showSnackbar(const GetSnackBar(
//           message: 'Microphone permission required',
//           duration: Duration(seconds: 2),
//           backgroundColor: AppColors.error,
//           borderRadius: 10,
//           margin: EdgeInsets.all(12),
//           icon: Icon(Icons.mic_off_rounded, color: Colors.white),
//         ));
//         return;
//       }
//
//       final dir  = await getTemporaryDirectory();
//       final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
//
//       await _recorder.start(
//         const RecordConfig(
//           encoder: AudioEncoder.aacLc,
//           sampleRate: 44100,
//           bitRate: 128000,
//         ),
//         path: path,
//       );
//
//       setState(() {
//         _isRecording = true;
//         _recDur  = Duration.zero;
//         _recPath = path;
//       });
//
//       // tick timer every second
//       _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
//         if (mounted) setState(() => _recDur += const Duration(seconds: 1));
//       });
//     } catch (e) {
//       debugPrint('🎤 Start recording error: $e');
//     }
//   }
//
//   void _cancelRecording() async {
//     _recTimer?.cancel();
//     await _recorder.stop();
//     // delete temp file
//     if (_recPath != null) {
//       try { await File(_recPath!).delete(); } catch (_) {}
//     }
//     if (mounted) {
//       setState(() {
//         _isRecording = false;
//         _recDur  = Duration.zero;
//         _recPath = null;
//       });
//     }
//   }
//
//   Future<void> _stopAndSendVoice() async {
//     _recTimer?.cancel();
//     final durationSec = _recDur.inSeconds;
//     final path = await _recorder.stop();
//
//     if (mounted) setState(() { _isRecording = false; _isSendingVoice = true; });
//
//     if (path == null || durationSec < 1) {
//       if (_recPath != null) {
//         try { await File(_recPath!).delete(); } catch (_) {}
//       }
//       if (mounted) setState(() { _isSendingVoice = false; _recPath = null; });
//       return;
//     }
//
//     try {
//       final bytes      = await File(path).readAsBytes();
//       final base64Data = base64Encode(bytes);
//
//       debugPrint('🎤 Voice POST ▶ $_kVoiceSendUrl  dur=${durationSec}s  size=${bytes.length}b');
//
//       final response = await http.post(
//         Uri.parse(_kVoiceSendUrl),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'taskId'     : widget.task.id,
//           'username'   : _username,
//           'companyCode': _companyCode,
//           'mimeType'   : 'audio/aac',
//           'durationSec': durationSec,
//           'audioBase64': base64Data,
//         }),
//       ).timeout(const Duration(seconds: 60));
//
//       debugPrint('🎤 Voice POST ◀ ${response.statusCode}: ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final data = jsonDecode(response.body) as Map<String, dynamic>;
//         if (data['success'] == 'Y') {
//           await _fetchMessages(silent: true);
//           WidgetsBinding.instance
//               .addPostFrameCallback((_) => _scrollToBottom(animate: true));
//         } else {
//           Get.showSnackbar(GetSnackBar(
//             message: data['error'] as String? ?? 'Failed to send voice',
//             duration: const Duration(seconds: 2),
//             backgroundColor: AppColors.error,
//             borderRadius: 10,
//             margin: const EdgeInsets.all(12),
//             icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
//           ));
//         }
//       } else {
//         Get.showSnackbar(GetSnackBar(
//           message: 'Server error: ${response.statusCode}',
//           duration: const Duration(seconds: 2),
//           backgroundColor: AppColors.error,
//           borderRadius: 10,
//           margin: const EdgeInsets.all(12),
//           icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
//         ));
//       }
//     } catch (e) {
//       debugPrint('🎤 Voice send error: $e');
//       Get.showSnackbar(const GetSnackBar(
//         message: 'Connection failed',
//         duration: Duration(seconds: 2),
//         backgroundColor: AppColors.error,
//         borderRadius: 10,
//         margin: EdgeInsets.all(12),
//         icon: Icon(Icons.error_outline_rounded, color: Colors.white),
//       ));
//     } finally {
//       try { await File(path).delete(); } catch (_) {}
//       if (mounted) setState(() { _isSendingVoice = false; _recPath = null; });
//     }
//   }
//
//   // ── Emoji picker ─────────────────────────────────────────────
//   void _toggleEmojiPicker() {
//     if (_showEmojiPicker) {
//       setState(() => _showEmojiPicker = false);
//     } else {
//       FocusScope.of(context).unfocus();
//       setState(() => _showEmojiPicker = true);
//     }
//   }
//
//   void _onEmojiSelected(Emoji emoji) {
//     final text = _msgCtrl.text;
//     final selection = _msgCtrl.selection;
//     final cursor = selection.start >= 0 ? selection.start : text.length;
//     final newText = text.replaceRange(cursor, cursor, emoji.emoji);
//     _msgCtrl.value = TextEditingValue(
//       text: newText,
//       selection: TextSelection.collapsed(offset: cursor + emoji.emoji.length),
//     );
//   }
//
//   // ── Scroll ────────────────────────────────────────────────────
//   void _scrollToBottom({bool animate = true}) {
//     if (!_scrollCtrl.hasClients) return;
//     if (animate) {
//       _scrollCtrl.animateTo(
//         _scrollCtrl.position.maxScrollExtent,
//         duration: const Duration(milliseconds: 350),
//         curve: Curves.easeOut,
//       );
//     } else {
//       _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
//     }
//   }
//
//   // ── Helpers ───────────────────────────────────────────────────
//   bool _isSameDay(DateTime a, DateTime b) =>
//       a.year == b.year && a.month == b.month && a.day == b.day;
//
//   String _monthName(int m) => const [
//     'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
//     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
//   ][m - 1];
//
//   String _initials(String name) {
//     if (name.isEmpty) return '?';
//     final parts = name.trim().split(' ');
//     if (parts.length >= 2) {
//       return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
//     }
//     return name[0].toUpperCase();
//   }
//
//   // ─────────────────────────────────────────────────────────────
//   //  BUILD
//   // ─────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       resizeToAvoidBottomInset: true,
//       body: Column(
//         children: [
//           // ── Header ───────────────────────────────────────────
//           FadeTransition(
//             opacity: _headerFade,
//             child: _buildHeader(),
//           ),
//
//           // ── Body ─────────────────────────────────────────────
//           Expanded(
//             child: GestureDetector(
//               onTap: () => FocusScope.of(context).unfocus(),
//               child: _buildBody(),
//             ),
//           ),
//
//           // ── Input bar ─────────────────────────────────────────
//           SlideTransition(
//             position: _inputSlide,
//             child: _buildInputBar(),
//           ),
//
//           // ── Emoji picker panel ───────────────────────────────
//           AnimatedContainer(
//             duration: const Duration(milliseconds: 220),
//             curve: Curves.easeOut,
//             height: _showEmojiPicker
//                 ? MediaQuery.of(context).size.height * 0.32
//                 : 0,
//             child: _showEmojiPicker
//                 ? EmojiPicker(
//               onEmojiSelected: (category, emoji) =>
//                   _onEmojiSelected(emoji),
//               config: Config(
//                 checkPlatformCompatibility: false,
//                 emojiViewConfig: EmojiViewConfig(
//                   backgroundColor: AppColors.cardBg,
//                   columns: 8,
//                 ),
//                 bottomActionBarConfig: BottomActionBarConfig(
//                   backgroundColor: AppColors.cardBg,
//                   buttonColor: AppColors.primary,
//                 ),
//                 categoryViewConfig: CategoryViewConfig(
//                   backgroundColor: AppColors.cardBg,
//                   indicatorColor: AppColors.primary,
//                   iconColorSelected: AppColors.primary,
//                 ),
//                 searchViewConfig: SearchViewConfig(
//                   backgroundColor: AppColors.cardBg,
//                 ),
//               ),
//             )
//                 : const SizedBox.shrink(),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────
//   //  HEADER
//   // ─────────────────────────────────────────────────────────────
//   Widget _buildHeader() {
//     final status = widget.task.status;
//     Color statusColor;
//     IconData statusIcon;
//     String statusLabel;
//
//     if (status == 'Done' || status == 'Completed') {
//       statusColor = AppColors.greenTeal;
//       statusIcon  = Icons.check_circle_rounded;
//       statusLabel = 'Completed';
//     } else if (status == 'In Progress') {
//       statusColor = AppColors.skyBlueDk;
//       statusIcon  = Icons.autorenew_rounded;
//       statusLabel = 'In Progress';
//     } else if (status == 'Cancel' || status == 'Cancelled') {
//       statusColor = AppColors.error;
//       statusIcon  = Icons.cancel_rounded;
//       statusLabel = 'Cancelled';
//     } else {
//       statusColor = AppColors.warning;
//       statusIcon  = Icons.hourglass_empty_rounded;
//       statusLabel = 'Open';
//     }
//
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [AppColors.primary, AppColors.cyan],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//       ),
//       child: SafeArea(
//         bottom: false,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(6, 6, 16, 14),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // ── Row 1: back + info + badge ─────────────────
//               Row(
//                 children: [
//                   IconButton(
//                     onPressed: () {
//                       HapticFeedback.lightImpact();
//                       Get.back();
//                     },
//                     icon: const Icon(
//                       Icons.arrow_back_ios_new_rounded,
//                       color: Colors.white,
//                       size: 20,
//                     ),
//                   ),
//
//                   // Avatar area
//                   Container(
//                     width: 44,
//                     height: 44,
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.22),
//                       borderRadius: BorderRadius.circular(14),
//                       border: Border.all(
//                           color: Colors.white.withOpacity(0.3), width: 1.5),
//                     ),
//                     child: Center(
//                       child: Icon(
//                         Icons.task_alt_rounded,
//                         color: Colors.white,
//                         size: 20,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//
//                   // Title + message count
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Task Discussion',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w700,
//                             fontSize: 15,
//                             letterSpacing: -0.3,
//                           ),
//                         ),
//                         const SizedBox(height: 3),
//                         AnimatedSwitcher(
//                           duration: const Duration(milliseconds: 300),
//                           child: _isLoading
//                               ? Row(
//                             children: [
//                               SizedBox(
//                                 width: 10,
//                                 height: 10,
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 1.5,
//                                   color: Colors.white.withOpacity(0.7),
//                                 ),
//                               ),
//                               const SizedBox(width: 6),
//                               Text(
//                                 'Loading...',
//                                 style: TextStyle(
//                                     color: Colors.white.withOpacity(0.75),
//                                     fontSize: 11),
//                               ),
//                             ],
//                           )
//                               : Text(
//                             key: ValueKey(_msgs.length),
//                             '${_msgs.length} message${_msgs.length != 1 ? 's' : ''}',
//                             style: TextStyle(
//                                 color: Colors.white.withOpacity(0.78),
//                                 fontSize: 11),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // Refresh button
//                   GestureDetector(
//                     onTap: _fetchMessages,
//                     child: Container(
//                       width: 36,
//                       height: 36,
//                       margin: const EdgeInsets.only(right: 8),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.15),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: const Icon(
//                           Icons.refresh_rounded, color: Colors.white, size: 18),
//                     ),
//                   ),
//
//                   // Status badge
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 10, vertical: 5),
//                     decoration: BoxDecoration(
//                       color: statusColor.withOpacity(0.22),
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(
//                           color: Colors.white.withOpacity(0.25), width: 1),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(statusIcon, color: Colors.white, size: 11),
//                         const SizedBox(width: 4),
//                         Text(
//                           statusLabel,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 10,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//
//               const SizedBox(height: 10),
//
//               // ── Row 2: Task info strip ──────────────────────
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 14, vertical: 10),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.13),
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(
//                       color: Colors.white.withOpacity(0.18)),
//                 ),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.task_alt_rounded,
//                         color: Colors.white, size: 15),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         widget.task.taskTitle,
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.95),
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 8, vertical: 3),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.18),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Text(
//                         '#${widget.task.id}',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────
//   //  BODY (loading / error / messages)
//   // ─────────────────────────────────────────────────────────────
//   Widget _buildBody() {
//     if (_isLoading) return _buildLoadingState();
//     if (_hasError)  return _buildErrorState();
//     if (_msgs.isEmpty) return _buildEmptyState();
//     return _buildMessageList();
//   }
//
//   // ── Loading ──────────────────────────────────────────────────
//   Widget _buildLoadingState() {
//     return Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 56,
//             height: 56,
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                   colors: [AppColors.primary, AppColors.cyan]),
//               borderRadius: BorderRadius.circular(18),
//             ),
//             child: const Padding(
//               padding: EdgeInsets.all(14),
//               child: CircularProgressIndicator(
//                 strokeWidth: 2.5,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'Loading messages...',
//             style: TextStyle(
//                 color: AppColors.textSecondary, fontSize: 13),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Error ────────────────────────────────────────────────────
//   Widget _buildErrorState() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 72,
//               height: 72,
//               decoration: BoxDecoration(
//                 color: AppColors.error.withOpacity(0.1),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(Icons.wifi_off_rounded,
//                   color: AppColors.error, size: 34),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               _errorMsg,
//               style: TextStyle(
//                   color: AppColors.textSecondary, fontSize: 13),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 24),
//             GestureDetector(
//               onTap: _fetchMessages,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 28, vertical: 13),
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [AppColors.primary, AppColors.cyan],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.circular(14),
//                   boxShadow: [
//                     BoxShadow(
//                       color: AppColors.cyan.withOpacity(0.3),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: const Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.refresh_rounded,
//                         color: Colors.white, size: 16),
//                     SizedBox(width: 8),
//                     Text(
//                       'Retry',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w700,
//                         fontSize: 13,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Empty ────────────────────────────────────────────────────
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 72,
//             height: 72,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   AppColors.primary.withOpacity(0.15),
//                   AppColors.cyan.withOpacity(0.15),
//                 ],
//               ),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(Icons.chat_bubble_outline_rounded,
//                 color: AppColors.cyan, size: 32),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'No messages yet',
//             style: TextStyle(
//               color: AppColors.textSecondary,
//               fontSize: 13,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Text(
//             'Is task ke baray mein pehla note likhein',
//             style: TextStyle(
//               color: AppColors.textSecondary.withOpacity(0.6),
//               fontSize: 11,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Messages ─────────────────────────────────────────────────
//   Widget _buildMessageList() {
//     return RefreshIndicator(
//       color: AppColors.cyan,
//       backgroundColor: AppColors.cardBg,
//       onRefresh: _fetchMessages,
//       child: ListView.builder(
//         controller: _scrollCtrl,
//         padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//         itemCount: _msgs.length,
//         itemBuilder: (_, i) {
//           final msg = _msgs[i];
//           final showDateSep =
//               i == 0 || !_isSameDay(_msgs[i - 1].time, msg.time);
//           final isLastInGroup = i == _msgs.length - 1 ||
//               _msgs[i + 1].isMe != msg.isMe ||
//               !_isSameDay(msg.time, _msgs[i + 1].time);
//
//           return Column(
//             children: [
//               if (showDateSep) _buildDateSeparator(msg.time),
//               _AnimatedMsgBubble(
//                 msg: msg,
//                 showAvatar: !msg.isMe && isLastInGroup,
//                 index: i,
//                 initials: _initials(msg.senderName),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildDateSeparator(DateTime time) {
//     final now = DateTime.now();
//     String label;
//     if (_isSameDay(time, now)) {
//       label = 'Today';
//     } else if (_isSameDay(
//         time, now.subtract(const Duration(days: 1)))) {
//       label = 'Yesterday';
//     } else {
//       label = '${time.day} ${_monthName(time.month)} ${time.year}';
//     }
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 14),
//       child: Row(
//         children: [
//           Expanded(
//               child: Container(height: 1, color: AppColors.divider)),
//           Container(
//             margin: const EdgeInsets.symmetric(horizontal: 12),
//             padding:
//             const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
//             decoration: BoxDecoration(
//               color: AppColors.cardBg,
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: AppColors.divider),
//             ),
//             child: Text(
//               label,
//               style: TextStyle(
//                   color: AppColors.textSecondary,
//                   fontSize: 10,
//                   fontWeight: FontWeight.w600),
//             ),
//           ),
//           Expanded(
//               child: Container(height: 1, color: AppColors.divider)),
//         ],
//       ),
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────
//   //  INPUT BAR
//   // ─────────────────────────────────────────────────────────────
//   Widget _buildInputBar() {
//     return Container(
//       padding: EdgeInsets.only(
//         left: 14,
//         right: 14,
//         top: 10,
//         bottom: MediaQuery.of(context).padding.bottom + 10,
//       ),
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.07),
//             blurRadius: 14,
//             offset: const Offset(0, -3),
//           ),
//         ],
//       ),
//       child: AnimatedSwitcher(
//         duration: const Duration(milliseconds: 220),
//         child: _isRecording ? _buildRecordingRow() : _buildNormalRow(),
//       ),
//     );
//   }
//
//   // ── Recording row ─────────────────────────────────────────────
//   Widget _buildRecordingRow() {
//     return Row(
//       key: const ValueKey('recording'),
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         // Cancel button
//         GestureDetector(
//           onTap: _cancelRecording,
//           child: Container(
//             width: 42,
//             height: 42,
//             decoration: BoxDecoration(
//               color: AppColors.error.withOpacity(0.10),
//               borderRadius: BorderRadius.circular(21),
//               border: Border.all(color: AppColors.error.withOpacity(0.25)),
//             ),
//             child: const Icon(
//                 Icons.delete_outline_rounded, color: AppColors.error, size: 20),
//           ),
//         ),
//         const SizedBox(width: 10),
//
//         // Pulsing indicator + waveform + timer
//         Expanded(
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//             decoration: BoxDecoration(
//               color: AppColors.error.withOpacity(0.06),
//               borderRadius: BorderRadius.circular(24),
//               border: Border.all(color: AppColors.error.withOpacity(0.18)),
//             ),
//             child: Row(
//               children: [
//                 const _RecordingDot(),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: _RecordingWaveform(color: AppColors.error.withOpacity(0.45)),
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   _fmtRecDur(_recDur),
//                   style: const TextStyle(
//                     color: AppColors.error,
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                     fontFeatures: [FontFeature.tabularFigures()],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//
//         // Stop & Send button
//         GestureDetector(
//           onTap: _isSendingVoice ? null : _stopAndSendVoice,
//           child: Container(
//             width: 46,
//             height: 46,
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [AppColors.primary, AppColors.cyan],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(15),
//               boxShadow: [
//                 BoxShadow(
//                   color: AppColors.cyan.withOpacity(0.35),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: _isSendingVoice
//                 ? const Padding(
//               padding: EdgeInsets.all(13),
//               child: CircularProgressIndicator(
//                   strokeWidth: 2, color: Colors.white),
//             )
//                 : const Icon(Icons.send_rounded, color: Colors.white, size: 19),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ── Normal row ────────────────────────────────────────────────
//   Widget _buildNormalRow() {
//     final hasText = _msgCtrl.text.trim().isNotEmpty;
//     return Row(
//       key: const ValueKey('normal'),
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: [
//         // Emoji toggle
//         GestureDetector(
//           onTap: _toggleEmojiPicker,
//           child: Container(
//             width: 40,
//             height: 40,
//             margin: const EdgeInsets.only(bottom: 3),
//             decoration: BoxDecoration(
//               color: _showEmojiPicker
//                   ? AppColors.primary.withOpacity(0.12)
//                   : AppColors.surface,
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: AppColors.divider),
//             ),
//             child: Icon(
//               _showEmojiPicker
//                   ? Icons.keyboard_rounded
//                   : Icons.emoji_emotions_outlined,
//               color: _showEmojiPicker
//                   ? AppColors.primary
//                   : AppColors.textSecondary,
//               size: 21,
//             ),
//           ),
//         ),
//         const SizedBox(width: 6),
//
//         // Attachment button
//         GestureDetector(
//           onTap: _isSendingAttachment ? null : _sendAttachment,
//           child: Container(
//             width: 40,
//             height: 40,
//             margin: const EdgeInsets.only(bottom: 3),
//             decoration: BoxDecoration(
//               color: _isSendingAttachment
//                   ? AppColors.primary.withOpacity(0.12)
//                   : AppColors.surface,
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: AppColors.divider),
//             ),
//             child: _isSendingAttachment
//                 ? const Padding(
//               padding: EdgeInsets.all(11),
//               child: CircularProgressIndicator(
//                   strokeWidth: 2, color: AppColors.primary),
//             )
//                 : const Icon(Icons.attach_file_rounded,
//                 color: AppColors.textSecondary, size: 21),
//           ),
//         ),
//         const SizedBox(width: 6),
//
//         // Text field
//         Expanded(
//           child: Container(
//             decoration: BoxDecoration(
//               color: AppColors.surface,
//               borderRadius: BorderRadius.circular(24),
//               border: Border.all(color: AppColors.divider),
//             ),
//             child: TextField(
//               controller: _msgCtrl,
//               focusNode: _focusNode,
//               onTap: () {
//                 if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
//               },
//               style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
//               maxLines: 4,
//               minLines: 1,
//               textCapitalization: TextCapitalization.sentences,
//               decoration: InputDecoration(
//                 hintText: 'Add a comment...',
//                 hintStyle: TextStyle(
//                   color: AppColors.textSecondary.withOpacity(0.5),
//                   fontSize: 14,
//                 ),
//                 border: InputBorder.none,
//                 contentPadding:
//                 const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//
//         // Send / Mic button (switches based on text content)
//         GestureDetector(
//           onTap: _isSending
//               ? null
//               : (hasText ? _sendMessage : _startRecording),
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 200),
//             width: 46,
//             height: 46,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: hasText
//                     ? [AppColors.primary, AppColors.cyan]
//                     : [AppColors.error.withOpacity(0.85), AppColors.error],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(15),
//               boxShadow: [
//                 BoxShadow(
//                   color: (hasText ? AppColors.cyan : AppColors.error)
//                       .withOpacity(0.32),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: _isSending
//                 ? const Padding(
//               padding: EdgeInsets.all(13),
//               child: CircularProgressIndicator(
//                   strokeWidth: 2, color: Colors.white),
//             )
//                 : AnimatedSwitcher(
//               duration: const Duration(milliseconds: 180),
//               transitionBuilder: (child, anim) =>
//                   ScaleTransition(scale: anim, child: child),
//               child: Icon(
//                 hasText ? Icons.send_rounded : Icons.mic_rounded,
//                 key: ValueKey(hasText),
//                 color: Colors.white,
//                 size: 19,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════
// //  RECORDING DOT  (pulsing red circle)
// // ═══════════════════════════════════════════════════════════════
//
// class _RecordingDot extends StatefulWidget {
//   const _RecordingDot();
//
//   @override
//   State<_RecordingDot> createState() => _RecordingDotState();
// }
//
// class _RecordingDotState extends State<_RecordingDot>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _ctrl;
//
//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);
//   }
//
//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FadeTransition(
//       opacity: _ctrl,
//       child: Container(
//         width: 9,
//         height: 9,
//         decoration: const BoxDecoration(
//           color: AppColors.error,
//           shape: BoxShape.circle,
//         ),
//       ),
//     );
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════
// //  RECORDING WAVEFORM  (animated bars)
// // ═══════════════════════════════════════════════════════════════
//
// class _RecordingWaveform extends StatefulWidget {
//   final Color color;
//   const _RecordingWaveform({required this.color});
//
//   @override
//   State<_RecordingWaveform> createState() => _RecordingWaveformState();
// }
//
// class _RecordingWaveformState extends State<_RecordingWaveform>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _ctrl;
//
//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 900),
//     )..repeat(reverse: true);
//   }
//
//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     const baseHeights = [4.0, 10, 6, 14, 8, 12, 5, 16, 9, 13, 7, 11, 5, 14, 8];
//     return AnimatedBuilder(
//       animation: _ctrl,
//       builder: (_, __) {
//         return Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: List.generate(baseHeights.length, (i) {
//             final phase = (i / baseHeights.length);
//             final factor = 0.4 +
//                 0.6 *
//                     (0.5 +
//                         0.5 *
//                             (phase < _ctrl.value
//                                 ? _ctrl.value - phase
//                                 : 1 - (_ctrl.value - phase).abs()));
//             return Container(
//               width: 3,
//               height: (baseHeights[i] * factor).clamp(3.0, 18.0),
//               decoration: BoxDecoration(
//                 color: widget.color,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             );
//           }),
//         );
//       },
//     );
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════
// //  ANIMATED MESSAGE BUBBLE WRAPPER
// // ═══════════════════════════════════════════════════════════════
//
// class _AnimatedMsgBubble extends StatefulWidget {
//   final _ChatMsg msg;
//   final bool showAvatar;
//   final int index;
//   final String initials;
//
//   const _AnimatedMsgBubble({
//     required this.msg,
//     required this.showAvatar,
//     required this.index,
//     required this.initials,
//   });
//
//   @override
//   State<_AnimatedMsgBubble> createState() => _AnimatedMsgBubbleState();
// }
//
// class _AnimatedMsgBubbleState extends State<_AnimatedMsgBubble>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _ctrl;
//   late final Animation<double> _fade;
//   late final Animation<Offset> _slide;
//
//   @override
//   void initState() {
//     super.initState();
//     final delayMs = (widget.index * 30).clamp(0, 280);
//
//     _ctrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 320));
//     _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
//     _slide = Tween<Offset>(
//       begin: Offset(widget.msg.isMe ? 0.2 : -0.2, 0.04),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
//
//     Future.delayed(Duration(milliseconds: delayMs),
//             () { if (mounted) _ctrl.forward(); });
//   }
//
//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FadeTransition(
//       opacity: _fade,
//       child: SlideTransition(
//         position: _slide,
//         child: _MsgBubble(
//           msg: widget.msg,
//           showAvatar: widget.showAvatar,
//           initials: widget.initials,
//         ),
//       ),
//     );
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════
// //  MESSAGE BUBBLE
// // ═══════════════════════════════════════════════════════════════
//
// class _MsgBubble extends StatelessWidget {
//   final _ChatMsg msg;
//   final bool showAvatar;
//   final String initials;
//
//   const _MsgBubble({
//     required this.msg,
//     required this.showAvatar,
//     required this.initials,
//   });
//
//   String _formatTime(DateTime t) =>
//       '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
//
//   @override
//   Widget build(BuildContext context) {
//     final timeStr = _formatTime(msg.time);
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 4),
//       child: Row(
//         mainAxisAlignment:
//         msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [
//           // ── Avatar (received side) ────────────────────────
//           if (!msg.isMe) ...[
//             if (showAvatar)
//               _SenderAvatar(initials: initials, isAdmin: msg.isAdmin)
//             else
//               const SizedBox(width: 32),
//             const SizedBox(width: 8),
//           ],
//
//           // ── Bubble ───────────────────────────────────────
//           ConstrainedBox(
//             constraints: BoxConstraints(
//                 maxWidth: MediaQuery.of(context).size.width * 0.70),
//             child: msg.isMe
//                 ? _SentBubble(msg: msg, timeStr: timeStr)
//                 : _ReceivedBubble(
//               msg: msg,
//               timeStr: timeStr,
//               showName: showAvatar,
//             ),
//           ),
//
//           if (msg.isMe) const SizedBox(width: 4),
//         ],
//       ),
//     );
//   }
// }
//
// // ── Sender Avatar ─────────────────────────────────────────────
//
// class _SenderAvatar extends StatelessWidget {
//   final String initials;
//   final bool isAdmin;
//
//   const _SenderAvatar({required this.initials, required this.isAdmin});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 32,
//       height: 32,
//       decoration: BoxDecoration(
//         gradient: isAdmin
//             ? const LinearGradient(
//             colors: [AppColors.warning, Color(0xFFFFA500)])
//             : const LinearGradient(
//             colors: [AppColors.primary, AppColors.cyan]),
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Center(
//         child: Text(
//           initials,
//           style: const TextStyle(
//               color: Colors.white,
//               fontSize: 9,
//               fontWeight: FontWeight.w800),
//         ),
//       ),
//     );
//   }
// }
//
// // ── Sent Bubble ───────────────────────────────────────────────
//
// class _SentBubble extends StatelessWidget {
//   final _ChatMsg msg;
//   final String timeStr;
//
//   const _SentBubble({required this.msg, required this.timeStr});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [AppColors.primary, AppColors.cyan],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(18),
//           topRight: Radius.circular(18),
//           bottomLeft: Radius.circular(18),
//           bottomRight: Radius.circular(4),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: AppColors.primary.withOpacity(0.28),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [
//           Text(
//             msg.senderName,
//             style: TextStyle(
//               color: Colors.white.withOpacity(0.85),
//               fontSize: 11,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           const SizedBox(height: 5),
//           if (msg.isAudio)
//             _VoiceNoteBubble(
//               url: '$_kVoiceNoteBase${msg.id}',
//               isMe: true,
//             )
//           else if (msg.isAttachment)
//             _AttachmentBubble(
//               fileId: msg.fileId,
//               fileName: msg.fileName.isNotEmpty ? msg.fileName : msg.text,
//               mimeType: msg.mimeType,
//               isMe: true,
//             )
//           else
//             Text(
//               msg.text,
//               style: const TextStyle(
//                   color: Colors.white, fontSize: 13.5, height: 1.45),
//             ),
//           const SizedBox(height: 5),
//           Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 timeStr,
//                 style: TextStyle(
//                     color: Colors.white.withOpacity(0.72), fontSize: 10),
//               ),
//               const SizedBox(width: 4),
//               Icon(Icons.done_all_rounded,
//                   color: Colors.white.withOpacity(0.72), size: 13),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ── Received Bubble ───────────────────────────────────────────
//
// class _ReceivedBubble extends StatelessWidget {
//   final _ChatMsg msg;
//   final String timeStr;
//   final bool showName;
//
//   const _ReceivedBubble({
//     required this.msg,
//     required this.timeStr,
//     required this.showName,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final nameColor =
//     msg.isAdmin ? AppColors.warning : AppColors.cyan;
//
//     return Container(
//       padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(4),
//           topRight: Radius.circular(18),
//           bottomLeft: Radius.circular(18),
//           bottomRight: Radius.circular(18),
//         ),
//         border: Border.all(color: AppColors.divider),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (msg.isAdmin)
//                 Container(
//                   margin: const EdgeInsets.only(right: 5),
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 5, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: AppColors.warning.withOpacity(0.15),
//                     borderRadius: BorderRadius.circular(5),
//                   ),
//                   child: const Text(
//                     'ADMIN',
//                     style: TextStyle(
//                       color: AppColors.warning,
//                       fontSize: 8,
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),
//                 ),
//               Text(
//                 msg.senderName,
//                 style: TextStyle(
//                   color: nameColor,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 5),
//           if (msg.isAudio)
//             _VoiceNoteBubble(
//               url: '$_kVoiceNoteBase${msg.id}',
//               isMe: false,
//             )
//           else if (msg.isAttachment)
//             _AttachmentBubble(
//               fileId: msg.fileId,
//               fileName: msg.fileName.isNotEmpty ? msg.fileName : msg.text,
//               mimeType: msg.mimeType,
//               isMe: false,
//             )
//           else
//             Text(
//               msg.text,
//               style: TextStyle(
//                 color: AppColors.textPrimary,
//                 fontSize: 13.5,
//                 height: 1.45,
//               ),
//             ),
//           const SizedBox(height: 5),
//           Text(
//             timeStr,
//             style: TextStyle(
//               color: AppColors.textSecondary.withOpacity(0.55),
//               fontSize: 10,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════
// //  ATTACHMENT BUBBLE
// // ═══════════════════════════════════════════════════════════════
//
// class _AttachmentBubble extends StatefulWidget {
//   final String fileId;
//   final String fileName;
//   final String mimeType;
//   final bool isMe;
//
//   const _AttachmentBubble({
//     required this.fileId,
//     required this.fileName,
//     required this.mimeType,
//     required this.isMe,
//   });
//
//   @override
//   State<_AttachmentBubble> createState() => _AttachmentBubbleState();
// }
//
// class _AttachmentBubbleState extends State<_AttachmentBubble> {
//   bool _isDownloading = false;
//   double? _downloadProgress; // null = indeterminate
//
//   Future<Uint8List>? _imageFuture;
//
//   String get _fileUrl => '$_kFileGetBase${widget.fileId}';
//
//   bool get _isImage {
//     if (widget.mimeType.toLowerCase().startsWith('image/')) return true;
//     final ext = widget.fileName.contains('.')
//         ? widget.fileName.split('.').last.toLowerCase()
//         : '';
//     return const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     if (_isImage) _imageFuture = _fetchImageBytes();
//   }
//
//   // Fetches the raw bytes and validates the response is actually an image
//   // (not the "{"success":"N","error":"File not found"}" JSON the Oracle
//   // procedure returns when :id doesn't match a row — that JSON was silently
//   // being treated as image/file bytes before, which is why nothing opened).
//   Future<Uint8List> _fetchImageBytes() async {
//     if (widget.fileId.isEmpty) {
//       throw Exception('Missing file id');
//     }
//     final response = await http
//         .get(Uri.parse(_fileUrl))
//         .timeout(const Duration(seconds: 60));
//
//     final contentType = response.headers['content-type'] ?? '';
//
//     if (response.statusCode != 200) {
//       throw Exception('Server returned ${response.statusCode}');
//     }
//     if (contentType.contains('json') ||
//         (response.bodyBytes.isNotEmpty &&
//             response.bodyBytes.first == 0x7B /* JSON opening brace */)) {
//       // Server returned an error JSON instead of the image binary
//       try {
//         final err = jsonDecode(utf8.decode(response.bodyBytes));
//         throw Exception(err['error']?.toString() ?? 'File not found on server');
//       } catch (_) {
//         throw Exception('File not found on server');
//       }
//     }
//     return response.bodyBytes;
//   }
//
//   void _retryImage() {
//     setState(() => _imageFuture = _fetchImageBytes());
//   }
//
//   // ── Open full-screen image viewer (pinch-to-zoom, like WhatsApp) ──
//   void _openImageViewer(Uint8List bytes) {
//     Navigator.of(context).push(
//       PageRouteBuilder(
//         opaque: false,
//         barrierColor: Colors.black,
//         pageBuilder: (_, __, ___) => _FullScreenImageViewer(
//           url: _fileUrl,
//           fileName: widget.fileName,
//           initialBytes: bytes,
//         ),
//       ),
//     );
//   }
//
//   // ── Download then open with the device's default app ───────────
//   Future<void> _downloadAndOpen() async {
//     if (widget.fileId.isEmpty || _isDownloading) return;
//
//     setState(() {
//       _isDownloading = true;
//       _downloadProgress = null;
//     });
//
//     try {
//       final uri = Uri.parse(_fileUrl);
//       final req = http.Request('GET', uri);
//       final streamed = await req.send().timeout(const Duration(seconds: 60));
//
//       if (streamed.statusCode != 200) {
//         throw Exception('Server returned ${streamed.statusCode}');
//       }
//
//       final contentType = streamed.headers['content-type'] ?? '';
//       final total = streamed.contentLength ?? 0;
//       final bytes = <int>[];
//       await for (final chunk in streamed.stream) {
//         bytes.addAll(chunk);
//         if (total > 0 && mounted) {
//           setState(() => _downloadProgress = bytes.length / total);
//         }
//       }
//
//       // Same "File not found" JSON check as images — a wrong/expired file
//       // id downloads fine (200 OK) but the bytes are a tiny JSON error, not
//       // a real PDF/DOC, which is exactly why the OS said "can't open file".
//       if (contentType.contains('json') ||
//           (bytes.isNotEmpty && bytes.first == 0x7B)) {
//         String msg = 'File not found on server';
//         try {
//           final err = jsonDecode(utf8.decode(bytes));
//           msg = err['error']?.toString() ?? msg;
//         } catch (_) {}
//         throw Exception(msg);
//       }
//
//       final dir = await getTemporaryDirectory();
//       final safeName = widget.fileName.isNotEmpty
//           ? widget.fileName
//           : 'file_${widget.fileId}';
//       final path = '${dir.path}/$safeName';
//       final file = File(path);
//       await file.writeAsBytes(bytes, flush: true);
//
//       final result = await OpenFile.open(path);
//       if (result.type != ResultType.done && mounted) {
//         Get.showSnackbar(GetSnackBar(
//           message: 'Could not open file: ${result.message}',
//           duration: const Duration(seconds: 2),
//           backgroundColor: AppColors.error,
//           borderRadius: 10,
//           margin: const EdgeInsets.all(12),
//           icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
//         ));
//       }
//     } catch (e) {
//       debugPrint('📎 Attachment open error: $e');
//       if (mounted) {
//         Get.showSnackbar(GetSnackBar(
//           message: e.toString().replaceFirst('Exception: ', ''),
//           duration: const Duration(seconds: 2),
//           backgroundColor: AppColors.error,
//           borderRadius: 10,
//           margin: const EdgeInsets.all(12),
//           icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
//         ));
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isDownloading = false;
//           _downloadProgress = null;
//         });
//       }
//     }
//   }
//
//   IconData _iconForMime(String mime) {
//     if (mime.startsWith('image/'))             return Icons.image_rounded;
//     if (mime.contains('pdf'))                  return Icons.picture_as_pdf_rounded;
//     if (mime.contains('word') ||
//         mime.contains('msword'))               return Icons.description_rounded;
//     if (mime.contains('excel') ||
//         mime.contains('sheet') ||
//         mime.contains('csv'))                  return Icons.table_chart_rounded;
//     if (mime.contains('powerpoint') ||
//         mime.contains('presentation'))         return Icons.slideshow_rounded;
//     if (mime.contains('zip') ||
//         mime.contains('rar'))                  return Icons.folder_zip_rounded;
//     if (mime.contains('audio') ||
//         mime.contains('mp3'))                  return Icons.audio_file_rounded;
//     if (mime.contains('video') ||
//         mime.contains('mp4'))                  return Icons.video_file_rounded;
//     if (mime.contains('text'))                 return Icons.article_rounded;
//     return Icons.insert_drive_file_rounded;
//   }
//
//   String _extLabel(String mime, String name) {
//     if (name.contains('.')) return name.split('.').last.toUpperCase();
//     if (mime.contains('pdf'))                  return 'PDF';
//     if (mime.startsWith('image/jpeg'))         return 'JPG';
//     if (mime.startsWith('image/png'))          return 'PNG';
//     if (mime.startsWith('image/gif'))          return 'GIF';
//     if (mime.contains('word'))                 return 'DOC';
//     if (mime.contains('excel') ||
//         mime.contains('sheet'))                return 'XLS';
//     if (mime.contains('powerpoint') ||
//         mime.contains('presentation'))         return 'PPT';
//     if (mime.contains('csv'))                  return 'CSV';
//     if (mime.contains('zip'))                  return 'ZIP';
//     if (mime.contains('text'))                 return 'TXT';
//     return 'FILE';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isImage) return _buildImagePreview();
//     return _buildDocumentTile();
//   }
//
//   // ── Inline image thumbnail (WhatsApp-style) ─────────────────────
//   Widget _buildImagePreview() {
//     final placeholderColor = widget.isMe
//         ? Colors.white.withOpacity(0.12)
//         : AppColors.primary.withOpacity(0.06);
//
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(14),
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(
//           maxWidth: 220,
//           maxHeight: 220,
//           minWidth: 140,
//           minHeight: 120,
//         ),
//         child: FutureBuilder<Uint8List>(
//           future: _imageFuture,
//           builder: (context, snapshot) {
//             if (snapshot.connectionState != ConnectionState.done) {
//               return Container(
//                 width: 180,
//                 height: 140,
//                 color: placeholderColor,
//                 child: Center(
//                   child: SizedBox(
//                     width: 26,
//                     height: 26,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2.5,
//                       color: widget.isMe ? Colors.white : AppColors.primary,
//                     ),
//                   ),
//                 ),
//               );
//             }
//
//             if (snapshot.hasError || !snapshot.hasData) {
//               final msg = snapshot.error
//                   ?.toString()
//                   .replaceFirst('Exception: ', '') ??
//                   'Failed to load';
//               return GestureDetector(
//                 onTap: _retryImage,
//                 child: Container(
//                   width: 180,
//                   height: 120,
//                   padding: const EdgeInsets.all(10),
//                   color: placeholderColor,
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.broken_image_rounded,
//                           color: widget.isMe
//                               ? Colors.white.withOpacity(0.7)
//                               : AppColors.textSecondary,
//                           size: 26),
//                       const SizedBox(height: 4),
//                       Text(
//                         msg,
//                         textAlign: TextAlign.center,
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           fontSize: 10,
//                           color: widget.isMe
//                               ? Colors.white.withOpacity(0.7)
//                               : AppColors.textSecondary,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         'Tap to retry',
//                         style: TextStyle(
//                           fontSize: 9,
//                           fontWeight: FontWeight.w600,
//                           color: widget.isMe
//                               ? Colors.white.withOpacity(0.9)
//                               : AppColors.primary,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             }
//
//             final bytes = snapshot.data!;
//             return GestureDetector(
//               onTap: () => _openImageViewer(bytes),
//               child: Hero(
//                 tag: 'attachment_$_fileUrl',
//                 child: Image.memory(bytes, fit: BoxFit.cover),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   // ── Document / file tile (tap → download → open) ────────────────
//   Widget _buildDocumentTile() {
//     final icon       = _iconForMime(widget.mimeType);
//     final ext        = _extLabel(widget.mimeType, widget.fileName);
//     final nameToShow = widget.fileName.isNotEmpty ? widget.fileName : 'Attachment';
//
//     final iconBg    = widget.isMe
//         ? Colors.white.withOpacity(0.22)
//         : AppColors.primary.withOpacity(0.12);
//     final iconColor = widget.isMe ? Colors.white : AppColors.primary;
//     final nameColor = widget.isMe ? Colors.white : AppColors.textPrimary;
//     final extColor  = widget.isMe
//         ? Colors.white.withOpacity(0.70)
//         : AppColors.textSecondary;
//
//     return GestureDetector(
//       onTap: _downloadAndOpen,
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // File type icon box (shows progress while downloading)
//           Container(
//             width: 42,
//             height: 42,
//             decoration: BoxDecoration(
//               color: iconBg,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: _isDownloading
//                 ? Padding(
//               padding: const EdgeInsets.all(11),
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 value: _downloadProgress,
//                 color: iconColor,
//               ),
//             )
//                 : Icon(icon, color: iconColor, size: 22),
//           ),
//           const SizedBox(width: 10),
//
//           // File name + extension label
//           ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 130),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   nameToShow,
//                   style: TextStyle(
//                     color: nameColor,
//                     fontSize: 12.5,
//                     fontWeight: FontWeight.w600,
//                   ),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   _isDownloading ? 'Opening…' : ext,
//                   style: TextStyle(color: extColor, fontSize: 10),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════
// //  FULL-SCREEN IMAGE VIEWER (pinch-zoom + save)
// // ═══════════════════════════════════════════════════════════════
//
// class _FullScreenImageViewer extends StatefulWidget {
//   final String url;
//   final String fileName;
//   final Uint8List? initialBytes;
//
//   const _FullScreenImageViewer({
//     required this.url,
//     required this.fileName,
//     this.initialBytes,
//   });
//
//   @override
//   State<_FullScreenImageViewer> createState() =>
//       _FullScreenImageViewerState();
// }
//
// class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
//   bool _isSaving = false;
//
//   Future<void> _saveToDevice() async {
//     if (_isSaving) return;
//     setState(() => _isSaving = true);
//     try {
//       final response = await http
//           .get(Uri.parse(widget.url))
//           .timeout(const Duration(seconds: 60));
//       if (response.statusCode != 200) {
//         throw Exception('Server returned ${response.statusCode}');
//       }
//       final contentType = response.headers['content-type'] ?? '';
//       if (contentType.contains('json') ||
//           (response.bodyBytes.isNotEmpty &&
//               response.bodyBytes.first == 0x7B)) {
//         throw Exception('File not found on server');
//       }
//       final dir = await getTemporaryDirectory();
//       final safeName =
//       widget.fileName.isNotEmpty ? widget.fileName : 'image.jpg';
//       final path = '${dir.path}/$safeName';
//       final file = File(path);
//       await file.writeAsBytes(response.bodyBytes, flush: true);
//       await OpenFile.open(path);
//     } catch (e) {
//       debugPrint('🖼️ Save image error: $e');
//       Get.showSnackbar(const GetSnackBar(
//         message: 'Failed to save image',
//         duration: Duration(seconds: 2),
//         backgroundColor: AppColors.error,
//         borderRadius: 10,
//         margin: EdgeInsets.all(12),
//         icon: Icon(Icons.error_outline_rounded, color: Colors.white),
//       ));
//     } finally {
//       if (mounted) setState(() => _isSaving = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           Positioned.fill(
//             child: InteractiveViewer(
//               minScale: 0.8,
//               maxScale: 5,
//               child: Center(
//                 child: Hero(
//                   tag: 'attachment_${widget.url}',
//                   child: widget.initialBytes != null
//                       ? Image.memory(widget.initialBytes!, fit: BoxFit.contain)
//                       : Image.network(
//                     widget.url,
//                     fit: BoxFit.contain,
//                     loadingBuilder: (context, child, progress) {
//                       if (progress == null) return child;
//                       return const Center(
//                         child: CircularProgressIndicator(
//                             color: Colors.white),
//                       );
//                     },
//                     errorBuilder: (context, error, stack) =>
//                     const Center(
//                       child: Icon(Icons.broken_image_rounded,
//                           color: Colors.white54, size: 48),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.close_rounded,
//                         color: Colors.white, size: 28),
//                     onPressed: () => Navigator.of(context).pop(),
//                   ),
//                   IconButton(
//                     icon: _isSaving
//                         ? const SizedBox(
//                       width: 22,
//                       height: 22,
//                       child: CircularProgressIndicator(
//                           strokeWidth: 2, color: Colors.white),
//                     )
//                         : const Icon(Icons.download_rounded,
//                         color: Colors.white, size: 26),
//                     onPressed: _isSaving ? null : _saveToDevice,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════
// //  VOICE NOTE BUBBLE
// // ═══════════════════════════════════════════════════════════════
//
// class _VoiceNoteBubble extends StatefulWidget {
//   final String url;
//   final bool isMe;
//
//   const _VoiceNoteBubble({required this.url, required this.isMe});
//
//   @override
//   State<_VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
// }
//
// class _VoiceNoteBubbleState extends State<_VoiceNoteBubble> {
//   final _player = AudioPlayer();
//   PlayerState _playerState = PlayerState.stopped;
//   Duration _duration = Duration.zero;
//   Duration _position = Duration.zero;
//   bool _loading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _player.onPlayerStateChanged.listen((s) {
//       if (mounted) setState(() => _playerState = s);
//     });
//     _player.onDurationChanged.listen((d) {
//       if (mounted) setState(() => _duration = d);
//     });
//     _player.onPositionChanged.listen((p) {
//       if (mounted) setState(() => _position = p);
//     });
//   }
//
//   @override
//   void dispose() {
//     _player.dispose();
//     super.dispose();
//   }
//
//   Future<void> _togglePlay() async {
//     try {
//       if (_playerState == PlayerState.playing) {
//         await _player.pause();
//       } else if (_playerState == PlayerState.paused) {
//         await _player.resume();
//       } else {
//         setState(() => _loading = true);
//         await _player.play(UrlSource(widget.url));
//         if (mounted) setState(() => _loading = false);
//       }
//     } catch (e) {
//       if (mounted) setState(() => _loading = false);
//       debugPrint('🎵 Voice play error: $e');
//     }
//   }
//
//   String _fmtDuration(Duration d) {
//     final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
//     final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isPlaying = _playerState == PlayerState.playing;
//     final progress = _duration.inMilliseconds > 0
//         ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
//         : 0.0;
//
//     final displayTime = _duration > Duration.zero
//         ? _fmtDuration(
//         _playerState == PlayerState.stopped ||
//             _playerState == PlayerState.completed
//             ? _duration
//             : _position)
//         : '--:--';
//
//     final iconColor = widget.isMe ? Colors.white : AppColors.primary;
//     final trackBg = widget.isMe
//         ? Colors.white.withOpacity(0.28)
//         : AppColors.divider;
//     final trackFill = widget.isMe ? Colors.white : AppColors.primary;
//     final timeColor = widget.isMe
//         ? Colors.white.withOpacity(0.70)
//         : AppColors.textSecondary.withOpacity(0.65);
//
//     const _barHeights = [
//       6.0, 10, 14, 8, 16, 12, 18, 10, 14, 8,
//       16, 12, 10, 18, 6, 14, 10, 16, 8, 12,
//     ];
//
//     return SizedBox(
//       width: 200,
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           // ── Play / Pause button ──────────────────────────────
//           GestureDetector(
//             onTap: _loading ? null : _togglePlay,
//             child: Container(
//               width: 38,
//               height: 38,
//               decoration: BoxDecoration(
//                 color: widget.isMe
//                     ? Colors.white.withOpacity(0.22)
//                     : AppColors.primary.withOpacity(0.12),
//                 borderRadius: BorderRadius.circular(19),
//               ),
//               child: _loading
//                   ? Padding(
//                 padding: const EdgeInsets.all(10),
//                 child: CircularProgressIndicator(
//                     strokeWidth: 2, color: iconColor),
//               )
//                   : Icon(
//                 isPlaying
//                     ? Icons.pause_rounded
//                     : Icons.play_arrow_rounded,
//                 color: iconColor,
//                 size: 22,
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//
//           // ── Waveform bars + time ─────────────────────────────
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Waveform bars coloured by progress
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: List.generate(_barHeights.length, (i) {
//                     final isActive = (i / _barHeights.length) <= progress;
//                     return Container(
//                       width: 3,
//                       height: _barHeights[i].toDouble(),
//                       decoration: BoxDecoration(
//                         color: isActive ? trackFill : trackBg,
//                         borderRadius: BorderRadius.circular(2),
//                       ),
//                     );
//                   }),
//                 ),
//                 const SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(Icons.mic_rounded, size: 11, color: timeColor),
//                     const SizedBox(width: 3),
//                     Text(
//                       displayTime,
//                       style: TextStyle(color: timeColor, fontSize: 10),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../AppColors.dart';
import '../Models/task_model.dart';

// ── Voice note streaming URL ─────────────────────────────────
const _kVoiceNoteBase =
    'http://oracle.metaxperts.net/ords/gps_workforce/voicenotes/note/';

// ── Voice note upload URL ─────────────────────────────────────
const _kVoiceSendUrl =
    'http://oracle.metaxperts.net/ords/gps_workforce/task-voice/send';

// ── File attachment GET (view / download) URL ──────────────────
// Serves the raw BLOB (with correct mime + Content-Disposition) for
// both images (inline preview) and documents (download-then-open).
const _kFileGetBase =
    'http://oracle.metaxperts.net/ords/gps_workforce/task-file/get/';

// ═══════════════════════════════════════════════════════════════
//  MODEL
// ═══════════════════════════════════════════════════════════════

class _ChatMsg {
  final String id;
  final String senderName;
  final String text;
  final DateTime time;
  final bool isMe;
  final bool isAdmin;
  final bool isAudio;      // voice note
  final bool isAttachment; // file attachment
  final String fileName;   // original file name
  final String mimeType;   // mime type
  final String fileId;     // TM_TASK_CHAT_FILES.FILE_ID (used for task-file/get/:id)

  const _ChatMsg({
    required this.id,
    required this.senderName,
    required this.text,
    required this.time,
    required this.isMe,
    this.isAdmin = false,
    this.isAudio = false,
    this.isAttachment = false,
    this.fileName = '',
    this.mimeType = '',
    this.fileId = '',
  });

  /// Strip Oracle's "[File: report.pdf]" / "[Photo]" style placeholder text
  /// down to a clean filename with a valid extension. Without this the
  /// trailing "]" breaks extension-based image detection and corrupts the
  /// filename used when saving/opening the file.
  static String _cleanFileName(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;

    // "[File: name.ext]" → "name.ext"
    final bracketMatch = RegExp(r'^\[\s*File\s*:\s*(.+?)\s*\]$', caseSensitive: false)
        .firstMatch(s);
    if (bracketMatch != null) {
      s = bracketMatch.group(1)!.trim();
    } else {
      // "File attachment: name.ext" → "name.ext"  (admin panel format)
      final prefixMatch = RegExp(r'^File\s+attachment\s*:\s*(.+)$', caseSensitive: false)
          .firstMatch(s);
      if (prefixMatch != null) {
        s = prefixMatch.group(1)!.trim();
      } else {
        // Generic bracket strip: "[Photo]", "[Image]", trailing/leading "[" "]"
        s = s.replaceAll(RegExp(r'^\[+'), '').replaceAll(RegExp(r'\]+$'), '').trim();
      }
    }
    return s;
  }

  /// Parse from ORDS JSON row
  factory _ChatMsg.fromJson(Map<String, dynamic> json, String currentEmpId) {
    // ORDS returns lowercase column names
    final loggedBy = json['logged_by']?.toString() ?? '';
    final loggedType = json['logged_type'] as String?;
    final isAdmin = loggedType != null &&
        loggedType.toUpperCase() == 'ADMIN';

    // isMe: current employee sent this (not admin, same ID)
    final isMe = !isAdmin && loggedBy == currentEmpId;

    // Parse timestamp  (e.g. "2025-06-30T10:30:00" or "2025-06-30T10:30:00+05:00")
    DateTime time = DateTime.now();
    final rawTime = json['logged_at'] as String? ?? json['log_date'] as String? ?? '';
    if (rawTime.isNotEmpty) {
      try {
        time = DateTime.parse(rawTime);
      } catch (_) {}
    }

    final name = json['employee_name'] as String? ?? (isAdmin ? 'Admin' : 'Unknown');

    // detect voice note – by msg_type / logged_type field OR by note placeholder text
    final msgType = (json['msg_type'] ?? json['note_type'] ??
        json['message_type'] ?? '')
        .toString()
        .toUpperCase()
        .trim();
    final noteText = (json['note'] as String? ?? '').trim().toLowerCase();
    final isAudio = msgType == 'AUDIO' ||
        loggedType?.toUpperCase() == 'AUDIO' ||
        noteText == 'voice message'   ||
        noteText == '[voice message]' ||
        noteText == 'voice note'      ||
        noteText == 'voicenote'       ||
        noteText == 'audio';

    // detect file attachment – Oracle uses logged_type field
    final isAttachment = msgType == 'FILE' ||
        msgType == 'ATTACHMENT' ||
        msgType == 'DOCUMENT' ||
        loggedType?.toUpperCase() == 'FILE' ||
        loggedType?.toUpperCase() == 'ATTACHMENT' ||
        loggedType?.toUpperCase() == 'DOCUMENT';

    // fileName: prefer explicit field, fallback to note (Oracle often puts a
    // placeholder like "[File: report.pdf]" in the note column instead of a
    // clean file_name column). Strip that wrapper so we get a real filename
    // with a valid extension (needed for image-detection + opening the file).
    final rawFileName = (json['file_name'] as String? ??
        json['filename'] as String? ??
        json['original_name'] as String? ??
        (isAttachment ? (json['note'] as String? ?? '') : ''));
    final fileName = _cleanFileName(rawFileName);

    final mimeType = (json['mime_type'] as String? ??
        json['mimetype'] as String? ??
        '');

    // fileId: the TM_TASK_CHAT_FILES.FILE_ID needed for task-file/get/:id.
    // Backend may expose this under a few different keys depending on the
    // endpoint version — try the likely ones, else fall back to log_id
    // (older rows / single-table setups where log_id == file_id).
    final fileId = (json['file_id']?.toString() ??
        json['fileid']?.toString() ??
        json['fileId']?.toString() ??
        json['attachment_id']?.toString() ??
        json['attachmentid']?.toString() ??
        json['task_file_id']?.toString() ??
        json['taskfileid']?.toString() ??
        json['file_no']?.toString() ??
        json['doc_id']?.toString() ??
        json['docid']?.toString() ??
        json['log_id']?.toString() ??
        '');

    // TEMP DEBUG: while wiring up the file-id, print the raw row for every
    // attachment so we can see in `flutter logs` / logcat exactly which key
    // the backend actually uses for the file id. Remove once confirmed.
    if (isAttachment) {
      debugPrint('📎 RAW attachment row → $json');
      debugPrint('📎 Resolved fileId=$fileId  fileName=$fileName  mime=$mimeType');
    }

    return _ChatMsg(
      id: json['log_id']?.toString() ?? '',
      senderName: name,
      text: json['note'] as String? ?? '',
      time: time,
      isMe: isMe,
      isAdmin: isAdmin,
      isAudio: isAudio,
      isAttachment: isAttachment,
      fileName: fileName,
      mimeType: mimeType,
      fileId: fileId,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════

class TaskChatScreen extends StatefulWidget {
  final TaskModel task;
  const TaskChatScreen({super.key, required this.task});

  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  final _msgCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  // ── State ────────────────────────────────────────────────────
  final List<_ChatMsg> _msgs = [];
  bool _isLoading = true;
  bool _hasError  = false;
  String _errorMsg = '';

  // ── Session ──────────────────────────────────────────────────
  String _currentEmpId  = '';
  String _companyCode   = '';
  String _currentName   = '';
  String _username      = '';   // login username for file API

  // ── Animations ───────────────────────────────────────────────
  late final AnimationController _headerAnim;
  late final AnimationController _inputAnim;
  late final Animation<double>   _headerFade;
  late final Animation<Offset>   _inputSlide;

  static const _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/chatdetail/get/';

  static const _postUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/chatposting/post/';

  static const _fileUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/task-files/send';

  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _isSendingAttachment = false;

  // ── Voice recording ───────────────────────────────────────────
  final _recorder   = AudioRecorder();
  bool     _isRecording = false;
  bool     _isSendingVoice = false;
  Duration _recDur  = Duration.zero;
  Timer?   _recTimer;
  String?  _recPath;

  Timer? _autoRefreshTimer;

  // ── Lifecycle ────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _headerFade =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);

    _inputAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _inputSlide = Tween<Offset>(
        begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _inputAnim, curve: Curves.easeOut));

    _headerAnim.forward();
    _inputAnim.forward();

    _initAndFetch();

    // Rebuild send↔mic button when text changes
    _msgCtrl.addListener(() { if (mounted) setState(() {}); });

    // Auto-refresh chat every 5 seconds (silent, no loading spinner)
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _fetchMessages(silent: true),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _recTimer?.cancel();
    _recorder.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _headerAnim.dispose();
    _inputAnim.dispose();
    super.dispose();
  }

  // ── Init + Fetch ─────────────────────────────────────────────
  Future<void> _initAndFetch() async {
    await _loadSession();
    await _fetchMessages();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentEmpId = (prefs.get('empId') ?? prefs.get('employeeId') ?? prefs.get('emp_id') ?? '')
          .toString();
      _companyCode = prefs.getString('companyCode') ??
          prefs.getString('company_code') ??
          '';
      _currentName = prefs.getString('userName') ?? 'Me';
      _username    = prefs.getString('emp_name') ??
          prefs.getString('username') ??
          prefs.getString('userName') ??
          '';
    });
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError  = false;
      });
    }

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'task_id'     : widget.task.id.toString(),
        'company_code': _companyCode,
      });

      debugPrint('📨 Chat API ▶ $uri');

      final response =
      await http.get(uri).timeout(const Duration(seconds: 15));

      debugPrint('📨 Chat API ◀ ${response.statusCode}');
      debugPrint('📨 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // ORDS wraps rows in "items"
        final items = (data['items'] as List?) ?? [];

        final parsed = items
            .map((e) => _ChatMsg.fromJson(
            Map<String, dynamic>.from(e as Map), _currentEmpId))
            .where((m) => m.text.isNotEmpty || m.isAudio || m.isAttachment)
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));

        final hadFewerMsgs = parsed.length > _msgs.length;

        setState(() {
          _msgs
            ..clear()
            ..addAll(parsed);
          _isLoading = false;
        });

        if (!silent || hadFewerMsgs) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom(animate: silent));
        }
      } else {
        if (!silent) {
          setState(() {
            _isLoading = false;
            _hasError  = true;
            _errorMsg  = 'Server error: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (!silent) {
        setState(() {
          _isLoading = false;
          _hasError  = true;
          _errorMsg  = 'Connection failed';
        });
      }
      debugPrint('📨 Chat fetch error: $e');
    }
  }

  // ── Send ─────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final uri = Uri.parse(_postUrl);

      debugPrint('📨 Chat POST ▶ $uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_id'     : widget.task.id.toString(),
          'note'        : text,
          'emp_id'      : _currentEmpId,
          'company_code': _companyCode,
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📨 Chat POST ◀ ${response.statusCode}');
      debugPrint('📨 Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _msgCtrl.clear();
        FocusScope.of(context).unfocus();
        await _fetchMessages(silent: true);
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom(animate: true));
      } else {
        Get.showSnackbar(GetSnackBar(
          message: 'Failed to send: ${response.statusCode}',
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.error,
          borderRadius: 10,
          margin: const EdgeInsets.all(12),
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        ));
      }
    } catch (e) {
      debugPrint('📨 Chat send error: $e');
      Get.showSnackbar(const GetSnackBar(
        message: 'Connection failed',
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.error,
        borderRadius: 10,
        margin: EdgeInsets.all(12),
        icon: Icon(Icons.error_outline_rounded, color: Colors.white),
      ));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Send Attachment ──────────────────────────────────────────
  Future<void> _sendAttachment() async {
    if (_isSendingAttachment) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      debugPrint('📎 File picker error: $e');
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isSendingAttachment = true);

    try {
      final base64Data = base64Encode(file.bytes!);
      final mimeType   = _getMimeType(file.extension ?? '');

      final uri = Uri.parse(_fileUrl);

      debugPrint('📎 File POST ▶ $uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'taskId'     : widget.task.id,
          'username'   : _username,
          'companyCode': _companyCode,
          'fileName'   : file.name,
          'mimeType'   : mimeType,
          'fileBase64' : base64Data,
        }),
      ).timeout(const Duration(seconds: 60));

      debugPrint('📎 File POST ◀ ${response.statusCode}');
      debugPrint('📎 Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == 'Y') {
          await _fetchMessages(silent: true);
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom(animate: true));
        } else {
          Get.showSnackbar(GetSnackBar(
            message: data['error'] as String? ?? 'Failed to send file',
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.error,
            borderRadius: 10,
            margin: const EdgeInsets.all(12),
            icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
          ));
        }
      } else {
        Get.showSnackbar(GetSnackBar(
          message: 'Failed to send: ${response.statusCode}',
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.error,
          borderRadius: 10,
          margin: const EdgeInsets.all(12),
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        ));
      }
    } catch (e) {
      debugPrint('📎 Attachment send error: $e');
      Get.showSnackbar(const GetSnackBar(
        message: 'Connection failed',
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.error,
        borderRadius: 10,
        margin: EdgeInsets.all(12),
        icon: Icon(Icons.error_outline_rounded, color: Colors.white),
      ));
    } finally {
      if (mounted) setState(() => _isSendingAttachment = false);
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      case 'pdf':  return 'application/pdf';
      case 'doc':  return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':  return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':  return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':  return 'text/plain';
      case 'csv':  return 'text/csv';
      case 'mp4':  return 'video/mp4';
      case 'mp3':  return 'audio/mpeg';
      case 'zip':  return 'application/zip';
      default:     return 'application/octet-stream';
    }
  }

  // ── Voice Recording ──────────────────────────────────────────
  String _fmtRecDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        Get.showSnackbar(const GetSnackBar(
          message: 'Microphone permission required',
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.error,
          borderRadius: 10,
          margin: EdgeInsets.all(12),
          icon: Icon(Icons.mic_off_rounded, color: Colors.white),
        ));
        return;
      }

      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recDur  = Duration.zero;
        _recPath = path;
      });

      // tick timer every second
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recDur += const Duration(seconds: 1));
      });
    } catch (e) {
      debugPrint('🎤 Start recording error: $e');
    }
  }

  void _cancelRecording() async {
    _recTimer?.cancel();
    await _recorder.stop();
    // delete temp file
    if (_recPath != null) {
      try { await File(_recPath!).delete(); } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recDur  = Duration.zero;
        _recPath = null;
      });
    }
  }

  Future<void> _stopAndSendVoice() async {
    _recTimer?.cancel();
    final durationSec = _recDur.inSeconds;
    final path = await _recorder.stop();

    if (mounted) setState(() { _isRecording = false; _isSendingVoice = true; });

    if (path == null || durationSec < 1) {
      if (_recPath != null) {
        try { await File(_recPath!).delete(); } catch (_) {}
      }
      if (mounted) setState(() { _isSendingVoice = false; _recPath = null; });
      return;
    }

    try {
      final bytes      = await File(path).readAsBytes();
      final base64Data = base64Encode(bytes);

      debugPrint('🎤 Voice POST ▶ $_kVoiceSendUrl  dur=${durationSec}s  size=${bytes.length}b');

      final response = await http.post(
        Uri.parse(_kVoiceSendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'taskId'     : widget.task.id,
          'username'   : _username,
          'companyCode': _companyCode,
          'mimeType'   : 'audio/aac',
          'durationSec': durationSec,
          'audioBase64': base64Data,
        }),
      ).timeout(const Duration(seconds: 60));

      debugPrint('🎤 Voice POST ◀ ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == 'Y') {
          await _fetchMessages(silent: true);
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom(animate: true));
        } else {
          Get.showSnackbar(GetSnackBar(
            message: data['error'] as String? ?? 'Failed to send voice',
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.error,
            borderRadius: 10,
            margin: const EdgeInsets.all(12),
            icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
          ));
        }
      } else {
        Get.showSnackbar(GetSnackBar(
          message: 'Server error: ${response.statusCode}',
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.error,
          borderRadius: 10,
          margin: const EdgeInsets.all(12),
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        ));
      }
    } catch (e) {
      debugPrint('🎤 Voice send error: $e');
      Get.showSnackbar(const GetSnackBar(
        message: 'Connection failed',
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.error,
        borderRadius: 10,
        margin: EdgeInsets.all(12),
        icon: Icon(Icons.error_outline_rounded, color: Colors.white),
      ));
    } finally {
      try { await File(path).delete(); } catch (_) {}
      if (mounted) setState(() { _isSendingVoice = false; _recPath = null; });
    }
  }

  // ── Emoji picker ─────────────────────────────────────────────
  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _onEmojiSelected(Emoji emoji) {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    final cursor = selection.start >= 0 ? selection.start : text.length;
    final newText = text.replaceRange(cursor, cursor, emoji.emoji);
    _msgCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + emoji.emoji.length),
    );
  }

  // ── Scroll ────────────────────────────────────────────────────
  void _scrollToBottom({bool animate = true}) {
    if (!_scrollCtrl.hasClients) return;
    if (animate) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthName(int m) => const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m - 1];

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────
          FadeTransition(
            opacity: _headerFade,
            child: _buildHeader(),
          ),

          // ── Body ─────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _buildBody(),
            ),
          ),

          // ── Input bar ─────────────────────────────────────────
          SlideTransition(
            position: _inputSlide,
            child: _buildInputBar(),
          ),

          // ── Emoji picker panel ───────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: _showEmojiPicker
                ? MediaQuery.of(context).size.height * 0.32
                : 0,
            child: _showEmojiPicker
                ? EmojiPicker(
              onEmojiSelected: (category, emoji) =>
                  _onEmojiSelected(emoji),
              config: Config(
                checkPlatformCompatibility: false,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: AppColors.cardBg,
                  columns: 8,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: AppColors.cardBg,
                  buttonColor: AppColors.primary,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: AppColors.cardBg,
                  indicatorColor: AppColors.primary,
                  iconColorSelected: AppColors.primary,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: AppColors.cardBg,
                ),
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final status = widget.task.status;
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (status == 'Done' || status == 'Completed') {
      statusColor = AppColors.greenTeal;
      statusIcon  = Icons.check_circle_rounded;
      statusLabel = 'Completed';
    } else if (status == 'In Progress') {
      statusColor = AppColors.skyBlueDk;
      statusIcon  = Icons.autorenew_rounded;
      statusLabel = 'In Progress';
    } else if (status == 'Cancel' || status == 'Cancelled') {
      statusColor = AppColors.error;
      statusIcon  = Icons.cancel_rounded;
      statusLabel = 'Cancelled';
    } else {
      statusColor = AppColors.warning;
      statusIcon  = Icons.hourglass_empty_rounded;
      statusLabel = 'Open';
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Row 1: back + info + badge ─────────────────
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Get.back();
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),

                  // Avatar area
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.task_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title + message count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task Discussion',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isLoading
                              ? Row(
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Loading...',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 11),
                              ),
                            ],
                          )
                              : Text(
                            key: ValueKey(_msgs.length),
                            '${_msgs.length} message${_msgs.length != 1 ? 's' : ''}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.78),
                                fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Refresh button
                  GestureDetector(
                    onTap: _fetchMessages,
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.refresh_rounded, color: Colors.white, size: 18),
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.25), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: Colors.white, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Row 2: Task info strip ──────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.task_alt_rounded,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.task.taskTitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${widget.task.id}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BODY (loading / error / messages)
  // ─────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_hasError)  return _buildErrorState();
    if (_msgs.isEmpty) return _buildEmptyState();
    return _buildMessageList();
  }

  // ── Loading ──────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.cyan]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMsg,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _fetchMessages,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty ────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.cyan.withOpacity(0.15),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.cyan, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Is task ke baray mein pehla note likhein',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── Messages ─────────────────────────────────────────────────
  Widget _buildMessageList() {
    return RefreshIndicator(
      color: AppColors.cyan,
      backgroundColor: AppColors.cardBg,
      onRefresh: _fetchMessages,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: _msgs.length,
        itemBuilder: (_, i) {
          final msg = _msgs[i];
          final showDateSep =
              i == 0 || !_isSameDay(_msgs[i - 1].time, msg.time);
          final isLastInGroup = i == _msgs.length - 1 ||
              _msgs[i + 1].isMe != msg.isMe ||
              !_isSameDay(msg.time, _msgs[i + 1].time);

          return Column(
            children: [
              if (showDateSep) _buildDateSeparator(msg.time),
              _AnimatedMsgBubble(
                msg: msg,
                showAvatar: !msg.isMe && isLastInGroup,
                index: i,
                initials: _initials(msg.senderName),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateSeparator(DateTime time) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(time, now)) {
      label = 'Today';
    } else if (_isSameDay(
        time, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = '${time.day} ${_monthName(time.month)} ${time.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
              child: Container(height: 1, color: AppColors.divider)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              label,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
              child: Container(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  INPUT BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _isRecording ? _buildRecordingRow() : _buildNormalRow(),
      ),
    );
  }

  // ── Recording row ─────────────────────────────────────────────
  Widget _buildRecordingRow() {
    return Row(
      key: const ValueKey('recording'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Cancel button
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.10),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: AppColors.error.withOpacity(0.25)),
            ),
            child: const Icon(
                Icons.delete_outline_rounded, color: AppColors.error, size: 20),
          ),
        ),
        const SizedBox(width: 10),

        // Pulsing indicator + waveform + timer
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.error.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                const _RecordingDot(),
                const SizedBox(width: 8),
                Expanded(
                  child: _RecordingWaveform(color: AppColors.error.withOpacity(0.45)),
                ),
                const SizedBox(width: 8),
                Text(
                  _fmtRecDur(_recDur),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Stop & Send button
        GestureDetector(
          onTap: _isSendingVoice ? null : _stopAndSendVoice,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.cyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isSendingVoice
                ? const Padding(
              padding: EdgeInsets.all(13),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 19),
          ),
        ),
      ],
    );
  }

  // ── Normal row ────────────────────────────────────────────────
  Widget _buildNormalRow() {
    final hasText = _msgCtrl.text.trim().isNotEmpty;
    return Row(
      key: const ValueKey('normal'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Emoji toggle
        GestureDetector(
          onTap: _toggleEmojiPicker,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: _showEmojiPicker
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Icon(
              _showEmojiPicker
                  ? Icons.keyboard_rounded
                  : Icons.emoji_emotions_outlined,
              color: _showEmojiPicker
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 21,
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Attachment button
        GestureDetector(
          onTap: _isSendingAttachment ? null : _sendAttachment,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: _isSendingAttachment
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: _isSendingAttachment
                ? const Padding(
              padding: EdgeInsets.all(11),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
                : const Icon(Icons.attach_file_rounded,
                color: AppColors.textSecondary, size: 21),
          ),
        ),
        const SizedBox(width: 6),

        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.divider),
            ),
            child: TextField(
              controller: _msgCtrl,
              focusNode: _focusNode,
              onTap: () {
                if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
              },
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Send / Mic button (switches based on text content)
        GestureDetector(
          onTap: _isSending
              ? null
              : (hasText ? _sendMessage : _startRecording),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasText
                    ? [AppColors.primary, AppColors.cyan]
                    : [AppColors.error.withOpacity(0.85), AppColors.error],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: (hasText ? AppColors.cyan : AppColors.error)
                      .withOpacity(0.32),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isSending
                ? const Padding(
              padding: EdgeInsets.all(13),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                hasText ? Icons.send_rounded : Icons.mic_rounded,
                key: ValueKey(hasText),
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  RECORDING DOT  (pulsing red circle)
// ═══════════════════════════════════════════════════════════════

class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  RECORDING WAVEFORM  (animated bars)
// ═══════════════════════════════════════════════════════════════

class _RecordingWaveform extends StatefulWidget {
  final Color color;
  const _RecordingWaveform({required this.color});

  @override
  State<_RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<_RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseHeights = [4.0, 10, 6, 14, 8, 12, 5, 16, 9, 13, 7, 11, 5, 14, 8];
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(baseHeights.length, (i) {
            final phase = (i / baseHeights.length);
            final factor = 0.4 +
                0.6 *
                    (0.5 +
                        0.5 *
                            (phase < _ctrl.value
                                ? _ctrl.value - phase
                                : 1 - (_ctrl.value - phase).abs()));
            return Container(
              width: 3,
              height: (baseHeights[i] * factor).clamp(3.0, 18.0),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ANIMATED MESSAGE BUBBLE WRAPPER
// ═══════════════════════════════════════════════════════════════

class _AnimatedMsgBubble extends StatefulWidget {
  final _ChatMsg msg;
  final bool showAvatar;
  final int index;
  final String initials;

  const _AnimatedMsgBubble({
    required this.msg,
    required this.showAvatar,
    required this.index,
    required this.initials,
  });

  @override
  State<_AnimatedMsgBubble> createState() => _AnimatedMsgBubbleState();
}

class _AnimatedMsgBubbleState extends State<_AnimatedMsgBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 30).clamp(0, 280);

    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(widget.msg.isMe ? 0.2 : -0.2, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: delayMs),
            () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _MsgBubble(
          msg: widget.msg,
          showAvatar: widget.showAvatar,
          initials: widget.initials,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  MESSAGE BUBBLE
// ═══════════════════════════════════════════════════════════════

class _MsgBubble extends StatelessWidget {
  final _ChatMsg msg;
  final bool showAvatar;
  final String initials;

  const _MsgBubble({
    required this.msg,
    required this.showAvatar,
    required this.initials,
  });

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(msg.time);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
        msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Avatar (received side) ────────────────────────
          if (!msg.isMe) ...[
            if (showAvatar)
              _SenderAvatar(initials: initials, isAdmin: msg.isAdmin)
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],

          // ── Bubble ───────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.70),
            child: msg.isMe
                ? _SentBubble(msg: msg, timeStr: timeStr)
                : _ReceivedBubble(
              msg: msg,
              timeStr: timeStr,
              showName: showAvatar,
            ),
          ),

          if (msg.isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Sender Avatar ─────────────────────────────────────────────

class _SenderAvatar extends StatelessWidget {
  final String initials;
  final bool isAdmin;

  const _SenderAvatar({required this.initials, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: isAdmin
            ? const LinearGradient(
            colors: [AppColors.warning, Color(0xFFFFA500)])
            : const LinearGradient(
            colors: [AppColors.primary, AppColors.cyan]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Sent Bubble ───────────────────────────────────────────────

class _SentBubble extends StatelessWidget {
  final _ChatMsg msg;
  final String timeStr;

  const _SentBubble({required this.msg, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            msg.senderName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          if (msg.isAudio)
            _VoiceNoteBubble(
              url: '$_kVoiceNoteBase${msg.id}',
              isMe: true,
            )
          else if (msg.isAttachment)
            _AttachmentBubble(
              fileId: msg.fileId,
              fileName: msg.fileName.isNotEmpty ? msg.fileName : msg.text,
              mimeType: msg.mimeType,
              isMe: true,
            )
          else
            Text(
              msg.text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13.5, height: 1.45),
            ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.72), fontSize: 10),
              ),
              const SizedBox(width: 4),
              Icon(Icons.done_all_rounded,
                  color: Colors.white.withOpacity(0.72), size: 13),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Received Bubble ───────────────────────────────────────────

class _ReceivedBubble extends StatelessWidget {
  final _ChatMsg msg;
  final String timeStr;
  final bool showName;

  const _ReceivedBubble({
    required this.msg,
    required this.timeStr,
    required this.showName,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor =
    msg.isAdmin ? AppColors.warning : AppColors.cyan;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.isAdmin)
                Container(
                  margin: const EdgeInsets.only(right: 5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Text(
                msg.senderName,
                style: TextStyle(
                  color: nameColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (msg.isAudio)
            _VoiceNoteBubble(
              url: '$_kVoiceNoteBase${msg.id}',
              isMe: false,
            )
          else if (msg.isAttachment)
            _AttachmentBubble(
              fileId: msg.fileId,
              fileName: msg.fileName.isNotEmpty ? msg.fileName : msg.text,
              mimeType: msg.mimeType,
              isMe: false,
            )
          else
            Text(
              msg.text,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 5),
          Text(
            timeStr,
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.55),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ATTACHMENT BUBBLE
// ═══════════════════════════════════════════════════════════════

class _AttachmentBubble extends StatefulWidget {
  final String fileId;
  final String fileName;
  final String mimeType;
  final bool isMe;

  const _AttachmentBubble({
    required this.fileId,
    required this.fileName,
    required this.mimeType,
    required this.isMe,
  });

  @override
  State<_AttachmentBubble> createState() => _AttachmentBubbleState();
}

class _AttachmentBubbleState extends State<_AttachmentBubble> {
  bool _isDownloading = false;
  double? _downloadProgress; // null = indeterminate

  Future<Uint8List>? _imageFuture;

  String get _fileUrl => '$_kFileGetBase${widget.fileId}';

  bool get _isImage {
    if (widget.mimeType.toLowerCase().startsWith('image/')) return true;
    final ext = widget.fileName.contains('.')
        ? widget.fileName.split('.').last.toLowerCase()
        : '';
    return const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  @override
  void initState() {
    super.initState();
    if (_isImage) _imageFuture = _fetchImageBytes();
  }

  // Fetches the raw bytes and validates the response is actually an image
  // (not the "{"success":"N","error":"File not found"}" JSON the Oracle
  // procedure returns when :id doesn't match a row — that JSON was silently
  // being treated as image/file bytes before, which is why nothing opened).
  Future<Uint8List> _fetchImageBytes() async {
    if (widget.fileId.isEmpty) {
      throw Exception('Missing file id');
    }
    final response = await http
        .get(Uri.parse(_fileUrl))
        .timeout(const Duration(seconds: 60));

    final contentType = response.headers['content-type'] ?? '';

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }
    if (contentType.contains('json') ||
        (response.bodyBytes.isNotEmpty &&
            response.bodyBytes.first == 0x7B /* JSON opening brace */)) {
      // Server returned an error JSON instead of the image binary
      try {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(err['error']?.toString() ?? 'File not found on server');
      } catch (_) {
        throw Exception('File not found on server');
      }
    }
    return response.bodyBytes;
  }

  void _retryImage() {
    final future = _fetchImageBytes();
    setState(() => _imageFuture = future);
  }

  // ── Open full-screen image viewer (pinch-to-zoom, like WhatsApp) ──
  void _openImageViewer(Uint8List bytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullScreenImageViewer(
          url: _fileUrl,
          fileName: widget.fileName,
          initialBytes: bytes,
        ),
      ),
    );
  }

  // ── Download then open with the device's default app ───────────
  Future<void> _downloadAndOpen() async {
    if (widget.fileId.isEmpty || _isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = null;
    });

    try {
      final uri = Uri.parse(_fileUrl);
      final req = http.Request('GET', uri);
      final streamed = await req.send().timeout(const Duration(seconds: 60));

      if (streamed.statusCode != 200) {
        throw Exception('Server returned ${streamed.statusCode}');
      }

      final contentType = streamed.headers['content-type'] ?? '';
      final total = streamed.contentLength ?? 0;
      final bytes = <int>[];
      await for (final chunk in streamed.stream) {
        bytes.addAll(chunk);
        if (total > 0 && mounted) {
          setState(() => _downloadProgress = bytes.length / total);
        }
      }

      // Same "File not found" JSON check as images — a wrong/expired file
      // id downloads fine (200 OK) but the bytes are a tiny JSON error, not
      // a real PDF/DOC, which is exactly why the OS said "can't open file".
      if (contentType.contains('json') ||
          (bytes.isNotEmpty && bytes.first == 0x7B)) {
        String msg = 'File not found on server';
        try {
          final err = jsonDecode(utf8.decode(bytes));
          msg = err['error']?.toString() ?? msg;
        } catch (_) {}
        throw Exception(msg);
      }

      final dir = await getTemporaryDirectory();
      final safeName = widget.fileName.isNotEmpty
          ? widget.fileName
          : 'file_${widget.fileId}';
      final path = '${dir.path}/$safeName';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFile.open(path);
      if (result.type != ResultType.done && mounted) {
        Get.showSnackbar(GetSnackBar(
          message: 'Could not open file: ${result.message}',
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.error,
          borderRadius: 10,
          margin: const EdgeInsets.all(12),
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        ));
      }
    } catch (e) {
      debugPrint('📎 Attachment open error: $e');
      if (mounted) {
        Get.showSnackbar(GetSnackBar(
          message: e.toString().replaceFirst('Exception: ', ''),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.error,
          borderRadius: 10,
          margin: const EdgeInsets.all(12),
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  IconData _iconForMime(String mime) {
    if (mime.startsWith('image/'))             return Icons.image_rounded;
    if (mime.contains('pdf'))                  return Icons.picture_as_pdf_rounded;
    if (mime.contains('word') ||
        mime.contains('msword'))               return Icons.description_rounded;
    if (mime.contains('excel') ||
        mime.contains('sheet') ||
        mime.contains('csv'))                  return Icons.table_chart_rounded;
    if (mime.contains('powerpoint') ||
        mime.contains('presentation'))         return Icons.slideshow_rounded;
    if (mime.contains('zip') ||
        mime.contains('rar'))                  return Icons.folder_zip_rounded;
    if (mime.contains('audio') ||
        mime.contains('mp3'))                  return Icons.audio_file_rounded;
    if (mime.contains('video') ||
        mime.contains('mp4'))                  return Icons.video_file_rounded;
    if (mime.contains('text'))                 return Icons.article_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String _extLabel(String mime, String name) {
    if (name.contains('.')) return name.split('.').last.toUpperCase();
    if (mime.contains('pdf'))                  return 'PDF';
    if (mime.startsWith('image/jpeg'))         return 'JPG';
    if (mime.startsWith('image/png'))          return 'PNG';
    if (mime.startsWith('image/gif'))          return 'GIF';
    if (mime.contains('word'))                 return 'DOC';
    if (mime.contains('excel') ||
        mime.contains('sheet'))                return 'XLS';
    if (mime.contains('powerpoint') ||
        mime.contains('presentation'))         return 'PPT';
    if (mime.contains('csv'))                  return 'CSV';
    if (mime.contains('zip'))                  return 'ZIP';
    if (mime.contains('text'))                 return 'TXT';
    return 'FILE';
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage) return _buildImagePreview();
    return _buildDocumentTile();
  }

  // ── Inline image thumbnail (WhatsApp-style) ─────────────────────
  Widget _buildImagePreview() {
    final placeholderColor = widget.isMe
        ? Colors.white.withOpacity(0.12)
        : AppColors.primary.withOpacity(0.06);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 220,
          maxHeight: 220,
          minWidth: 140,
          minHeight: 120,
        ),
        child: FutureBuilder<Uint8List>(
          future: _imageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Container(
                width: 180,
                height: 140,
                color: placeholderColor,
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: widget.isMe ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              final msg = snapshot.error
                  ?.toString()
                  .replaceFirst('Exception: ', '') ??
                  'Failed to load';
              return GestureDetector(
                onTap: _retryImage,
                child: Container(
                  width: 180,
                  height: 120,
                  padding: const EdgeInsets.all(10),
                  color: placeholderColor,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_rounded,
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.7)
                              : AppColors.textSecondary,
                          size: 26),
                      const SizedBox(height: 4),
                      Text(
                        msg,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to retry',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.9)
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final bytes = snapshot.data!;
            return GestureDetector(
              onTap: () => _openImageViewer(bytes),
              child: Hero(
                tag: 'attachment_$_fileUrl',
                child: Image.memory(bytes, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Document / file tile (tap → download → open) ────────────────
  Widget _buildDocumentTile() {
    final icon       = _iconForMime(widget.mimeType);
    final ext        = _extLabel(widget.mimeType, widget.fileName);
    final nameToShow = widget.fileName.isNotEmpty ? widget.fileName : 'Attachment';

    final iconBg    = widget.isMe
        ? Colors.white.withOpacity(0.22)
        : AppColors.primary.withOpacity(0.12);
    final iconColor = widget.isMe ? Colors.white : AppColors.primary;
    final nameColor = widget.isMe ? Colors.white : AppColors.textPrimary;
    final extColor  = widget.isMe
        ? Colors.white.withOpacity(0.70)
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: _downloadAndOpen,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File type icon box (shows progress while downloading)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isDownloading
                ? Padding(
              padding: const EdgeInsets.all(11),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: _downloadProgress,
                color: iconColor,
              ),
            )
                : Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),

          // File name + extension label
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nameToShow,
                  style: TextStyle(
                    color: nameColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _isDownloading ? 'Opening…' : ext,
                  style: TextStyle(color: extColor, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FULL-SCREEN IMAGE VIEWER (pinch-zoom + save)
// ═══════════════════════════════════════════════════════════════

class _FullScreenImageViewer extends StatefulWidget {
  final String url;
  final String fileName;
  final Uint8List? initialBytes;

  const _FullScreenImageViewer({
    required this.url,
    required this.fileName,
    this.initialBytes,
  });

  @override
  State<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  bool _isSaving = false;

  Future<void> _saveToDevice() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final response = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('json') ||
          (response.bodyBytes.isNotEmpty &&
              response.bodyBytes.first == 0x7B)) {
        throw Exception('File not found on server');
      }
      final dir = await getTemporaryDirectory();
      final safeName =
      widget.fileName.isNotEmpty ? widget.fileName : 'image.jpg';
      final path = '${dir.path}/$safeName';
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      await OpenFile.open(path);
    } catch (e) {
      debugPrint('🖼️ Save image error: $e');
      Get.showSnackbar(const GetSnackBar(
        message: 'Failed to save image',
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.error,
        borderRadius: 10,
        margin: EdgeInsets.all(12),
        icon: Icon(Icons.error_outline_rounded, color: Colors.white),
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Hero(
                  tag: 'attachment_${widget.url}',
                  child: widget.initialBytes != null
                      ? Image.memory(widget.initialBytes!, fit: BoxFit.contain)
                      : Image.network(
                    widget.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stack) =>
                    const Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: Colors.white54, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    icon: _isSaving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.download_rounded,
                        color: Colors.white, size: 26),
                    onPressed: _isSaving ? null : _saveToDevice,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  VOICE NOTE BUBBLE
// ═══════════════════════════════════════════════════════════════

class _VoiceNoteBubble extends StatefulWidget {
  final String url;
  final bool isMe;

  const _VoiceNoteBubble({required this.url, required this.isMe});

  @override
  State<_VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<_VoiceNoteBubble> {
  final _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else if (_playerState == PlayerState.paused) {
        await _player.resume();
      } else {
        setState(() => _loading = true);
        await _player.play(UrlSource(widget.url));
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('🎵 Voice play error: $e');
    }
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final displayTime = _duration > Duration.zero
        ? _fmtDuration(
        _playerState == PlayerState.stopped ||
            _playerState == PlayerState.completed
            ? _duration
            : _position)
        : '--:--';

    final iconColor = widget.isMe ? Colors.white : AppColors.primary;
    final trackBg = widget.isMe
        ? Colors.white.withOpacity(0.28)
        : AppColors.divider;
    final trackFill = widget.isMe ? Colors.white : AppColors.primary;
    final timeColor = widget.isMe
        ? Colors.white.withOpacity(0.70)
        : AppColors.textSecondary.withOpacity(0.65);

    const _barHeights = [
      6.0, 10, 14, 8, 16, 12, 18, 10, 14, 8,
      16, 12, 10, 18, 6, 14, 10, 16, 8, 12,
    ];

    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Play / Pause button ──────────────────────────────
          GestureDetector(
            onTap: _loading ? null : _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.22)
                    : AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(19),
              ),
              child: _loading
                  ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: iconColor),
              )
                  : Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: iconColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Waveform bars + time ─────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform bars coloured by progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_barHeights.length, (i) {
                    final isActive = (i / _barHeights.length) <= progress;
                    return Container(
                      width: 3,
                      height: _barHeights[i].toDouble(),
                      decoration: BoxDecoration(
                        color: isActive ? trackFill : trackBg,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.mic_rounded, size: 11, color: timeColor),
                    const SizedBox(width: 3),
                    Text(
                      displayTime,
                      style: TextStyle(color: timeColor, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
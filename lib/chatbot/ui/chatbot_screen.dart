// // // // // import 'package:flutter/material.dart';
// // // // // import 'package:dio/dio.dart';
// // // // //
// // // // // import '../core/api_router.dart';
// // // // // import '../core/chat_controller.dart';
// // // // // import '../models/chat_message.dart';
// // // // // import '../services/analytics_api_service.dart';
// // // // // import '../services/attendance_api_service.dart';
// // // // //
// // // // // class ChatbotScreen extends StatefulWidget {
// // // // //   const ChatbotScreen({super.key});
// // // // //
// // // // //   @override
// // // // //   State<ChatbotScreen> createState() => _ChatbotScreenState();
// // // // // }
// // // // //
// // // // // class _ChatbotScreenState extends State<ChatbotScreen> {
// // // // //   final TextEditingController inputController = TextEditingController();
// // // // //   final ScrollController scrollController = ScrollController();
// // // // //
// // // // //   late final ChatController chatController;
// // // // //
// // // // //   @override
// // // // //   void initState() {
// // // // //     super.initState();
// // // // //
// // // // //     final dio = Dio(
// // // // //       BaseOptions(
// // // // //         connectTimeout: const Duration(seconds: 15),
// // // // //         receiveTimeout: const Duration(seconds: 15),
// // // // //       ),
// // // // //     );
// // // // //
// // // // //     final router = ApiRouter(
// // // // //       AnalyticsApiService(dio),
// // // // //       AttendanceApiService(dio),
// // // // //     );
// // // // //
// // // // //     chatController = ChatController(router);
// // // // //     chatController.addListener(_onUpdate);
// // // // //   }
// // // // //
// // // // //   void _onUpdate() {
// // // // //     setState(() {});
// // // // //     _scrollToBottom();
// // // // //   }
// // // // //
// // // // //   Future<void> _send() async {
// // // // //     final text = inputController.text;
// // // // //     inputController.clear();
// // // // //     await chatController.sendMessage(text);
// // // // //   }
// // // // //
// // // // //   void _scrollToBottom() {
// // // // //     Future.delayed(const Duration(milliseconds: 150), () {
// // // // //       if (scrollController.hasClients) {
// // // // //         scrollController.animateTo(
// // // // //           scrollController.position.maxScrollExtent,
// // // // //           duration: const Duration(milliseconds: 250),
// // // // //           curve: Curves.easeOut,
// // // // //         );
// // // // //       }
// // // // //     });
// // // // //   }
// // // // //
// // // // //   @override
// // // // //   void dispose() {
// // // // //     chatController.removeListener(_onUpdate);
// // // // //     inputController.dispose();
// // // // //     scrollController.dispose();
// // // // //     super.dispose();
// // // // //   }
// // // // //
// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     final messages = chatController.messages;
// // // // //     final showTyping = chatController.isTyping;
// // // // //
// // // // //     return Scaffold(
// // // // //       appBar: AppBar(
// // // // //         title: const Text("Attendance Assistant"),
// // // // //         centerTitle: true,
// // // // //       ),
// // // // //       body: Column(
// // // // //         children: [
// // // // //           Expanded(
// // // // //             child: ListView.builder(
// // // // //               controller: scrollController,
// // // // //               padding: const EdgeInsets.all(10),
// // // // //               itemCount: messages.length + (showTyping ? 1 : 0),
// // // // //               itemBuilder: (context, index) {
// // // // //                 if (showTyping && index == messages.length) {
// // // // //                   return _buildBubble(
// // // // //                     ChatMessage(text: "Typing...", isUser: false),
// // // // //                   );
// // // // //                 }
// // // // //                 return _buildBubble(messages[index]);
// // // // //               },
// // // // //             ),
// // // // //           ),
// // // // //           const Divider(height: 1),
// // // // //           Container(
// // // // //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
// // // // //             child: Row(
// // // // //               children: [
// // // // //                 Expanded(
// // // // //                   child: TextField(
// // // // //                     controller: inputController,
// // // // //                     decoration: const InputDecoration(
// // // // //                       hintText: "Apna sawal likhein...",
// // // // //                       border: InputBorder.none,
// // // // //                     ),
// // // // //                     onSubmitted: (_) => _send(),
// // // // //                   ),
// // // // //                 ),
// // // // //                 IconButton(
// // // // //                   icon: const Icon(Icons.send),
// // // // //                   color: Colors.blue,
// // // // //                   onPressed: _send,
// // // // //                 ),
// // // // //               ],
// // // // //             ),
// // // // //           ),
// // // // //         ],
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // //
// // // // //   Widget _buildBubble(ChatMessage msg) {
// // // // //     return Align(
// // // // //       alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
// // // // //       child: Container(
// // // // //         margin: const EdgeInsets.symmetric(vertical: 4),
// // // // //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
// // // // //         constraints: BoxConstraints(
// // // // //           maxWidth: MediaQuery.of(context).size.width * 0.75,
// // // // //         ),
// // // // //         decoration: BoxDecoration(
// // // // //           color: msg.isUser
// // // // //               ? Colors.blue
// // // // //               : (msg.isError ? Colors.red.shade100 : Colors.grey.shade300),
// // // // //           borderRadius: BorderRadius.circular(14),
// // // // //         ),
// // // // //         child: Text(
// // // // //           msg.text,
// // // // //           style: TextStyle(
// // // // //             color: msg.isUser
// // // // //                 ? Colors.white
// // // // //                 : (msg.isError ? Colors.red.shade900 : Colors.black87),
// // // // //           ),
// // // // //         ),
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }
// // // //
// // // // import 'package:flutter/material.dart';
// // // // import 'package:dio/dio.dart';
// // // //
// // // // import '../core/api_router.dart';
// // // // import '../core/chat_controller.dart';
// // // // import '../models/chat_message.dart';
// // // // import '../services/analytics_api_service.dart';
// // // // import '../services/attendance_api_service.dart';
// // // //
// // // // class ChatbotScreen extends StatefulWidget {
// // // //   const ChatbotScreen({super.key});
// // // //
// // // //   @override
// // // //   State<ChatbotScreen> createState() => _ChatbotScreenState();
// // // // }
// // // //
// // // // class _ChatbotScreenState extends State<ChatbotScreen> {
// // // //   final TextEditingController inputController = TextEditingController();
// // // //   final ScrollController scrollController = ScrollController();
// // // //
// // // //   late final ChatController chatController;
// // // //
// // // //   @override
// // // //   void initState() {
// // // //     super.initState();
// // // //
// // // //     final dio = Dio(
// // // //       BaseOptions(
// // // //         connectTimeout: const Duration(seconds: 15),
// // // //         receiveTimeout: const Duration(seconds: 15),
// // // //       ),
// // // //     );
// // // //
// // // //     final router = ApiRouter(
// // // //       AnalyticsApiService(dio),
// // // //       AttendanceApiService(dio),
// // // //     );
// // // //
// // // //     chatController = ChatController(router);
// // // //     chatController.addListener(_onUpdate);
// // // //   }
// // // //
// // // //   void _onUpdate() {
// // // //     setState(() {});
// // // //     _scrollToBottom();
// // // //   }
// // // //
// // // //   Future<void> _send() async {
// // // //     final text = inputController.text;
// // // //     inputController.clear();
// // // //     await chatController.sendMessage(text);
// // // //   }
// // // //
// // // //   void _scrollToBottom() {
// // // //     Future.delayed(const Duration(milliseconds: 150), () {
// // // //       if (scrollController.hasClients) {
// // // //         scrollController.animateTo(
// // // //           scrollController.position.maxScrollExtent,
// // // //           duration: const Duration(milliseconds: 250),
// // // //           curve: Curves.easeOut,
// // // //         );
// // // //       }
// // // //     });
// // // //   }
// // // //
// // // //   @override
// // // //   void dispose() {
// // // //     chatController.removeListener(_onUpdate);
// // // //     inputController.dispose();
// // // //     scrollController.dispose();
// // // //     super.dispose();
// // // //   }
// // // //
// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     final messages = chatController.messages;
// // // //     final showTyping = chatController.isTyping;
// // // //     final isListening = chatController.isListening;
// // // //     final isSpeaking = chatController.isSpeaking;
// // // //
// // // //     return Scaffold(
// // // //       appBar: AppBar(
// // // //         title: const Text("Attendance Assistant"),
// // // //         centerTitle: true,
// // // //         actions: [
// // // //           // Speaking indicator
// // // //           if (isSpeaking)
// // // //             IconButton(
// // // //               icon: const Icon(Icons.volume_up, color: Colors.green),
// // // //               onPressed: () => chatController.stopSpeaking(),
// // // //               tooltip: 'Stop speaking',
// // // //             ),
// // // //           // Voice availability indicator
// // // //           if (chatController.isVoiceAvailable)
// // // //             IconButton(
// // // //               icon: Icon(
// // // //                 isListening ? Icons.mic : Icons.mic_none,
// // // //                 color: isListening ? Colors.red : null,
// // // //               ),
// // // //               onPressed: () {
// // // //                 if (isListening) {
// // // //                   chatController.stopVoiceInput();
// // // //                 } else {
// // // //                   chatController.startVoiceInput();
// // // //                 }
// // // //               },
// // // //               tooltip: isListening ? 'Stop listening' : 'Start voice input',
// // // //             ),
// // // //         ],
// // // //       ),
// // // //       body: Column(
// // // //         children: [
// // // //           // Voice listening indicator
// // // //           if (isListening)
// // // //             Container(
// // // //               padding: const EdgeInsets.all(8),
// // // //               color: Colors.red.shade50,
// // // //               child: Row(
// // // //                 mainAxisAlignment: MainAxisAlignment.center,
// // // //                 children: [
// // // //                   const Icon(Icons.mic, color: Colors.red),
// // // //                   const SizedBox(width: 8),
// // // //                   Expanded(
// // // //                     child: Text(
// // // //                       chatController.voiceTranscript.isEmpty
// // // //                           ? '🎤 Sun raha hoon... (bolna shuru karein)'
// // // //                           : '🎤 "${chatController.voiceTranscript}"',
// // // //                       style: const TextStyle(fontSize: 14),
// // // //                       overflow: TextOverflow.ellipsis,
// // // //                     ),
// // // //                   ),
// // // //                   IconButton(
// // // //                     icon: const Icon(Icons.close, size: 20),
// // // //                     onPressed: () => chatController.stopVoiceInput(),
// // // //                   ),
// // // //                 ],
// // // //               ),
// // // //             ),
// // // //           Expanded(
// // // //             child: ListView.builder(
// // // //               controller: scrollController,
// // // //               padding: const EdgeInsets.all(10),
// // // //               itemCount: messages.length + (showTyping ? 1 : 0),
// // // //               itemBuilder: (context, index) {
// // // //                 if (showTyping && index == messages.length) {
// // // //                   return _buildBubble(
// // // //                     ChatMessage(text: "Typing...", isUser: false),
// // // //                   );
// // // //                 }
// // // //                 return _buildBubble(messages[index]);
// // // //               },
// // // //             ),
// // // //           ),
// // // //           const Divider(height: 1),
// // // //           Container(
// // // //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
// // // //             child: Row(
// // // //               children: [
// // // //                 // Voice input button
// // // //                 if (chatController.isVoiceAvailable)
// // // //                   IconButton(
// // // //                     icon: Icon(
// // // //                       isListening ? Icons.mic : Icons.mic_none,
// // // //                       color: isListening ? Colors.red : Colors.grey,
// // // //                     ),
// // // //                     onPressed: () {
// // // //                       if (isListening) {
// // // //                         chatController.stopVoiceInput();
// // // //                       } else {
// // // //                         chatController.startVoiceInput();
// // // //                       }
// // // //                     },
// // // //                     tooltip: isListening ? 'Stop listening' : 'Start voice input',
// // // //                   ),
// // // //                 Expanded(
// // // //                   child: TextField(
// // // //                     controller: inputController,
// // // //                     decoration: InputDecoration(
// // // //                       hintText: isListening ? '🎤 Speaking...' : 'Apna sawal likhein...',
// // // //                       border: InputBorder.none,
// // // //                       suffixIcon: isListening
// // // //                           ? const Icon(Icons.circle, color: Colors.red, size: 12)
// // // //                           : null,
// // // //                     ),
// // // //                     onSubmitted: (_) => _send(),
// // // //                     enabled: !isListening,
// // // //                   ),
// // // //                 ),
// // // //                 IconButton(
// // // //                   icon: const Icon(Icons.send),
// // // //                   color: Colors.blue,
// // // //                   onPressed: _send,
// // // //                 ),
// // // //               ],
// // // //             ),
// // // //           ),
// // // //         ],
// // // //       ),
// // // //     );
// // // //   }
// // // //
// // // //   Widget _buildBubble(ChatMessage msg) {
// // // //     return Align(
// // // //       alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
// // // //       child: Container(
// // // //         margin: const EdgeInsets.symmetric(vertical: 4),
// // // //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
// // // //         constraints: BoxConstraints(
// // // //           maxWidth: MediaQuery.of(context).size.width * 0.75,
// // // //         ),
// // // //         decoration: BoxDecoration(
// // // //           color: msg.isUser
// // // //               ? Colors.blue
// // // //               : (msg.isError ? Colors.red.shade100 : Colors.grey.shade300),
// // // //           borderRadius: BorderRadius.circular(14),
// // // //         ),
// // // //         child: Row(
// // // //           mainAxisSize: MainAxisSize.min,
// // // //           crossAxisAlignment: CrossAxisAlignment.start,
// // // //           children: [
// // // //             Expanded(
// // // //               child: Text(
// // // //                 msg.text,
// // // //                 style: TextStyle(
// // // //                   color: msg.isUser
// // // //                       ? Colors.white
// // // //                       : (msg.isError ? Colors.red.shade900 : Colors.black87),
// // // //                 ),
// // // //               ),
// // // //             ),
// // // //             // Speaker icon for bot messages
// // // //             if (!msg.isUser && !msg.isError)
// // // //               IconButton(
// // // //                 icon: const Icon(Icons.volume_up, size: 18),
// // // //                 onPressed: () => chatController.speakResponse(msg.text),
// // // //                 tooltip: 'Listen to response',
// // // //                 padding: EdgeInsets.zero,
// // // //                 constraints: const BoxConstraints(),
// // // //                 color: msg.isUser ? Colors.white70 : Colors.grey.shade700,
// // // //               ),
// // // //           ],
// // // //         ),
// // // //       ),
// // // //     );
// // // //   }
// // // // }
// // //
// // //
// // // import 'package:flutter/material.dart';
// // // import 'package:dio/dio.dart';
// // // import 'package:shared_preferences/shared_preferences.dart';
// // //
// // // import '../../Screens/HomeScreenComponents/app_bottom_navbar.dart';
// // // import '../../Screens/HomeScreenComponents/navbar.dart';
// // // import '../../Screens/HomeScreenComponents/sidebar_drawer.dart';
// // // import '../core/api_router.dart';
// // // import '../core/chat_controller.dart';
// // // import '../models/chat_message.dart';
// // // import '../services/analytics_api_service.dart';
// // // import '../services/attendance_api_service.dart';
// // //
// // //
// // // class ChatbotScreen extends StatefulWidget {
// // //   final int currentIndex;
// // //   final int chatBadgeCount;
// // //   final ValueChanged<int>? onNavTap;
// // //
// // //   const ChatbotScreen({
// // //     super.key,
// // //     this.currentIndex = 2,
// // //     this.chatBadgeCount = 0,
// // //     this.onNavTap,
// // //   });
// // //
// // //   @override
// // //   State<ChatbotScreen> createState() => _ChatbotScreenState();
// // // }
// // //
// // // class _ChatbotScreenState extends State<ChatbotScreen> {
// // //   final TextEditingController inputController = TextEditingController();
// // //   final ScrollController scrollController = ScrollController();
// // //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
// // //
// // //   late final ChatController chatController;
// // //
// // //   String _empName = 'Employee';
// // //   String _userInitials = '?';
// // //
// // //   // Track which message is currently speaking
// // //   int? _speakingMessageIndex;
// // //
// // //   // Color theme matching the navbar
// // //   static const Color _tealLight = Color(0xFF3DAF93);
// // //   static const Color _tealDark = Color(0xFF1A6E59);
// // //   static const Color _tealVeryLight = Color(0xFFE8F5F2);
// // //
// // //   // Quick shortcut chips - updated with better queries
// // //   final List<Map<String, String>> _shortcuts = const [
// // //     {'label': '📊 Summary', 'query': 'meri attendance summary batao'},
// // //     {'label': '✅ Present', 'query': 'kitne din present raha'},
// // //     {'label': '⏰ Late', 'query': 'kitni late hui'},
// // //     {'label': '⏱️ Hours', 'query': 'kitni working hours hain'},
// // //     {'label': '📍 Geo', 'query': 'kya koi violation hai'},
// // //     {'label': '🏖️ Leave', 'query': 'kitni chutti li'},
// // //   ];
// // //
// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _loadUserData();
// // //
// // //     final dio = Dio(
// // //       BaseOptions(
// // //         connectTimeout: const Duration(seconds: 15),
// // //         receiveTimeout: const Duration(seconds: 15),
// // //       ),
// // //     );
// // //
// // //     final router = ApiRouter(
// // //       AnalyticsApiService(dio),
// // //       AttendanceApiService(dio),
// // //     );
// // //
// // //     chatController = ChatController(router);
// // //     chatController.addListener(_onUpdate);
// // //   }
// // //
// // //   Future<void> _loadUserData() async {
// // //     final prefs = await SharedPreferences.getInstance();
// // //     final name = prefs.getString('userName') ?? 'Employee';
// // //     setState(() {
// // //       _empName = name;
// // //       _userInitials = _getInitials(name);
// // //     });
// // //   }
// // //
// // //   String _getInitials(String name) {
// // //     final parts = name.trim().split(' ');
// // //     if (parts.length >= 2) {
// // //       return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
// // //     }
// // //     return name.isNotEmpty ? name[0].toUpperCase() : '?';
// // //   }
// // //
// // //   void _onUpdate() {
// // //     setState(() {});
// // //     _scrollToBottom();
// // //   }
// // //
// // //   Future<void> _send() async {
// // //     final text = inputController.text;
// // //     if (text.trim().isEmpty) return;
// // //     inputController.clear();
// // //     await chatController.sendMessage(text);
// // //   }
// // //
// // //   Future<void> _sendShortcut(String query) async {
// // //     await chatController.sendMessage(query);
// // //   }
// // //
// // //   void _scrollToBottom() {
// // //     Future.delayed(const Duration(milliseconds: 150), () {
// // //       if (scrollController.hasClients) {
// // //         scrollController.animateTo(
// // //           scrollController.position.maxScrollExtent,
// // //           duration: const Duration(milliseconds: 250),
// // //           curve: Curves.easeOut,
// // //         );
// // //       }
// // //     });
// // //   }
// // //
// // //   @override
// // //   void dispose() {
// // //     chatController.removeListener(_onUpdate);
// // //     inputController.dispose();
// // //     scrollController.dispose();
// // //     super.dispose();
// // //   }
// // //
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final messages = chatController.messages;
// // //     final showTyping = chatController.isTyping;
// // //     final isListening = chatController.isListening;
// // //     final isSpeaking = chatController.isSpeaking;
// // //
// // //     return Scaffold(
// // //       key: _scaffoldKey,
// // //       backgroundColor: Colors.grey.shade50,
// // //       appBar: Navbar(
// // //         userName: _empName,
// // //         userInitials: _userInitials,
// // //         scaffoldKey: _scaffoldKey,
// // //       ),
// // //       drawer: AppDrawer(),
// // //       bottomNavigationBar: widget.onNavTap != null
// // //           ? AppBottomNavBar(
// // //         currentIndex: widget.currentIndex,
// // //         chatBadgeCount: widget.chatBadgeCount,
// // //         onTap: widget.onNavTap!,
// // //       )
// // //           : null,
// // //       body: SafeArea(
// // //         child: Column(
// // //           children: [
// // //             // ── Chat Header ──────────────────────────────────────────────────────
// // //             Container(
// // //               padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
// // //               decoration: BoxDecoration(
// // //                 color: Colors.white,
// // //                 boxShadow: [
// // //                   BoxShadow(
// // //                     color: Colors.grey.withOpacity(0.08),
// // //                     blurRadius: 4,
// // //                     offset: const Offset(0, 2),
// // //                   ),
// // //                 ],
// // //               ),
// // //               child: Row(
// // //                 children: [
// // //                   Container(
// // //                     padding: const EdgeInsets.all(8),
// // //                     decoration: BoxDecoration(
// // //                       color: _tealVeryLight,
// // //                       borderRadius: BorderRadius.circular(10),
// // //                     ),
// // //                     child: Icon(
// // //                       Icons.chat_bubble_outline,
// // //                       color: _tealDark,
// // //                       size: 22,
// // //                     ),
// // //                   ),
// // //                   const SizedBox(width: 12),
// // //                   Column(
// // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // //                     children: [
// // //                       const Text(
// // //                         'Chat Assistance',
// // //                         style: TextStyle(
// // //                           fontSize: 18,
// // //                           fontWeight: FontWeight.w700,
// // //                           color: Color(0xFF1A1A2E),
// // //                         ),
// // //                       ),
// // //                       Text(
// // //                         'Ask about your attendance anytime',
// // //                         style: TextStyle(
// // //                           fontSize: 12,
// // //                           color: Colors.grey.shade600,
// // //                         ),
// // //                       ),
// // //                     ],
// // //                   ),
// // //                   const Spacer(),
// // //                   // Voice status indicator
// // //                   if (isListening)
// // //                     Container(
// // //                       padding: const EdgeInsets.symmetric(
// // //                         horizontal: 10,
// // //                         vertical: 4,
// // //                       ),
// // //                       decoration: BoxDecoration(
// // //                         color: Colors.red.shade50,
// // //                         borderRadius: BorderRadius.circular(12),
// // //                         border: Border.all(color: Colors.red.shade200),
// // //                       ),
// // //                       child: Row(
// // //                         mainAxisSize: MainAxisSize.min,
// // //                         children: [
// // //                           const Icon(Icons.circle, color: Colors.red, size: 8),
// // //                           const SizedBox(width: 4),
// // //                           Text(
// // //                             'Recording...',
// // //                             style: TextStyle(
// // //                               fontSize: 11,
// // //                               color: Colors.red.shade700,
// // //                               fontWeight: FontWeight.w500,
// // //                             ),
// // //                           ),
// // //                         ],
// // //                       ),
// // //                     ),
// // //                   if (isSpeaking)
// // //                     Container(
// // //                       padding: const EdgeInsets.symmetric(
// // //                         horizontal: 10,
// // //                         vertical: 4,
// // //                       ),
// // //                       decoration: BoxDecoration(
// // //                         color: Colors.green.shade50,
// // //                         borderRadius: BorderRadius.circular(12),
// // //                         border: Border.all(color: Colors.green.shade200),
// // //                       ),
// // //                       child: Row(
// // //                         mainAxisSize: MainAxisSize.min,
// // //                         children: [
// // //                           Icon(Icons.volume_up, color: Colors.green.shade700, size: 16),
// // //                           const SizedBox(width: 4),
// // //                           Text(
// // //                             'Speaking...',
// // //                             style: TextStyle(
// // //                               fontSize: 11,
// // //                               color: Colors.green.shade700,
// // //                               fontWeight: FontWeight.w500,
// // //                             ),
// // //                           ),
// // //                           const SizedBox(width: 4),
// // //                           GestureDetector(
// // //                             onTap: () => chatController.stopSpeaking(),
// // //                             child: Icon(
// // //                               Icons.close,
// // //                               size: 16,
// // //                               color: Colors.green.shade700,
// // //                             ),
// // //                           ),
// // //                         ],
// // //                       ),
// // //                     ),
// // //                 ],
// // //               ),
// // //             ),
// // //
// // //             // ── Shortcut Chips ──────────────────────────────────────────────────
// // //             Container(
// // //               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
// // //               decoration: BoxDecoration(
// // //                 color: Colors.white,
// // //                 border: Border(
// // //                   bottom: BorderSide(color: Colors.grey.shade200),
// // //                 ),
// // //               ),
// // //               child: SizedBox(
// // //                 height: 40,
// // //                 child: ListView.separated(
// // //                   scrollDirection: Axis.horizontal,
// // //                   itemCount: _shortcuts.length,
// // //                   separatorBuilder: (_, __) => const SizedBox(width: 8),
// // //                   itemBuilder: (context, index) {
// // //                     final shortcut = _shortcuts[index];
// // //                     return ActionChip(
// // //                       label: Text(
// // //                         shortcut['label']!,
// // //                         style: TextStyle(
// // //                           fontSize: 13,
// // //                           fontWeight: FontWeight.w500,
// // //                           color: _tealDark,
// // //                         ),
// // //                       ),
// // //                       onPressed: () => _sendShortcut(shortcut['query']!),
// // //                       backgroundColor: _tealVeryLight,
// // //                       shape: RoundedRectangleBorder(
// // //                         borderRadius: BorderRadius.circular(20),
// // //                         side: BorderSide(color: _tealDark.withOpacity(0.15)),
// // //                       ),
// // //                       padding: const EdgeInsets.symmetric(
// // //                         horizontal: 14,
// // //                         vertical: 6,
// // //                       ),
// // //                       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
// // //                     );
// // //                   },
// // //                 ),
// // //               ),
// // //             ),
// // //
// // //             // ── Voice Listening Indicator ─────────────────────────────────────
// // //             if (isListening)
// // //               Container(
// // //                 padding: const EdgeInsets.all(10),
// // //                 color: Colors.red.shade50,
// // //                 child: Row(
// // //                   children: [
// // //                     const Icon(Icons.mic, color: Colors.red),
// // //                     const SizedBox(width: 10),
// // //                     Expanded(
// // //                       child: Text(
// // //                         chatController.voiceTranscript.isEmpty
// // //                             ? '🎤 Sun raha hoon... (bolna shuru karein)'
// // //                             : '🎤 "${chatController.voiceTranscript}"',
// // //                         style: const TextStyle(fontSize: 14),
// // //                         overflow: TextOverflow.ellipsis,
// // //                       ),
// // //                     ),
// // //                     if (chatController.voiceConfidence > 0.3)
// // //                       Container(
// // //                         padding: const EdgeInsets.symmetric(
// // //                           horizontal: 8,
// // //                           vertical: 2,
// // //                         ),
// // //                         decoration: BoxDecoration(
// // //                           color: Colors.green.shade100,
// // //                           borderRadius: BorderRadius.circular(10),
// // //                         ),
// // //                         child: Text(
// // //                           '${(chatController.voiceConfidence * 100).toInt()}%',
// // //                           style: TextStyle(
// // //                             fontSize: 11,
// // //                             color: Colors.green.shade700,
// // //                             fontWeight: FontWeight.w600,
// // //                           ),
// // //                         ),
// // //                       ),
// // //                     IconButton(
// // //                       icon: const Icon(Icons.close, size: 20),
// // //                       onPressed: () => chatController.stopVoiceInput(),
// // //                     ),
// // //                   ],
// // //                 ),
// // //               ),
// // //
// // //             // ── Messages ─────────────────────────────────────────────────────
// // //             Expanded(
// // //               child: messages.isEmpty
// // //                   ? _buildEmptyState()
// // //                   : ListView.builder(
// // //                 controller: scrollController,
// // //                 padding: const EdgeInsets.all(12),
// // //                 itemCount: messages.length + (showTyping ? 1 : 0),
// // //                 itemBuilder: (context, index) {
// // //                   if (showTyping && index == messages.length) {
// // //                     return _buildTypingIndicator();
// // //                   }
// // //                   return _buildMessageBubble(messages[index], index);
// // //                 },
// // //               ),
// // //             ),
// // //
// // //             // ── Input Bar ─────────────────────────────────────────────────────
// // //             Container(
// // //               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// // //               decoration: BoxDecoration(
// // //                 color: Colors.white,
// // //                 boxShadow: [
// // //                   BoxShadow(
// // //                     color: Colors.grey.withOpacity(0.1),
// // //                     blurRadius: 8,
// // //                     offset: const Offset(0, -2),
// // //                   ),
// // //                 ],
// // //               ),
// // //               child: Row(
// // //                 children: [
// // //                   // Voice input button
// // //                   if (chatController.isVoiceAvailable)
// // //                     Container(
// // //                       decoration: BoxDecoration(
// // //                         color: isListening ? Colors.red.shade50 : _tealVeryLight,
// // //                         shape: BoxShape.circle,
// // //                       ),
// // //                       child: IconButton(
// // //                         icon: Icon(
// // //                           isListening ? Icons.mic : Icons.mic_none,
// // //                           color: isListening ? Colors.red : _tealDark,
// // //                           size: 24,
// // //                         ),
// // //                         onPressed: () {
// // //                           if (isListening) {
// // //                             chatController.stopVoiceInput();
// // //                           } else {
// // //                             chatController.startVoiceInput();
// // //                           }
// // //                         },
// // //                         tooltip: isListening ? 'Stop listening' : 'Start voice input',
// // //                         padding: const EdgeInsets.all(8),
// // //                         constraints: const BoxConstraints(),
// // //                       ),
// // //                     ),
// // //                   const SizedBox(width: 8),
// // //                   // Text field
// // //                   Expanded(
// // //                     child: Container(
// // //                       decoration: BoxDecoration(
// // //                         color: Colors.grey.shade100,
// // //                         borderRadius: BorderRadius.circular(24),
// // //                         border: Border.all(
// // //                           color: isListening ? Colors.red.shade300 : Colors.transparent,
// // //                           width: 1.5,
// // //                         ),
// // //                       ),
// // //                       child: TextField(
// // //                         controller: inputController,
// // //                         decoration: InputDecoration(
// // //                           hintText: isListening
// // //                               ? '🎤 Speaking...'
// // //                               : 'Ask about attendance...',
// // //                           hintStyle: TextStyle(
// // //                             color: Colors.grey.shade500,
// // //                             fontSize: 14,
// // //                           ),
// // //                           border: InputBorder.none,
// // //                           contentPadding: const EdgeInsets.symmetric(
// // //                             horizontal: 16,
// // //                             vertical: 10,
// // //                           ),
// // //                           suffixIcon: isListening
// // //                               ? const Padding(
// // //                             padding: EdgeInsets.all(10),
// // //                             child: Icon(
// // //                               Icons.circle,
// // //                               color: Colors.red,
// // //                               size: 10,
// // //                             ),
// // //                           )
// // //                               : null,
// // //                         ),
// // //                         onSubmitted: (_) => _send(),
// // //                         enabled: !isListening,
// // //                       ),
// // //                     ),
// // //                   ),
// // //                   const SizedBox(width: 8),
// // //                   // Send button
// // //                   Container(
// // //                     decoration: const BoxDecoration(
// // //                       gradient: LinearGradient(
// // //                         colors: [_tealLight, _tealDark],
// // //                         begin: Alignment.topLeft,
// // //                         end: Alignment.bottomRight,
// // //                       ),
// // //                       shape: BoxShape.circle,
// // //                     ),
// // //                     child: IconButton(
// // //                       icon: const Icon(
// // //                         Icons.send_rounded,
// // //                         color: Colors.white,
// // //                         size: 22,
// // //                       ),
// // //                       onPressed: _send,
// // //                       padding: const EdgeInsets.all(10),
// // //                       constraints: const BoxConstraints(),
// // //                     ),
// // //                   ),
// // //                 ],
// // //               ),
// // //             ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // //
// // //   Widget _buildEmptyState() {
// // //     return Center(
// // //       child: Column(
// // //         mainAxisAlignment: MainAxisAlignment.center,
// // //         children: [
// // //           Container(
// // //             padding: const EdgeInsets.all(24),
// // //             decoration: BoxDecoration(
// // //               color: _tealVeryLight,
// // //               shape: BoxShape.circle,
// // //             ),
// // //             child: Icon(
// // //               Icons.chat_bubble_outline,
// // //               color: _tealDark,
// // //               size: 48,
// // //             ),
// // //           ),
// // //           const SizedBox(height: 16),
// // //           Text(
// // //             'Ask me about your attendance',
// // //             style: TextStyle(
// // //               fontSize: 18,
// // //               fontWeight: FontWeight.w600,
// // //               color: Colors.grey.shade800,
// // //             ),
// // //           ),
// // //           const SizedBox(height: 8),
// // //           Text(
// // //             'Try asking: "meri attendance batao" or "kitne din present"',
// // //             style: TextStyle(
// // //               fontSize: 14,
// // //               color: Colors.grey.shade500,
// // //             ),
// // //             textAlign: TextAlign.center,
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // //
// // //   Widget _buildTypingIndicator() {
// // //     return Align(
// // //       alignment: Alignment.centerLeft,
// // //       child: Container(
// // //         margin: const EdgeInsets.symmetric(vertical: 4),
// // //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// // //         decoration: BoxDecoration(
// // //           color: Colors.grey.shade200,
// // //           borderRadius: BorderRadius.circular(16),
// // //         ),
// // //         child: SizedBox(
// // //           width: 50,
// // //           height: 20,
// // //           child: Row(
// // //             mainAxisAlignment: MainAxisAlignment.center,
// // //             children: [
// // //               _buildDot(0),
// // //               const SizedBox(width: 4),
// // //               _buildDot(1),
// // //               const SizedBox(width: 4),
// // //               _buildDot(2),
// // //             ],
// // //           ),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // //
// // //   Widget _buildDot(int index) {
// // //     return AnimatedContainer(
// // //       duration: const Duration(milliseconds: 400),
// // //       curve: Curves.easeInOut,
// // //       width: 8,
// // //       height: 8,
// // //       decoration: BoxDecoration(
// // //         color: _tealDark.withOpacity(0.5 + (index * 0.2)),
// // //         shape: BoxShape.circle,
// // //       ),
// // //     );
// // //   }
// // //
// // //   Widget _buildMessageBubble(ChatMessage msg, int index) {
// // //     final isUser = msg.isUser;
// // //     final isError = msg.isError;
// // //     final isSpeaking = _speakingMessageIndex == index;
// // //
// // //     return Align(
// // //       alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
// // //       child: Container(
// // //         margin: const EdgeInsets.symmetric(vertical: 4),
// // //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
// // //         constraints: BoxConstraints(
// // //           maxWidth: MediaQuery.of(context).size.width * 0.80,
// // //         ),
// // //         decoration: BoxDecoration(
// // //           color: isUser
// // //               ? _tealDark
// // //               : (isError ? Colors.red.shade100 : Colors.grey.shade200),
// // //           borderRadius: BorderRadius.circular(16).copyWith(
// // //             bottomRight: isUser ? const Radius.circular(4) : Radius.zero,
// // //             bottomLeft: isUser ? Radius.zero : const Radius.circular(4),
// // //           ),
// // //         ),
// // //         child: Row(
// // //           mainAxisSize: MainAxisSize.min,
// // //           crossAxisAlignment: CrossAxisAlignment.start,
// // //           children: [
// // //             Expanded(
// // //               child: Text(
// // //                 msg.text,
// // //                 style: TextStyle(
// // //                   fontSize: 14,
// // //                   height: 1.4,
// // //                   color: isUser
// // //                       ? Colors.white
// // //                       : (isError ? Colors.red.shade900 : Colors.black87),
// // //                 ),
// // //               ),
// // //             ),
// // //             // Speaker/Stop button for bot messages
// // //             if (!isUser && !isError)
// // //               Padding(
// // //                 padding: const EdgeInsets.only(left: 8),
// // //                 child: GestureDetector(
// // //                   onTap: () {
// // //                     if (isSpeaking) {
// // //                       // Stop speaking
// // //                       chatController.stopSpeaking();
// // //                       setState(() {
// // //                         _speakingMessageIndex = null;
// // //                       });
// // //                     } else {
// // //                       // Start speaking
// // //                       setState(() {
// // //                         _speakingMessageIndex = index;
// // //                       });
// // //                       chatController.speakResponse(msg.text).then((_) {
// // //                         if (mounted) {
// // //                           setState(() {
// // //                             _speakingMessageIndex = null;
// // //                           });
// // //                         }
// // //                       });
// // //                     }
// // //                   },
// // //                   child: Container(
// // //                     padding: const EdgeInsets.all(4),
// // //                     decoration: BoxDecoration(
// // //                       color: isSpeaking
// // //                           ? Colors.red.shade100
// // //                           : Colors.grey.shade300.withOpacity(0.4),
// // //                       shape: BoxShape.circle,
// // //                     ),
// // //                     child: Icon(
// // //                       isSpeaking ? Icons.stop : Icons.volume_up_rounded,
// // //                       size: 16,
// // //                       color: isSpeaking ? Colors.red.shade700 : Colors.grey.shade700,
// // //                     ),
// // //                   ),
// // //                 ),
// // //               ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }
// //
// // //both language
// // import 'package:flutter/material.dart';
// // import 'package:dio/dio.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// //
// // import '../../Screens/HomeScreenComponents/app_bottom_navbar.dart';
// // import '../../Screens/HomeScreenComponents/navbar.dart';
// // import '../../Screens/HomeScreenComponents/sidebar_drawer.dart';
// // import '../core/api_router.dart';
// // import '../core/chat_controller.dart';
// // import '../models/chat_message.dart';
// // import '../services/analytics_api_service.dart';
// // import '../services/attendance_api_service.dart';
// //
// // class ChatbotScreen extends StatefulWidget {
// //   final int currentIndex;
// //   final int chatBadgeCount;
// //   final ValueChanged<int>? onNavTap;
// //
// //   const ChatbotScreen({
// //     super.key,
// //     this.currentIndex = 2,
// //     this.chatBadgeCount = 0,
// //     this.onNavTap,
// //   });
// //
// //   @override
// //   State<ChatbotScreen> createState() => _ChatbotScreenState();
// // }
// //
// // class _ChatbotScreenState extends State<ChatbotScreen> {
// //   final TextEditingController inputController = TextEditingController();
// //   final ScrollController scrollController = ScrollController();
// //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
// //
// //   late final ChatController chatController;
// //
// //   String _empName = 'Employee';
// //   String _userInitials = '?';
// //
// //   // Color theme matching the navbar
// //   static const Color _tealLight = Color(0xFF3DAF93);
// //   static const Color _tealDark = Color(0xFF1A6E59);
// //   static const Color _tealVeryLight = Color(0xFFE8F5F2);
// //
// //   // Quick shortcut chips
// //   final List<Map<String, String>> _shortcuts = const [
// //     {'label': '📊 Summary', 'query': 'meri attendance summary batao'},
// //     {'label': '✅ Present', 'query': 'kitne din present raha'},
// //     {'label': '⏰ Late', 'query': 'kitni late hui'},
// //     {'label': '⏱️ Hours', 'query': 'kitni working hours hain'},
// //     {'label': '📍 Geo', 'query': 'kya koi violation hai'},
// //     {'label': '🏖️ Leave', 'query': 'kitni chutti li'},
// //   ];
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadUserData();
// //
// //     final dio = Dio(
// //       BaseOptions(
// //         connectTimeout: const Duration(seconds: 15),
// //         receiveTimeout: const Duration(seconds: 15),
// //       ),
// //     );
// //
// //     final router = ApiRouter(
// //       AnalyticsApiService(dio),
// //       AttendanceApiService(dio),
// //     );
// //
// //     chatController = ChatController(router);
// //     chatController.addListener(_onUpdate);
// //   }
// //
// //   Future<void> _loadUserData() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final name = prefs.getString('userName') ?? 'Employee';
// //     setState(() {
// //       _empName = name;
// //       _userInitials = _getInitials(name);
// //     });
// //   }
// //
// //   String _getInitials(String name) {
// //     final parts = name.trim().split(' ');
// //     if (parts.length >= 2) {
// //       return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
// //     }
// //     return name.isNotEmpty ? name[0].toUpperCase() : '?';
// //   }
// //
// //   void _onUpdate() {
// //     setState(() {});
// //     _scrollToBottom();
// //   }
// //
// //   Future<void> _send() async {
// //     final text = inputController.text;
// //     if (text.trim().isEmpty) return;
// //     inputController.clear();
// //     await chatController.sendMessage(text);
// //   }
// //
// //   Future<void> _sendShortcut(String query) async {
// //     await chatController.sendMessage(query);
// //   }
// //
// //   void _scrollToBottom() {
// //     Future.delayed(const Duration(milliseconds: 150), () {
// //       if (scrollController.hasClients) {
// //         scrollController.animateTo(
// //           scrollController.position.maxScrollExtent,
// //           duration: const Duration(milliseconds: 250),
// //           curve: Curves.easeOut,
// //         );
// //       }
// //     });
// //   }
// //
// //   @override
// //   void dispose() {
// //     chatController.removeListener(_onUpdate);
// //     inputController.dispose();
// //     scrollController.dispose();
// //     super.dispose();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final messages = chatController.messages;
// //     final showTyping = chatController.isTyping;
// //     final isListening = chatController.isListening;
// //     final isSpeaking = chatController.isSpeaking;
// //
// //     return Scaffold(
// //       key: _scaffoldKey,
// //       backgroundColor: Colors.grey.shade50,
// //       appBar: Navbar(
// //         userName: _empName,
// //         userInitials: _userInitials,
// //         scaffoldKey: _scaffoldKey,
// //       ),
// //       drawer: AppDrawer(),
// //       bottomNavigationBar: widget.onNavTap != null
// //           ? AppBottomNavBar(
// //         currentIndex: widget.currentIndex,
// //         chatBadgeCount: widget.chatBadgeCount,
// //         onTap: widget.onNavTap!,
// //       )
// //           : null,
// //       body: SafeArea(
// //         child: Column(
// //           children: [
// //             // ── Chat Header ──────────────────────────────────────────────────────
// //             Container(
// //               padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
// //               decoration: BoxDecoration(
// //                 color: Colors.white,
// //                 boxShadow: [
// //                   BoxShadow(
// //                     color: Colors.grey.withOpacity(0.08),
// //                     blurRadius: 4,
// //                     offset: const Offset(0, 2),
// //                   ),
// //                 ],
// //               ),
// //               child: Row(
// //                 children: [
// //                   Container(
// //                     padding: const EdgeInsets.all(8),
// //                     decoration: BoxDecoration(
// //                       color: _tealVeryLight,
// //                       borderRadius: BorderRadius.circular(10),
// //                     ),
// //                     child: Icon(
// //                       Icons.chat_bubble_outline,
// //                       color: _tealDark,
// //                       size: 22,
// //                     ),
// //                   ),
// //                   const SizedBox(width: 12),
// //                   Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       const Text(
// //                         'Chat Assistance',
// //                         style: TextStyle(
// //                           fontSize: 18,
// //                           fontWeight: FontWeight.w700,
// //                           color: Color(0xFF1A1A2E),
// //                         ),
// //                       ),
// //                       Text(
// //                         'Ask about your attendance anytime',
// //                         style: TextStyle(
// //                           fontSize: 12,
// //                           color: Colors.grey.shade600,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                   const Spacer(),
// //                   // Voice status indicator
// //                   if (isListening)
// //                     Container(
// //                       padding: const EdgeInsets.symmetric(
// //                         horizontal: 10,
// //                         vertical: 4,
// //                       ),
// //                       decoration: BoxDecoration(
// //                         color: Colors.red.shade50,
// //                         borderRadius: BorderRadius.circular(12),
// //                         border: Border.all(color: Colors.red.shade200),
// //                       ),
// //                       child: Row(
// //                         mainAxisSize: MainAxisSize.min,
// //                         children: [
// //                           const Icon(Icons.circle, color: Colors.red, size: 8),
// //                           const SizedBox(width: 4),
// //                           Text(
// //                             'Recording...',
// //                             style: TextStyle(
// //                               fontSize: 11,
// //                               color: Colors.red.shade700,
// //                               fontWeight: FontWeight.w500,
// //                             ),
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   if (isSpeaking)
// //                     Container(
// //                       padding: const EdgeInsets.symmetric(
// //                         horizontal: 10,
// //                         vertical: 4,
// //                       ),
// //                       decoration: BoxDecoration(
// //                         color: Colors.green.shade50,
// //                         borderRadius: BorderRadius.circular(12),
// //                         border: Border.all(color: Colors.green.shade200),
// //                       ),
// //                       child: Row(
// //                         mainAxisSize: MainAxisSize.min,
// //                         children: [
// //                           Icon(Icons.volume_up, color: Colors.green.shade700, size: 16),
// //                           const SizedBox(width: 4),
// //                           Text(
// //                             'Speaking...',
// //                             style: TextStyle(
// //                               fontSize: 11,
// //                               color: Colors.green.shade700,
// //                               fontWeight: FontWeight.w500,
// //                             ),
// //                           ),
// //                           const SizedBox(width: 4),
// //                           GestureDetector(
// //                             onTap: () => chatController.stopSpeaking(),
// //                             child: Icon(
// //                               Icons.close,
// //                               size: 16,
// //                               color: Colors.green.shade700,
// //                             ),
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                 ],
// //               ),
// //             ),
// //
// //             // ── Shortcut Chips ──────────────────────────────────────────────────
// //             Container(
// //               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
// //               decoration: BoxDecoration(
// //                 color: Colors.white,
// //                 border: Border(
// //                   bottom: BorderSide(color: Colors.grey.shade200),
// //                 ),
// //               ),
// //               child: SizedBox(
// //                 height: 40,
// //                 child: ListView.separated(
// //                   scrollDirection: Axis.horizontal,
// //                   itemCount: _shortcuts.length,
// //                   separatorBuilder: (_, __) => const SizedBox(width: 8),
// //                   itemBuilder: (context, index) {
// //                     final shortcut = _shortcuts[index];
// //                     return ActionChip(
// //                       label: Text(
// //                         shortcut['label']!,
// //                         style: TextStyle(
// //                           fontSize: 13,
// //                           fontWeight: FontWeight.w500,
// //                           color: _tealDark,
// //                         ),
// //                       ),
// //                       onPressed: () => _sendShortcut(shortcut['query']!),
// //                       backgroundColor: _tealVeryLight,
// //                       shape: RoundedRectangleBorder(
// //                         borderRadius: BorderRadius.circular(20),
// //                         side: BorderSide(color: _tealDark.withOpacity(0.15)),
// //                       ),
// //                       padding: const EdgeInsets.symmetric(
// //                         horizontal: 14,
// //                         vertical: 6,
// //                       ),
// //                       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
// //                     );
// //                   },
// //                 ),
// //               ),
// //             ),
// //
// //             // ── Voice Listening Indicator ─────────────────────────────────────
// //             if (isListening)
// //               Container(
// //                 padding: const EdgeInsets.all(10),
// //                 color: Colors.red.shade50,
// //                 child: Row(
// //                   children: [
// //                     const Icon(Icons.mic, color: Colors.red),
// //                     const SizedBox(width: 10),
// //                     Expanded(
// //                       child: Text(
// //                         chatController.voiceTranscript.isEmpty
// //                             ? '🎤 Sun raha hoon... (bolna shuru karein)'
// //                             : '🎤 "${chatController.voiceTranscript}"',
// //                         style: const TextStyle(fontSize: 14),
// //                         overflow: TextOverflow.ellipsis,
// //                       ),
// //                     ),
// //                     if (chatController.voiceConfidence > 0.3)
// //                       Container(
// //                         padding: const EdgeInsets.symmetric(
// //                           horizontal: 8,
// //                           vertical: 2,
// //                         ),
// //                         decoration: BoxDecoration(
// //                           color: Colors.green.shade100,
// //                           borderRadius: BorderRadius.circular(10),
// //                         ),
// //                         child: Text(
// //                           '${(chatController.voiceConfidence * 100).toInt()}%',
// //                           style: TextStyle(
// //                             fontSize: 11,
// //                             color: Colors.green.shade700,
// //                             fontWeight: FontWeight.w600,
// //                           ),
// //                         ),
// //                       ),
// //                     IconButton(
// //                       icon: const Icon(Icons.close, size: 20),
// //                       onPressed: () => chatController.stopVoiceInput(),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //
// //             // ── Messages ─────────────────────────────────────────────────────
// //             Expanded(
// //               child: messages.isEmpty
// //                   ? _buildEmptyState()
// //                   : ListView.builder(
// //                 controller: scrollController,
// //                 padding: const EdgeInsets.all(12),
// //                 itemCount: messages.length + (showTyping ? 1 : 0),
// //                 itemBuilder: (context, index) {
// //                   if (showTyping && index == messages.length) {
// //                     return _buildTypingIndicator();
// //                   }
// //                   return _buildMessageBubble(messages[index], index);
// //                 },
// //               ),
// //             ),
// //
// //             // ── Input Bar ─────────────────────────────────────────────────────
// //             Container(
// //               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //               decoration: BoxDecoration(
// //                 color: Colors.white,
// //                 boxShadow: [
// //                   BoxShadow(
// //                     color: Colors.grey.withOpacity(0.1),
// //                     blurRadius: 8,
// //                     offset: const Offset(0, -2),
// //                   ),
// //                 ],
// //               ),
// //               child: Row(
// //                 children: [
// //                   // Voice input button
// //                   if (chatController.isVoiceAvailable)
// //                     Container(
// //                       decoration: BoxDecoration(
// //                         color: isListening ? Colors.red.shade50 : _tealVeryLight,
// //                         shape: BoxShape.circle,
// //                       ),
// //                       child: IconButton(
// //                         icon: Icon(
// //                           isListening ? Icons.mic : Icons.mic_none,
// //                           color: isListening ? Colors.red : _tealDark,
// //                           size: 24,
// //                         ),
// //                         onPressed: () {
// //                           if (isListening) {
// //                             chatController.stopVoiceInput();
// //                           } else {
// //                             chatController.startVoiceInput();
// //                           }
// //                         },
// //                         tooltip: isListening ? 'Stop listening' : 'Start voice input',
// //                         padding: const EdgeInsets.all(8),
// //                         constraints: const BoxConstraints(),
// //                       ),
// //                     ),
// //                   const SizedBox(width: 8),
// //                   // Text field
// //                   Expanded(
// //                     child: Container(
// //                       decoration: BoxDecoration(
// //                         color: Colors.grey.shade100,
// //                         borderRadius: BorderRadius.circular(24),
// //                         border: Border.all(
// //                           color: isListening ? Colors.red.shade300 : Colors.transparent,
// //                           width: 1.5,
// //                         ),
// //                       ),
// //                       child: TextField(
// //                         controller: inputController,
// //                         decoration: InputDecoration(
// //                           hintText: isListening
// //                               ? '🎤 Speaking...'
// //                               : 'Ask about attendance...',
// //                           hintStyle: TextStyle(
// //                             color: Colors.grey.shade500,
// //                             fontSize: 14,
// //                           ),
// //                           border: InputBorder.none,
// //                           contentPadding: const EdgeInsets.symmetric(
// //                             horizontal: 16,
// //                             vertical: 10,
// //                           ),
// //                           suffixIcon: isListening
// //                               ? const Padding(
// //                             padding: EdgeInsets.all(10),
// //                             child: Icon(
// //                               Icons.circle,
// //                               color: Colors.red,
// //                               size: 10,
// //                             ),
// //                           )
// //                               : null,
// //                         ),
// //                         onSubmitted: (_) => _send(),
// //                         enabled: !isListening,
// //                       ),
// //                     ),
// //                   ),
// //                   const SizedBox(width: 8),
// //                   // Send button
// //                   Container(
// //                     decoration: const BoxDecoration(
// //                       gradient: LinearGradient(
// //                         colors: [_tealLight, _tealDark],
// //                         begin: Alignment.topLeft,
// //                         end: Alignment.bottomRight,
// //                       ),
// //                       shape: BoxShape.circle,
// //                     ),
// //                     child: IconButton(
// //                       icon: const Icon(
// //                         Icons.send_rounded,
// //                         color: Colors.white,
// //                         size: 22,
// //                       ),
// //                       onPressed: _send,
// //                       padding: const EdgeInsets.all(10),
// //                       constraints: const BoxConstraints(),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildEmptyState() {
// //     return Center(
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           Container(
// //             padding: const EdgeInsets.all(24),
// //             decoration: BoxDecoration(
// //               color: _tealVeryLight,
// //               shape: BoxShape.circle,
// //             ),
// //             child: Icon(
// //               Icons.chat_bubble_outline,
// //               color: _tealDark,
// //               size: 48,
// //             ),
// //           ),
// //           const SizedBox(height: 16),
// //           Text(
// //             'Ask me about your attendance',
// //             style: TextStyle(
// //               fontSize: 18,
// //               fontWeight: FontWeight.w600,
// //               color: Colors.grey.shade800,
// //             ),
// //           ),
// //           const SizedBox(height: 8),
// //           Text(
// //             'Try asking: "meri attendance batao" or "kitne din present"',
// //             style: TextStyle(
// //               fontSize: 14,
// //               color: Colors.grey.shade500,
// //             ),
// //             textAlign: TextAlign.center,
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Widget _buildTypingIndicator() {
// //     return Align(
// //       alignment: Alignment.centerLeft,
// //       child: Container(
// //         margin: const EdgeInsets.symmetric(vertical: 4),
// //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //         decoration: BoxDecoration(
// //           color: Colors.grey.shade200,
// //           borderRadius: BorderRadius.circular(16),
// //         ),
// //         child: SizedBox(
// //           width: 50,
// //           height: 20,
// //           child: Row(
// //             mainAxisAlignment: MainAxisAlignment.center,
// //             children: [
// //               _buildDot(0),
// //               const SizedBox(width: 4),
// //               _buildDot(1),
// //               const SizedBox(width: 4),
// //               _buildDot(2),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildDot(int index) {
// //     return AnimatedContainer(
// //       duration: const Duration(milliseconds: 400),
// //       curve: Curves.easeInOut,
// //       width: 8,
// //       height: 8,
// //       decoration: BoxDecoration(
// //         color: _tealDark.withOpacity(0.5 + (index * 0.2)),
// //         shape: BoxShape.circle,
// //       ),
// //     );
// //   }
// //
// //   // ──────────────────────────────────────────────────────────────────────────
// //   // Language Selector
// //   // ──────────────────────────────────────────────────────────────────────────
// //
// //   Widget _buildLanguageSelector(String query) {
// //     return Align(
// //       alignment: Alignment.center,
// //       child: Container(
// //         margin: const EdgeInsets.symmetric(vertical: 8),
// //         padding: const EdgeInsets.all(16),
// //         decoration: BoxDecoration(
// //           color: Colors.white,
// //           borderRadius: BorderRadius.circular(16),
// //           boxShadow: [
// //             BoxShadow(
// //               color: Colors.grey.withOpacity(0.1),
// //               blurRadius: 8,
// //               offset: const Offset(0, 2),
// //             ),
// //           ],
// //         ),
// //         child: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Text(
// //               'Select Language / زبان منتخب کریں',
// //               style: TextStyle(
// //                 fontSize: 14,
// //                 fontWeight: FontWeight.w600,
// //                 color: Colors.grey.shade700,
// //               ),
// //             ),
// //             const SizedBox(height: 12),
// //             Row(
// //               mainAxisAlignment: MainAxisAlignment.center,
// //               children: [
// //                 _buildLanguageButton('urdu', '🇵🇰 اردو', query),
// //                 const SizedBox(width: 12),
// //                 _buildLanguageButton('english', '🇬🇧 English', query),
// //               ],
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildLanguageButton(String language, String label, String query) {
// //     return ElevatedButton.icon(
// //       onPressed: () => chatController.selectLanguage(language, query),
// //       icon: Text(
// //         language == 'urdu' ? '🇵🇰' : '🇬🇧',
// //         style: const TextStyle(fontSize: 20),
// //       ),
// //       label: Text(label),
// //       style: ElevatedButton.styleFrom(
// //         backgroundColor: language == 'urdu' ? _tealVeryLight : Colors.blue.shade50,
// //         foregroundColor: language == 'urdu' ? _tealDark : Colors.blue.shade800,
// //         shape: RoundedRectangleBorder(
// //           borderRadius: BorderRadius.circular(12),
// //           side: BorderSide(
// //             color: language == 'urdu' ? _tealDark : Colors.blue.shade300,
// //             width: 1.5,
// //           ),
// //         ),
// //         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
// //       ),
// //     );
// //   }
// //
// //   // ──────────────────────────────────────────────────────────────────────────
// //   // Message Bubble
// //   // ──────────────────────────────────────────────────────────────────────────
// //
// //   Widget _buildMessageBubble(ChatMessage msg, int index) {
// //     // Check if this is a language selector
// //     if (msg.isLanguageSelector && !msg.isUser) {
// //       return _buildLanguageSelector(msg.query ?? '');
// //     }
// //
// //     final isUser = msg.isUser;
// //     final isError = msg.isError;
// //
// //     // Check if this message has bilingual responses
// //     final responses = chatController.getResponseForMessage(index);
// //     final language = chatController.getLanguageForMessage(index);
// //
// //     // Check if this message is currently speaking
// //     final isSpeaking = chatController.isMessageSpeaking(index);
// //
// //     return Align(
// //       alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
// //       child: Container(
// //         margin: const EdgeInsets.symmetric(vertical: 4),
// //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
// //         constraints: BoxConstraints(
// //           maxWidth: MediaQuery.of(context).size.width * 0.85,
// //         ),
// //         decoration: BoxDecoration(
// //           color: isUser
// //               ? _tealDark
// //               : (isError ? Colors.red.shade100 : Colors.grey.shade200),
// //           borderRadius: BorderRadius.circular(16).copyWith(
// //             bottomRight: isUser ? const Radius.circular(4) : Radius.zero,
// //             bottomLeft: isUser ? Radius.zero : const Radius.circular(4),
// //           ),
// //         ),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             // Message text
// //             Text(
// //               msg.text,
// //               style: TextStyle(
// //                 fontSize: 14,
// //                 height: 1.4,
// //                 color: isUser
// //                     ? Colors.white
// //                     : (isError ? Colors.red.shade900 : Colors.black87),
// //               ),
// //             ),
// //
// //             // ── Bilingual speaker buttons (only for bot messages) ──────────
// //             if (!isUser && !isError && responses != null)
// //               Padding(
// //                 padding: const EdgeInsets.only(top: 8),
// //                 child: Row(
// //                   mainAxisSize: MainAxisSize.min,
// //                   children: [
// //                     // Urdu speaker
// //                     _buildSpeakerButton(
// //                       language: 'urdu',
// //                       label: 'اردو',
// //                       flag: '🇵🇰',
// //                       text: responses['urdu'] ?? msg.text,
// //                       index: index,
// //                       isSpeaking: isSpeaking && language == 'urdu',
// //                     ),
// //                     const SizedBox(width: 8),
// //                     // English speaker
// //                     _buildSpeakerButton(
// //                       language: 'english',
// //                       label: 'English',
// //                       flag: '🇬🇧',
// //                       text: responses['english'] ?? msg.text,
// //                       index: index,
// //                       isSpeaking: isSpeaking && language == 'english',
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //
// //             // ── Single speaker for non-bilingual messages ──────────────────
// //             if (!isUser && !isError && responses == null)
// //               Padding(
// //                 padding: const EdgeInsets.only(top: 4),
// //                 child: _buildSingleSpeakerButton(
// //                   text: msg.text,
// //                   index: index,
// //                   isSpeaking: isSpeaking,
// //                 ),
// //               ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildSpeakerButton({
// //     required String language,
// //     required String label,
// //     required String flag,
// //     required String text,
// //     required int index,
// //     required bool isSpeaking,
// //   }) {
// //     return GestureDetector(
// //       onTap: () {
// //         if (isSpeaking) {
// //           // Stop if already speaking
// //           chatController.stopSpeaking();
// //         } else {
// //           // Speak in selected language
// //           chatController.toggleSpeak(index, text, language);
// //         }
// //       },
// //       child: Container(
// //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
// //         decoration: BoxDecoration(
// //           color: isSpeaking
// //               ? Colors.red.shade100
// //               : (language == 'urdu' ? _tealVeryLight : Colors.blue.shade50),
// //           borderRadius: BorderRadius.circular(12),
// //           border: Border.all(
// //             color: isSpeaking
// //                 ? Colors.red.shade300
// //                 : (language == 'urdu' ? _tealDark : Colors.blue.shade300),
// //             width: 1,
// //           ),
// //         ),
// //         child: Row(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Text(flag, style: const TextStyle(fontSize: 14)),
// //             const SizedBox(width: 4),
// //             Text(
// //               label,
// //               style: TextStyle(
// //                 fontSize: 11,
// //                 fontWeight: FontWeight.w500,
// //                 color: isSpeaking
// //                     ? Colors.red.shade700
// //                     : (language == 'urdu' ? _tealDark : Colors.blue.shade700),
// //               ),
// //             ),
// //             const SizedBox(width: 4),
// //             Icon(
// //               isSpeaking ? Icons.stop : Icons.volume_up,
// //               size: 14,
// //               color: isSpeaking
// //                   ? Colors.red.shade700
// //                   : (language == 'urdu' ? _tealDark : Colors.blue.shade700),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildSingleSpeakerButton({
// //     required String text,
// //     required int index,
// //     required bool isSpeaking,
// //   }) {
// //     return GestureDetector(
// //       onTap: () {
// //         if (isSpeaking) {
// //           chatController.stopSpeaking();
// //         } else {
// //           chatController.toggleSpeak(index, text, 'urdu');
// //         }
// //       },
// //       child: Container(
// //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
// //         decoration: BoxDecoration(
// //           color: isSpeaking ? Colors.red.shade100 : _tealVeryLight,
// //           borderRadius: BorderRadius.circular(12),
// //           border: Border.all(
// //             color: isSpeaking ? Colors.red.shade300 : _tealDark,
// //             width: 1,
// //           ),
// //         ),
// //         child: Row(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Icon(
// //               isSpeaking ? Icons.stop : Icons.volume_up,
// //               size: 14,
// //               color: isSpeaking ? Colors.red.shade700 : _tealDark,
// //             ),
// //             const SizedBox(width: 4),
// //             Text(
// //               isSpeaking ? 'Stop' : 'Listen',
// //               style: TextStyle(
// //                 fontSize: 11,
// //                 fontWeight: FontWeight.w500,
// //                 color: isSpeaking ? Colors.red.shade700 : _tealDark,
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
//
// import 'package:flutter/material.dart';
// import 'package:dio/dio.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../Screens/HomeScreenComponents/app_bottom_navbar.dart';
// import '../../Screens/HomeScreenComponents/navbar.dart';
// import '../../Screens/HomeScreenComponents/sidebar_drawer.dart';
// import '../core/api_router.dart';
// import '../core/chat_controller.dart';
// import '../models/chat_message.dart';
// import '../services/analytics_api_service.dart';
// import '../services/attendance_api_service.dart';
//
// class ChatbotScreen extends StatefulWidget {
//   final int currentIndex;
//   final int chatBadgeCount;
//   final ValueChanged<int>? onNavTap;
//
//   const ChatbotScreen({
//     super.key,
//     this.currentIndex = 2,
//     this.chatBadgeCount = 0,
//     this.onNavTap,
//   });
//
//   @override
//   State<ChatbotScreen> createState() => _ChatbotScreenState();
// }
//
// class _ChatbotScreenState extends State<ChatbotScreen> {
//   final TextEditingController inputController = TextEditingController();
//   final ScrollController scrollController = ScrollController();
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   late final ChatController chatController;
//
//   String _empName = 'Employee';
//   String _userInitials = '?';
//
//   static const Color _tealLight = Color(0xFF3DAF93);
//   static const Color _tealDark = Color(0xFF1A6E59);
//   static const Color _tealVeryLight = Color(0xFFE8F5F2);
//
//   final List<Map<String, String>> _shortcuts = const [
//     {'label': '📊 Summary', 'query': 'meri attendance summary batao'},
//     {'label': '✅ Present', 'query': 'kitne din present raha'},
//     {'label': '⏰ Late', 'query': 'kitni late hui'},
//     {'label': '⏱️ Hours', 'query': 'kitni working hours hain'},
//     {'label': '📍 Geo', 'query': 'kya koi violation hai'},
//     {'label': '🏖️ Leave', 'query': 'kitni chutti li'},
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//
//     final dio = Dio(
//       BaseOptions(
//         connectTimeout: const Duration(seconds: 15),
//         receiveTimeout: const Duration(seconds: 15),
//       ),
//     );
//
//     final router = ApiRouter(
//       AnalyticsApiService(dio),
//       AttendanceApiService(dio),
//     );
//
//     chatController = ChatController(router);
//     chatController.addListener(_onUpdate);
//   }
//
//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final name = prefs.getString('userName') ?? 'Employee';
//     setState(() {
//       _empName = name;
//       _userInitials = _getInitials(name);
//     });
//   }
//
//   String _getInitials(String name) {
//     final parts = name.trim().split(' ');
//     if (parts.length >= 2) {
//       return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
//     }
//     return name.isNotEmpty ? name[0].toUpperCase() : '?';
//   }
//
//   void _onUpdate() {
//     setState(() {});
//     _scrollToBottom();
//   }
//
//   Future<void> _send() async {
//     final text = inputController.text;
//     if (text.trim().isEmpty) return;
//     inputController.clear();
//     await chatController.sendMessage(text);
//   }
//
//   Future<void> _sendShortcut(String query) async {
//     await chatController.sendMessage(query);
//   }
//
//   void _scrollToBottom() {
//     Future.delayed(const Duration(milliseconds: 150), () {
//       if (scrollController.hasClients) {
//         scrollController.animateTo(
//           scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 250),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     chatController.removeListener(_onUpdate);
//     inputController.dispose();
//     scrollController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final messages = chatController.messages;
//     final showTyping = chatController.isTyping;
//     final isListening = chatController.isListening;
//     final isSpeaking = chatController.isSpeaking;
//
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: Colors.grey.shade50,
//       appBar: Navbar(
//         userName: _empName,
//         userInitials: _userInitials,
//         scaffoldKey: _scaffoldKey,
//       ),
//       drawer: AppDrawer(),
//       bottomNavigationBar: widget.onNavTap != null
//           ? AppBottomNavBar(
//         currentIndex: widget.currentIndex,
//         chatBadgeCount: widget.chatBadgeCount,
//         onTap: widget.onNavTap!,
//       )
//           : null,
//       body: SafeArea(
//         child: Column(
//           children: [
//             // ── Chat Header ──────────────────────────────────────────────────
//             Container(
//               padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.08),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: _tealVeryLight,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: const Icon(
//                       Icons.smart_toy_outlined,
//                       color: _tealDark,
//                       size: 22,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Attendance Assistant',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w700,
//                           color: Color(0xFF1A1A2E),
//                         ),
//                       ),
//                       Text(
//                         'Ask about your attendance anytime',
//                         style: TextStyle(
//                           fontSize: 11,
//                           color: Colors.grey.shade500,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const Spacer(),
//                   // Status badges
//                   if (isListening)
//                     _buildStatusBadge(
//                       icon: Icons.circle,
//                       label: 'Recording',
//                       color: Colors.red,
//                       iconSize: 8,
//                     ),
//                   if (isSpeaking)
//                     _buildStatusBadge(
//                       icon: Icons.volume_up,
//                       label: 'Speaking',
//                       color: Colors.green,
//                       iconSize: 14,
//                       onTap: () => chatController.stopSpeaking(),
//                     ),
//                 ],
//               ),
//             ),
//
//             // ── Shortcut Chips ────────────────────────────────────────────────
//             Container(
//               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 border: Border(
//                   bottom: BorderSide(color: Colors.grey.shade200),
//                 ),
//               ),
//               child: SizedBox(
//                 height: 36,
//                 child: ListView.separated(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: _shortcuts.length,
//                   separatorBuilder: (_, __) => const SizedBox(width: 8),
//                   itemBuilder: (context, index) {
//                     final shortcut = _shortcuts[index];
//                     return ActionChip(
//                       label: Text(
//                         shortcut['label']!,
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                           color: _tealDark,
//                         ),
//                       ),
//                       onPressed: () => _sendShortcut(shortcut['query']!),
//                       backgroundColor: _tealVeryLight,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(20),
//                         side: BorderSide(color: _tealDark.withOpacity(0.2)),
//                       ),
//                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                     );
//                   },
//                 ),
//               ),
//             ),
//
//             // ── Voice Listening Indicator ─────────────────────────────────────
//             if (isListening)
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                 color: Colors.red.shade50,
//                 child: Row(
//                   children: [
//                     const Icon(Icons.mic, color: Colors.red, size: 18),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Text(
//                         chatController.voiceTranscript.isEmpty
//                             ? 'Listening... start speaking'
//                             : '"${chatController.voiceTranscript}"',
//                         style: TextStyle(fontSize: 13, color: Colors.red.shade700),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     if (chatController.voiceConfidence > 0.3)
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                         decoration: BoxDecoration(
//                           color: Colors.green.shade100,
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Text(
//                           '${(chatController.voiceConfidence * 100).toInt()}%',
//                           style: TextStyle(
//                             fontSize: 11,
//                             color: Colors.green.shade700,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     GestureDetector(
//                       onTap: () => chatController.stopVoiceInput(),
//                       child: const Padding(
//                         padding: EdgeInsets.all(4),
//                         child: Icon(Icons.close, size: 18, color: Colors.red),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//             // ── Messages ─────────────────────────────────────────────────────
//             Expanded(
//               child: messages.isEmpty
//                   ? _buildEmptyState()
//                   : ListView.builder(
//                 controller: scrollController,
//                 padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
//                 itemCount: messages.length + (showTyping ? 1 : 0),
//                 itemBuilder: (context, index) {
//                   if (showTyping && index == messages.length) {
//                     return _buildTypingIndicator();
//                   }
//                   return _buildMessageBubble(messages[index], index);
//                 },
//               ),
//             ),
//
//             // ── Input Bar ─────────────────────────────────────────────────────
//             Container(
//               padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.1),
//                     blurRadius: 8,
//                     offset: const Offset(0, -2),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 children: [
//                   // Mic button
//                   if (chatController.isVoiceAvailable)
//                     GestureDetector(
//                       onTap: () {
//                         if (isListening) {
//                           chatController.stopVoiceInput();
//                         } else {
//                           chatController.startVoiceInput();
//                         }
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: isListening ? Colors.red.shade50 : _tealVeryLight,
//                           shape: BoxShape.circle,
//                           border: Border.all(
//                             color: isListening ? Colors.red.shade300 : _tealDark.withOpacity(0.3),
//                           ),
//                         ),
//                         child: Icon(
//                           isListening ? Icons.mic : Icons.mic_none,
//                           color: isListening ? Colors.red : _tealDark,
//                           size: 20,
//                         ),
//                       ),
//                     ),
//                   const SizedBox(width: 8),
//                   // Text field
//                   Expanded(
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade100,
//                         borderRadius: BorderRadius.circular(24),
//                         border: Border.all(
//                           color: isListening
//                               ? Colors.red.shade300
//                               : Colors.grey.shade200,
//                           width: 1.5,
//                         ),
//                       ),
//                       child: TextField(
//                         controller: inputController,
//                         decoration: InputDecoration(
//                           hintText: isListening
//                               ? '🎤 Listening...'
//                               : 'Ask about your attendance...',
//                           hintStyle: TextStyle(
//                             color: Colors.grey.shade500,
//                             fontSize: 14,
//                           ),
//                           border: InputBorder.none,
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 16,
//                             vertical: 10,
//                           ),
//                         ),
//                         onSubmitted: (_) => _send(),
//                         enabled: !isListening,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   // Send button
//                   GestureDetector(
//                     onTap: _send,
//                     child: Container(
//                       padding: const EdgeInsets.all(11),
//                       decoration: const BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [_tealLight, _tealDark],
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                         ),
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.send_rounded,
//                         color: Colors.white,
//                         size: 20,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Status Badge ──────────────────────────────────────────────────────────
//
//   Widget _buildStatusBadge({
//     required IconData icon,
//     required String label,
//     required Color color,
//     required double iconSize,
//     VoidCallback? onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         margin: const EdgeInsets.only(left: 6),
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.08),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: color.withOpacity(0.3)),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(icon, color: color, size: iconSize),
//             const SizedBox(width: 4),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 11,
//                 color: color,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             if (onTap != null) ...[
//               const SizedBox(width: 4),
//               Icon(Icons.close, size: 13, color: color),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Empty State ───────────────────────────────────────────────────────────
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 32),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(24),
//               decoration: const BoxDecoration(
//                 color: _tealVeryLight,
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.smart_toy_outlined,
//                 color: _tealDark,
//                 size: 44,
//               ),
//             ),
//             const SizedBox(height: 20),
//             const Text(
//               'Attendance Assistant',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w700,
//                 color: Color(0xFF1A1A2E),
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Ask anything about your attendance in Urdu or English',
//               style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 24),
//             // Example chips
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               alignment: WrapAlignment.center,
//               children: [
//                 _buildExampleChip('meri attendance batao'),
//                 _buildExampleChip('kitni late hui'),
//                 _buildExampleChip('working hours?'),
//                 _buildExampleChip('koi violation hai?'),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildExampleChip(String text) {
//     return GestureDetector(
//       onTap: () => _sendShortcut(text),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//         decoration: BoxDecoration(
//           color: _tealVeryLight,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: _tealDark.withOpacity(0.2)),
//         ),
//         child: Text(
//           text,
//           style: const TextStyle(
//             fontSize: 12,
//             color: _tealDark,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Typing Indicator ──────────────────────────────────────────────────────
//
//   Widget _buildTypingIndicator() {
//     return Align(
//       alignment: Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 4),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         decoration: BoxDecoration(
//           color: Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(16).copyWith(
//             bottomLeft: const Radius.circular(4),
//           ),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _buildDot(0),
//             const SizedBox(width: 4),
//             _buildDot(1),
//             const SizedBox(width: 4),
//             _buildDot(2),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDot(int index) {
//     return TweenAnimationBuilder<double>(
//       tween: Tween(begin: 0.4, end: 1.0),
//       duration: Duration(milliseconds: 400 + (index * 150)),
//       builder: (_, value, __) => Container(
//         width: 7,
//         height: 7,
//         decoration: BoxDecoration(
//           color: _tealDark.withOpacity(value),
//           shape: BoxShape.circle,
//         ),
//       ),
//     );
//   }
//
//   // ── Language Selector ─────────────────────────────────────────────────────
//   //
//   // FIX: ElevatedButton.icon was duplicating the flag because both icon: and
//   // label: contained the flag emoji. Now using plain ElevatedButton with a
//   // custom Row child, so the flag appears only once.
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Widget _buildLanguageSelector(String query) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Small label above the buttons
//           Padding(
//             padding: const EdgeInsets.only(left: 4, bottom: 8),
//             child: Text(
//               'Choose response language:',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey.shade500,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//           Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _buildLangButton(
//                 flag: '🇵🇰',
//                 label: 'اردو',
//                 language: 'urdu',
//                 query: query,
//                 color: _tealDark,
//                 bgColor: _tealVeryLight,
//               ),
//               const SizedBox(width: 10),
//               _buildLangButton(
//                 flag: '🇬🇧',
//                 label: 'English',
//                 language: 'english',
//                 query: query,
//                 color: Colors.blue.shade700,
//                 bgColor: Colors.blue.shade50,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLangButton({
//     required String flag,
//     required String label,
//     required String language,
//     required String query,
//     required Color color,
//     required Color bgColor,
//   }) {
//     return GestureDetector(
//       onTap: () => chatController.selectLanguage(language, query),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//         decoration: BoxDecoration(
//           color: bgColor,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: color.withOpacity(0.4), width: 1.5),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(flag, style: const TextStyle(fontSize: 18)),
//             const SizedBox(width: 8),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: color,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Message Bubble ────────────────────────────────────────────────────────
//
//   Widget _buildMessageBubble(ChatMessage msg, int index) {
//     if (msg.isLanguageSelector && !msg.isUser) {
//       return _buildLanguageSelector(msg.query ?? '');
//     }
//
//     // FIX: Skip the "→ 🇵🇰 اردو" confirmation bubble — handled inside
//     // selectLanguage() now. If you still see it, the controller adds it;
//     // the screen just ignores it visually by treating it as a ghost bubble.
//     if (msg.isLanguageConfirmation) return const SizedBox.shrink();
//
//     final isUser = msg.isUser;
//     final isError = msg.isError;
//
//     final responses = chatController.getResponseForMessage(index);
//     final language = chatController.getLanguageForMessage(index);
//     final isSpeaking = chatController.isMessageSpeaking(index);
//
//     return Align(
//       alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
//       child: Column(
//         crossAxisAlignment:
//         isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//         children: [
//           Container(
//             margin: const EdgeInsets.symmetric(vertical: 3),
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//             constraints: BoxConstraints(
//               maxWidth: MediaQuery.of(context).size.width * 0.82,
//             ),
//             decoration: BoxDecoration(
//               color: isUser
//                   ? _tealDark
//                   : (isError ? Colors.red.shade50 : Colors.white),
//               borderRadius: BorderRadius.circular(16).copyWith(
//                 bottomRight:
//                 isUser ? const Radius.circular(4) : Radius.zero,
//                 bottomLeft:
//                 isUser ? Radius.zero : const Radius.circular(4),
//               ),
//               border: isUser
//                   ? null
//                   : Border.all(
//                 color: isError
//                     ? Colors.red.shade200
//                     : Colors.grey.shade200,
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Message text
//                 Text(
//                   msg.text,
//                   style: TextStyle(
//                     fontSize: 14,
//                     height: 1.5,
//                     color: isUser
//                         ? Colors.white
//                         : (isError
//                         ? Colors.red.shade800
//                         : const Color(0xFF1A1A2E)),
//                   ),
//                 ),
//
//                 // ── TTS buttons for bot messages ─────────────────────────
//                 if (!isUser && !isError && responses != null) ...[
//                   const SizedBox(height: 10),
//                   Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       _buildSpeakerChip(
//                         flag: '🇵🇰',
//                         label: 'اردو',
//                         langKey: 'urdu',
//                         text: responses['urdu'] ?? msg.text,
//                         index: index,
//                         isSpeaking: isSpeaking && language == 'urdu',
//                       ),
//                       const SizedBox(width: 6),
//                       _buildSpeakerChip(
//                         flag: '🇬🇧',
//                         label: 'EN',
//                         langKey: 'english',
//                         text: responses['english'] ?? msg.text,
//                         index: index,
//                         isSpeaking: isSpeaking && language == 'english',
//                       ),
//                     ],
//                   ),
//                 ],
//
//                 if (!isUser && !isError && responses == null) ...[
//                   const SizedBox(height: 6),
//                   _buildSingleSpeakerChip(
//                     text: msg.text,
//                     index: index,
//                     isSpeaking: isSpeaking,
//                   ),
//                 ],
//               ],
//             ),
//           ),
//
//           // ── Related suggestions below bot response ────────────────────
//           if (!isUser && !isError && msg.suggestions != null)
//             _buildSuggestions(msg.suggestions!),
//         ],
//       ),
//     );
//   }
//
//   // ── Speaker Chips ─────────────────────────────────────────────────────────
//
//   Widget _buildSpeakerChip({
//     required String flag,
//     required String label,
//     required String langKey,
//     required String text,
//     required int index,
//     required bool isSpeaking,
//   }) {
//     return GestureDetector(
//       onTap: () {
//         if (isSpeaking) {
//           chatController.stopSpeaking();
//         } else {
//           chatController.toggleSpeak(index, text, langKey);
//         }
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         decoration: BoxDecoration(
//           color: isSpeaking ? Colors.red.shade50 : Colors.grey.shade100,
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(
//             color: isSpeaking
//                 ? Colors.red.shade300
//                 : Colors.grey.shade300,
//           ),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(flag, style: const TextStyle(fontSize: 12)),
//             const SizedBox(width: 4),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 11,
//                 fontWeight: FontWeight.w500,
//                 color: isSpeaking
//                     ? Colors.red.shade700
//                     : Colors.grey.shade700,
//               ),
//             ),
//             const SizedBox(width: 4),
//             Icon(
//               isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
//               size: 12,
//               color: isSpeaking ? Colors.red.shade700 : Colors.grey.shade600,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSingleSpeakerChip({
//     required String text,
//     required int index,
//     required bool isSpeaking,
//   }) {
//     return GestureDetector(
//       onTap: () {
//         if (isSpeaking) {
//           chatController.stopSpeaking();
//         } else {
//           chatController.toggleSpeak(index, text, 'urdu');
//         }
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         decoration: BoxDecoration(
//           color: isSpeaking ? Colors.red.shade50 : Colors.grey.shade100,
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(
//             color: isSpeaking ? Colors.red.shade300 : Colors.grey.shade300,
//           ),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(
//               isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
//               size: 13,
//               color: isSpeaking ? Colors.red.shade700 : Colors.grey.shade600,
//             ),
//             const SizedBox(width: 4),
//             Text(
//               isSpeaking ? 'Stop' : 'Listen',
//               style: TextStyle(
//                 fontSize: 11,
//                 fontWeight: FontWeight.w500,
//                 color: isSpeaking ? Colors.red.shade700 : Colors.grey.shade700,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Related Suggestions ───────────────────────────────────────────────────
//
//   Widget _buildSuggestions(List<String> suggestions) {
//     return Padding(
//       padding: const EdgeInsets.only(top: 6, bottom: 4),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.only(left: 4, bottom: 6),
//             child: Text(
//               'You might also ask:',
//               style: TextStyle(
//                 fontSize: 11,
//                 color: Colors.grey.shade500,
//               ),
//             ),
//           ),
//           Wrap(
//             spacing: 6,
//             runSpacing: 6,
//             children: suggestions
//                 .map(
//                   (s) => GestureDetector(
//                 onTap: () => _sendShortcut(s),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: _tealVeryLight,
//                     borderRadius: BorderRadius.circular(14),
//                     border:
//                     Border.all(color: _tealDark.withOpacity(0.2)),
//                   ),
//                   child: Text(
//                     s,
//                     style: const TextStyle(
//                       fontSize: 11,
//                       color: _tealDark,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ),
//             )
//                 .toList(),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Screens/HomeScreenComponents/app_bottom_navbar.dart';
import '../../Screens/HomeScreenComponents/navbar.dart';
import '../../Screens/HomeScreenComponents/sidebar_drawer.dart';
import '../core/api_router.dart';
import '../core/chat_controller.dart';
import '../models/chat_message.dart';
import '../services/analytics_api_service.dart';
import '../services/attendance_api_service.dart';

class ChatbotScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int>? onNavTap;

  const ChatbotScreen({
    super.key,
    this.currentIndex = 2,
    this.chatBadgeCount = 0,
    this.onNavTap,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final ChatController chatController;

  String _empName = 'Employee';
  String _userInitials = '?';

  static const Color _tealLight = Color(0xFF3DAF93);
  static const Color _tealDark = Color(0xFF1A6E59);
  static const Color _tealVeryLight = Color(0xFFE8F5F2);

  final List<Map<String, String>> _shortcuts = const [
    {'label': '📊 Summary', 'query': 'meri attendance summary batao'},
    {'label': '✅ Present', 'query': 'kitne din present raha'},
    {'label': '⏰ Late', 'query': 'kitni late hui'},
    {'label': '⏱️ Hours', 'query': 'kitni working hours hain'},
    {'label': '📍 Geo', 'query': 'kya koi violation hai'},
    {'label': '🏖️ Leave', 'query': 'kitni chutti li'},
  ];

  // FIX: tracks which language is currently shown in the bubble for each
  // bot message (keyed by message index). Defaults to Urdu. Tapping the
  // اردو/EN chip now updates this (see _buildSpeakerChip) so the visible
  // text actually switches, instead of the chip only triggering TTS.
  final Map<int, String> _displayLanguage = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    final router = ApiRouter(
      AnalyticsApiService(dio),
      AttendanceApiService(dio),
    );

    chatController = ChatController(router);
    chatController.addListener(_onUpdate);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName') ?? 'Employee';
    setState(() {
      _empName = name;
      _userInitials = _getInitials(name);
    });
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _onUpdate() {
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = inputController.text;
    if (text.trim().isEmpty) return;
    inputController.clear();
    await chatController.sendMessage(text);
  }

  Future<void> _sendShortcut(String query) async {
    await chatController.sendMessage(query);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    chatController.removeListener(_onUpdate);
    inputController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = chatController.messages;
    final showTyping = chatController.isTyping;
    final isListening = chatController.isListening;
    final isSpeaking = chatController.isSpeaking;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade50,
      appBar: Navbar(
        userName: _empName,
        userInitials: _userInitials,
        scaffoldKey: _scaffoldKey,
      ),
      drawer: AppDrawer(),
      bottomNavigationBar: widget.onNavTap != null
          ? AppBottomNavBar(
        currentIndex: widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap: widget.onNavTap!,
      )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // ── Chat Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _tealVeryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: _tealDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attendance Assistant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        'Ask about your attendance anytime',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Status badges
                  if (isListening)
                    _buildStatusBadge(
                      icon: Icons.circle,
                      label: 'Recording',
                      color: Colors.red,
                      iconSize: 8,
                    ),
                  if (isSpeaking)
                    _buildStatusBadge(
                      icon: Icons.volume_up,
                      label: 'Speaking',
                      color: Colors.green,
                      iconSize: 14,
                      onTap: () => chatController.stopSpeaking(),
                    ),
                ],
              ),
            ),

            // ── Shortcut Chips ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _shortcuts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final shortcut = _shortcuts[index];
                    return ActionChip(
                      label: Text(
                        shortcut['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _tealDark,
                        ),
                      ),
                      onPressed: () => _sendShortcut(shortcut['query']!),
                      backgroundColor: _tealVeryLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: _tealDark.withOpacity(0.2)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  },
                ),
              ),
            ),

            // ── Voice Listening Indicator ─────────────────────────────────────
            if (isListening)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        chatController.voiceTranscript.isEmpty
                            ? 'Listening... start speaking'
                            : '"${chatController.voiceTranscript}"',
                        style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (chatController.voiceConfidence > 0.3)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(chatController.voiceConfidence * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => chatController.stopVoiceInput(),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Messages ─────────────────────────────────────────────────────
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: messages.length + (showTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (showTyping && index == messages.length) {
                    return _buildTypingIndicator();
                  }
                  return _buildMessageBubble(messages[index], index);
                },
              ),
            ),

            // ── Input Bar ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Mic button
                  if (chatController.isVoiceAvailable)
                    GestureDetector(
                      onTap: () {
                        if (isListening) {
                          chatController.stopVoiceInput();
                        } else {
                          chatController.startVoiceInput();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isListening ? Colors.red.shade50 : _tealVeryLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isListening ? Colors.red.shade300 : _tealDark.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          isListening ? Icons.mic : Icons.mic_none,
                          color: isListening ? Colors.red : _tealDark,
                          size: 20,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Text field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isListening
                              ? Colors.red.shade300
                              : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: inputController,
                        decoration: InputDecoration(
                          hintText: isListening
                              ? '🎤 Listening...'
                              : 'Ask about your attendance...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                        enabled: !isListening,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_tealLight, _tealDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status Badge ──────────────────────────────────────────────────────────

  Widget _buildStatusBadge({
    required IconData icon,
    required String label,
    required Color color,
    required double iconSize,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: iconSize),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.close, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: _tealVeryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: _tealDark,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Attendance Assistant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask anything about your attendance in Urdu or English',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Example chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildExampleChip('meri attendance batao'),
                _buildExampleChip('kitni late hui'),
                _buildExampleChip('working hours?'),
                _buildExampleChip('koi violation hai?'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return GestureDetector(
      onTap: () => _sendShortcut(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _tealVeryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _tealDark.withOpacity(0.2)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: _tealDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Typing Indicator ──────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      builder: (_, value, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: _tealDark.withOpacity(value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ── Language Selector ─────────────────────────────────────────────────────
  //
  // FIX: ElevatedButton.icon was duplicating the flag because both icon: and
  // label: contained the flag emoji. Now using plain ElevatedButton with a
  // custom Row child, so the flag appears only once.
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLanguageSelector(String query) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small label above the buttons
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Choose response language:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLangButton(
                flag: '🇵🇰',
                label: 'اردو',
                language: 'urdu',
                query: query,
                color: _tealDark,
                bgColor: _tealVeryLight,
              ),
              const SizedBox(width: 10),
              _buildLangButton(
                flag: '🇬🇧',
                label: 'English',
                language: 'english',
                query: query,
                color: Colors.blue.shade700,
                bgColor: Colors.blue.shade50,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangButton({
    required String flag,
    required String label,
    required String language,
    required String query,
    required Color color,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: () => chatController.selectLanguage(language, query),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIX: the bubble was showing raw "**0**" / "**41 minutes**" instead of
  // bold text, because Text() doesn't understand markdown — it was just
  // printing the literal asterisks. This parses **...** segments and
  // renders them with FontWeight.bold via TextSpans, dropping the markers.
  Widget _buildFormattedText(String text, TextStyle baseStyle) {
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    final spans = <TextSpan>[];
    int start = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }

  // ── Message Bubble ────────────────────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessage msg, int index) {
    if (msg.isLanguageSelector && !msg.isUser) {
      return _buildLanguageSelector(msg.query ?? '');
    }

    // FIX: Skip the "→ 🇵🇰 اردو" confirmation bubble — handled inside
    // selectLanguage() now. If you still see it, the controller adds it;
    // the screen just ignores it visually by treating it as a ghost bubble.
    if (msg.isLanguageConfirmation) return const SizedBox.shrink();

    final isUser = msg.isUser;
    final isError = msg.isError;

    final responses = chatController.getResponseForMessage(index);
    final language = chatController.getLanguageForMessage(index);
    final isSpeaking = chatController.isMessageSpeaking(index);

    // FIX: pick which language's text to actually show in the bubble.
    // Defaults to Urdu (existing behaviour) until the user taps a chip.
    final currentDisplayLang = _displayLanguage[index] ?? 'urdu';
    final displayText = (!isUser && responses != null)
        ? (responses[currentDisplayLang] ?? msg.text)
        : msg.text;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? _tealDark
                  : (isError ? Colors.red.shade50 : Colors.white),
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight:
                isUser ? const Radius.circular(4) : Radius.zero,
                bottomLeft:
                isUser ? Radius.zero : const Radius.circular(4),
              ),
              border: isUser
                  ? null
                  : Border.all(
                color: isError
                    ? Colors.red.shade200
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Message text
                // FIX: wrap in Directionality so English renders LTR and
                // Urdu renders RTL regardless of which one is selected —
                // this also avoids any leftover bidi-reordering artifacts.
                Directionality(
                  textDirection: (!isUser && currentDisplayLang == 'english')
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  child: _buildFormattedText(
                    displayText,
                    TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isUser
                          ? Colors.white
                          : (isError
                          ? Colors.red.shade800
                          : const Color(0xFF1A1A2E)),
                    ),
                  ),
                ),

                // ── TTS buttons for bot messages ─────────────────────────
                if (!isUser && !isError && responses != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSpeakerChip(
                        flag: '🇵🇰',
                        label: 'اردو',
                        langKey: 'urdu',
                        text: responses['urdu'] ?? msg.text,
                        index: index,
                        isSpeaking: isSpeaking && language == 'urdu',
                        isSelected: currentDisplayLang == 'urdu',
                      ),
                      const SizedBox(width: 6),
                      _buildSpeakerChip(
                        flag: '🇬🇧',
                        label: 'EN',
                        langKey: 'english',
                        text: responses['english'] ?? msg.text,
                        index: index,
                        isSpeaking: isSpeaking && language == 'english',
                        isSelected: currentDisplayLang == 'english',
                      ),
                    ],
                  ),
                ],

                if (!isUser && !isError && responses == null) ...[
                  const SizedBox(height: 6),
                  _buildSingleSpeakerChip(
                    text: msg.text,
                    index: index,
                    isSpeaking: isSpeaking,
                  ),
                ],
              ],
            ),
          ),

          // ── Related suggestions below bot response ────────────────────
          if (!isUser && !isError && msg.suggestions != null)
            _buildSuggestions(msg.suggestions!),
        ],
      ),
    );
  }

  // ── Speaker Chips ─────────────────────────────────────────────────────────

  Widget _buildSpeakerChip({
    required String flag,
    required String label,
    required String langKey,
    required String text,
    required int index,
    required bool isSpeaking,
    bool isSelected = false,
  }) {
    // FIX: tapping the chip now also switches which language is displayed
    // in the bubble (previously this only toggled text-to-speech).
    final Color bg = isSpeaking
        ? Colors.red.shade50
        : (isSelected ? _tealVeryLight : Colors.grey.shade100);
    final Color border = isSpeaking
        ? Colors.red.shade300
        : (isSelected ? _tealDark.withOpacity(0.4) : Colors.grey.shade300);
    final Color fg = isSpeaking
        ? Colors.red.shade700
        : (isSelected ? _tealDark : Colors.grey.shade700);

    return GestureDetector(
      onTap: () {
        setState(() {
          _displayLanguage[index] = langKey;
        });
        if (isSpeaking) {
          chatController.stopSpeaking();
        } else {
          chatController.toggleSpeak(index, text, langKey);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: 12,
              color: isSpeaking ? Colors.red.shade700 : fg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSpeakerChip({
    required String text,
    required int index,
    required bool isSpeaking,
  }) {
    return GestureDetector(
      onTap: () {
        if (isSpeaking) {
          chatController.stopSpeaking();
        } else {
          chatController.toggleSpeak(index, text, 'urdu');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSpeaking ? Colors.red.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSpeaking ? Colors.red.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: 13,
              color: isSpeaking ? Colors.red.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              isSpeaking ? 'Stop' : 'Listen',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSpeaking ? Colors.red.shade700 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Related Suggestions ───────────────────────────────────────────────────

  Widget _buildSuggestions(List<String> suggestions) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'You might also ask:',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions
                .map(
                  (s) => GestureDetector(
                onTap: () => _sendShortcut(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _tealVeryLight,
                    borderRadius: BorderRadius.circular(14),
                    border:
                    Border.all(color: _tealDark.withOpacity(0.2)),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _tealDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }
}
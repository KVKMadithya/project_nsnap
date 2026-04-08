import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  const ChatScreen({super.key, required this.receiverId, required this.receiverName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  String getChatId() {
    List<String> ids = [currentUserId, widget.receiverId];
    ids.sort();
    return ids.join("_");
  }

  void _send() async {
    if (_msgController.text.trim().isEmpty) return;
    String chatId = getChatId();
    String msg = _msgController.text.trim();

    // Clear instantly for good UX
    _msgController.clear();

    // 1. Save the actual message
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUserId,
      'message': msg,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update the main chat document (This powers the Inbox)
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'users': [currentUserId, widget.receiverId],
      'lastMessage': msg,
      'lastTimestamp': FieldValue.serverTimestamp(),
      // --- NEW: INBOX GLOW WIRE-UP ---
      'lastSenderId': currentUserId,
      'isRead': false,
    }, SetOptions(merge: true));
  }

  // Quick helper to format Firestore timestamps without needing extra packages
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "Sending...";
    DateTime date = timestamp.toDate();
    String hour = date.hour > 12 ? (date.hour - 12).toString() : date.hour.toString();
    if (hour == '0') hour = '12';
    String minute = date.minute.toString().padLeft(2, '0');
    String ampm = date.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $ampm";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 1,
        shadowColor: Colors.black45,
        iconTheme: const IconThemeData(color: c5CreamGreen),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: c2DeepOlive,
              child: Text(
                widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : "?",
                style: const TextStyle(color: c5CreamGreen, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Text(
                widget.receiverName,
                style: const TextStyle(color: c5CreamGreen, fontSize: 18, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(getChatId())
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: c3MediumSage));
                }

                if (snap.data!.docs.isEmpty) {
                  return Center(
                      child: Text(
                          "Say hi to ${widget.receiverName}! 👋",
                          style: const TextStyle(color: c4LightSage, fontSize: 16)
                      )
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: snap.data!.docs.length,
                  itemBuilder: (context, i) {
                    var m = snap.data!.docs[i].data() as Map<String, dynamic>;
                    bool isMe = m['senderId'] == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? c3MediumSage : c2DeepOlive,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                                m['message'],
                                style: TextStyle(
                                    color: isMe ? c1DeepForest : c5CreamGreen,
                                    fontSize: 16
                                )
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(m['timestamp'] as Timestamp?),
                              style: TextStyle(
                                color: isMe ? c1DeepForest.withValues(alpha: 0.7) : c4LightSage.withValues(alpha: 0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 20, top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: c5CreamGreen),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Message...",
                        hintStyle: const TextStyle(color: c4LightSage),
                        filled: true,
                        fillColor: c2DeepOlive,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: c3MediumSage,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: c1DeepForest, size: 24),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
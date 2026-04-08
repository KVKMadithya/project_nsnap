import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String _searchQuery = "";
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // --- HELPER: TIME FORMATTER ---
  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m";
    if (diff.inDays < 1) return "${diff.inHours}h";
    if (diff.inDays < 7) return "${diff.inDays}d";
    return "${date.month}/${date.day}";
  }

  // --- HELPER: SAFE AVATAR BUILDER ---
  Widget _buildAvatar(String? url, String username) {
    if (url == null || url.trim().isEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: c2DeepOlive,
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : "?",
          style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: c2DeepOlive,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {}, // Fails silently instead of crashing
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        title: const Text("Messages", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: Column(
        children: [
          // 1. SLEEK SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: const TextStyle(color: c5CreamGreen),
              decoration: InputDecoration(
                hintText: "Search users...",
                hintStyle: const TextStyle(color: c4LightSage),
                prefixIcon: const Icon(Icons.search, color: c4LightSage),
                filled: true,
                fillColor: c2DeepOlive.withValues(alpha: 0.4), // Softer background
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. DYNAMIC CONTENT
          Expanded(
            child: _searchQuery.isNotEmpty ? _buildSearchResults() : _buildChatList(),
          ),
        ],
      ),
    );
  }

  // --- SEARCH RESULTS UI ---
  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: c3MediumSage));

        var users = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return (data['username'] ?? "").toString().toLowerCase().contains(_searchQuery) && doc.id != currentUserId;
        }).toList();

        if (users.isEmpty) {
          return const Center(child: Text("No users found.", style: TextStyle(color: c4LightSage)));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userData = users[index].data() as Map<String, dynamic>;
            String username = userData['username'] ?? "User";

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: _buildAvatar(userData['profilePicUrl'], username),
              title: Text(username, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.w600, fontSize: 16)),
              onTap: () {
                // Clear search when navigating
                setState(() => _searchQuery = "");
                FocusScope.of(context).unfocus(); // Close keyboard
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: users[index].id, receiverName: username)));
              },
            );
          },
        );
      },
    );
  }

  // --- ACTIVE CHATS UI ---
  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: currentUserId)
          .orderBy('lastTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: c3MediumSage));

        if (snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 60, color: c2DeepOlive),
                  SizedBox(height: 16),
                  Text("No messages yet.", style: TextStyle(color: c4LightSage, fontSize: 16)),
                ],
              )
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chatDoc = snapshot.data!.docs[index];
            var chat = chatDoc.data() as Map<String, dynamic>;
            String otherUserId = (chat['users'] as List).firstWhere((id) => id != currentUserId);

            // --- UNREAD LOGIC ---
            // Assumes backend saves 'lastSenderId' and 'isRead'. Defaults to false if missing.
            String lastSenderId = chat['lastSenderId'] ?? "";
            bool isRead = chat['isRead'] ?? true;
            bool isUnreadForMe = (lastSenderId == otherUserId && !isRead);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const ListTile(
                    leading: CircleAvatar(backgroundColor: c2DeepOlive),
                    title: Text("Loading...", style: TextStyle(color: c2DeepOlive)),
                  );
                }

                var userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                String username = userData['username'] ?? "Nsnap User";
                String timeAgo = _formatTimeAgo(chat['lastTimestamp'] as Timestamp?);

                return InkWell(
                  onTap: () {
                    // Mark as read in Firestore when clicked
                    if (isUnreadForMe) {
                      FirebaseFirestore.instance.collection('chats').doc(chatDoc.id).update({'isRead': true});
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: otherUserId, receiverName: username)));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Row(
                      children: [
                        _buildAvatar(userData['profilePicUrl'], username),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  username,
                                  style: TextStyle(
                                      color: c5CreamGreen,
                                      fontWeight: isUnreadForMe ? FontWeight.w800 : FontWeight.w600, // Thicker if unread
                                      fontSize: 16
                                  )
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        chat['lastMessage'] ?? "",
                                        style: TextStyle(
                                          color: isUnreadForMe ? c5CreamGreen : c4LightSage,
                                          fontWeight: isUnreadForMe ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis
                                    ),
                                  ),
                                  Text(
                                      " · $timeAgo",
                                      style: TextStyle(
                                        color: isUnreadForMe ? c5CreamGreen : c4LightSage,
                                        fontWeight: isUnreadForMe ? FontWeight.bold : FontWeight.normal,
                                      )
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isUnreadForMe) ...[
                          const SizedBox(width: 12),
                          // The Instagram-style glowing dot
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: c3MediumSage,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: c3MediumSage.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  )
                                ]
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
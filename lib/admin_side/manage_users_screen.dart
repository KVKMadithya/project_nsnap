import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final String _currentAdminId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- DATABASE ACTIONS ---

  Future<void> _toggleAdminRole(String targetUid, String currentRole) async {
    String newRole = currentRole == 'admin' ? 'user' : 'admin';
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
      'role': newRole,
    });
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newRole == 'admin' ? "Promoted to Admin" : "Demoted to User"),
      backgroundColor: c3MediumSage,
    ));
  }

  Future<void> _banUser(String targetUid) async {
    await FirebaseFirestore.instance.collection('users').doc(targetUid).delete();
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("User has been banned and removed."),
      backgroundColor: Colors.redAccent.shade400,
    ));
  }

  // --- NEW: SECURE PASSWORD MANAGEMENT ---
  Future<void> _sendPasswordReset(String email) async {
    if (email.isEmpty || email == "No Email Registered") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Cannot send reset: No valid email found."),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Password reset email sent to $email"),
        backgroundColor: c3MediumSage,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error sending reset email: $e"),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  // --- INTERACTIVE BOTTOM SHEET (USER DETAILS) ---

  void _showUserDetailsSheet(Map<String, dynamic> user, String targetUid) {
    String name = user['username'] ?? "No Name";
    String email = user['email'] ?? "No Email Registered";
    String pic = user['profilePicUrl'] ?? "";
    String role = user['role'] ?? "user";
    bool isMe = targetUid == _currentAdminId;

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: c1DeepForest,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              border: Border(top: BorderSide(color: c3MediumSage, width: 2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: c4LightSage, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),

                CircleAvatar(
                  radius: 50,
                  backgroundColor: c2DeepOlive,
                  backgroundImage: pic.isNotEmpty ? CachedNetworkImageProvider(pic) : null,
                  child: pic.isEmpty ? const Icon(Icons.person, size: 50, color: c4LightSage) : null,
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(color: c5CreamGreen, fontSize: 24, fontWeight: FontWeight.bold)),
                    if (role == 'admin') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                        child: const Text("ADMIN", style: TextStyle(color: c1DeepForest, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 24),

                // --- CREDENTIALS & SECURITY SECTION ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: c2DeepOlive.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, color: c4LightSage, size: 16),
                          SizedBox(width: 6),
                          Text("Security & Credentials", style: TextStyle(color: c4LightSage, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(color: c2DeepOlive, height: 20),
                      const Text("Registered Email:", style: TextStyle(color: c4LightSage, fontSize: 12)),
                      Text(email, style: const TextStyle(color: c5CreamGreen, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text("System ID (UID):", style: TextStyle(color: c4LightSage, fontSize: 12)),
                      Text(targetUid, style: const TextStyle(color: c4LightSage, fontSize: 12, fontFamily: 'monospace')),
                      const SizedBox(height: 16),

                      // Password Reset Button
                      if (!isMe)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                            label: const Text("Send Password Reset Email"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                              foregroundColor: Colors.blueAccent.shade100,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _sendPasswordReset(email),
                          ),
                        )
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // --- ACTION BUTTONS ---
                if (isMe)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20.0),
                    child: Text("🛡️ Super Admin Account (Protected)", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(role == 'admin' ? Icons.remove_moderator : Icons.add_moderator),
                      label: Text(role == 'admin' ? "Revoke Admin Privileges" : "Promote to Admin"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: role == 'admin' ? c2DeepOlive : c3MediumSage,
                        foregroundColor: role == 'admin' ? c5CreamGreen : c1DeepForest,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _toggleAdminRole(targetUid, role),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.gavel),
                      label: const Text("Ban & Delete User"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _banUser(targetUid),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]
              ],
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        title: const Text("User Management", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              style: const TextStyle(color: c5CreamGreen),
              decoration: InputDecoration(
                hintText: "Search by username...",
                hintStyle: TextStyle(color: c4LightSage.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.search, color: c3MediumSage),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').orderBy('username').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: c3MediumSage));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No users found.", style: TextStyle(color: c4LightSage)));
                }

                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String username = (data['username'] ?? "").toLowerCase();
                  return username.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemBuilder: (context, index) {
                    var user = filteredDocs[index].data() as Map<String, dynamic>;
                    String docId = filteredDocs[index].id;
                    String pic = user['profilePicUrl'] ?? "";
                    String role = user['role'] ?? "user";
                    String email = user['email'] ?? "No email";

                    bool isMe = docId == _currentAdminId;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                          color: isMe ? c2DeepOlive.withValues(alpha: 0.6) : c2DeepOlive.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isMe ? c3MediumSage : Colors.transparent)
                      ),
                      child: ListTile(
                        onTap: () => _showUserDetailsSheet(user, docId),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: c1DeepForest,
                          backgroundImage: pic.isNotEmpty ? CachedNetworkImageProvider(pic) : null,
                          child: pic.isEmpty ? const Icon(Icons.person, color: c4LightSage) : null,
                        ),
                        title: Row(
                          children: [
                            Text(user['username'] ?? "Unknown", style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
                            if (role == 'admin') ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.security, size: 14, color: Colors.amber),
                            ]
                          ],
                        ),
                        subtitle: Text(email, style: const TextStyle(color: c4LightSage, fontSize: 12)),
                        trailing: const Icon(Icons.more_vert, color: c4LightSage),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
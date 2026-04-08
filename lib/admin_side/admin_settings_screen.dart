import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart'; // Needed for Logout

const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _forbiddenWords = ['badword1', 'hate', 'spam', 'scam'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- TIME HELPER ---
  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    Duration diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "Just now";
  }

  // --- REPORT ACTIONS ---
  Future<void> _updateReportStatus(String reportId, String userId, String status, String message) async {
    // 1. Update the report in the global reports collection
    if (status == 'Resolved' || status == 'Rejected') {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).delete();
    } else {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({'status': status});
    }

    // 2. Notify the user using our custom Report Notification logic
    await FirebaseFirestore.instance.collection('users').doc(userId).collection('userNotifications').add({
      'type': 'report',
      'reportStatus': status,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Report marked as $status"),
            backgroundColor: status == 'Rejected' ? Colors.redAccent : c3MediumSage,
          )
      );
    }
  }

  // --- LOGOUT DIALOG ---
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c1DeepForest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c3MediumSage.withValues(alpha: 0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Admin Logout", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Are you really sure you want to securely log out of the Admin Console?", style: TextStyle(color: c4LightSage)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: c4LightSage))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().auth.signOut();
              await AuthService().googleSignIn.signOut();
            },
            child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      appBar: AppBar(
        backgroundColor: c1DeepForest,
        elevation: 0,
        title: const Text("Support & Security", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          // --- THE THREE DOTS MENU ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: c5CreamGreen, size: 28),
            color: c2DeepOlive,
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.redAccent, size: 20),
                        SizedBox(width: 10),
                        Text("Log out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                      ]
                  )
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: c5CreamGreen,
          indicatorWeight: 3,
          labelColor: c5CreamGreen,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelColor: c4LightSage.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: "AI Flags"),
            Tab(text: "User Reports"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAIModerationTab(),
          _buildReportCenterTab(),
        ],
      ),
    );
  }

  // --- TAB 1: AI MODERATION (Polished) ---
  Widget _buildAIModerationTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('comments').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: c3MediumSage));

        var flagged = snapshot.data!.docs.where((doc) {
          String text = (doc.data() as Map<String, dynamic>)['comment']?.toString().toLowerCase() ?? "";
          return _forbiddenWords.any((word) => text.contains(word));
        }).toList();

        if (flagged.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 60, color: c3MediumSage.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text("System Secure. No AI flags detected.", style: TextStyle(color: c4LightSage, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 40),
          itemCount: flagged.length,
          itemBuilder: (context, index) => _buildCommentCard(flagged[index]),
        );
      },
    );
  }

  Widget _buildCommentCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: c2DeepOlive.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
        ),
        title: Text("@${data['username']}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text('"${data['comment']}"', style: const TextStyle(color: c5CreamGreen, fontStyle: FontStyle.italic)),
        ),
        trailing: IconButton(
            icon: const Icon(Icons.delete_forever, color: c4LightSage),
            onPressed: () {
              // Delete comment logic here
              doc.reference.delete();
            }
        ),
      ),
    );
  }

  // --- TAB 2: REPORT CENTER (Ticketing System) ---
  Widget _buildReportCenterTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: c3MediumSage));

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 60, color: c3MediumSage.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text("Inbox Zero! No active reports.", style: TextStyle(color: c4LightSage, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 40),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var report = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String id = snapshot.data!.docs[index].id;
            String status = report['status'] ?? 'New';
            String timeAgo = _getTimeAgo(report['createdAt'] as Timestamp?);

            // Dynamic Status Styling
            Color statusColor = Colors.blueAccent;
            IconData statusIcon = Icons.mark_email_unread_outlined;
            if (status == 'Pending') {
              statusColor = Colors.orange;
              statusIcon = Icons.hourglass_empty;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: c2DeepOlive.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(statusIcon, color: statusColor),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Ticket from @${report['username']}", style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(timeAgo, style: const TextStyle(color: c4LightSage, fontSize: 12)),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    report['description'] ?? "Support Request",
                    style: const TextStyle(color: c4LightSage),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: c1DeepForest, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_ios, color: c3MediumSage, size: 16),
                ),
                onTap: () => _showReportDialog(id, report, statusColor),
              ),
            );
          },
        );
      },
    );
  }

  // --- REPORT MANAGEMENT MODAL ---
  void _showReportDialog(String id, Map<String, dynamic> report, Color themeColor) {
    String status = report['status'] ?? 'New';
    String userId = report['userId'];
    String timeAgo = _getTimeAgo(report['createdAt'] as Timestamp?);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c1DeepForest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: themeColor.withValues(alpha: 0.5), width: 2),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(status.toUpperCase(), style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Text(timeAgo, style: const TextStyle(color: c4LightSage, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            const Text("User Report", style: TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c2DeepOlive.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('"${report['description']}"', style: const TextStyle(color: c4LightSage, fontSize: 14, height: 1.4)),
        ),
        actionsPadding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => _updateReportStatus(id, userId, 'Rejected', "Your report was reviewed: No violation found. Dismissed."),
                child: const Text("Dismiss", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
              if (status == 'New')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => _updateReportStatus(id, userId, 'Pending', "An admin is currently reviewing your report. Stand by."),
                  child: const Text("Mark Pending", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              if (status == 'Pending')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: c3MediumSage, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => _updateReportStatus(id, userId, 'Resolved', "Great news! Your reported issue has been officially resolved."),
                  child: const Text("Mark Resolved", style: TextStyle(color: c1DeepForest, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
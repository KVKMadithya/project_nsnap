import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../posting/post_detail_screen.dart';

const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ViewProfileScreen extends StatelessWidget {
  final String targetUserId;
  const ViewProfileScreen({super.key, required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: c1DeepForest,
        appBar: AppBar(
          backgroundColor: c1DeepForest,
          iconTheme: const IconThemeData(color: c5CreamGreen),
          title: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(targetUserId).snapshots(),
              builder: (context, snapshot) {
                String username = "Loading...";
                if (snapshot.hasData && snapshot.data!.exists) {
                  username = snapshot.data!.get('username') ?? "User";
                }
                return Text(username, style: const TextStyle(color: c5CreamGreen, fontWeight: FontWeight.bold));
              }
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(targetUserId).snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

              return Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: c2DeepOlive,
                    backgroundImage: userData['profilePicUrl'] != null ? NetworkImage(userData['profilePicUrl']) : null,
                    child: userData['profilePicUrl'] == null ? const Icon(Icons.person, size: 40, color: c4LightSage) : null,
                  ),
                  const SizedBox(height: 12),
                  Text(userData['name'] ?? "", style: const TextStyle(color: c5CreamGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(userData['bio'] ?? "", style: const TextStyle(color: c4LightSage)),
                  const SizedBox(height: 20),

                  // We can add the Follow button logic here later!
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: c3MediumSage, foregroundColor: c1DeepForest),
                      onPressed: () {},
                      child: const Text("Follow")
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: c2DeepOlive),

                  // Show their posts
                  Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: targetUserId).orderBy('createdAt', descending: true).snapshots(),
                          builder: (context, postSnapshot) {
                            if (!postSnapshot.hasData) return const SizedBox();
                            return GridView.builder(
                              padding: const EdgeInsets.all(2),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                              itemCount: postSnapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                var post = postSnapshot.data!.docs[index].data() as Map<String, dynamic>;
                                return GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postData: post))),
                                  child: Container(
                                    color: c2DeepOlive,
                                    child: post['type'] == 'video'
                                        ? const Icon(Icons.play_circle_fill, color: c4LightSage)
                                        : Image.network(post['thumbnailUrl'] ?? '', fit: BoxFit.cover),
                                  ),
                                );
                              },
                            );
                          }
                      )
                  )
                ],
              );
            }
        )
    );
  }
}
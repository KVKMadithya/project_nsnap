import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <--- NEW IMPORT
import '../posting/post_detail_screen.dart';
import '../ar_features/ar_map_screen.dart';

// Palette
const Color c1DeepForest = Color(0xFF0F2A1D);
const Color c2DeepOlive = Color(0xFF375534);
const Color c3MediumSage = Color(0xFF6B9071);
const Color c4LightSage = Color(0xFFAEC3B0);
const Color c5CreamGreen = Color(0xFFE3EED4);

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";
  String _selectedCategory = "All";
  final List<String> _categories = ["All", "Landscape", "Portrait", "Nature", "Model"];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c1DeepForest,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ARMapScreen()),
            );
          },
          backgroundColor: c3MediumSage,
          foregroundColor: c1DeepForest,
          elevation: 10,
          icon: const Icon(Icons.explore_outlined),
          label: const Text("Open AR Map", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // 1. THE DYNAMIC SEARCH BAR
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: c2DeepOlive.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: c5CreamGreen),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search posts, captions, or users...",
                    hintStyle: const TextStyle(color: c4LightSage),
                    prefixIcon: const Icon(Icons.search, color: c4LightSage),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: c4LightSage),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                ),
              ),
            ),

            // 2. THE HORIZONTAL CATEGORY FILTERS
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  String category = _categories[index];
                  bool isSelected = _selectedCategory == category;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      decoration: BoxDecoration(
                        color: isSelected ? c3MediumSage : c2DeepOlive.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? c5CreamGreen : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? c1DeepForest : c4LightSage,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // 3. THE SMART FILTERED GRID (With Caching!)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: c3MediumSage));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No posts found", style: TextStyle(color: c4LightSage)));
                  }

                  var filteredDocs = snapshot.data!.docs.where((doc) {
                    var post = doc.data() as Map<String, dynamic>;
                    String caption = (post['caption'] ?? "").toString().toLowerCase();
                    String username = (post['username'] ?? "").toString().toLowerCase();
                    List<dynamic> postCategories = post['categories'] ?? [];

                    bool matchesCategory = true;
                    if (_selectedCategory != "All") {
                      matchesCategory = postCategories.contains(_selectedCategory);
                    }

                    bool matchesSearch = true;
                    if (_searchQuery.isNotEmpty) {
                      matchesSearch = caption.contains(_searchQuery) || username.contains(_searchQuery);
                    }

                    return matchesCategory && matchesSearch;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                        child: Text("No results for '$_searchQuery' \nin $_selectedCategory",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: c4LightSage, fontSize: 16)
                        )
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var post = filteredDocs[index].data() as Map<String, dynamic>;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (context) => PostDetailScreen(postData: post)
                          ));
                        },
                        child: Container(
                          color: c2DeepOlive,
                          // --- UPDATED: CACHED NETWORK IMAGE ---
                          child: post['thumbnailUrl'] != null
                              ? CachedNetworkImage(
                            imageUrl: post['thumbnailUrl'],
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c3MediumSage,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image,
                              color: c4LightSage,
                            ),
                            fit: BoxFit.cover,
                            memCacheHeight: 400, // Keeps it light on memory
                          )
                              : const Icon(Icons.image, color: c4LightSage),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
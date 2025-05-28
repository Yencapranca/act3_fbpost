import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facebook Post App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[200],
      ),
      home: FacebookHomePage(),
    );
  }
}

class FacebookHomePage extends StatefulWidget {
  @override
  _FacebookHomePageState createState() => _FacebookHomePageState();
}

class _FacebookHomePageState extends State<FacebookHomePage> {
  final _logger = Logger('FacebookHomePage');
  List<dynamic> posts = [];

  @override
  void initState() {
    super.initState();
    _getPosts();
  }

  Future<void> _getPosts() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/posts'),
      );

      if (response.statusCode == 200) {
        setState(() {
          posts = json.decode(response.body);
        });
      } else {
        _logger.severe(
          'Failed to load posts. Status Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.severe('Error fetching posts: $e');
    }
  }

  void _showPostDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PostCreationDialog(
        onPostCreated: _getPosts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facebook Replication'),
        centerTitle: false,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _getPosts,
        child: ListView(
          children: [
            // Post creation at the top
            PostCreationCard(onPostPressed: _showPostDialog),
            
            // Display all posts
            if (posts.isEmpty)
              const Center(child: Text('No posts yet. Create one!'))
            else
              ...posts.reversed.map((post) => FacebookPostCard(
                    post: post,
                    key: ValueKey(post['_id']),
                  )),
          ],
        ),
      ),
    );
  }
}

class PostCreationCard extends StatelessWidget {
  final Function(BuildContext) onPostPressed;

  const PostCreationCard({Key? key, required this.onPostPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                const UserAvatar(
                  imagePath: "assets/images/wonyoung1.jpg",
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onPostPressed(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "What's on your mind?",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => onPostPressed(context),
                  icon: const Icon(Icons.photo_library, color: Colors.green),
                  label: const Text('Photo'),
                ),
                TextButton.icon(
                  onPressed: () => onPostPressed(context),
                  icon: const Icon(Icons.video_library, color: Colors.red),
                  label: const Text('Video'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PostCreationDialog extends StatefulWidget {
  final Function onPostCreated;

  const PostCreationDialog({Key? key, required this.onPostCreated})
      : super(key: key);

  @override
  _PostCreationDialogState createState() => _PostCreationDialogState();
}

class _PostCreationDialogState extends State<PostCreationDialog> {
  final TextEditingController _captionController = TextEditingController();
  File? _image;
  final _logger = Logger('PostCreationDialog');

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _createPost() async {
    if (_image == null && _captionController.text.isEmpty) {
      _logger.warning('Both image and caption are missing');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a caption or image')),
      );
      return;
    }

    if (_image == null) {
      // Create text-only post
      try {
        final response = await http.post(
          Uri.parse('http://localhost:3000/api/posts'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'subtext': _captionController.text}),
        );

        if (response.statusCode == 200) {
          widget.onPostCreated();
          Navigator.pop(context);
        } else {
          _logger.severe(
            'Failed to create post. Status Code: ${response.statusCode}',
          );
        }
      } catch (e) {
        _logger.severe('Error during post creation: $e');
      }
    } else {
      // Create post with image
      final uri = Uri.parse('http://localhost:3000/api/posts');
      final request = http.MultipartRequest('POST', uri);

      request.fields['subtext'] = _captionController.text;
      if (_image != null) {
        final imageFile =
            await http.MultipartFile.fromPath('image', _image!.path);
        request.files.add(imageFile);
      }

      try {
        final response = await request.send();
        if (response.statusCode == 200) {
          widget.onPostCreated();
          Navigator.pop(context);
        } else {
          _logger.severe(
            'Failed to create post. Status Code: ${response.statusCode}',
          );
        }
      } catch (e) {
        _logger.severe('Error during post creation: $e');
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Post',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const ListTile(
              leading: UserAvatar(
                imagePath: "assets/images/wonyoung1.jpg",
                radius: 20,
              ),
              title: Text(
                'Yen Capranca',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Stack(
                  children: [
                    Image.file(_image!),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          color: Colors.white,
                          onPressed: () {
                            setState(() {
                              _image = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library, color: Colors.green),
                  onPressed: _pickImage,
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _createPost,
                  child: const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FacebookPostCard extends StatelessWidget {
  final dynamic post;

  const FacebookPostCard({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Profile Section
          ListTile(
            leading: const UserAvatar(
              imagePath: "assets/images/wonyoung1.jpg",
              radius: 20,
            ),
            title: const Text(
              'Yen Capranca',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(post['created_at'] ?? 'Just now'),
            trailing: const Icon(Icons.more_horiz),
          ),

          // Post Content
          if (post['subtext'] != null && post['subtext'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(post['subtext']),
            ),

          // Post Image
          if (post['image'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  'http://localhost:3000/uploads/${post['image']}',
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported,
                            size: 50, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Like and Comment Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.thumb_up, color: Colors.blue, size: 18),
                const SizedBox(width: 8.0),
                const Text("100 Likes"),
                const Spacer(),
                Text("30 Comments • 20 Shares"),
              ],
            ),
          ),

          const Divider(height: 1),

          // Actions (Like, Comment, Share)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const LikeButton(),
              const CommentButton(),
              _actionButton(Icons.share, "Share"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label) {
    return TextButton.icon(
      onPressed: () {},
      icon: Icon(icon, color: Colors.grey),
      label: Text(label, style: const TextStyle(color: Colors.grey)),
    );
  }
}

// User Profile Avatar Widget
class UserAvatar extends StatelessWidget {
  final String imagePath;
  final double radius;

  const UserAvatar({
    Key? key,
    required this.imagePath,
    this.radius = 25,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      backgroundImage: AssetImage(imagePath),
    );
  }
}

// Like Button Widget
class LikeButton extends StatefulWidget {
  const LikeButton({Key? key}) : super(key: key);

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool isLiked = false;
  int likeCount = 177;

  void toggleLike() {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: toggleLike,
      icon: Icon(
        isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
        color: isLiked ? Colors.blue : Colors.grey,
      ),
      label: Text(
        "Like",
        style: TextStyle(color: isLiked ? Colors.blue : Colors.grey),
      ),
    );
  }
}

// Comment Button Widget
class CommentButton extends StatelessWidget {
  const CommentButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _actionButton(Icons.mode_comment_outlined, "Comment");
  }
}

Widget _actionButton(IconData icon, String label) {
  return TextButton.icon(
    onPressed: () {},
    icon: Icon(icon, color: Colors.grey),
    label: Text(label, style: const TextStyle(color: Colors.grey)),
  );
}
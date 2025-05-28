import 'package:flutter/material.dart';
import '../widgets/newsfeed.dart';
import 'facebookpost.dart';

class NewsFeedScreen extends StatelessWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          // Facebook post creation and feed
          SizedBox(
            height: MediaQuery.of(context).size.height,
            child: const FacebookHomePage(),
          ),
          
          // Your existing news feed cards
          const NewsFeedCard(userName: 'Yen Capranca', postContent: 'Wonyoung is Pretty'),
          const NewsFeedCard(userName: 'Jang Wonyoung', postContent: 'Yen is Handsome'),
          const NewsFeedCard(userName: 'Delulu Momments', postContent: 'Delulu Momments'),
        ],
      ),
    );
  }
}
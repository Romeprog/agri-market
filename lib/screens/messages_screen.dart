import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';

enum MessagingRole { buyer, seller, rider }

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key, this.role = MessagingRole.buyer});

  final MessagingRole role;

  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

  String get _subtitle => switch (role) {
    MessagingRole.buyer => 'Chat with sellers about your orders',
    MessagingRole.seller => 'Chat with your buyers',
    MessagingRole.rider => 'Chat with buyers and sellers about deliveries',
  };

  String get _emptyStateBody => switch (role) {
    MessagingRole.buyer =>
      'Message a seller from a product page to start chatting',
    MessagingRole.seller => 'Conversations with your buyers will show up here',
    MessagingRole.rider =>
      'Conversations about your deliveries will show up here',
  };

  String _otherUserId(List<dynamic> participants, String myUid) {
    return participants.cast<String>().firstWhere(
      (id) => id != myUid,
      orElse: () => myUid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(decoration: BoxDecoration(color: _seedColor)),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Messages',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                _subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _bgColor.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
      body: user == null
          ? Center(child: Text('Please sign in.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: user.uid)
                  .orderBy('lastMessageAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _seedColor),
                  );
                }
                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 44,
                            color: _seedColor.withValues(alpha: 0.4),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No conversations yet',
                            style: GoogleFonts.fraunces(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _seedColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _emptyStateBody,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final participants = List<dynamic>.from(
                      data['participants'] as List? ?? [],
                    );
                    final otherUserId = _otherUserId(participants, user.uid);
                    final lastMessage = data['lastMessage'] as String? ?? '';
                    final participantNames =
                        data['participantNames'] as Map<String, dynamic>? ?? {};
                    final otherName =
                        participantNames[otherUserId] as String? ??
                        'AgriMarket User';
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _seedColor.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                otherUserId: otherUserId,
                                otherUserName: otherName,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: _seedColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.person_outline,
                                    color: _seedColor,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        otherName,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
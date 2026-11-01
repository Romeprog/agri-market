import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.sharedProduct,
  });

  final String otherUserId;
  final String otherUserName;
  final Product? sharedProduct;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

  final _messageController = TextEditingController();

  Product? _pendingProduct;

  @override
  void initState() {
    super.initState();
    _pendingProduct = widget.sharedProduct;
    _markAsRead();
  }

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  String get _chatId {
    final ids = [_currentUid!, widget.otherUserId]..sort();
    return ids.join('_');
  }

  Future<void> _markAsRead() async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
        'unreadBy': FieldValue.arrayRemove([uid]),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<String> _resolveMyName(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['name'] as String? ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'AgriMarket User';
  }

  Future<void> _sendProductCard(Product product) async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      final myName = await _resolveMyName(uid);
      final chatDoc = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId);

      await chatDoc.set({
        'participants': ([uid, widget.otherUserId]..sort()),
        'participantNames': {
          uid: myName,
          widget.otherUserId: widget.otherUserName,
        },
        'lastMessage': '📦 ${product.name}',
        'lastMessageAt': Timestamp.now(),
        'unreadBy': FieldValue.arrayUnion([widget.otherUserId]),
      }, SetOptions(merge: true));

      await chatDoc.collection('messages').add({
        'senderId': uid,
        'type': 'product',
        'productId': product.id,
        'productName': product.name,
        'productImage': product.image,
        'productPrice': product.price,
        'productUnit': product.unit,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not share that product. Please try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openSharedProduct(
    BuildContext context,
    String? productId,
  ) async {
    if (productId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .get();
    if (!context.mounted) return;
    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This product is no longer available.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailScreen(product: Product.fromFirestore(doc)),
      ),
    );
  }

  Future<void> _openProductPicker() async {
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductPickerSheet(
        sellerId: widget.otherUserId,
        seedColor: _seedColor,
      ),
    );

    if (selected != null) {
      setState(() => _pendingProduct = selected);
    }
  }

  void _removePendingProduct() {
    setState(() => _pendingProduct = null);
  }

  Future<void> _handleSend() async {
    final uid = _currentUid;
    if (uid == null) return;

    if (_pendingProduct != null) {
      final product = _pendingProduct!;
      setState(() => _pendingProduct = null);
      await _sendProductCard(product);
    }

    await _sendMessage();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final uid = _currentUid;
    if (text.isEmpty || uid == null) return;

    _messageController.clear();

    try {
      final myName = await _resolveMyName(uid);
      final chatDoc = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId);

      await chatDoc.set({
        'participants': ([uid, widget.otherUserId]..sort()),
        'participantNames': {
          uid: myName,
          widget.otherUserId: widget.otherUserName,
        },
        'lastMessage': text,
        'lastMessageAt': Timestamp.now(),
        'unreadBy': FieldValue.arrayUnion([widget.otherUserId]),
      }, SetOptions(merge: true));

      await chatDoc.collection('messages').add({
        'senderId': uid,
        'text': text,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      if (!mounted) return;
      _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message not sent. Check your connection and try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 4,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(decoration: BoxDecoration(color: _seedColor)),
          ),
          leading: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back, color: _bgColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          title: Text(
            widget.otherUserName,
            style: GoogleFonts.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _bgColor,
            ),
          ),
        ),
      ),
      body: uid == null
          ? Center(child: Text('Please sign in to chat.'))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(_chatId)
                          .collection('messages')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Could not load messages. Check your '
                                'connection and try again.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(color: _seedColor),
                          );
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _markAsRead(),
                          );
                        }

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
                                    'Say hello!',
                                    style: GoogleFonts.fraunces(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _seedColor,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Start the conversation with ${widget.otherUserName}',
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

                        return ListView.builder(
                          reverse: true,
                          padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final isMine = data['senderId'] == uid;
                            final type = data['type'] as String? ?? 'text';

                            if (type == 'product') {
                              return _ProductMessageCard(
                                isMine: isMine,
                                seedColor: _seedColor,
                                productName:
                                    data['productName'] as String? ?? 'Product',
                                productImage:
                                    data['productImage'] as String? ?? '',
                                productPrice:
                                    (data['productPrice'] as num?)
                                        ?.toDouble() ??
                                    0,
                                productUnit:
                                    data['productUnit'] as String? ?? '',
                                onTap: () => _openSharedProduct(
                                  context,
                                  data['productId'] as String?,
                                ),
                              );
                            }
                            final text = data['text'] as String? ?? '';
                            return Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.72,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine ? _seedColor : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(14),
                                    topRight: Radius.circular(14),
                                    bottomLeft: Radius.circular(
                                      isMine ? 14 : 2,
                                    ),
                                    bottomRight: Radius.circular(
                                      isMine ? 2 : 14,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  text,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isMine
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_pendingProduct != null)
                            _PendingProductPreview(
                              product: _pendingProduct!,
                              seedColor: _seedColor,
                              onRemove: _removePendingProduct,
                            ),
                          Row(
                            children: [
                              Material(
                                color: _bgColor,
                                shape: CircleBorder(),
                                child: InkWell(
                                  customBorder: CircleBorder(),
                                  onTap: _openProductPicker,
                                  child: Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.add_circle_outline,
                                      color: _seedColor,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 1,
                                  maxLines: 4,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: 'Type a message',
                                    hintStyle: GoogleFonts.inter(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: _bgColor,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) => _handleSend(),
                                ),
                              ),
                              SizedBox(width: 8),
                              Material(
                                color: _seedColor,
                                shape: CircleBorder(),
                                child: InkWell(
                                  customBorder: CircleBorder(),
                                  onTap: _handleSend,
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProductMessageCard extends StatelessWidget {
  const _ProductMessageCard({
    required this.isMine,
    required this.seedColor,
    required this.productName,
    required this.productImage,
    required this.productPrice,
    required this.productUnit,
    required this.onTap,
  });

  final bool isMine;
  final Color seedColor;
  final String productName;
  final String productImage;
  final double productPrice;
  final String productUnit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: seedColor.withValues(alpha: 0.08),
      child: Icon(Icons.image_not_supported_outlined, color: seedColor),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: 8),
          width: 210,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: seedColor.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 100,
                width: double.infinity,
                child: productImage.startsWith('http')
                    ? Image.network(
                        productImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => fallback,
                      )
                    : Image.asset(
                        productImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => fallback,
                      ),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₱${productPrice.toStringAsFixed(2)} · $productUnit',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: seedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingProductPreview extends StatelessWidget {
  const _PendingProductPreview({
    required this.product,
    required this.seedColor,
    required this.onRemove,
  });

  final Product product;
  final Color seedColor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: seedColor.withValues(alpha: 0.08),
      child: Icon(product.icon, color: seedColor, size: 18),
    );

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: seedColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: seedColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 42,
              height: 42,
              child: product.image.startsWith('http')
                  ? Image.network(
                      product.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    )
                  : Image.asset(
                      product.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '₱${product.price.toStringAsFixed(2)} · ${product.unit}',
                  style: GoogleFonts.inter(
                    color: seedColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18),
            onPressed: onRemove,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({required this.sellerId, required this.seedColor});

  final String sellerId;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Send a product',
                    style: GoogleFonts.fraunces(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: seedColor,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('farmerId', isEqualTo: sellerId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: seedColor),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No products to show yet.',
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = Product.fromFirestore(docs[index]);
                      final fallback = Container(
                        color: seedColor.withValues(alpha: 0.08),
                        child: Icon(product.icon, color: seedColor, size: 20),
                      );
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: product.image.startsWith('http')
                                ? Image.network(
                                    product.image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => fallback,
                                  )
                                : Image.asset(
                                    product.image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => fallback,
                                  ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '₱${product.price.toStringAsFixed(2)} · ${product.unit}',
                          style: GoogleFonts.inter(
                            color: seedColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, product),
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
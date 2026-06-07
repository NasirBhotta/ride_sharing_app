import 'package:cloud_firestore/cloud_firestore.dart';

class RideMessage {
  RideMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.encryptedText,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderRole;
  final String encryptedText;
  final DateTime? createdAt;

  factory RideMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return RideMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? 'unknown',
      encryptedText: data['encryptedText'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

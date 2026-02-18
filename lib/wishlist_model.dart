import 'package:cloud_firestore/cloud_firestore.dart';

class Wishlist {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final List<String> productIds;
  final DateTime createdAt;

  Wishlist({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.productIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'description': description,
      'productIds': productIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Wishlist.fromMap(String id, Map<String, dynamic> map) {
    return Wishlist(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? 'New List',
      description: map['description'],
      productIds: List<String>.from(map['productIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
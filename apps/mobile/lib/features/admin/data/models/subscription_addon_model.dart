import 'package:flutter/material.dart';

class SubscriptionAddonModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final double gstRate;
  final String category; // 'seats', 'directory', 'notifications', 'supplies', 'hardware', 'support'
  final String period; // 'monthly', 'yearly', 'one_time'
  final List<String> features;
  final IconData icon;
  final bool isAvailable;

  const SubscriptionAddonModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.gstRate = 18.0,
    required this.category,
    this.period = 'monthly',
    this.features = const [],
    this.icon = Icons.extension_rounded,
    this.isAvailable = true,
  });

  SubscriptionAddonModel copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    double? gstRate,
    String? category,
    String? period,
    List<String>? features,
    IconData? icon,
    bool? isAvailable,
  }) {
    return SubscriptionAddonModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      gstRate: gstRate ?? this.gstRate,
      category: category ?? this.category,
      period: period ?? this.period,
      features: features ?? this.features,
      icon: icon ?? this.icon,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'name': title,
      'description': description,
      'price': price,
      'gstRate': gstRate,
      'category': category,
      'period': period,
      'features': features,
      'isAvailable': isAvailable,
      'isActive': isAvailable,
    };
  }

  factory SubscriptionAddonModel.fromMap(Map<String, dynamic> map, String id) {
    final cat = (map['category'] as String?)?.toLowerCase() ?? 'hardware';
    IconData icon = Icons.extension_rounded;
    if (cat.contains('printer') || cat == 'hardware') {
      icon = Icons.print_rounded;
    } else if (cat.contains('scanner')) {
      icon = Icons.qr_code_scanner_rounded;
    } else if (cat.contains('scale')) {
      icon = Icons.scale_rounded;
    } else if (cat.contains('supplies') || cat.contains('roll')) {
      icon = Icons.receipt_long_rounded;
    } else if (cat.contains('seat') || cat.contains('staff') || cat.contains('user')) {
      icon = Icons.person_add_alt_1_rounded;
    } else if (cat.contains('shop') || cat.contains('store') || cat.contains('directory')) {
      icon = Icons.storefront_rounded;
    } else if (cat.contains('whatsapp') || cat.contains('sms') || cat.contains('notif')) {
      icon = Icons.chat_bubble_outline_rounded;
    } else if (cat.contains('support') || cat.contains('vip')) {
      icon = Icons.verified_user_rounded;
    }

    final rawFeats = map['features'];
    List<String> features = [];
    if (rawFeats is List) {
      features = rawFeats.map((e) => e.toString()).toList();
    }

    final isAvail = map['isAvailable'] == true ||
        map['isActive'] == true ||
        (map['isAvailable'] == null && map['isActive'] == null);

    return SubscriptionAddonModel(
      id: map['id']?.toString() ?? id,
      title: map['title']?.toString() ?? map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 18.0,
      category: map['category']?.toString() ?? 'hardware',
      period: map['period']?.toString() ?? 'monthly',
      features: features,
      icon: icon,
      isAvailable: isAvail,
    );
  }
}

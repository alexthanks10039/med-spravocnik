import 'package:flutter/material.dart';

enum ContentType { disease, drug, calculator, article }

class MedicalItem {
  const MedicalItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.sections,
    this.badge,
    this.relatedIds = const [],
  });

  final String id;
  final ContentType type;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Map<String, String> sections;
  final String? badge;
  final List<String> relatedIds;
}

class MedicalCategory {
  const MedicalCategory(this.title, this.subtitle, this.icon, this.color);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

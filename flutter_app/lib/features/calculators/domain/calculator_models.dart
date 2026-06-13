import 'package:flutter/material.dart';

enum CalculatorCollection { all, popular, recent, favorites }

class CalculatorCategory {
  const CalculatorCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.searchTerms,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String searchTerms;
}

class CalculatorDefinition {
  const CalculatorDefinition({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.searchTerms,
    this.isPopular = false,
  });

  final String id;
  final String categoryId;
  final String title;
  final String subtitle;
  final IconData icon;
  final String searchTerms;
  final bool isPopular;
}

import 'package:flutter/material.dart';

import '../domain/calculator_models.dart';

const calculatorCategories = <CalculatorCategory>[
  CalculatorCategory(
    id: 'general-practice',
    title: 'Общая практика',
    subtitle: 'Антропометрия и базовая клиническая оценка',
    icon: Icons.medical_services_outlined,
    accent: Color(0xFF0B7C82),
    searchTerms: 'общая практика терапия bmi индекс массы тела',
  ),
  CalculatorCategory(
    id: 'cardiology',
    title: 'Кардиология',
    subtitle: 'Сердечно-сосудистый риск и гемодинамика',
    icon: Icons.favorite_outline_rounded,
    accent: Color(0xFFC34A5A),
    searchTerms: 'кардиология сердце давление риск сосуды',
  ),
  CalculatorCategory(
    id: 'neurology',
    title: 'Неврология',
    subtitle: 'Шкалы инсульта, сознания и когнитивной функции',
    icon: Icons.psychology_outlined,
    accent: Color(0xFF4968A9),
    searchTerms: 'неврология мозг инсульт сознание шкала',
  ),
  CalculatorCategory(
    id: 'gynecology',
    title: 'Гинекология',
    subtitle: 'Акушерские сроки и женское здоровье',
    icon: Icons.female_rounded,
    accent: Color(0xFFB34E7E),
    searchTerms: 'гинекология акушерство беременность женское здоровье',
  ),
  CalculatorCategory(
    id: 'pediatrics',
    title: 'Педиатрия',
    subtitle: 'Возрастные нормы, дозировки и развитие ребёнка',
    icon: Icons.child_care_outlined,
    accent: Color(0xFFE28A33),
    searchTerms: 'педиатрия дети ребенок возраст дозировка',
  ),
  CalculatorCategory(
    id: 'nephrology',
    title: 'Нефрология',
    subtitle: 'Функция почек, фильтрация и электролиты',
    icon: Icons.water_drop_outlined,
    accent: Color(0xFF1686A7),
    searchTerms: 'нефрология почки скф egfr креатинин',
  ),
  CalculatorCategory(
    id: 'pulmonology',
    title: 'Пульмонология',
    subtitle: 'Дыхательная функция и газовый состав крови',
    icon: Icons.air_rounded,
    accent: Color(0xFF238B73),
    searchTerms: 'пульмонология легкие дыхание газы крови',
  ),
  CalculatorCategory(
    id: 'endocrinology',
    title: 'Эндокринология',
    subtitle: 'Метаболизм, диабет и гормональная оценка',
    icon: Icons.hub_outlined,
    accent: Color(0xFF657C3C),
    searchTerms: 'эндокринология диабет гормоны метаболизм',
  ),
  CalculatorCategory(
    id: 'gastroenterology',
    title: 'Гастроэнтерология',
    subtitle: 'Печёночные шкалы и оценка ЖКТ',
    icon: Icons.monitor_heart_outlined,
    accent: Color(0xFF9B6B32),
    searchTerms: 'гастроэнтерология печень жкт желудок кишечник',
  ),
  CalculatorCategory(
    id: 'critical-care',
    title: 'Реаниматология',
    subtitle: 'Тяжесть состояния и интенсивная терапия',
    icon: Icons.emergency_outlined,
    accent: Color(0xFFB6473E),
    searchTerms: 'реанимация интенсивная терапия критическое состояние',
  ),
];

const calculatorDefinitions = <CalculatorDefinition>[
  CalculatorDefinition(
    id: 'bmi',
    categoryId: 'general-practice',
    title: 'Индекс массы тела',
    subtitle: 'BMI · оценка соотношения веса и роста',
    icon: Icons.straighten_rounded,
    searchTerms: 'индекс массы тела bmi вес рост ожирение',
    isPopular: true,
  ),
  CalculatorDefinition(
    id: 'egfr-ckd-epi-2021',
    categoryId: 'nephrology',
    title: 'eGFR CKD-EPI 2021',
    subtitle: 'Расчётная скорость клубочковой фильтрации',
    icon: Icons.water_drop_outlined,
    searchTerms: 'egfr ckd epi функция почек креатинин скф',
    isPopular: true,
  ),
];

CalculatorCategory? calculatorCategoryById(String id) {
  for (final category in calculatorCategories) {
    if (category.id == id) return category;
  }
  return null;
}

List<CalculatorDefinition> calculatorsForCategory(String categoryId) {
  return calculatorDefinitions
      .where((calculator) => calculator.categoryId == categoryId)
      .toList(growable: false);
}

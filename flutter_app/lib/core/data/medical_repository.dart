import 'package:flutter/material.dart';

import '../models/medical_content.dart';

abstract interface class MedicalRepository {
  Future<List<MedicalItem>> search(String query);
  Future<List<MedicalItem>> byType(ContentType type);
  Future<MedicalItem?> getById(String id);
  Future<List<MedicalItem>> recent();
}

class OfflineMedicalRepository implements MedicalRepository {
  static const _items = <MedicalItem>[
    MedicalItem(
      id: 'hypertension',
      type: ContentType.disease,
      title: 'Артериальная гипертензия',
      subtitle: 'Диагностика, стратификация риска и ведение',
      category: 'Кардиология',
      icon: Icons.favorite_outline,
      badge: 'МКБ-10 I10',
      relatedIds: ['amlodipine', 'cv-risk'],
      sections: {
        'Кратко':
            'Стойкое повышение артериального давления. Диагноз требует корректного повторного измерения и оценки сердечно-сосудистого риска.',
        'Диагностика':
            'Подтвердите повышение АД офисными и, при возможности, домашними или суточными измерениями. Оцените поражение органов-мишеней.',
        'Красные флаги':
            'АД ≥180/120 мм рт. ст. с острым поражением органов-мишеней требует неотложной оценки.',
        'Лечение':
            'Модификация образа жизни и персонализированная антигипертензивная терапия с контролем переносимости.',
      },
    ),
    MedicalItem(
      id: 'pneumonia',
      type: ContentType.disease,
      title: 'Внебольничная пневмония',
      subtitle: 'Первичная оценка и выбор тактики',
      category: 'Пульмонология',
      icon: Icons.air,
      badge: 'МКБ-10 J18',
      relatedIds: ['amoxicillin'],
      sections: {
        'Кратко':
            'Острая инфекция лёгочной ткани, возникшая вне стационара или в первые 48 часов госпитализации.',
        'Клиника':
            'Лихорадка, кашель, одышка, плевральная боль и локальные аускультативные признаки.',
        'Диагностика':
            'Оценка витальных функций, сатурации и тяжести. Визуализация используется для подтверждения при доступности.',
        'Тактика':
            'Место лечения и антибактериальная терапия зависят от тяжести, коморбидности и локальной резистентности.',
      },
    ),
    MedicalItem(
      id: 'amlodipine',
      type: ContentType.drug,
      title: 'Амлодипин',
      subtitle: 'Блокатор медленных кальциевых каналов',
      category: 'Сердечно-сосудистые',
      icon: Icons.medication_outlined,
      badge: 'Rx',
      relatedIds: ['hypertension'],
      sections: {
        'Показания': 'Артериальная гипертензия и стабильная стенокардия.',
        'Дозирование':
            'Обычно 5 мг 1 раз в сутки; диапазон 2,5–10 мг с учётом ответа и переносимости.',
        'Противопоказания':
            'Гиперчувствительность; осторожность при выраженной гипотензии и тяжёлом аортальном стенозе.',
        'Нежелательные реакции':
            'Периферические отёки, головная боль, приливы, сердцебиение.',
      },
    ),
    MedicalItem(
      id: 'amoxicillin',
      type: ContentType.drug,
      title: 'Амоксициллин',
      subtitle: 'Аминопенициллин широкого спектра',
      category: 'Антибактериальные',
      icon: Icons.medication_outlined,
      badge: 'Rx',
      relatedIds: ['pneumonia'],
      sections: {
        'Показания':
            'Чувствительные бактериальные инфекции дыхательных путей, ЛОР-органов и мочевых путей.',
        'Дозирование':
            'Доза зависит от инфекции, возраста, массы тела и функции почек. Проверяйте локальные рекомендации.',
        'Коррекция дозы':
            'При снижении функции почек может потребоваться увеличение интервала между приёмами.',
        'Взаимодействия':
            'Учитывайте антикоагулянты, аллопуринол и другие потенциально значимые комбинации.',
      },
    ),
    MedicalItem(
      id: 'chest-pain-assessment',
      type: ContentType.article,
      title: 'Первичная оценка боли в груди',
      subtitle: 'Короткий алгоритм для первичного контакта',
      category: 'Неотложная помощь',
      icon: Icons.alt_route_rounded,
      badge: 'Алгоритм',
      relatedIds: ['hypertension', 'cv-risk'],
      sections: {
        'Первичная оценка':
            'Оцените витальные функции, характеристики боли и признаки гемодинамической нестабильности.',
        'Красные флаги':
            'Синкопе, гипотензия, выраженная одышка, неврологический дефицит или сохраняющаяся интенсивная боль требуют срочной маршрутизации.',
        'Следующий шаг':
            'Тактика определяется вероятностью острого коронарного синдрома и альтернативных жизнеугрожающих причин.',
      },
    ),
    MedicalItem(
      id: 'antibiotic-stewardship',
      type: ContentType.article,
      title: 'Рациональная антибиотикотерапия',
      subtitle: 'Практические принципы выбора и пересмотра терапии',
      category: 'Клинические рекомендации',
      icon: Icons.alt_route_rounded,
      badge: 'Памятка',
      relatedIds: ['amoxicillin', 'pneumonia'],
      sections: {
        'До назначения':
            'Уточните предполагаемый очаг, тяжесть инфекции, аллергологический анамнез и локальные данные резистентности.',
        'Контроль':
            'Пересматривайте необходимость, спектр и путь введения антибиотика после получения новых клинических данных.',
        'Безопасность':
            'Учитывайте функцию почек, лекарственные взаимодействия и риск нежелательных реакций.',
      },
    ),
    MedicalItem(
      id: 'cv-risk',
      type: ContentType.calculator,
      title: 'Сердечно-сосудистый риск',
      subtitle: 'Оценка 10-летнего риска',
      category: 'Кардиология',
      icon: Icons.monitor_heart_outlined,
      sections: {
        'Назначение':
            'Поддержка совместного решения о профилактической стратегии.',
        'Важно': 'Результат не заменяет клиническую оценку.',
      },
    ),
    MedicalItem(
      id: 'egfr',
      type: ContentType.calculator,
      title: 'eGFR CKD-EPI 2021',
      subtitle: 'Расчёт скорости клубочковой фильтрации',
      category: 'Нефрология',
      icon: Icons.water_drop_outlined,
      sections: {
        'Назначение': 'Оценка функции почек у взрослых.',
        'Поля': 'Возраст, пол и креатинин сыворотки.',
      },
    ),
    MedicalItem(
      id: 'bmi',
      type: ContentType.calculator,
      title: 'Индекс массы тела',
      subtitle: 'BMI по росту и массе тела',
      category: 'Общие',
      icon: Icons.straighten,
      sections: {
        'Назначение': 'Быстрая скрининговая оценка соотношения массы и роста.',
        'Ограничения': 'Не отражает состав тела и распределение жировой ткани.',
      },
    ),
  ];

  @override
  Future<List<MedicalItem>> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _items;
    return _items
        .where(
          (item) => '${item.title} ${item.subtitle} ${item.category}'
              .toLowerCase()
              .contains(normalized),
        )
        .toList();
  }

  @override
  Future<List<MedicalItem>> byType(ContentType type) async =>
      _items.where((item) => item.type == type).toList();

  @override
  Future<MedicalItem?> getById(String id) async {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<MedicalItem>> recent() async => _items.take(4).toList();
}

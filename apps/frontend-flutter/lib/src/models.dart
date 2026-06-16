class CalculatorSummary {
  const CalculatorSummary({
    required this.toolId,
    required this.name,
    required this.purpose,
    required this.specialties,
    required this.outputType,
  });

  final String toolId;
  final String name;
  final String purpose;
  final List<String> specialties;
  final String outputType;

  factory CalculatorSummary.fromJson(Map<String, dynamic> json) {
    return CalculatorSummary(
      toolId: json['tool_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      specialties: _stringList(json['specialties']),
      outputType: json['output_type']?.toString() ?? '',
    );
  }
}

class CalculatorField {
  const CalculatorField({
    required this.id,
    required this.label,
    required this.description,
    required this.type,
    required this.required,
    required this.defaultValue,
    required this.unit,
    required this.minimum,
    required this.maximum,
    required this.options,
  });

  final String id;
  final String label;
  final String description;
  final String type;
  final bool required;
  final Object? defaultValue;
  final String unit;
  final num? minimum;
  final num? maximum;
  final List<Object?> options;

  factory CalculatorField.fromJson(Map<String, dynamic> json) {
    return CalculatorField(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'string',
      required: json['required'] == true,
      defaultValue: json['default'],
      unit: json['unit']?.toString() ?? '',
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      options: json['options'] is List
          ? List<Object?>.from(json['options'] as List)
          : const [],
    );
  }
}

class CalculationResult {
  const CalculationResult({
    required this.success,
    required this.scoreName,
    required this.value,
    required this.unit,
    required this.summary,
    required this.severity,
    required this.recommendation,
    required this.components,
    required this.error,
  });

  final bool success;
  final String scoreName;
  final Object? value;
  final String unit;
  final String summary;
  final String severity;
  final String recommendation;
  final Map<String, dynamic> components;
  final String error;

  factory CalculationResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] is Map<String, dynamic>
        ? json['result'] as Map<String, dynamic>
        : <String, dynamic>{};
    final interpretation = result['interpretation'] is Map<String, dynamic>
        ? result['interpretation'] as Map<String, dynamic>
        : <String, dynamic>{};
    return CalculationResult(
      success: json['success'] == true,
      scoreName: result['score_name']?.toString() ?? '',
      value: result['value'],
      unit: result['unit']?.toString() ?? '',
      summary: interpretation['summary']?.toString() ?? '',
      severity: interpretation['severity']?.toString() ?? '',
      recommendation: interpretation['recommendation']?.toString() ?? '',
      components: result['component_scores'] is Map<String, dynamic>
          ? result['component_scores'] as Map<String, dynamic>
          : const {},
      error: json['error']?.toString() ?? '',
    );
  }
}

class KnowledgeEvidence {
  const KnowledgeEvidence({
    required this.docId,
    required this.title,
    required this.sectionPath,
    required this.text,
    required this.contentType,
    required this.version,
    required this.approvalDate,
    required this.score,
    required this.versionWarning,
  });

  final String docId;
  final String title;
  final String sectionPath;
  final String text;
  final String contentType;
  final String version;
  final String approvalDate;
  final double score;
  final String versionWarning;

  factory KnowledgeEvidence.fromJson(Map<String, dynamic> json) {
    return KnowledgeEvidence(
      docId: json['doc_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Без названия',
      sectionPath: json['section_path']?.toString() ?? '',
      text: json['display_text']?.toString() ?? json['text']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      approvalDate: json['approval_date']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      versionWarning: json['version_warning']?.toString() ?? '',
    );
  }
}

class ClinicalCategory {
  const ClinicalCategory({
    required this.id,
    required this.title,
    required this.diseaseCount,
  });

  final String id;
  final String title;
  final int diseaseCount;

  factory ClinicalCategory.fromJson(Map<String, dynamic> json) {
    return ClinicalCategory(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Без категории',
      diseaseCount: (json['disease_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClinicalDiseaseSummary {
  const ClinicalDiseaseSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.icd10Codes,
    required this.approvalDate,
    required this.version,
    required this.protocolNumber,
  });

  final String id;
  final String title;
  final String category;
  final List<String> icd10Codes;
  final String approvalDate;
  final String version;
  final String protocolNumber;

  factory ClinicalDiseaseSummary.fromJson(Map<String, dynamic> json) {
    return ClinicalDiseaseSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Без названия',
      category: json['category']?.toString() ?? '',
      icd10Codes: _stringList(json['icd10_codes']),
      approvalDate: json['approval_date']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      protocolNumber: json['protocol_number']?.toString() ?? '',
    );
  }
}

class ProtocolDocument {
  const ProtocolDocument({
    required this.id,
    required this.title,
    required this.version,
    required this.approvalDate,
    required this.protocolNumber,
    required this.icd10Codes,
    required this.sections,
    required this.empty,
  });

  final String id;
  final String title;
  final String version;
  final String approvalDate;
  final String protocolNumber;
  final List<String> icd10Codes;
  final List<ProtocolSection> sections;
  final bool empty;

  factory ProtocolDocument.fromJson(Map<String, dynamic> json) {
    final metadata = _map(json['document']);
    return ProtocolDocument(
      id: metadata['doc_id']?.toString() ?? '',
      title: metadata['title']?.toString() ?? 'Без названия',
      version: metadata['version_label']?.toString() ?? '',
      approvalDate: metadata['approval_date']?.toString() ?? '',
      protocolNumber: metadata['protocol_number']?.toString() ?? '',
      icd10Codes: _stringList(metadata['icd10_codes']),
      sections: _mapList(
        json['sections'],
      ).map(ProtocolSection.fromJson).toList(growable: false),
      empty: json['empty'] == true,
    );
  }
}

class ProtocolSection {
  const ProtocolSection({
    required this.id,
    required this.title,
    required this.path,
    required this.blocks,
  });

  final String id;
  final String title;
  final String path;
  final List<PresentationBlock> blocks;

  factory ProtocolSection.fromJson(Map<String, dynamic> json) {
    return ProtocolSection(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Раздел',
      path: json['path']?.toString() ?? '',
      blocks: _mapList(
        json['blocks'],
      ).map(PresentationBlock.fromJson).toList(growable: false),
    );
  }
}

class PresentationBlock {
  const PresentationBlock({
    required this.type,
    required this.text,
    required this.items,
    required this.references,
    required this.table,
  });

  final String type;
  final String text;
  final List<String> items;
  final List<String> references;
  final PresentationTable? table;

  factory PresentationBlock.fromJson(Map<String, dynamic> json) {
    return PresentationBlock(
      type: json['type']?.toString() ?? 'paragraph',
      text: json['text']?.toString() ?? '',
      items: _stringList(json['items']),
      references: _stringList(json['references']),
      table: json['type'] == 'table' ? PresentationTable.fromJson(json) : null,
    );
  }
}

class PresentationTable {
  const PresentationTable({
    required this.id,
    required this.title,
    required this.renderMode,
    required this.columns,
    required this.rows,
    required this.fallbackText,
    required this.message,
  });

  final String id;
  final String title;
  final String renderMode;
  final List<String> columns;
  final List<List<String>> rows;
  final String fallbackText;
  final String message;

  bool get isStructured => renderMode == 'structured' && columns.isNotEmpty;

  factory PresentationTable.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'] is List ? json['rows'] as List : const [];
    return PresentationTable(
      id: json['table_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Таблица',
      renderMode: json['render_mode']?.toString() ?? 'fallback',
      columns: _stringList(json['columns']),
      rows: rows
          .whereType<List>()
          .map(
            (row) => row.map((cell) => cell.toString()).toList(growable: false),
          )
          .toList(growable: false),
      fallbackText: json['fallback_text']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

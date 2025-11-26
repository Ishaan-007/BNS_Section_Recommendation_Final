class BnsSection {
  final String chapter;
  final String chapterName;
  final String chapterSubtype;
  final String section;
  final String sectionName;
  final String description;
  final String processedDescription;

  BnsSection({
    required this.chapter,
    required this.chapterName,
    required this.chapterSubtype,
    required this.section,
    required this.sectionName,
    required this.description,
    required this.processedDescription,
  });

  factory BnsSection.fromCsv(List<dynamic> row) {
    return BnsSection(
      chapter: row[0].toString(),
      chapterName: row[1].toString(),
      chapterSubtype: row[2].toString(),
      section: row[3].toString(),
      sectionName: row[4].toString(),
      description: row[5].toString(),
      processedDescription: row[6].toString(),
    );
  }
}

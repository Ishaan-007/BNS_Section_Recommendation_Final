import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../models/bns_section.dart';

class BnsService {
  List<BnsSection> _sections = [];

  List<BnsSection> get sections => _sections;

  Future<void> loadCsv() async {
    final csvString = await rootBundle.loadString(
      'assets/data/bns_sections.csv',
    );
    
    rootBundle.loadString("assets/data/bns_sections.csv").then((text) {
      print("CSV loaded successfully. Length: ${text.length}");
    }).catchError((e) {
      print("ERROR: $e");
    });


    // Use proper CSV parsing with field delimiter and text delimiter
    final rows = const CsvToListConverter(
      shouldParseNumbers: false, // Keep as strings to avoid parsing issues
      eol: '\n',
    ).convert(csvString);

    print("Total rows in CSV: ${rows.length}"); // Debug

    // Skip header row
    _sections = rows.skip(1).map((row) {
      try {
        return BnsSection.fromCsv(row);
      } catch (e) {
        print("Error parsing row: $row");
        print("Error: $e");
        rethrow;
      }
    }).toList();

    print("Total sections parsed: ${_sections.length}"); // Debug
  }

  List<BnsSection> search(String query) {
    final q = query.toLowerCase();
    return _sections.where((s) {
      return s.chapter.toLowerCase().contains(q) ||
          s.chapterName.toLowerCase().contains(q) ||
          s.chapterSubtype.toLowerCase().contains(q) ||
          s.section.toLowerCase().contains(q) ||
          s.sectionName.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.processedDescription.toLowerCase().contains(q);
    }).toList();
  }
}

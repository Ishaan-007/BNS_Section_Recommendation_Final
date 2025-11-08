import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final int sectionId;
  final String sectionText;
  final double similarity;

  const SectionCard({
    super.key,
    required this.sectionId,
    required this.sectionText,
    required this.similarity,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Section $sectionId",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(sectionText, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: similarity,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: Colors.indigo,
            ),
            const SizedBox(height: 5),
            Text("Similarity: ${(similarity * 100).toStringAsFixed(2)}%",
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

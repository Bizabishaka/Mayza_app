class JsonParser {
  final String recommendations;
  final String disease;
  final String description;

  JsonParser({
    required this.recommendations,
    required this.disease,
    required this.description,
  });

  // ✅ Define the fromJson method
  factory JsonParser.fromJson(Map<String, dynamic> json) {
    return JsonParser(
      recommendations: json['recommendations'] ?? 'No recommendation',
      disease: json['disease'] ?? 'Unknown',
      description: json['description'] ?? 'No description available',
    );
  }
}

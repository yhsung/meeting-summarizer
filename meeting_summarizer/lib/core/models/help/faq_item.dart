/// Represents a Frequently Asked Question with answer and metadata
class FaqItem {
  final String id;
  final String question;
  final String answer;
  final List<String> tags;
  final String categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int viewCount;
  final bool isPopular;
  final List<String> relatedQuestions;
  final int helpfulVotes;
  final int totalVotes;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.tags,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.viewCount = 0,
    this.isPopular = false,
    this.relatedQuestions = const [],
    this.helpfulVotes = 0,
    this.totalVotes = 0,
  });

  /// Calculate helpfulness percentage
  double get helpfulnessPercent {
    if (totalVotes == 0) return 0.0;
    return (helpfulVotes / totalVotes) * 100;
  }

  FaqItem copyWith({
    String? id,
    String? question,
    String? answer,
    List<String>? tags,
    String? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewCount,
    bool? isPopular,
    List<String>? relatedQuestions,
    int? helpfulVotes,
    int? totalVotes,
  }) {
    return FaqItem(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      tags: tags ?? this.tags,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      isPopular: isPopular ?? this.isPopular,
      relatedQuestions: relatedQuestions ?? this.relatedQuestions,
      helpfulVotes: helpfulVotes ?? this.helpfulVotes,
      totalVotes: totalVotes ?? this.totalVotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'tags': tags,
      'categoryId': categoryId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'viewCount': viewCount,
      'isPopular': isPopular,
      'relatedQuestions': relatedQuestions,
      'helpfulVotes': helpfulVotes,
      'totalVotes': totalVotes,
    };
  }

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      tags: List<String>.from(json['tags'] as List),
      categoryId: json['categoryId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      viewCount: json['viewCount'] as int? ?? 0,
      isPopular: json['isPopular'] as bool? ?? false,
      relatedQuestions: List<String>.from(
        json['relatedQuestions'] as List? ?? [],
      ),
      helpfulVotes: json['helpfulVotes'] as int? ?? 0,
      totalVotes: json['totalVotes'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FaqItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FaqItem(id: $id, question: $question)';
  }
}

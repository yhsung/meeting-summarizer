import 'package:flutter/material.dart';

/// Represents a help article with content and metadata
class HelpArticle {
  final String id;
  final String title;
  final String content;
  final String excerpt;
  final List<String> tags;
  final HelpCategory category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int viewCount;
  final bool isFeatured;
  final String? videoUrl;
  final List<String> relatedArticles;
  final Map<String, dynamic>? metadata;

  const HelpArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.tags,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.viewCount = 0,
    this.isFeatured = false,
    this.videoUrl,
    this.relatedArticles = const [],
    this.metadata,
  });

  HelpArticle copyWith({
    String? id,
    String? title,
    String? content,
    String? excerpt,
    List<String>? tags,
    HelpCategory? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewCount,
    bool? isFeatured,
    String? videoUrl,
    List<String>? relatedArticles,
    Map<String, dynamic>? metadata,
  }) {
    return HelpArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      excerpt: excerpt ?? this.excerpt,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      isFeatured: isFeatured ?? this.isFeatured,
      videoUrl: videoUrl ?? this.videoUrl,
      relatedArticles: relatedArticles ?? this.relatedArticles,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'excerpt': excerpt,
      'tags': tags,
      'category': category.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'viewCount': viewCount,
      'isFeatured': isFeatured,
      'videoUrl': videoUrl,
      'relatedArticles': relatedArticles,
      'metadata': metadata,
    };
  }

  factory HelpArticle.fromJson(Map<String, dynamic> json) {
    return HelpArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      excerpt: json['excerpt'] as String,
      tags: List<String>.from(json['tags'] as List),
      category: HelpCategory.fromJson(json['category'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      viewCount: json['viewCount'] as int? ?? 0,
      isFeatured: json['isFeatured'] as bool? ?? false,
      videoUrl: json['videoUrl'] as String?,
      relatedArticles: List<String>.from(
        json['relatedArticles'] as List? ?? [],
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HelpArticle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'HelpArticle(id: $id, title: $title, category: ${category.name})';
  }
}

/// Represents a help category for organizing articles
class HelpCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int sortOrder;
  final bool isVisible;

  const HelpCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
    this.isVisible = true,
  });

  HelpCategory copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    Color? color,
    int? sortOrder,
    bool? isVisible,
  }) {
    return HelpCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'colorValue': color.value,
      'sortOrder': sortOrder,
      'isVisible': isVisible,
    };
  }

  factory HelpCategory.fromJson(Map<String, dynamic> json) {
    return HelpCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: IconData(
        json['iconCodePoint'] as int,
        fontFamily: json['iconFontFamily'] as String?,
      ),
      color: Color(json['colorValue'] as int),
      sortOrder: json['sortOrder'] as int? ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HelpCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'HelpCategory(id: $id, name: $name)';
  }
}

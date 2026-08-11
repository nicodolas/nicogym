import 'dart:convert';

import 'package:flutter/services.dart';

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.prescription,
    required this.primaryMuscles,
    required this.equipment,
    required this.summary,
    required this.setup,
    required this.steps,
    required this.cues,
    required this.mistakes,
    required this.safety,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.videoUrl,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    prescription: json['prescription'] as String,
    primaryMuscles: List<String>.from(json['primaryMuscles'] as List),
    equipment: json['equipment'] as String,
    summary: json['summary'] as String,
    setup: List<String>.from(json['setup'] as List),
    steps: List<String>.from(json['steps'] as List),
    cues: List<String>.from(json['cues'] as List),
    mistakes: List<String>.from(json['mistakes'] as List),
    safety: json['safety'] as String,
    sourceLabel: json['sourceLabel'] as String,
    sourceUrl: json['sourceUrl'] as String,
    videoUrl: json['videoUrl'] as String,
  );

  final String id;
  final String name;
  final String prescription;
  final List<String> primaryMuscles;
  final String equipment;
  final String summary;
  final List<String> setup;
  final List<String> steps;
  final List<String> cues;
  final List<String> mistakes;
  final String safety;
  final String sourceLabel;
  final String sourceUrl;
  final String videoUrl;
}

class ExerciseLibrary {
  ExerciseLibrary._();

  static Future<List<Exercise>>? _cache;

  static Future<List<Exercise>> load() => _cache ??= _read();

  static Future<List<Exercise>> _read() async {
    final content = await rootBundle.loadString(
      'assets/data/exercises.vi.json',
    );
    final records = jsonDecode(content) as List<dynamic>;
    return records
        .map((record) => Exercise.fromJson(record as Map<String, dynamic>))
        .toList(growable: false);
  }
}

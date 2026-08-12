import 'package:flutter/material.dart';

const ink = Color(0xFF111310);
const paper = Color(0xFFF1F0E9);
const lime = Color(0xFFC7F36B);
const muted = Color(0xFF74786E);

ThemeData buildNicoGymTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: lime,
    brightness: Brightness.light,
    surface: paper,
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'BarlowCondensed',
      fontFamilyFallback: ['NotoSans'],
      fontSize: 64,
      height: .86,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'BarlowCondensed',
      fontFamilyFallback: ['NotoSans'],
      fontSize: 38,
      height: .95,
      fontWeight: FontWeight.w800,
    ),
    titleLarge: TextStyle(
      fontFamily: 'BarlowCondensed',
      fontFamilyFallback: ['NotoSans'],
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Barlow',
      fontFamilyFallback: ['NotoSans'],
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Barlow',
      fontFamilyFallback: ['NotoSans'],
      fontSize: 14,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Barlow',
      fontFamilyFallback: ['NotoSans'],
      fontWeight: FontWeight.w700,
    ),
  ),
);

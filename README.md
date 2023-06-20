# cash_cash

Projet pour la soutenance L3 E3IN 2023.

Application web et mobile de reconnaissance de:
- chèques
- billets
- pièces de monnaie

## Getting Started

This project is a starting point for a Flutter application.
A few resources to get you started if this is your first Flutter project:
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Pré-requis

Entrer ceci dans un terminal: 
- flutter pub add google_mlkit_object_detection ;
- flutter pub add google_mlkit_text_recognition ;

Ensuite pour utiliser les kits il faudra insérer dans chaque fichier .dart:
- ```import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';```
- ```import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';```

## Source

[object detection](https://pub.dev/packages/google_mlkit_object_detection),
[text_recognition](https://pub.dev/packages/google_mlkit_text_recognition)
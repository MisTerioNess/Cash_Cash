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
    
## Installation

Entrer ceci dans un terminal: 
- flutter pub add google_mlkit_object_detection ;
- flutter pub add google_mlkit_text_recognition ;

Ensuite pour utiliser les kits il faudra insérer dans chaque fichier .dart:
- ```import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';```
- ```import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';```

## Utiliser un téléphone physique

# Android

- sur votre téléphone 
il faut activer le mode développeur en cliquant plusieurs fois sur le numéro de série puis
en cherchant les options de développeurs vous activez le mode développeur et le débogage USB
[documentation](https://developer.android.com/studio/debug/dev-options?hl=fr)
- sur votre ordinateur
il faut installer le pilote OEM de la marque du téléphone utilisé via ce lien:
[pilote OEM](https://developer.android.com/studio/run/oem-usb?hl=fr#Drivers)

Enfin il faut brancher le téléphone à l'ordinateur via USB et autoriser le débogage USB lorsque
la pop-up apparaitra. 
Dès lors que ceci est fait vous aurez le nom du modèle de votre téléphone dans la sélection des appareils.

# IOS (WIP)

## Source

[object detection](https://pub.dev/packages/google_mlkit_object_detection),
[text_recognition](https://pub.dev/packages/google_mlkit_text_recognition)
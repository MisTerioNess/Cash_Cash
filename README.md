# cash_cash

Projet pour la soutenance L3 E3IN 2023.

Application web et mobile de reconnaissance de:
- chèques
- billets
- pièces de monnaie

## Pour commencer 

Installer flutter :
- [Installation de flutter](https://docs.flutter.dev/get-started/install)
- [Flutter documentation](https://docs.flutter.dev/)

Installer Dart :
- [Installation de Dart](https://dart.dev/get-dart)
- [Dart documentation](https://dart.dev/guides)
    
# Installation
Ouvrir un terminal.

Télécharger le projet.
```console
git clone git@github.com:MisTerioNess/Cash_Cash.git
```

Se mettre dans le dossier du projet.
```console
cd Cash_Cash
```

Installation des dépendances.
```console
flutter pub add google_mlkit_object_detection
```
```console
flutter pub add google_mlkit_text_recognition
```

Ensuite pour utiliser les kits il faudra insérer dans chaque fichier .dart:
```console 
import 'lib/module/google_mlkit_imports.dart';
```

# Utiliser un téléphone physique

## Android

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

## IOS (WIP)

# Source

[object detection](https://pub.dev/packages/google_mlkit_object_detection),
[text_recognition](https://pub.dev/packages/google_mlkit_text_recognition),
[incorporer la camera](https://developer.android.com/training/permissions/declaring?hl=fr)

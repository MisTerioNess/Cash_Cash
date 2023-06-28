import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'module/object_detector.dart';

/// Initialisation d'une liste qui va contenir les caméras de l'appareil de l'utilisateur.
List<CameraDescription> cameras = [];

/// Fonction princiaple.
Future<void> main() async {
  /// S'assure que les widgets sont initialisés correctement avant d'exécuter le reste du code.
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
  runApp(MyApp());
}

/// Fonction principale du projet.
///
/// @param key : nombre entier.
/// @return La page d'accueil de l'application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ObjectDetectorView(),
    );
  }
}
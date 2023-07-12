import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'module/chequeDetail.dart';
import 'module/object_detector.dart';
import 'package:universal_platform/universal_platform.dart';
import 'mainWeb.dart';

/// Initialisation d'une liste qui va contenir les caméras de l'appareil de l'utilisateur.
List<CameraDescription> cameras = [];

void main() async {
  bool isWeb = UniversalPlatform.isWeb;
  if (isWeb) {
    runApp(MyWebApp());
  }
  else {
    /// S'assure que les widgets sont initialisés correctement avant d'exécuter le reste du code.
    WidgetsFlutterBinding.ensureInitialized();

    cameras = await availableCameras();
    runApp(MyApp());
  }
}

/// Fonction principale du projet.
///
/// @param key : nombre entier.
/// @return La page d'accueil de l'application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();

    cameras = await availableCameras();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateRoute: (settings) {
        // If you push the name like '/chequeDetail'
        if (settings.name == '/chequeDetail') {
          final arguments = settings.arguments as Map<String, dynamic>;
          final int id = arguments["id"];
          final String imageFile = arguments["path"];
          final String recognizedText = arguments["txt"];
          List imgCheques = arguments["imgCheques"];
          return MaterialPageRoute(
            builder: (context) => ChequeDetail(imgCheques: imgCheques, id: id, imageFile: imageFile, recognizedText: recognizedText), // Assurez-vous que ChequeDetail prend un paramètre id
          );
        }
      },
      debugShowCheckedModeBanner: false,
      home: ObjectDetectorView(),
    );
  }
}
  

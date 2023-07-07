import 'dart:io' as io;
import 'package:camera/camera.dart';
import 'package:cash_cash/module/painters/painters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'camera_view.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'painters/paintersText.dart';

import '../main.dart';

/// Cette classe est utilisée pour définir une vue qui peut être mise à jour dynamiquement en réponse à des changements d'état.
class ObjectDetectorView extends StatefulWidget {
  const ObjectDetectorView({super.key});

  @override
  State<ObjectDetectorView> createState() => _ObjectDetectorView();
}

/// Mise à jour de la vue.
class _ObjectDetectorView extends State<ObjectDetectorView> {
  late ObjectDetector _objectDetector;
  late ObjectDetector _objectDetectorImage;
  bool _canProcess = false;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;

  /// Initialisation de l'état de base.
  @override
  void initState() {
    super.initState();
    _initializeDetector(DetectionMode.stream);
  }

  CustomPaint? _customPaintText;
  late ObjectDetector _objectDetectorImage;

  /// Met à jour le widget principal.
  @override
  Widget build(BuildContext context) {
    return CameraView(
      title: 'Cash Cash',
      customPaint: _customPaint,
      text: _text,
      onImage: (inputImage) {
        processImage(inputImage);
      },
      resetCustomPaint: (customPaint) {
        resetCustomPaint(customPaint);
      },
      onScreenModeChanged: _onScreenModeChanged,
      initialDirection: CameraLensDirection.back,
    );
  }

  void resetCustomPaint(CustomPaint? value) {
    setState(() {
      _customPaint = value;
    });
  }

  /// Changement de mode. LivePreview ou Galerie.
  void _onScreenModeChanged(ScreenMode mode) {
    switch (mode) {
      case ScreenMode.gallery:
        _initializeDetector(DetectionMode.single);
        return;

      case ScreenMode.liveFeed:
        _initializeDetector(DetectionMode.stream);
        return;
    }
    
    /// Vide la mémoire.
    @override
    void dispose() {
      _canProcess = false;
      _objectDetector.close();
      super.dispose();
    }

  /// Initialise les détecteurs d'objets.
  /// Cette fonction initialise les détecteurs d'objets en fonction du mode de détection spécifié.
  /// Deux options sont disponibles : une détection basée sur un modèle par défaut ou une détection basée sur un modèle local.
  void _initializeDetector(DetectionMode mode) async {

    final optionsImage = ObjectDetectorOptions(
        mode: mode,
        classifyObjects: true,
        multipleObjects: true
    );
    _objectDetectorImage = ObjectDetector(options: optionsImage);

    final modelPath = await _getModel('assets/ml/bob.tflite');
    final options = LocalObjectDetectorOptions(
      modelPath: modelPath,
      classifyObjects: true,
      multipleObjects: true,
      mode: DetectionMode.stream,
    );
    _objectDetector = ObjectDetector(options: options);

    // Une fois le détecteur d'objets initialisé, il est prt à traiter les images
    _canProcess = true;
  }


  /// Traitement de l'image.
  /// Cette fonction prend une [inputImage] en paramètre et effectue un traitement
  /// en fonction des métadonnées de l'image.
  /// Le traitement peut être effectué en temps réel ou sur des images statiques.
  Future<void> processImage(InputImage inputImage) async {
    // Si on ne peut pas traiter l'image ou si une opération est déjà en cours, on arrête le traitement
    if (!_canProcess || _isBusy) return;

    _isBusy = true;

    // Réinitialise le texte affiché
    setState(() {
      _text = '';
    });

    List<DetectedObject> objects;
    Size size;
    InputImageRotation rotation;

    // Si les métadonnées de l'image sont disponibles, cela signifie que nous avons une image en temps réel
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {

      // Utilise le modèle Bob, plus performant pour la détection d'objets en temps réel
      objects = await _objectDetector.processImage(inputImage);
      size = inputImage.metadata!.size;
      rotation = inputImage.metadata!.rotation;

    } else {

      // Utilise le modèle John, moins performant mais plus rapide pour la détection d'objets sur des images statiques
      objects = await _objectDetectorImage.processImage(inputImage);

      // Converti l'image pour récupérer ses dimensions
      String? path = inputImage.filePath;
      final file = io.File(path!);
      final img.Image? image = img.decodeImage(await file.readAsBytes());
      final double? width = image?.width.toDouble();
      final double? height = image?.height.toDouble();

      size = Size(width!, height!);
      rotation = InputImageRotation.rotation0deg;

    }

    // Création du peintre pour l'affichage des rectangles autour des objets
    final painter = ObjectDetectorPainter(objects, rotation, size);
    _customPaint = CustomPaint(painter: painter);

    _isBusy = false;

    // Met à jour l'état de l'application si elle est toujours montée
    if (mounted) {
      setState(() {});
    }

  /// Fonction pour récupérer le modèle (ou tout autre fichier d'asset).
  ///
  /// Cette fonction récupère le chemin d'un fichier de modèle donné en fonction de la plateforme
  /// sur laquelle l'application s'exécute. Elle effectue différentes tâches en fonction de la plateforme.
  ///
  /// [assetPath] est le chemin de l'asset au sein du bundle d'assets de Flutter.
  Future<String> _getModel(String assetPath) async {

    // Si la plateforme est Android
    if (io.Platform.isAndroid) {
      // Sur Android, nous pouvons accéder directement à l'asset à partir du bundle d'assets de Flutter.
      return 'flutter_assets/$assetPath';
    }

    // Si la plateforme n'est pas Android (probablement iOS)
    // Nous obtenons le répertoire de support de l'application, et ajoutons le assetPath.
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';

    // Le répertoire pour le fichier est créé s'il n'existe pas.
    // Ceci est fait de manière récursive, ce qui signifier qu'il créera tous les répertoires jusqu'au chemin donné s'ils n'existent pas.
    await io.Directory(dirname(path)).create(recursive: true);

    // Une référence au fichier est créée.
    final file = io.File(path);

    // Si le fichier n'existe pas déjà
    if (!await file.exists()) {
      // Nous chargeons les données de l'asset du bundle d'assets de Flutter
      final byteData = await rootBundle.load(assetPath);

      // Nous écrivons ces données dans un fichier au chemin spécifié
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    // Nous retournons le chemin du fichier
    return file.path;
  }

}

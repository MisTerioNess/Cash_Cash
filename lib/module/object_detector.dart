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
    img.Image? croppedImage;

    void uploadImage(io.File imageFile) async {
      // L'URL de votre endpoint de téléchargement
      var uri = Uri.parse('http://149.202.49.224:8000/upload_image');

      // Créer une requête multipart
      var request = http.MultipartRequest('POST', uri);

      // Ajouter le fichier à la requête
      request.files.add(await http.MultipartFile.fromPath(
        'image', // le nom du paramètre POST pour le fichier
        imageFile.path,
        filename: basename(imageFile.path), // le nom du fichier à envoye
      ));

      // Envoyer la requête
      var response = await request.send();

      // Vérifier la réponse
      if (response.statusCode == 200) {
        print('Upload successful');
      } else {
        print('Upload failed with status: ${response.statusCode}');
      }
    }

    /// Initialisation de l'état de base.
    @override
    void initState() {
      super.initState();

      _initializeDetector(DetectionMode.stream);
    }

    /// Vide la mémoire.
    @override
    void dispose() {
      _canProcess = false;
      _objectDetector.close();
      super.dispose();
    }

    /// Met à jour un widget.
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
    }

    /// Initialise le detecteur d'objets.
    void _initializeDetector(DetectionMode mode) async {
      print('Set detector in mode: $mode');

      // uncomment next lines if you want to use the default model
      final optionsImage = ObjectDetectorOptions(
          mode: mode,
          classifyObjects: true,
          multipleObjects: true);
      _objectDetectorImage = ObjectDetector(options: optionsImage);

      // uncomment next lines if you want to use a local model
      // make sure to add tflite model to assets/ml
      final modelPath = await _getModel('assets/ml/object_labeler.tflite');
      final options = LocalObjectDetectorOptions(
        modelPath: modelPath,
        classifyObjects: true,
        multipleObjects: true,
        mode: DetectionMode.stream,
      );
      _objectDetector = ObjectDetector(options: options);
      _canProcess = true;
    }

    /// Traitement de l'image.
    Future<void> processImage(InputImage inputImage) async {
      if (!_canProcess) return;
      if (_isBusy) return;
      _isBusy = true;
      setState(() {
        _text = '';
      });

      if (inputImage.metadata?.size != null &&
          inputImage.metadata?.rotation != null) {
        final objects = await _objectDetector.processImage(inputImage);
        final painter = ObjectDetectorPainter(
            objects, inputImage.metadata!.rotation, inputImage.metadata!.size);
        _customPaint = CustomPaint(painter: painter);
      } else {
        final objects = await _objectDetectorImage.processImage(inputImage);
        // Create a File object with the picture
        String? path = inputImage.filePath;
        final file = io.File(path!);
        final img.Image? image = img.decodeImage(await file.readAsBytes());
        // Get the size of the image
        final double? width = image?.width.toDouble();
        final double? height = image?.height.toDouble();

        // Add rect on objects detected.
        final painter = ObjectDetectorPainter(
            objects, InputImageRotation.rotation0deg, Size(width!, height!));
        _customPaint = CustomPaint(painter: painter);

        // String text = 'Objects found: ${objects.length}\n\n';
        for (final object in objects) {
          _text = 'Object:  trackingId: ${object.trackingId} - ${object.labels.map((e) => e.text)}\n\n';
        }
        uploadImage(file);

      }
      _isBusy = false;
      if (mounted) {
        setState(() {});
      }
    }

    /// Récupère le modèle.
    Future<String> _getModel(String assetPath) async {
      if (io.Platform.isAndroid) {
        return 'flutter_assets/$assetPath';
      }
      final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
      await io.Directory(dirname(path)).create(recursive: true);
      final file = io.File(path);
      if (!await file.exists()) {
        final byteData = await rootBundle.load(assetPath);
        await file.writeAsBytes(byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }
      return file.path;
    }
}

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
import 'dart:io';
import '../mainWeb.dart';
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
    bool _canProcess = false;
    bool _isBusy = false;
    CustomPaint? _customPaint;
    String? _text;
    img.Image? croppedImage;

    void uploadImage(File imageFile) async {
      // L'URL de votre endpoint de téléchargement
      var uri = Uri.parse('http://149.202.49.224:49153/image');

      // Créer une requête multipart
      var request = http.MultipartRequest('POST', uri);

      // Ajouter le fichier à la requête
      request.files.add(await http.MultipartFile.fromPath(
        'file', // le nom du paramètre POST pour le fichier
        imageFile.path,
        filename: basename(imageFile.path), // le nom du fichier à envoyer
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
        onScreenModeChanged: _onScreenModeChanged,
        initialDirection: CameraLensDirection.back,
      );
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
      final options = ObjectDetectorOptions(
          mode: mode,
          classifyObjects: true,
          multipleObjects: true);
      _objectDetector = ObjectDetector(options: options);

      // uncomment next lines if you want to use a local model
      // make sure to add tflite model to assets/ml
      // const path = 'object_labeler.tflite';
      // final modelPath = await _getModel(path);
      // print(modelPath);
      // final options = LocalObjectDetectorOptions(
      //   mode: mode,
      //   modelPath: modelPath,
      //   classifyObjects: true,
      //   multipleObjects: true,
      // );
      // _objectDetector = ObjectDetector(options: options);

      // uncomment next lines if you want to use a remote model
      // make sure to add model to firebase
      // final modelName = 'bird-classifier';
      // final response =
      //     await FirebaseObjectDetectorModelManager().downloadModel(modelName);
      // print('Downloaded: $response');
      // final options = FirebaseObjectDetectorOptions(
      //   mode: mode,
      //   modelName: modelName,
      //   classifyObjects: true,
      //   multipleObjects: true,
      // );
      // _objectDetector = ObjectDetector(options: options);

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
      final objects = await _objectDetector.processImage(inputImage);
      if (inputImage.metadata?.size != null &&
          inputImage.metadata?.rotation != null) {
        final painter = ObjectDetectorPainter(
            objects, inputImage.metadata!.rotation, inputImage.metadata!.size);
        _customPaint = CustomPaint(painter: painter);
      } else {
        // Create a File object with the picture
        String? path = inputImage.filePath;
        final file = File(path!);
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
          uploadImage(file);
          // print(object.boundingBox);
          // print("INFOS DU RECTANGLE");
          // print(object.boundingBox.size.width);
          // print(object.boundingBox.size.height);
          // final int width = object.boundingBox.size.width.toInt();
          // final int height = object.boundingBox.size.height.toInt();
          // final img.Image cropImage = img.copyCrop(image!, x: 50, y: 50, width: width, height: height);
          // croppedImage = cropImage;
          // print("C'est le objectRect");
          // Rect objectRect = object.boundingBox;
          // img.Image croppedImage = img.copyCrop(image!, x: objectRect.left.round(), y: objectRect.top.round(), width: objectRect.width.round(), height: objectRect.height.round());
          // // Convertir l'image extraite en bytes.
          // print("Je suis en train de convertir l'image");
          // Uint8List croppedBytes = img.encodePng(croppedImage);
          // List<int> pngBytes = croppedBytes.buffer.asUint8List();
          //
          // // Obtenir un chemin de fichier pour enregistrer l'image
          // print("J'obtiens le chemin d'acces");
          // Directory appDocDir = await getApplicationDocumentsDirectory();
          // String path = '${appDocDir.path}/cropped.png';
          // print(appDocDir.path);
          //
          // // Enregistrer l'image dans un fichier
          // print("J'enregistre l'image");
          // File file = File(path);
          // await file.writeAsBytes(pngBytes);

          _text = 'Object:  trackingId: ${object.trackingId} - ${object.labels.map((e) => e.text)}\n\n';
        }
        // _text = text;

      }
      _isBusy = false;
      if (mounted) {
        setState(() {});
      }
    }

    /// Récupère le modèle.
    Future<String> _getModel(String assetPath) async {
      if (io.Platform.isAndroid) {
        return 'assets/$assetPath';
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

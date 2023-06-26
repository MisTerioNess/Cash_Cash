import 'dart:io' as io;
import 'package:camera/camera.dart';
import 'package:cash_cash/module/painters/painters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'camera_view.dart';

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
        String text = 'Objects found: ${objects.length}\n\n';
        for (final object in objects) {
          text +=
          'Object:  trackingId: ${object.trackingId} - ${object.labels.map((e) => e.text)}\n\n';
        }
        _text = text;
        // TODO: set _customPaint to draw boundingRect on top of image
        _customPaint = null;
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

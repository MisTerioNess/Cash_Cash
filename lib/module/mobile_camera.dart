import 'package:flutter/material.dart';
import 'package:camera/camera.dart' show CameraController, CameraPreview, ResolutionPreset, availableCameras;

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MobileCamera createState() => MobileCamera();
}

class MobileCamera extends State<MyApp> {
  CameraController? _cameraController;

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.medium,
    );

    _cameraController!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Widget cameraWidget() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          body: CameraPreview(_cameraController!),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: cameraWidget(),
    );
  }
}
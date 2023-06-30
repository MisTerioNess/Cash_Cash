import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cash_cash/module/object_detector.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';

/// Définition des mode.
enum ScreenMode { liveFeed, gallery }

/// Représente une vue de la caméra.
class CameraView extends StatefulWidget {
  const CameraView(
      {Key? key,
        required this.title,
        required this.customPaint,
        this.text,
        required this.onImage,
        required this.resetCustomPaint,
        this.onScreenModeChanged,
        this.initialDirection = CameraLensDirection.back,
      })
      : super(key: key);

  final String title;
  final CustomPaint? customPaint;
  final String? text;
  final Function(InputImage inputImage) onImage;
  final Function(CustomPaint customPaint) resetCustomPaint;
  final Function(ScreenMode mode)? onScreenModeChanged;
  final CameraLensDirection initialDirection;

  @override
  State<CameraView> createState() => _CameraViewState();
}

/// Mise à jour de la vue avec la caméra.
class _CameraViewState extends State<CameraView> {
  ScreenMode _mode = ScreenMode.liveFeed;
  CameraController? _controller;
  File? _image;
  XFile? _imageFile;
  String? _path;
  ImagePicker? _imagePicker;
  int _cameraIndex = -1;
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;
  final bool _allowPicker = true;
  bool _changingCameraLens = false;

  void resetCustomPaint() {
    // réinitialiser les bordures vertes du détecteur
    CustomPaint cp = CustomPaint();
    widget.resetCustomPaint(cp);
  }

  /// Initialisation de l'état de base.
  @override
  void initState() {
    super.initState();

    _imagePicker = ImagePicker();

    if (cameras.any(
          (element) =>
      element.lensDirection == widget.initialDirection &&
          element.sensorOrientation == 90,
    )) {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere((element) =>
        element.lensDirection == widget.initialDirection &&
            element.sensorOrientation == 90),
      );
    } else {
      for (var i = 0; i < cameras.length; i++) {
        if (cameras[i].lensDirection == widget.initialDirection) {
          _cameraIndex = i;
          break;
        }
      }
    }

    if (_cameraIndex != -1) {
      _startLiveFeed();
    } else {
      _mode = ScreenMode.gallery;
    }
  }

  /// Vide la mémoire.
  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  /// Met à jour un widget.
  @override
  Widget build(BuildContext context) {
    if(_imageFile != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(_imageFile!.path),
              fit: BoxFit.cover,
            ),
            Positioned.fill(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: widget.customPaint,
                // ou _customPaint si vous utilisez la variable _customPaint
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _retry,
                      child: Text('Réessayer'),
                    ),
                    SizedBox(width: 16.0),
                    ElevatedButton(
                      onPressed: _confirm,
                      child: Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (_allowPicker)
              Padding(
                padding: EdgeInsets.only(right: 20.0),
                child: GestureDetector(
                  onTap: _switchScreenMode,
                  child: Icon(
                    _mode == ScreenMode.liveFeed
                        ? Icons.photo_library_outlined
                        : (Platform.isIOS
                        ? Icons.camera_alt_outlined
                        : Icons.camera),
                  ),
                ),
              ),
          ],
        ),
        body: _body(),
        floatingActionButton: _floatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      );
    }
  }

  /// prendre une photo de la caméra
  Future<void> _takePhoto() async {
    if (_controller?.value.isInitialized == false) {
      return;
    }

    try {
      await _controller?.initialize();
      final imageFile = await _controller?.takePicture();

      setState(() {
        _imageFile = imageFile;
      });
    } catch (e) {
      print('Error taking picture: $e');
    }
  }
  /// annule la prise de la photo et retourne sur la preview de la caméra
  void _retry() {
    setState(() async {
      await _stopLiveFeed();
      _imageFile = null;
      resetCustomPaint();
      await _startLiveFeed();
    });
  }
  /// valide la prise de la photo
  void _confirm() {
    print('OK'); // TODO: rediriger l'image vers le dashboard
  }

  /// Met à jour un widget.
  Widget? _floatingActionButton() {
    if (_mode == ScreenMode.gallery) return null;
    if (cameras.length == 1) return null;

    return Row(
      children: [
        SizedBox(width: 150.0), // espacement pour mettre les boutons au centre
        SizedBox(
          height: 60.0,
          width: 60.0,
          child: FloatingActionButton(
            onPressed: _takePhoto,
            child: Icon(Icons.camera, size: 40),
          ),
        ),
        SizedBox(width: 50.0), // Espacement entre les boutons
        SizedBox(
          height: 50.0,
          width: 50.0,
          child: FloatingActionButton(
            onPressed: _switchLiveCamera,
            child: Icon(
              Platform.isIOS
                  ? Icons.flip_camera_ios_outlined
                  : Icons.flip_camera_android_outlined,
              size: 30
            ),
          ),
        ),
      ],
    );
  }

  /// Met à jour un widget.
  Widget _body() {
    Widget body;
    if (_mode == ScreenMode.liveFeed) {
      body = _liveFeedBody();
    } else {
      body = _galleryBody();
    }

    return body;
  }

  /// Met à jour un widget.
  Widget _liveFeedBody() {
    if (_controller?.value.isInitialized == false) {
      return Container();
    }

    final size = MediaQuery.of(context).size;
    // calculate scale depending on screen and camera ratios
    // this is actually size.aspectRatio / (1 / camera.aspectRatio)
    // because camera preview size is received as landscape
    // but we're calculating for portrait orientation
    var scale = size.aspectRatio * _controller!.value.aspectRatio;

    // to prevent scaling down, invert the value
    if (scale < 1) scale = 1 / scale;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.scale(
            scale: scale,
            child: Center(
              child: _changingCameraLens
                  ? Center(
                child: const Text('Changing camera lens'),
              )
                  : CameraPreview(_controller!),
            ),
          ),
          if (widget.customPaint != null) widget.customPaint!,
          Positioned(
            bottom: 100,
            left: 50,
            right: 50,
            child: Slider(
              value: zoomLevel,
              min: minZoomLevel,
              max: maxZoomLevel,
              onChanged: (newSliderValue) {
                setState(() {
                  zoomLevel = newSliderValue;
                  _controller!.setZoomLevel(zoomLevel);
                });
              },
              divisions: (maxZoomLevel - 1).toInt() < 1
                  ? null
                  : (maxZoomLevel - 1).toInt(),
            ),
          )
        ],
      ),
    );
  }

  /// Met à jour un widget.
  Widget _galleryBody() {
    return ListView(shrinkWrap: true, children: [
      _image != null
          ? SizedBox(
        height: 400,
        width: 400,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.file(_image!),
            if (widget.customPaint != null) widget.customPaint!,
          ],
        ),
      )
          : Icon(
        Icons.image,
        size: 200,
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: Text('From Gallery'),
          onPressed: () => _getImage(ImageSource.gallery),
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: Text('Take a picture'),
          onPressed: () => _getImage(ImageSource.camera),
        ),
      ),
      if (_image != null)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
              '${_path == null ? '' : 'Image path: $_path'}\n\n${widget.text ?? ''}'),
        ),
    ]);
  }

  Future _getImage(ImageSource source) async {
    setState(() {
      _image = null;
      _path = null;
    });

    final pickedFile = await _imagePicker?.pickImage(source: source);
    if (pickedFile != null) {
      _processPickedFile(pickedFile);
    }

    setState(() {});
  }

  /// Change le mode de la caméra
  void _switchScreenMode() {
    _image = null;

    if (_mode == ScreenMode.liveFeed) {
      _mode = ScreenMode.gallery;
      _stopLiveFeed();
    } else {
      _mode = ScreenMode.liveFeed;
      _startLiveFeed();
    }

    if (widget.onScreenModeChanged != null) {
      widget.onScreenModeChanged!(_mode);
    }

    setState(() {});
  }

  /// Démarre la preview de la caméra.
  Future _startLiveFeed() async {
    final camera = cameras[_cameraIndex];

    _controller = CameraController(
      camera,
      // Ne pas mettre la résolution sur ResolutionPreset.max. Sur certains modèles de téléphone, elle n'existe pas
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  /// Stop la preview de la caméra.
  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  /// Change le mode de preview de la caméra.
  Future _switchLiveCamera() async {
    setState(() => _changingCameraLens = true);
    _cameraIndex = (_cameraIndex + 1) % cameras.length;

    await _stopLiveFeed();
    await _startLiveFeed();
    setState(() => _changingCameraLens = false);
  }

  /// Analyse l'image fournis par l'utilisateur.
  Future _processPickedFile(XFile? pickedFile) async {
    final path = pickedFile?.path;
    if (path == null) {
      return;
    }
    setState(() {
      _image = File(path);
    });
    _path = path;
    final inputImage = InputImage.fromFilePath(path);
    await widget.onImage(inputImage);
  }

  /// Analyse l'image fournis par la caméra.
  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage);
  }

  /// Transforme l'image de la caméra en image statique.
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // get camera rotation
    final camera = cameras[_cameraIndex];
    final rotation =
    InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }
}

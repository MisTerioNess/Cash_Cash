import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../main.dart';

/// Définition des mode.
enum ScreenMode { liveFeed, gallery }

/// Représente une vue de la caméra.
class CameraView extends StatefulWidget {
  CameraView(
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
class _CameraViewState extends State<CameraView> with SingleTickerProviderStateMixin {
  ScreenMode _mode = ScreenMode.liveFeed;
  CameraController? _controller;
  File? _image;
  XFile? _imageFile;
  String? _path;
  ImagePicker? _imagePicker;
  int _cameraIndex = -1;
  double zoomLevel = 1.0, minZoomLevel = 1.0, maxZoomLevel = 10.0;
  final bool _allowPicker = true;
  bool _changingCameraLens = false;
  bool _showDashboard = false;
  double _scaleFactor = 1.0;
  double _baseScaleFactor = 1.0;
  late final AnimationController _animationController;
  late final Animation<double> _animation;
  bool _isProcess = false;
  late String total;
  late String total_banknotes;
  late String count_banknotes;
  late String total_coins;
  late String count_coins;
  late String total_cheques;
  late String count_cheques;

  void uploadImage(File imageFile) async {
    // L'URL de votre endpoint de téléchargement
    var uri = Uri.parse('http://149.202.49.224:8000/upload_image');

    // Créer une requête multipart
    var request = http.MultipartRequest('POST', uri);

    // Ajouter le fichier à la requête
    request.files.add(await http.MultipartFile.fromPath(
      'image', // le nom du paramètre POST pour le fichier
      imageFile.path,
      filename: path.basename(imageFile.path), // le nom du fichier à envoyer
    ));

    // Envoyer la requête
    var response = await request.send();
    var responseBody = await response.stream.transform(utf8.decoder).join();
    print(responseBody);
    var responseBodyDict = jsonDecode(responseBody);
    total = responseBodyDict['total'];
    total_banknotes = responseBodyDict['total_banknotes'];
    count_banknotes = responseBodyDict['count_banknotes'];
    total_coins = responseBodyDict['total_coins'];
    count_coins = responseBodyDict['count_coins'];
    total_cheques = responseBodyDict['total_cheques'];
    count_cheques = responseBodyDict['count_cheques'];

    // Vérifier la réponse
    if (response.statusCode == 200) {
      _isProcess = false;
      print('Upload successful');
      setState(() {});
    } else {
      print('Upload failed with status: ${response.statusCode}');
    }
  }

  void resetCustomPaint() {
    // réinitialiser les bordures vertes du détecteur
    CustomPaint cp = CustomPaint();
    widget.resetCustomPaint(cp);
  }

  /// Initialisation de l'état de base.
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 8).animate(_animationController);

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
    if(_showDashboard == true) {
      return _dashboard();
    } else if(_imageFile != null) {
      return _pictureBody();
      // affiche l'image ainsi qu'un formulaire pour valider ou reprendre la photo prise
    } else {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Color.fromARGB(255, 247,115,127),
          title: Row(
            children: [
              Image.asset(
                'assets/cc_icon.png',
                width: 24.0,
                height: 24.0,
              ),
              SizedBox(width: 8.0), // Espacement entre l'icône et le titre
              Text(widget.title),
            ],
          ),
          actions: [
            if (_allowPicker)
              Padding(
                padding: EdgeInsets.only(right: 20.0),
                child: GestureDetector(
                  onTap: _switchScreenMode,
                  child: Icon(
                    _mode == ScreenMode.liveFeed
                        ? Icons.image_outlined
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
      _controller!.setZoomLevel(zoomLevel);
      final imageFile = await _controller!.takePicture();

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
  void _confirm() async {
    await _stopLiveFeed();
    setState(() {
      _showDashboard = true;
    });
    final path = _imageFile?.path;
    _isProcess = true;
    uploadImage(File(path!));
  }

  /// depuis le dashboard, repartir dans la galerie
  void _returnToGallery() {
    setState(() {
      _showDashboard = false;
      _imageFile = null;
    });
  }

  /// Met à jour un widget.
  Widget? _floatingActionButton() {
    if (_mode == ScreenMode.gallery) return null;
    if (cameras.length == 1) return null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Centre les boutons dans la Row
      children: [
        SizedBox(
          height: 60.0,
          width: 60.0,
          child: FloatingActionButton(
            backgroundColor: Color.fromARGB(255, 252,183,94),
            onPressed: _takePhoto,
            child: Icon(Icons.camera, size: 40),
          ),
        ),
        SizedBox(width: 50.0), // Espacement entre les boutons
        SizedBox(
          height: 60.0, // Taille du bouton modifiée pour correspondre au premier bouton
          width: 60.0, // Taille du bouton modifiée pour correspondre au premier bouton
          child: FloatingActionButton(
            backgroundColor: Color.fromARGB(255, 130,71,207),
            onPressed: _switchLiveCamera,
            child: Icon(
                Platform.isIOS
                    ? Icons.flip_camera_ios_outlined
                    : Icons.flip_camera_android_outlined,
                size: 40 // Taille de l'icône modifiée pour correspondre à la première icône
            ),
          ),
        ),
      ],
    );
  }

  Widget _pictureBody() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 247,115,127),
        title: Row(
          children: [
            Image.asset(
              'assets/cc_icon.png',
              width: 24.0,
              height: 24.0,
            ),
            SizedBox(width: 8.0), // Espacement entre l'icône et le titre
            Text(widget.title),
          ],
        ),
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
                child: widget.customPaint
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
                    child: Text('Valider'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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

  /// Affiche la preview de la caméra
  Widget _liveFeedBody() {
    if (!_controller!.value.isInitialized) {
      return Container();
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;

    if (scale < 1) scale = 1 / scale;

    return Container(
      color: Colors.black,
      child: GestureDetector(
        onScaleStart: (details) {
          _baseScaleFactor = zoomLevel;
        },
        onScaleUpdate: (details) {
          setState(() {
            zoomLevel = _baseScaleFactor * details.scale;
            zoomLevel = zoomLevel.clamp(minZoomLevel, maxZoomLevel);

            _controller!.setZoomLevel(zoomLevel);
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CameraPreview(_controller!),
            if (widget.customPaint != null) widget.customPaint!,
          ],
        ),
      ),
    );
  }

  /// Affiche la galerie
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
        Icons.euro,
        size: 250,
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: Text('Image depuis la galerie'),
          onPressed: () => _getImage(ImageSource.gallery),
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: Text('Prendre une photo'),
          onPressed: () => _getImage(ImageSource.camera),
        ),
      ),
      // TODO: mettre l'historisation du dashboard ou l'afficher en dessous de ces boutons
      if (_image != null)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
              '${_path == null ? '' : 'Image path: $_path'}\n\n${widget.text ?? ''}'),
        ),
    ]);
  }

  /// Affiche le tableau de bord
  Widget _dashboard() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 247,115,127),
        title: Row(
          children: [
            Image.asset(
              'assets/cc_icon.png',
              width: 24.0,
              height: 24.0,
            ),
            SizedBox(width: 8.0), // Espacement entre l'icône et le titre
            Text(widget.title),
          ],
        ),
        actions: [
          if (_allowPicker)
            Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {
                  _mode = ScreenMode.gallery;
                  _galleryBody();
                  _returnToGallery();
                  print("tap");
                },
                child: Icon(Icons.view_cozy_outlined, opticalSize: 48),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView( // Ajout du SingleChildScrollView
        child: Column(
          children: [
            SizedBox(
              height: 550,
              width: 400,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.file(
                    File(_imageFile!.path),
                    fit: BoxFit.cover,
                  ),
                  if (_isProcess == true) // Si _isProcessing est true, affichez le spinner de chargement et le filtre blanc
                    Container(
                      color: Colors.white.withOpacity(0.5), // Couleur blanche avec opacité de 10%
                    ),
                  if (_isProcess == true) // Si _isProcessing est true, affichez le spinner de chargement
                    Center(
                      child: CircularProgressIndicator(),
                    ), // Si isProcessing est true, affichez le spinner de chargement
                  if(_isProcess == false) Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (BuildContext context, Widget? child) {
                        return Transform.translate(
                          offset: Offset(0, -_animation.value),
                          child: child,
                        );
                      },
                      child: Icon(Icons.arrow_downward, // Icône animé
                          color: Color.fromARGB(255, 247,115,127),
                          size: 50.0),
                    ),
                  ),
                  if (widget.customPaint != null) widget.customPaint!,
                ],
              ),
            ),
            if(_isProcess == false) Card(
              child: ListTile(
                leading: Image(
                  image: AssetImage('assets/cash_bill.png'),
                  width: 50, // Largeur souhaitée
                  height: 50, // Hauteur souhaitée
                  fit: BoxFit.contain, // Contrôle le mode d'ajustement de l'image
                ),
                title: Text("Montant total: ${total.isNotEmpty ? total : 'N/A'}"),
              ),
            ),
            if(_isProcess== false) Text("Détails"),
            if(_isProcess == false) Card(
              child: ListTile(
                leading: Icon(Icons.payments_outlined, size: 36),
                title: Text("Montant des billets: ${total_banknotes.isNotEmpty ? total_banknotes : 'N/A'}"),
                subtitle: Text("Nombre de billets: ${count_banknotes.isNotEmpty ? count_banknotes : 'N/A'}"),
              ),
            ),
            if(_isProcess == false) Card(
              child: ListTile(
                leading: Icon(Icons.paid_outlined, size: 36),
                title: Text("Montant des pièces: ${total_coins.isNotEmpty ? total_coins : 'N/A'}"),
                subtitle: Text("Nombre de pièces: ${count_coins.isNotEmpty ? count_coins : 'N/A'}"),
              ),
            ),
            if(_isProcess == false) Card(
                child: ListTile(
                    leading: Icon(Icons.request_quote_outlined, size: 36),
                    title: Text("Montant des chèques: ${total_cheques.isNotEmpty ? total_cheques : 'N/A'}"),
                    subtitle: Text("Nombre de chèques: ${count_cheques.isNotEmpty ? total_cheques : 'N/A'}")
                )
            )
          ],
        ),
      ),
    );
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

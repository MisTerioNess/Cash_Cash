import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/animation.dart';

import 'package:image_picker/image_picker.dart';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'package:graphic/graphic.dart';

import '../main.dart';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:document_file_save_plus/document_file_save_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsx;

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Définition des mode.
enum ScreenMode { liveFeed, gallery }

class CardItem {
  String date;
  String nom;
  String total;
  String amountOfBills;
  String numberOfBills;
  String amountOfCoins;
  String numberOfCoins;
  String amountOfCheques;
  String numberOfCheques;
  bool isExpanded = false;

  CardItem({
    required this.date,
    required this.nom,
    required this.total,
    required this.amountOfBills,
    required this.numberOfBills,
    required this.amountOfCoins,
    required this.numberOfCoins,
    required this.amountOfCheques,
    required this.numberOfCheques
  });
}

/// classe utilitaire pour SharedPreferences
class MySharedPreferences {
  static const String _key = 'myMapKey';

  //#region Map
  static Future<void> saveMap(Map<String, dynamic> map) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(map);

    await prefs.setString(_key, jsonString);
  }


  static Future<Map<String, dynamic>> loadMap() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(_key);
    if (jsonString != null) {
      Map<String, dynamic> map = jsonDecode(jsonString);

      return map;
    }

    return {};
  }

  static Future<void> removeMap() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }
  //#endregion

  //#region List<Map>
  static Future<void> saveList(List<Map<String, dynamic>> list) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> jsonStringList = list.map((map) => jsonEncode(map)).toList();

    await prefs.setStringList(_key, jsonStringList);
  }

  static Future<List<Map<String, dynamic>>> loadList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? jsonStringList = prefs.getStringList(_key);
    if (jsonStringList != null) {
      List<Map<String, dynamic>> list = jsonStringList
          .map((jsonString) => jsonDecode(jsonString) as Map<String, dynamic>)
          .toList();

      return list;
    }

    return [];
  }

  static Future<void> removeList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }
  //#endregion

  /*
  TODO: historiser les dashboards
  _key: {
    nom: 'caca1aaaaaaaaaaaaaaa',
    total: '550',
    amountOfBills: '100',
    numberOfBills: '5',
    amountOfCoins: '50',
    numberOfCoins: '10',
    amountOfCheques: '400',
    numberOfCheques: '2'
  }
   */
}

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
class _CameraViewState extends State<CameraView> with TickerProviderStateMixin {
  ScreenMode _mode = ScreenMode.liveFeed;
  CameraController? _controller;
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
  bool isLoading = true;

  // texte d'un dashboard
  final TextEditingController _textEditingController = TextEditingController();
  String date = '';
  bool _isEditing = false;
  bool _isTextValid = true;
  String _initialText = 'Mon cash cash';

  // historique
  List<CardItem> cards = [];
  void fetchData() async {
    final cardItemList = await getCardItemList();
    setState(() {
      cards = cardItemList;
    });
  }
  Future<void> clearDataList() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('dataList');
  }

  // données
  late String total;
  late String totalBanknotes;
  late String countBanknotes;
  late Map<String, dynamic> banknotes;
  late String totalCoins;
  late String countCoins;
  late Map<String, dynamic> coins;
  late String totalCheques;
  late String countCheques;
  List<Map<String, dynamic>> dataChart = [];

  List imgCheques = [];

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  List<Color> chartColor = [
    const Color.fromARGB(255, 252,183,94),
    const Color.fromARGB(255, 130,71,207),
    const Color.fromARGB(255, 247,115,127),
    const Color.fromARGB(255, 252,183,94),
    const Color.fromARGB(255, 130,71,207),
    const Color.fromARGB(255, 247,115,127),
    const Color.fromARGB(255, 252,183,94),
    const Color.fromARGB(255, 130,71,207),
    const Color.fromARGB(255, 247,115,127),
  ];
  final ScreenshotController screenshotController = ScreenshotController();

  /// Redimensionne une image.
  ///
  /// [imageBytes] - les bytes de l'image à redimensionner.
  /// [newWidth] - la nouvelle largeur de l'image.
  /// [newHeight] - la nouvelle hauteur de l'image.
  ///
  /// Retourne les bytes de l'image redimensionnée, ou null si l'image ne peut pas être décodée.
  Future<Uint8List?> resizeImage(Uint8List imageBytes, int newWidth, int newHeight) async {
    // Décode l'image à partir de la liste de bytes.
    final img.Image? image = img.decodeImage(imageBytes);

    // Si l'image ne peut pas être décodée, retourne null.
    if (image == null) {
      return null;
    }

    // Redimensionne l'image.
    final resizedImage = img.copyResize(image, width: newWidth, height: newHeight);

    // Renvoie les bytes de l'image redimensionnée.
    return img.encodePng(resizedImage);
  }

  /// Télécharge une image sur un serveur et traite la réponse.
  ///
  /// [imageFile] - le fichier image à télécharger.
  Future<void> uploadImage(File imageFile) async {
    // L'URL de votre endpoint de téléchargement
    final uri = Uri.parse('http://149.202.49.224:8000/upload_image');

    try {
      // Créer et envoyer une requête multipart
      final response = await _sendMultipartRequest(uri, imageFile);

      // Traiter la réponse du serveur
      await _handleServerResponse(response);
    } catch (e) {
      print('Exception lors de l\'upload de l\'image: $e');
    }
  }

  Future<http.StreamedResponse> _sendMultipartRequest(Uri uri, File imageFile) async {
    final request = http.MultipartRequest('POST', uri);

    // Ajouter le fichier à la requête
    request.files.add(await http.MultipartFile.fromPath(
      'image', // le nom du paramètre POST pour le fichier
      imageFile.path,
      filename: path.basename(imageFile.path), // le nom du fichier à envoyer
    ));
    
    return await request.send();
  }


  Future<void> _handleServerResponse(http.StreamedResponse response) async {
    if (response.statusCode == 200) {
      print('Upload successful');

      // Extraire les informations de la réponse
      final responseBody = await response.stream.transform(utf8.decoder).join();
      _extractResponseData(jsonDecode(responseBody));

      _isProcess = false;
      setState(() {});
    } else {
      print('Upload failed with status: ${response.statusCode}');
    }
  }

  void _extractResponseData(Map<String, dynamic> responseBody) {
    print(responseBody);
    total = responseBody['total'];
    totalBanknotes = responseBody['total_banknotes'];
    countBanknotes = responseBody['count_banknotes'];
    banknotes = Map<String, dynamic>.from(responseBody['all_banknotes']);
    totalCoins = responseBody['total_coins'];
    countCoins = responseBody['count_coins'];
    coins = Map<String, dynamic>.from(responseBody['all_coins']);
    totalCheques = responseBody['total_cheques'];
    countCheques = responseBody['count_cheques'];
    imgCheques = responseBody['img_cheques'];

    _extractCoinsAndBanknotes(coins);
    _extractCoinsAndBanknotes(banknotes);
  }

  void _extractCoinsAndBanknotes(Map<String, dynamic> items) {
    for (var entry in items.entries) {
      if (entry.value != 0) {
        Map<String, dynamic> entries = {'genre': entry.key, 'sold': entry.value};
        dataChart.add(entries);
      }
    }
  }

  void resetCustomPaint() {
    // réinitialiser les bordures vertes du détecteur
    CustomPaint cp = CustomPaint();
    widget.resetCustomPaint(cp);
  }

  /// obtenir la date actuelle au format français
  String getCurrentDate() {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd/mm/yyyy').format(now);

    return formattedDate;
  }

  Future<void> addToDataList(Map<String, dynamic> newData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Récupérer la liste existante de SharedPreferences
    final dataListString = prefs.getString('dataList');
    List<Map<String, dynamic>> dataList = [];

    if (dataListString != null) {
      final decodedList = jsonDecode(dataListString);
      print("decodedList: ${decodedList}");

      if (decodedList is List<dynamic>) {
        dataList = decodedList.cast<Map<String, dynamic>>();
      }
    }

    // Ajouter la nouvelle donnée à la liste
    dataList.add(newData);

    // Sauvegarder la liste mise à jour dans SharedPreferences
    final dataListStringUpdated = jsonEncode(dataList);
    prefs.setString('dataList', dataListStringUpdated);
  }

  Future<List<CardItem>> getCardItemList() async {
    final List<CardItem> cardItemList = [];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final dataListString = prefs.getString('dataList');
    print("dataListString: ${dataListString}");

    if (dataListString != null) {
      final dataList = jsonDecode(dataListString) as List<dynamic>;

      for (var data in dataList) {
        final cardItem = CardItem(
          date: data['date'],
          nom: data['nom'],
          total: data['total'],
          amountOfBills: data['amountOfBills'],
          numberOfBills: data['numberOfBills'],
          amountOfCoins: data['amountOfCoins'],
          numberOfCoins: data['numberOfCoins'],
          amountOfCheques: data['amountOfCheques'],
          numberOfCheques: data['numberOfCheques']
        );

        print("passe dans for(var data in dataList) getCardItemList()");
        print("length: ${cardItemList.length}");
        cardItemList.add(cardItem);
      }
    }

    isLoading = false;
    return cardItemList;
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

    // historisation
    this.date = getCurrentDate();
    fetchData();

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
    _animationController.dispose();
    _textEditingController.dispose();
    clearDataList();
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
    if(_mode == ScreenMode.gallery) {
      _returnToGallery();
    } else {
      setState(() async {
        await _stopLiveFeed();
        _imageFile = null;
        resetCustomPaint();
        await _startLiveFeed();
      });
    }
  }

  /// valide la prise de la photo
  void _confirm() async {
    await _stopLiveFeed();
    setState(() {
      _showDashboard = true;
    });

    final path = _imageFile?.path;
    print("path: ${path}");
    _isProcess = true;
    uploadImage(File(path!));
  }

  /// depuis le dashboard, repartir dans la galerie
  void _returnToGallery() {
    setState(() {
      _showDashboard = false;
      dataChart = [];
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
    return CustomScrollView(
      slivers: [
        _imageFile != null
        ?
          _dashboard()
        :
        SliverToBoxAdapter(
          child: Image.asset(
            'assets/cc_icon_t.png',
            width: 300.0,
            height: 300.0,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0.0),
            child: ElevatedButton(
              child: Text('Image depuis la galerie'),
              onPressed: () => _getImage(ImageSource.gallery),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              child: Text('Prendre une photo'),
              onPressed: () => _switchScreenMode(),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Historique", style: TextStyle(fontSize: 20)),
            ),
          ),
        ),
        SliverFillRemaining(
          child: _historisation()
        ),
      ],
    );
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

                  // historisation
                  Map<String, dynamic> objHistorisation = {
                    'date': date,
                    'nom': _initialText,
                    'total': total,
                    'amountOfBills': totalBanknotes,
                    'numberOfBills': countBanknotes,
                    'amountOfCoins': totalCoins,
                    'numberOfCoins': countCoins,
                    'amountOfCheques': totalCheques,
                    'numberOfCheques': countCheques
                  };
                  addToDataList(objHistorisation);

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
                      child: CircularProgressIndicator(
                        color: Color.fromARGB(255, 130,71,207),
                      ),
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
                title: Text("Montant total: ${total.isNotEmpty ? '$total €' : 'N/A'}"),
              ),
            ),
            if(_isProcess == false) _editableText(),
            if(_isProcess== false) Text("Détails"),
            if(_isProcess == false) Card(
              child: ListTile(
                leading: Icon(Icons.payments_outlined, size: 36),
                title: Text("Montant des billets: ${totalBanknotes.isNotEmpty ? '$totalBanknotes €' : 'N/A'}"),
                subtitle: Text("Nombre de billets: ${countBanknotes.isNotEmpty ? countBanknotes : 'N/A'}"),
              ),
            ),
            if(_isProcess == false) Card(
              child: ListTile(
                leading: Icon(Icons.paid_outlined, size: 36),
                title: Text("Montant des pièces: ${totalCoins.isNotEmpty ? '$totalCoins €' : 'N/A'}"),
                subtitle: Text("Nombre de pièces: ${totalCoins.isNotEmpty ? totalCoins : 'N/A'}"),
              ),
            ),
            if(_isProcess == false) Card(
              child: ListTile(
                leading: Icon(Icons.request_quote_outlined, size: 36),
                title: Text("Montant des chèques: ${totalCheques.isNotEmpty ? '$totalCheques €' : 'N/A'}"),
                subtitle: Text("Nombre de chèques: ${countCheques.isNotEmpty ? countCheques : 'N/A'}"),
                trailing: IconButton(
                  icon: Icon(Icons.add_box_outlined),
                  onPressed: () {
                    // Votre fonction à exécuter lorsque l'icône est pressée
                    showChequeDetail(_imageFile!);
                  },
                ),
              ),
            ),
            if(_isProcess == false) Container(
              margin: const EdgeInsets.only(top: 10),
              width: 350,
              height: 300,
              child: Screenshot(
                controller: screenshotController,
                child: Chart(
                  data: dataChart,
                  variables: {
                    'genre': Variable(
                        accessor: (Map map) => map['genre'] as String
                    ),
                    'sold': Variable(
                        accessor: (Map map) => map['sold'] as num
                    ),
                  },
                  transforms: [
                    Proportion( // faire une somme des montants
                      variable: 'sold',
                      as: 'percent',
                    )
                  ],
                  marks: [
                    IntervalMark(
                      position: Varset('percent') / Varset('genre'),
                      label: LabelEncode(
                        encoder: (tuple) => Label(
                          "qte: ${tuple['sold'].toString()}\n"
                              "${tuple['genre'].toString()}",
                          LabelStyle(textStyle: Defaults.runeStyle),
                        ),
                      ),
                      color: ColorEncode(
                          variable: 'genre', values: chartColor),
                      modifiers: [StackModifier()],
                    )
                  ],
                  coord: PolarCoord(transposed: true, dimCount: 1),
                ),
              )
            ),
            if(_isProcess == false) ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 130,71,207),  // Changer la couleur de l'arrière-plan ici
              ),
              child: Text(
                'Télécharger au format Excel',
                style: TextStyle(color: Colors.white),  // Changer la couleur du texte ici
              ),
              onPressed: () {
                _downloadExcel(context);
              },
            )
          ],
      ),
    ),
    );
  }

  Future<InputImage?> downloadImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final file = File('${Directory.systemTemp.path}/image.jpg');
      await file.writeAsBytes(response.bodyBytes);
      print('Image téléchargée avec succès : ${file.path}');
      return InputImage.fromFilePath(file.path);
    } else {
      print('Échec du téléchargement de l image. Code d erreur : ${response.statusCode}');
      return null;
    }
  }

  Future showChequeDetail(XFile inputImage) async {
    String path = imgCheques[0];


    final InputImage? inputImage = await downloadImage('http://149.202.49.224:8000/$path');
    final recognizedText = await _textRecognizer.processImage(inputImage!);
    print(recognizedText.text);
    Navigator.pushNamed(context, '/chequeDetail', arguments: {'path': path, 'txt': recognizedText.text});
    print("TAble");
  }

  /// Télécharge un fichier Excel avec des données de tableau et une capture d'écran d'un widget.
  ///
  /// [context] - Le contexte BuildContext dans lequel la fonction est appelée.
  Future<void> _downloadExcel(BuildContext context) async {
    // Créer un nouveau document Excel et accéder à la première feuille de calcul.
    final xlsx.Workbook workbook = xlsx.Workbook();
    final xlsx.Worksheet sheet = workbook.worksheets[0];

    // Ajouter les en-têtes dans le fichier Excel
    _addHeaders(sheet);

    // Ajouter les données dans le fichier Excel
    _addData(sheet);

    // Ajouter une capture d'écran d'un widget au fichier Excel
    await _addScreenshot(sheet);

    // Enregistrer et sauvegarder le fichier Excel
    _saveWorkbook(workbook);

    // Afficher un dialogue indiquant que le téléchargement est terminé
    _showDownloadCompletedDialog(context);
  }

  void _addHeaders(xlsx.Worksheet sheet) {
    sheet.getRangeByName('A1').setText('Devise');
    sheet.getRangeByName('B1').setText('Quantité');
  }

  void _addData(xlsx.Worksheet sheet) {
    for (int i = 0; i < dataChart.length; i++) {
      sheet.getRangeByName("A${i+2}").setText(dataChart[i]['genre'].toString());
      sheet.getRangeByName("B${i+2}").setText(dataChart[i]['sold'].toString());
    }
  }

  Future<void> _addScreenshot(xlsx.Worksheet sheet) async {
    final Uint8List? imageBytes = await screenshotController.capture();
    if (imageBytes != null) {
      final Uint8List? resizedImageBytes = await resizeImage(imageBytes, 300, 250);
      sheet.pictures.addStream(
        2,  // ligne
        3,  // colonne
        resizedImageBytes!,
      );
    }
  }

  void _saveWorkbook(xlsx.Workbook workbook) {
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    Uint8List utf8bytes = Uint8List.fromList(bytes);
    DocumentFileSavePlus().saveFile(utf8bytes, "test.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
  }

  void _showDownloadCompletedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Téléchargement terminé"),
          content: Text("Le fichier a été téléchargé avec succès."),
          actions: <Widget>[
            TextButton(
              child: Text("Fermer"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Widget permettant de modifier le texte du dashboard en cours
  Widget _editableText() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isEditing = true;
        });
      },
      child: Row(
        children: [
          Expanded(
            child: _isEditing
                ? TextField(
              controller: _textEditingController,
              maxLength: 20,
              onChanged: (value) {
                setState(() {
                  _isTextValid = value.isNotEmpty;
                });
              },
              decoration: InputDecoration(
                hintText: 'Entrez un texte',
              ),
            )
                : Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Text(
                    '${this.date} - ${_initialText}',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                if (!_isEditing)
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                  ),
              ],
            ),
          ),
          if (_isEditing)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.check),
                  onPressed: _isTextValid
                      ? () {
                          setState(() {
                            _initialText = _textEditingController.text;
                            _isEditing = false;
                          });
                        }
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                    });
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Widget affichant l'historique dans la gallerie
  Widget _historisation() {
    ScrollController _scrollController = ScrollController();

    _scrollController.addListener(() {
      setState(() {
        if (_scrollController.position.pixels == 0.0) {
          _scrollController.animateTo(
            0,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    });

    return Stack(
      children: [
        FutureBuilder<List<CardItem>>(
          future: getCardItemList(),
          builder: (context, snapshot) {
            if (isLoading) {
              return CircularProgressIndicator();
            } else if(snapshot.hasData) {
              print("snapshot.hasData: ${snapshot.hasData}");
              cards = snapshot.data!;
              ListView.builder(
                controller: _scrollController,
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        card.isExpanded = !card.isExpanded;
                      });
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  '${card.date} - ${card.nom}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 5.0),
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: FittedBox(
                                    child: FloatingActionButton(
                                      backgroundColor: Color.fromARGB(255, 255, 200, 0),
                                      onPressed: () {
                                        print("caca edition");
                                      },
                                      child: Icon(Icons.edit, size: 40),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: FittedBox(
                                  child: FloatingActionButton(
                                    backgroundColor: Color.fromARGB(255, 255, 0, 0),
                                    onPressed: () {
                                      print("caca delete");
                                    },
                                    child: Icon(Icons.delete, size: 40),
                                  ),
                                ),
                              ),
                            ]),
                            SizedBox(height: 8),
                            if (card.isExpanded) ...[
                              Text('montant total: ${card.total}'),
                              SizedBox(height: 8),
                              Text('Montant des billets: ${card.amountOfBills}'),
                              Text('Nombre de billets: ${card.numberOfBills}'),
                              SizedBox(height: 8),
                              Text('Montant des pièces: ${card.amountOfCoins}'),
                              Text('Nombre de pièces: ${card.numberOfCoins}'),
                              SizedBox(height: 8),
                              Text('Montant des chèques: ${card.amountOfCheques}'),
                              Text('Nombre de chèques: ${card.amountOfCheques}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            } else if(snapshot.hasError) {
              return Text("Erreur lors du chargement des données.");
            }

            // Gérer le cas où il n'y a pas de données
            return Text("Aucune donnée disponible.");
          },
        )
      ],
    );
  }

  void removeCards(CardItem card) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    cards.remove(card);
    //prefs.remove(key);
  }

  Future _getImage(ImageSource source) async {
    setState(() {
      _imageFile = null;
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
    _imageFile = null;

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
      _imageFile = XFile(File(path).path);
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

  /// Transformer l'image de la caméra en image statique.
  ///
  /// [image] - L'image provenant de la caméra.
  InputImage? _inputImageFromCameraImage(CameraImage image) {

    // Récupère l'orientation du capteur de la caméra.
    final camera = cameras[_cameraIndex];
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);

    // Si l'orientation du capteur n'est pas détectée, retourne null.
    if (rotation == null) return null;

    // Récupère le format de l'image.
    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    // Si le format de l'image n'est pas détecté, ou si le format ne correspond pas
    // aux formats supportés (nv21 pour Android, bgra8888 pour iOS), retourne null.
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // Si l'image ne comporte pas exactement une seule plane, retourne null.
    // Les formats nv21 et bgra8888 ont tous deux une seule plane.
    if (image.planes.length != 1) return null;

    // Récupère la première (et unique) plane de l'image.
    final plane = image.planes.first;

    // Construit une InputImage à partir des bytes de la plane, avec les métadonnées appropriées.
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // utilisé seulement sur Android
        format: format, // utilisé seulement sur iOS
        bytesPerRow: plane.bytesPerRow, // utilisé seulement sur iOS
      ),
    );
  }

}

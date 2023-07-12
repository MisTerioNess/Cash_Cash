import 'package:universal_html/html.dart' as html1;
import 'package:graphic/graphic.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsx;
import 'package:document_file_save_plus/document_file_save_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

Dio dio = Dio();

class MyWebApp extends StatelessWidget {
  const MyWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cash_Cash',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Cash_Cash'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  PlatformFile? _imageFile;
  late final AnimationController _animationController;
  late final Animation<double> _animation;
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
  final ScreenshotController screenshotController = ScreenshotController();
  bool _isProcess = false;
  bool _isFinished = false;
  bool _isSelected = false;
  bool _isUpload = false;
  bool _isExcelOk = false;
  bool _showDashboard = false;
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


  Future<void> pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result == null) return;

      setState(() {
        _imageFile = result.files.first;
        _isSelected = true;
        _isUpload = false;
        _isExcelOk = false;
      });
      print('Image selected: ${_imageFile!.name}');

    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void send() async {
    _isProcess = true;
    if (_imageFile == null) {
      print('No image selected.');
      return;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'http://149.202.49.224:8000/upload_image_web'), // URL du server
      );

      final fileBytes = _imageFile!.bytes!;
      request.files.add(
        http.MultipartFile.fromBytes(
            'image',
            fileBytes,
            filename: _imageFile!.name,
            contentType: MediaType('image', 'PNG')
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.transform(utf8.decoder).join();
        _isProcess = false;
        Map<String, dynamic> json = jsonDecode(responseBody);
        /*print(list);
        String responseBodyQuotes = list[0].replaceAll('"', '');
        print(responseBodyQuotes);
        Map<String, dynamic> json = list[1];
        _isFinished = true;
        _isUpload = true;
        _extractResponseData(json);*/
        String imgUrl = json["img"];
        print(responseBody);

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Objet trouvé'),
              content: Image.network(
                "http://149.202.49.224:8000/$imgUrl",
                alignment: Alignment.center,
                width: 800,
                height: 600,
              ),

              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Fermer'),
                ),
              ],
            );
          },
        );
      } else {
        print('Error uploading image. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending image: $e');
    }
  }

  void _extractResponseData(Map<String, dynamic> json) {
    total = json['total'];
    totalBanknotes = json['total_banknotes'];
    countBanknotes = json['count_banknotes'];
    banknotes = Map<String, dynamic>.from(json['all_banknotes']);
    totalCoins = json['total_coins'];
    countCoins = json['count_coins'];
    coins = Map<String, dynamic>.from(json['all_coins']);
    totalCheques = json['total_cheques'];
    countCheques = json['count_cheques'];
    _isExcelOk = true;
    _imageFile = null;

    _extractCoinsAndBanknotes(coins);
    _extractCoinsAndBanknotes(banknotes);
    setState(() {
      _showDashboard = true;
    });
  }
  void _extractCoinsAndBanknotes(Map<String, dynamic> items) {
    for (var entry in items.entries) {
      if (entry.value != 0) {
        Map<String, dynamic> entries = {'genre': entry.key, 'sold': entry.value};
        dataChart.add(entries);
      }
    }
  }
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

    launchUrl(
        "data:application/octet-stream;charset=utf-16le;base64,${base64.encode(bytes)}" as Uri);
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
  /// Initialisation de l'état de base.
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )
      ..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 8).animate(_animationController);
  }

  @override
  Widget build(BuildContext context) {
    if(_showDashboard == true){
      return _dashboard();}
    else{return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Cash Cash"),
        backgroundColor: Color.fromARGB(255, 247, 115, 127),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            "cc_icon.png",
          ),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            if (_imageFile != null)
            //Text(_txt2),
              Image.memory(
                Uint8List.fromList(_imageFile!.bytes!),
                alignment: Alignment.center,
                width: 800,
                height: 600,
              ),
            if (_imageFile == null)
              Text("Veuillez choisir une image"),
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
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Color.fromARGB(255, 130, 71, 207),
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Tooltip(
              message: 'Graphique',
              child: FloatingActionButton(
                onPressed: () {},
                backgroundColor: Color.fromARGB(255, 130, 71, 207),
                child: const Icon(
                  Icons.stacked_bar_chart,
                  color: Colors.white60,
                ),
                tooltip: 'Graphique',
              ),
            ),
            Tooltip(
              message: 'Envoi de l\'image',
              child: FloatingActionButton(
                onPressed: send,
                backgroundColor: Color.fromARGB(255, 130, 71, 207),
                child: const Icon(
                  Icons.upload_outlined,
                  color: Colors.white60,
                ),
                tooltip: 'Envoi de l\'image',
              ),
            ),
            const SizedBox(
              width: 20,
            ),
            Tooltip(
              message: 'Télécharger sous format excel \'.xlsv\'',
              child: FloatingActionButton(
                onPressed: () {},
                backgroundColor: Color.fromARGB(255, 130, 71, 207),
                child: const Icon(
                  Icons.file_download,
                  color: Colors.white60,
                ),
                tooltip: 'Télécharger sous format excel \'.xlsv\'',
              ),
            ),
            Tooltip(
              message: 'Paramètre',
              child: FloatingActionButton(
                onPressed: () {},
                backgroundColor: Color.fromARGB(255, 130, 71, 207),
                child: const Icon(
                  Icons.settings,
                  color: Colors.white60,
                ),
                tooltip: 'Paramètre',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _animation,
        builder: (BuildContext context, Widget? child) {
          return Transform.translate(
            offset: Offset(0, -_animation.value),
            child: child,
          );
        },
        child: FloatingActionButton(
          onPressed: pickImage,
          backgroundColor: Color.fromARGB(255, 252, 183, 94),
          child: const Icon(Icons.image_outlined),
          tooltip: 'Pick Image',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );}

  }
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
            if(_isProcess == false) Text("Détails"),
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
                subtitle: Text("Nombre de pièces: ${countCoins.isNotEmpty ? countCoins : 'N/A'}"),
              ),
            ),
            if(_isProcess == false) Card(
                child: ListTile(
                    leading: Icon(Icons.request_quote_outlined, size: 36),
                    title: Text("Montant des chèques: ${totalCheques.isNotEmpty ? '$totalCheques€' : 'N/A'}"),
                    subtitle: Text("Nombre de chèques: ${countCheques.isNotEmpty ? totalCheques : 'N/A'}")
                )
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
            // if(_isProcess == false) ElevatedButton(
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Color.fromARGB(255, 130,71,207),  // Changer la couleur de l'arrière-plan ici
            //   ),
            //   child: Text(
            //     'Télécharger au format Excel',
            //     style: TextStyle(color: Colors.white),  // Changer la couleur du texte ici
            //   ),
            //   onPressed: () {
            //     _downloadExcel(context);
            //   },
            // )
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Color.fromARGB(255, 130, 71, 207),
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Tooltip(
              message: 'Graphique',
              child: FloatingActionButton(
                onPressed: () {},
                backgroundColor: Color.fromARGB(255, 130, 71, 207),
                child: const Icon(
                  Icons.stacked_bar_chart,
                  color: Colors.white60,
                ),
                tooltip: 'Graphique',
              ),
            ),
            Tooltip(
              message: 'Envoi de l\'image',
              child: FloatingActionButton(
                onPressed: send,
                backgroundColor: Color.fromARGB(255, 130, 71, 207),
                child: const Icon(
                  Icons.upload_outlined,
                  color: Colors.white60,
                ),
                tooltip: 'Envoi de l\'image',
              ),
            ),
            const SizedBox(
              width: 20,
            ),
            Tooltip(
              message: 'Télécharger sous format excel \'.xlsv\'',
              child: FloatingActionButton(
                onPressed: () {},
                backgroundColor: Color.fromARGB(255, 130, 71, 207),
                child: const Icon(
                  Icons.file_download,
                  color: Colors.white60,
                ),
                tooltip: 'Télécharger sous format excel \'.xlsv\'',
              ),
            ),
            Tooltip(
              message: 'Paramètre',
              child: FloatingActionButton(
                onPressed: () {},
                backgroundColor: Color.fromARGB(255, 130, 71, 207),
                child: const Icon(
                  Icons.settings,
                  color: Colors.white60,
                ),
                tooltip: 'Paramètre',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _animation,
        builder: (BuildContext context, Widget? child) {
          return Transform.translate(
            offset: Offset(0, -_animation.value),
            child: child,
          );
        },
        child: FloatingActionButton(
          onPressed: pickImage,
          backgroundColor: Color.fromARGB(255, 252, 183, 94),
          child: const Icon(Icons.image_outlined),
          tooltip: 'Pick Image',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
/*Future<void> _downloadExcel(BuildContext context) async {
  // Créer un nouveau document Excel et accéder à la première feuille de calcul.
  final excel = Excel.createExcel();
  final Sheet sheet = excel['SheetName'];

  // Ajouter les en-têtes dans le fichier Excel
  _addHeaders(sheet);

  // Ajouter les données dans le fichier Excel
  _addData(sheet);

  // Ajouter une capture d'écran d'un widget au fichier Excel
  await _addScreenshot(sheet);

  // Enregistrer et sauvegarder le fichier Excel
  _saveExcel(excel);

  // Afficher un dialogue indiquant que le téléchargement est terminé
  _showDownloadCompletedDialog(context);
}
void _addHeaders(Sheet sheet) {
  sheet.cell(CellIndex.indexByString('A1')).value = 'devise';
  sheet.cell(CellIndex.indexByString('A1')).value = 'Quantité';
}

void _addData(Sheet sheet) {
  for (int i = 0; i < dataChart.length; i++) {
    sheet.cell(CellIndex.indexByString("A${i+2}")).value = dataChart[i]['genre'].toString();
    sheet.cell(CellIndex.indexByString("B${i+2}")).value = dataChart[i]['genre'].toString();
  }
}

Future<void> _addScreenshot(Sheet sheet) async {
  final Uint8List? imageBytes = await screenshotController.capture();
  if (imageBytes != null) {
    final Uint8List? resizedImageBytes = await resizeImage(imageBytes, 300, 250);
    sheet.(
  2,  // ligne
  3,  // colonne
  resizedImageBytes!,
  );
  }
}
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

void _saveExcel(Excel excel) {
  excel.save(fileName: "My_Excel_File_Name.xlsx");
  final List<int> bytes = excel.save()!.toList();
    excel.isUndefinedOrNull;

    Uint8List utf8bytes = Uint8List.fromList(bytes);
    DocumentFileSavePlus().saveFile(utf8bytes, "test.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
}*/

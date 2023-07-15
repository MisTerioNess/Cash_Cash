import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;


class ChequeDetail extends StatefulWidget {
  final int id;
  final String imageFile;
  final String recognizedText;
  final List imgCheques;


  ChequeDetail({
    Key? key,
    required this.imgCheques,
    required this.id,
    required this.imageFile,
    required this.recognizedText,
  }) : super(key: key);


  @override
  State<ChequeDetail> createState() => ChequeDetailPage();
}

class ChequeDetailPage  extends State<ChequeDetail> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 8).animate(_animationController);
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

  Future showChequeDetail(path, id) async {
    final InputImage? inputImage = await downloadImage('http://149.202.49.224:8000/$path');
    final recognizedText = await _textRecognizer.processImage(inputImage!);
    Navigator.pushNamed(context, '/chequeDetail', arguments: {'imgCheques': widget.imgCheques, 'id': id, 'path': path, 'txt': recognizedText.text});
  }

  @override
  void dispose() {
    _animationController.dispose();  // C'est ici que vous libérez les ressources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            Text("Detail du chèque ${widget.id}"),
          ],
        ),
        actions: <Widget>[
          if(widget.imgCheques.length > widget.id)
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Next Choice',
            onPressed: () {
              showChequeDetail(widget.imgCheques[widget.id], widget.id + 1);
            },
          ),
        ],
      ),
      body: ListView(shrinkWrap: true, children: [
          Center(
          child: Column(
            children: [
              SizedBox(
                height: 550,
                width: 400,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.network(
                      'http://149.202.49.224:8000/${widget.imageFile}',
                      height: 550,
                      width: 400,
                    ),
                    Align(
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
                    //if (widget.customPaint != null) widget.customPaint!,
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child:  Text(widget.recognizedText),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
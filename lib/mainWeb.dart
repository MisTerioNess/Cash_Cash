import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

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

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin{
  PlatformFile? _imageFile;
  bool _isImage = false;
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  Future<void> pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result == null) return;

      setState(() {
        _imageFile = result.files.first;
      });
      print('Image selected: ${_imageFile!.name}');
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void send() async {
    if (_imageFile == null) {
      print('No image selected.');
      return;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/upload_image'), // URL du server
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
        String responseBodyQuotes = responseBody.replaceAll('"', '');
        print(responseBodyQuotes);
        _isImage = true;

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Image Viewer'),
              content: Image.network(
                'http://127.0.0.1:8000/$responseBodyQuotes',
                alignment: Alignment.center,
                width: 800,
                height: 600,
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close'),
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

  /// Initialisation de l'état de base.
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 8).animate(_animationController);
  }

  @override
  Widget build(BuildContext context) {
    home:return Scaffold(
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
                Image.memory(
                  Uint8List.fromList(_imageFile!.bytes!),
                  alignment: Alignment.center,
                  width: 800,
                  height: 600,
                ),
              if(_isImage == false) Align(
                alignment: Alignment.topCenter,
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
            ]
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
              message: 'Graph',
              child: IconButton(
                icon: const Icon(
                  Icons.stacked_bar_chart,
                  color: Colors.white60,
                ),
                onPressed: () {},
              ),
            ),
            Tooltip(
              message: 'Import/Export',
              child: IconButton(
                icon: const Icon(
                  Icons.import_export_sharp,
                  color: Colors.white60,
                ),
                onPressed: send,
              ),
            ),
            const SizedBox(
              width: 20,
            ),
            Tooltip(
              message: 'Notifications',
              child: IconButton(
                icon: const Icon(
                  Icons.notifications,
                  color: Colors.white60,
                ),
                onPressed: () {},
              ),
            ),
            Tooltip(
              message: 'Settings',
              child: IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white60,
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickImage,
        backgroundColor: Color.fromARGB(255, 252, 183, 94),
        child: const Icon(Icons.image_outlined),
        tooltip: 'Pick Image',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
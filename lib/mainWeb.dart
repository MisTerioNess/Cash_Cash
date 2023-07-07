import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

Dio dio = Dio();

Dio dio = Dio();
PlatformFile? _imageFile;
Future<void> pickImage() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result == null) return;

    _imageFile = result.files.first;
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
      Uri.parse('http://149.202.49.224:8000/upload_image'), // Replace with your server URL
    );

    final fileBytes = _imageFile!.bytes!;
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        fileBytes,
        filename: _imageFile!.name,
      ),
    );

    final response = await request.send();

    //final responseBody = await response.stream.transform(utf8.decoder).join();
    //print(responseBody);
    if (response.statusCode == 200) {
      print('Image uploaded successfully.');
    } else {
      print('Error uploading image. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error sending image: $e');
  }
}

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

class _MyHomePageState extends State<MyHomePage> {
  PlatformFile? _imageFile;

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
  }

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
                  alignment: Alignment.bottomRight,
                  width: 800,
                  height: 600,
                )
              ]
            ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Color.fromARGB(255,130,71,207),
        title: const Text("Cash_Cash"),
        backgroundColor: Colors.blueGrey,
      ),
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // If image file is not null, display it using Image widget
              if (_imageFile != null)
                Image.memory(
                  Uint8List.fromList(_imageFile!.bytes!),
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                ),
            ],
          )
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.blueGrey,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(
                Icons.stacked_bar_chart,
                color: Colors.white60,
              ),
              onPressed:(){},
            ),
            IconButton(
              icon: const Icon(
                Icons.import_export_sharp,
                color: Colors.white60,
              ),
              onPressed: send,
            ),
            const SizedBox(
              width: 20,
            ),
            IconButton(
              icon: const Icon(
                Icons.notifications,
                color: Colors.white60,
              ),
              onPressed:(){},
            ),
            IconButton(
              icon: const Icon(
                Icons.settings,
                color: Colors.white60,
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: pickImage,
          backgroundColor: Color.fromARGB(255,252,183,94),
          child: const Icon(Icons.image_outlined)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
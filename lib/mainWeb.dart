import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
      Uri.parse('http://127.0.0.1:8005/image'), // Replace with your server URL
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

  /// Initialisation de l'état de base.
  @override
  void initState() {
    super.initState();

    // querySelector('#pickImage')?.onClick.listen((event) {
    //   pickImage();
    // });
    //
    // querySelector('#send')?.onClick.listen((event) {
    //   send();
    // });
  }

  /*void request() async {
    Response response;
    response = await dio.get('/test?id=12&name=dio');
    print(response.data.toString());
    // The below request is the same as above.

    response = await dio.get(
      '/test',
      queryParameters: {'id': 12, 'name': 'dio'},
    );
    print(response.data.toString());
  }*/

  @override
  Widget build(BuildContext context) {
    home:return Scaffold(
      appBar: AppBar(
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
                color: Colors.cyanAccent,
              ),
              onPressed:(){},
            ),
            IconButton(
              icon: const Icon(
                Icons.play_for_work_rounded,
                color: Colors.redAccent,
              ),
              onPressed: send,
            ),
            const SizedBox(
              width: 20,
            ),
            IconButton(
              icon: const Icon(
                Icons.notifications,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: pickImage,
          //_openImagePicker;
          backgroundColor: Colors.redAccent,
          child: const Icon(Icons.image_outlined)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
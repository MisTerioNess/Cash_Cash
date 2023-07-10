import 'dart:io';
import 'package:cash_cash/module/painters/paintersText.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class ChequeDetail extends StatefulWidget{
  @override
  State<ChequeDetail> createState() => ChequeDetailPage();
}

class ChequeDetailPage  extends State<ChequeDetail> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 8).animate(_animationController);
  }

  @override
  Widget build(BuildContext context) {
    final arguments = (ModalRoute.of(context)?.settings.arguments ?? <String, dynamic>{}) as Map;
    final String? imageFile = arguments["path"] as String? ;
    final String recognizedText = arguments["txt"] as String;
    // Utilisez imageFile pour afficher les détails du chèque

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
            Text("Detail du chèque"),
          ],
        ),
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
                      'http://149.202.49.224:8000/$imageFile',
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
                child: Text(recognizedText),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
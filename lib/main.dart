import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Backdrop issue Demo Flutter',
      home: BackDropDemo(),
    );
  }
}

class BackDropDemo extends StatefulWidget {
  const BackDropDemo({super.key});

  @override
  State<BackDropDemo> createState() => _BackDropDemoState();
}

class _BackDropDemoState extends State<BackDropDemo> {
  bool toggleNativeView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: GestureDetector(
          onTap: _toggle,
          child: Stack(
            children: [
              if (toggleNativeView)
                const NativeView()
              else
                Center(child: Image.network('https://picsum.photos/536/354')),
              Center(
                child: ClipOval(
                  child: ColoredBox(
                    color: Colors.black.withOpacity(0.5),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 30,
                        sigmaY: 30,
                      ),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('Hello World'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle() {
    setState(() {
      toggleNativeView = !toggleNativeView;
    });
  }
}

class NativeView extends StatelessWidget {
  const NativeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      child: UiKitView(
        viewType: 'id1',
        layoutDirection: TextDirection.ltr,
        creationParamsCodec: StandardMessageCodec(),
      ),
    );
  }
}

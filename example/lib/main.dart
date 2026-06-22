import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _artifactStatus = 'Loading...';
  final _rgbSdkFlutterPlugin = const RgbSdkFlutter();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    String artifactStatus;
    try {
      final info = await _rgbSdkFlutterPlugin.nativeArtifactInfo();
      artifactStatus = '${info.platform} | RLN ${info.rlnVersion}';
    } on PlatformException {
      artifactStatus = 'Failed to get native artifact info.';
    }

    if (!mounted) return;

    setState(() {
      _artifactStatus = artifactStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RGB SDK Flutter',
      home: Scaffold(
        appBar: AppBar(title: const Text('RGB SDK Flutter')),
        body: Center(
          child: Text(
            'Native artifact: $_artifactStatus',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

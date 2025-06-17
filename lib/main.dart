import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fbla_finance/pages/transactions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fbla_finance/backend/widget_tree.dart';
import 'package:fbla_finance/pages/awards_page.dart';
import 'package:fbla_finance/pages/home_page.dart';
import 'package:fbla_finance/pages/settings_page.dart';
import 'package:fbla_finance/pages/welcome_screen.dart';
import 'package:fbla_finance/backend/widget_tree.dart';
import 'package:fbla_finance/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_preview/device_preview.dart';
import 'package:fbla_finance/backend/custom_plugin.dart';
import 'dart:io';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseAuth.instanceFor(app: app);
  FirebaseFunctions.instanceFor(app: app);
  runApp(
    DevicePreview(
      enabled: true,
      tools: const [
        ...DevicePreview.defaultTools,
        CustomPlugin(),
      ],
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}):super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       // ignore: deprecated_member_use
       useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData(fontFamily: 'Roboto'),
      debugShowCheckedModeBanner: false,
      home: WidgetTree(),
    );
  }
}
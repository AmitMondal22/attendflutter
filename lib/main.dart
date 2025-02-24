import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:attend_master/utils/global_bindings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'navigation/app_routes.dart';
import 'navigation/route_names.dart';

Future<void> main() async {
  RenderErrorBox.backgroundColor = Colors.black26;
  RenderErrorBox.textStyle = ui.TextStyle(color: Colors.white);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark));
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attend Master',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
          useMaterial3: false),
      getPages: AppRoutes.instance.routes(),
      initialRoute: RouteNames.splash,
      initialBinding: GlobalBindings(),
    );
  }
}

import 'package:flutter/material.dart';
// import 'package:safety_pal/pages/about_user.dart';
// import 'package:safety_pal/pages/add_guardians.dart';
import 'package:safety_pal/pages/heat_map.dart';
// import 'package:safety_pal/pages/home_page.dart';
import 'package:safety_pal/pages/kids_navigation.dart';
import 'package:safety_pal/pages/register.dart';
import 'package:safety_pal/pages/safe_zones.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safety Pal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SignUpScreen(),
      routes: {
        '/safeZones': (context) => SafeZoneScreen(),
        '/dangerZones': (context) => HeatMapScreen(),
        '/kidsNavi': (context) => SafeNavigationApp(),
      },
    );
  }
}

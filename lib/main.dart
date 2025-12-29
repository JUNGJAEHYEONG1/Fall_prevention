import 'package:flutter/material.dart';
import 'screens/frt_screen.dart';
import 'screens/tug_screen.dart';
import 'screens/rom_screen.dart';
import 'screens/survey_screen.dart';

void main() {
  runApp(const FallRiskScreenApp());
}

class FallRiskScreenApp extends StatelessWidget {
  const FallRiskScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Risk Screen',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    FRTScreen(),
    TUGScreen(),
    ROMScreen(),
    SurveyScreen(),
  ];

  static const List<String> _screenTitles = <String>[
    'Forward Reach Test (FRT)',
    'Timed Up and Go (TUG)',
    'Range of Motion (ROM)',
    'Survey',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitles[_selectedIndex]),
      ),
      body: Center(
        child: _screens.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.transfer_within_a_station),
            label: 'FRT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_walk),
            label: 'TUG',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.accessibility_new),
            label: 'ROM',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Survey',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
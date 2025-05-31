import 'package:flutter/material.dart';

import 'location_tracking_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.teal[300],
        title: Text("Home Page"),
      ),

      body: Container(
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => LocationTrackingPage())),
          child: Text("Next Page",
            style: TextStyle(
              fontSize: 18,
              color: Colors.teal,
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      ),
    );
  }
}

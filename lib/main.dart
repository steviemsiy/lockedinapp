import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;



Future<String> fetchDistance() async {
  final response =
  await http.get(Uri.http('192.168.1.22:1880', 'front'));

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return response.body;
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to Access Sensor Data');
  }
}

Future<String> setupTimedFetch() {
  Timer.periodic(Duration(milliseconds: 1000), (timer) {
      try {
        return fetchDistance();
      }
      catch (e) {
        return "Error in Reaching Server";
      }
    });
}

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  MyApp({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<String> futureDistance;

  String messageTitle = "Empty";
  String notificationAlert = "alert";

  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  @override
  void initState() {
    super.initState();

    futureDistance = setupTimedFetch();



    _firebaseMessaging.configure(
      onMessage: (message) async{
        setState(() {
          messageTitle = message["notification"]["title"];
          notificationAlert = "New Notification Alert";
        });

      },
      onResume: (message) async{
        setState(() {
          messageTitle = message["data"]["title"];
          notificationAlert = "Application opened from Notification";
        });

      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Locked In',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Locked In'),
        ),
        body: Center(
          child:
          /*FutureBuilder<String>(
            future: futureDistance,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text(snapshot.data);
              } else if (snapshot.hasError) {
                return Text("${snapshot.error}");
              }

              // By default, show a loading spinner.
              return CircularProgressIndicator();
            },
          ),*/
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  notificationAlert,
                ),
                Text(
                  messageTitle,
                  style: Theme.of(context).textTheme.headline4,
                ),
              ],
            ),
        ),

      ),
    );
  }
}
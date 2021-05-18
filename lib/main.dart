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



void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  MyApp({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<String> futureDistance;
  int current = -1, prev = -1, difference;
  Text output;
  String messageTitle = "Empty";
  String notificationAlert = "alert";

  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  @override
  Future<void> initState()  {
    super.initState();

    setupTimedFetch();

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

  setupTimedFetch() {
    Timer.periodic(Duration(milliseconds: 1000), (timer) {
      setState(() {
        futureDistance = fetchDistance();
      });
    });
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
        body: Center (
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
          FutureBuilder<String>(
            future: futureDistance,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                //return Text(snapshot.data);
                current = int.parse(snapshot.data);
                difference = current - prev;
                if (difference.abs() > 3 && prev != -1) {
                 showDoorOpen(context);
                } else {
                  output = Text(snapshot.data);
                }
                prev = current;
                return output;
              } else if (snapshot.hasError) {
                return Text("${snapshot.error}");
              }
              // By default, show a loading spinner.
              return CircularProgressIndicator();
            },
          ),
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

  showDoorOpen(BuildContext context) async {
    await Future.delayed(Duration(microseconds: 2));
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('A DOOR HAS BEEN OPENED'),
            content: SingleChildScrollView(
              child: ListBody(
                children: const <Widget>[
                  Text('A door sensor has determined a door was opened in your house!'),
                  Text('Was this you?'),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: const Text('Yes'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop('dialog');
                },
              ),
              FlatButton(
                  child: const Text('No')
              ),
            ],
          );
        });
  }
}
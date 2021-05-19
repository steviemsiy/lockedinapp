import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final FlutterAppAuth appAuth = FlutterAppAuth();
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

const AUTH0_DOMAIN = 'dev-63ucptcl.us.auth0.com';
const AUTH0_CLIENT_ID = 'bZRHZKBibdWn5BI8PUxdefYGgUork0mF';

const AUTH0_REDIRECT_URI = 'demo://dev-63ucptcl.us.auth0.com/android/com.example.locked_in_app/callback';
const AUTH0_ISSUER = 'https://$AUTH0_DOMAIN';

bool isLoggedIn = false;
bool isNotSetup = true;
bool isDoorOpen = false;
bool isConfigured = false;
bool isBusy = false;

String RPIP = '192.168.1.22:1880';

Future<String> fetchDistance() async {
  final response =
  await http.get(Uri.http(RPIP, 'front'));

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
  String errorMessage;

  @override
  Future<void> initState()  {
    initAction();
    super.initState();

  }

  void initAction() async {
    final storedRefreshToken = await secureStorage.read(key: 'refresh_token');
    if (storedRefreshToken == null) return;

    setState(() {
      isBusy = true;
    });

    try {
      final response = await appAuth.token(TokenRequest(
        AUTH0_CLIENT_ID,
        AUTH0_REDIRECT_URI,
        issuer: AUTH0_ISSUER,
        refreshToken: storedRefreshToken,
      ));

      final idToken = parseIdToken(response.idToken);

      secureStorage.write(key: 'refresh_token', value: response.refreshToken);

      setState(() {
        isBusy = false;
        isLoggedIn = true;
      });
    } catch (e, s) {
      print('error on refresh token: $e - stack: $s');
      logoutAction();
    }
  }

  void logoutAction() async {
    await secureStorage.delete(key: 'refresh_token');
    setState(() {
      isLoggedIn = false;
      isBusy = false;
    });
  }

  Map<String, dynamic> parseIdToken(String idToken) {
    final parts = idToken.split(r'.');
    assert(parts.length == 3);

    return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
  }

  Future<void> loginAction() async {
    setState(() {
      isBusy = true;
      errorMessage = '';
    });

    try {
      final AuthorizationTokenResponse result =
      await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AUTH0_CLIENT_ID,
          AUTH0_REDIRECT_URI,
          issuer: 'https://$AUTH0_DOMAIN',
          scopes: ['openid', 'profile', 'offline_access'],
          // promptValues: ['login']
        ),
      );

      final idToken = parseIdToken(result.idToken);

      await secureStorage.write(
          key: 'refresh_token', value: result.refreshToken);

      setState(() {
        isBusy = false;
        isLoggedIn = true;
      });
    } catch (e, s) {
      print('login error: $e - stack: $s');

      setState(() {
        isBusy = false;
        isLoggedIn = false;
        errorMessage = e.toString();
      });
    }
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
          child: isBusy
          ? CircularProgressIndicator()
          :!isLoggedIn
            ? Login(loginAction(), errorMessage)
              : isNotSetup
              ? Settings()
              : Sensor()
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
                  child: const Text('No'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop('dialog');
                    isDoorOpen = true;
                },
              ),
            ],
          );
        });
  }
}

class Login extends StatelessWidget {
  final loginAction;
  final String loginError;

  const Login(this.loginAction, this.loginError);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        RaisedButton(
          onPressed: () {
            loginAction();
          },
          child: Text('Login'),
        ),
        Text(loginError ?? ''),
      ],
    );
  }
}

class SecurityRecs extends StatelessWidget {
   @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text('Our recommendation is to contact the Authorities or a neighbor to check in on your house.'),
        RaisedButton(
          child: const Text("Return"),
          onPressed: () {
            isDoorOpen = false;
          },
        )
      ],
    );
  }
}

class Settings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TextFormField(
          onChanged: (value) {
            RPIP = value;
          },
          decoration: const InputDecoration(
              labelText: 'Enter the IP address of the Raspberry Pi',
              hintText: 'IP Address:Port of Node-RED'
          ),
          validator: (String value) {
            if (value == null || value.isEmpty) {
              return 'Please enter something';
            }
            return null;
          },
        ),
        RaisedButton(
          child: const Text('Save Settings'),
          onPressed: () {
            isNotSetup = false;
          },
        )
      ]
    );
  }
}

class Sensor extends StatefulWidget {
  Sensor({Key key}) : super(key: key);

  @override
  _SensorState createState() => _SensorState();
}

class _SensorState extends State<MyApp> {
  Future<String> futureDistance;
  int current = -1,
      prev = -1,
      difference;
  Text output;
  String messageTitle = "Empty";
  String notificationAlert = "alert";
  String errorMessage;

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
                child: const Text('No'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop('dialog');
                  isDoorOpen = true;
                },
              ),
            ],
          );
        });
  }
}

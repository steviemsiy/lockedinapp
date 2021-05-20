import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';

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

bool dialogShowing = false;

const int ENTRIES = 5;

int next = 0, total = 0;
String fullList = '';
List<String> lastEntries = new List(ENTRIES);

String RPIP = ''; //'192.168.1.22:1880';
String port = '';
String route = '';

Future<String> fetchDistance() async {
  String nrURL = RPIP + ":" + port;
  final response =
  await http.get(Uri.http(nrURL, route));

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
  void initState()  {
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

  void saveSettings() async {
    setState(() {
      isNotSetup = false;
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
                ? Login(loginAction, errorMessage)
                : isNotSetup
                ? Settings(saveSettings: saveSettings)
                : Sensor(logoutAction: logoutAction)
        ),
      ),
    );
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

class Settings extends StatefulWidget {
  final saveSettings;
  //const Sensor(this.logoutAction);

  Settings({Key key, this.saveSettings}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState(key, saveSettings);
}

class _SettingsState extends State<Settings> {
  final passKey;
  final saveSettings;

  _SettingsState(this.passKey, this.saveSettings);

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextFormField(
              onChanged: (value) {
                RPIP = value;
              },
              decoration: const InputDecoration(
                  labelText: 'Enter the IP address of the Raspberry Pi',
                  hintText: '127.0.0.1'
              ),
              validator: (String value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter something';
                } else if (!value.contains(".")){
                  return 'Please enter a valid URL';
                }
                return null;
              },
            ),
            TextFormField(
              onChanged: (value) {
                port = value;
              },
              decoration: const InputDecoration(
                labelText: 'Enter the Port Node-RED is running on: ',
                hintText: '1880'
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (String value) {
                final isDigitsOnly = int.tryParse(value);
                if (value == null || value.isEmpty) {
                  return 'Please enter something';
                }
                return null;
              },
            ),
            TextFormField(
              onChanged: (value) {
                route = value;
              },
              decoration: const InputDecoration(
                  labelText: 'Enter the directory specified on Node-RED: ',
                  hintText: '/front'
              ),
              validator: (String value) {
                final isDigitsOnly = int.tryParse(value);
                if (value == null || value.isEmpty) {
                  return 'Please enter something';
                } else if (!value.contains("/")){
                  return 'Please enter the valid custom setting from Node-RED';
                }
                return null;
              },
            ),
            RaisedButton(
              child: const Text('Save Settings'),
              onPressed: () {
                if (_formKey.currentState.validate()) {
                  // If the form is valid, display a snackbar. In the real world,
                  // you'd often call a server or save the information in a database.
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Configuration Complete')));
                  saveSettings();
                }
              },
            )
          ]
      ),
    );
  }
}

class Sensor extends StatefulWidget {
  final logoutAction;

  //const Sensor(this.logoutAction);

  Sensor({Key key, this.logoutAction}) : super(key: key);

  @override
  _SensorState createState() => _SensorState(key, logoutAction);
}

class _SensorState extends State<Sensor> {
  final passkey;
  final logoutAction;

  _SensorState(this.passkey, this.logoutAction);

  Future<String> futureDistance;
  int current = -1,
      prev = -1,
      difference;
  Text output;
  String proximity;
  Text proxStatus;
  String messageTitle = "";
  String notificationAlert = "An alert will appear when a Door Opens";
  String errorMessage;
  String totalOutput;
  Text display;

  /*int oldest = 0;
  int newest = -1;
  bool firstFive = true;*/


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
      if(!isLoggedIn){
        timer.cancel();
      }
      setState(() {
        if (!dialogShowing) {
          futureDistance = fetchDistance();
        }
        notificationAlert = "Five Most Recent Entries";
        messageTitle = fullList;
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Center (
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text("Front Door Sensor\n",
              style: Theme.of(context).textTheme.headline3
          ),
          FutureBuilder<String>(
            future: futureDistance,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                //return Text(snapshot.data);
                current = int.parse(snapshot.data);
                difference = current - prev;
                if (difference.abs() > 3 && prev != -1) {
                  dialogShowing = true;
                  showDoorOpen(context);
                  if (isDoorOpen) {
                    //notificationAlert = "A door has been opened!";
                    messageTitle = fullList;
                    isDoorOpen = false;
                  }
                } else {
                  //notificationAlert = "An alert will appear when a Door Opens";
                  //messageTitle = "";

                  totalOutput = "Total Entries: " + total.toString() + "\n";

                  //output = Text(totalOutput, style: Theme.of(context).textTheme.headline4);

                  proximity = "Proximity to Door: " + snapshot.data + " cm\n";
                  //proxStatus = Text(proximity, style: Theme.of(context).textTheme.headline4);
                } // + '\n' + messageTitle);

                prev = current;
                output = Text(proximity + totalOutput,
                    style: Theme.of(context).textTheme.headline5
                );
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
            style: Theme.of(context).textTheme.headline5,

          ),
          Text(
            messageTitle,
            style: Theme.of(context).textTheme.headline5,
          ),
          RaisedButton(
              onPressed: () {
                logoutAction();
              },
              child: const Text("Logout")
          ),
        ],
      ),
    );
  }
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
                dialogShowing = false;
                Navigator.of(context, rootNavigator: true).pop('dialog');
              },
            ),
            FlatButton(
              child: const Text('No'),
              onPressed: () {
                lastEntries[next] =
                    DateFormat('MM/dd/yyyy hh:mm:ss').format(
                        DateTime.now());
                total++;
                next = (next + 1) % ENTRIES;
                fullList = "";
                if (total < 5) {
                  for (int i = 0; i < next; i++) {
                    fullList = fullList + lastEntries[i] + "\n";
                  }
                } else {
                  int j = next;
                  int printed = 0;
                  while (printed < ENTRIES) {
                    fullList = fullList + lastEntries[j] + "\n";
                    j = (j + 1) % ENTRIES;
                    printed++;
                  }
                }
                isDoorOpen = true;
                dialogShowing = false;

                Navigator.of(context, rootNavigator: true).pop('dialog');
              },
            ),
          ],
        );
      });
}


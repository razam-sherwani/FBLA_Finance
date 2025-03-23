import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class PlaidPage extends StatefulWidget {
  const PlaidPage({super.key});

  @override
  _PlaidPage createState() => _PlaidPage();
}

class _PlaidPage extends State<PlaidPage> {

  @override
  void initState() {
    super.initState();
  }

  Future<String?> getPlaidLinkToken() async {
  HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createLinkToken');
  final results = await callable();
  return results.data;
}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plaid Link Example'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              print("hello!");
              String? linkToken = await getPlaidLinkToken();
              if (linkToken != null) {
                print(linkToken);
                PlaidLink.create(configuration: LinkTokenConfiguration(token: linkToken));
                PlaidLink.open();
              } else {
                print('No link token available');
              }
            },
            child: const Text('Open Plaid Link'),
          ),
        ),
      ),
    );
  }
}
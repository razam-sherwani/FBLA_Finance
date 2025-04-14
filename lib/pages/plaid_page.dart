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
  String? _linkToken;

  @override
  void initState() {
    super.initState();
  }

  // Function to call Firebase Cloud Functions and fetch the Plaid link token
  Future<String?> getPlaidLinkToken() async {
    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createLinkToken');
      final results = await callable.call();
      if (results.data != null) {
        return results.data; // Assuming 'createLinkToken' returns the link token
      }
    } catch (e) {
      print("Error fetching link token: $e");
    }
    return null;
  }

  // Method to handle Plaid link after the token is retrieved
  void openPlaidLink(String linkToken) {
    // Create the Plaid link configuration
    PlaidLink.create(configuration: LinkTokenConfiguration(token: linkToken));

    // Open the Plaid link interface
    PlaidLink.open();
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
              print("Fetching Plaid link token...");

              // Get the link token
              String? linkToken = await getPlaidLinkToken();

              if (linkToken != null) {
                print("Link token fetched: $linkToken");
                // Open Plaid Link using the fetched token
                openPlaidLink(linkToken);
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

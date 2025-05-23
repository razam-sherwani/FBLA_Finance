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
  LinkTokenConfiguration? _configuration;

  @override
  void initState() {
    super.initState();
    //_streamEvent = PlaidLink.onEvent.listen(_onEvent);
    //_streamExit = PlaidLink.onExit.listen(_onExit);
    //_streamSuccess = PlaidLink.onSuccess.listen(_onSuccess);
  }

  void _onSuccess(LinkSuccess event) {
    final token = event.publicToken;
    final metadata = event.metadata.description();
    print("onSuccess: $token, metadata: $metadata");
    //setState(() => _successObject = event);
  }

  void _onExit(LinkExit event) {
    final metadata = event.metadata.description();
    final error = event.error?.description();
    print("onExit metadata: $metadata, error: $error");
  }

  void _createLinkTokenConfiguration() {
    setState(() {
      _configuration = LinkTokenConfiguration(
        token: _linkToken!,
      );
      PlaidLink.create(configuration: _configuration!);
    });
  }

  // Function to call Firebase Cloud Functions and fetch the Plaid link token
  Future<String?> getPlaidLinkToken() async {
    try {
      HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('createLinkToken');
      final results = await callable.call();
      if (results.data != null) {
        return results
            .data; // Assuming 'createLinkToken' returns the link token
      }
    } catch (e) {
      print("Error fetching link token: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plaid Link Example'),
        ),
        body: Center(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () async {
                  print("Fetching Plaid link token...");
                  String? linkToken = await getPlaidLinkToken();
                  if (linkToken != null) {
                    print("Link token fetched: $linkToken");
                    setState(() {
                      _linkToken = linkToken;
                      _configuration =
                          LinkTokenConfiguration(token: _linkToken!);
                      PlaidLink.create(configuration: _configuration!);
                    });
                  } else {
                    print('No link token available');
                  }
                },
                child: const Text('Fetch & Initialize Plaid'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    _configuration != null ? () => PlaidLink.open() : null,
                child: const Text("Open Plaid Link"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

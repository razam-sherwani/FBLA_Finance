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
  String? publicToken;

  @override
  void initState() {
    super.initState();
    PlaidLink.onSuccess.listen((LinkSuccess success) {
      publicToken = success.publicToken;
      LinkSuccessMetadata metadata = success.metadata;

      print('✅ Public Token: $publicToken');
      print('Institution: ${metadata.institution?.name}');
      print('Accounts: ${metadata.accounts.length}');

      // Now you can send publicToken to your backend
      exchangePublicToken(publicToken!);
    });
  }

  Future<void> exchangePublicToken(String publicToken) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('exchangePublicToken');
      print('Sending public token: $publicToken');
      final result = await callable.call({'public_token': publicToken});

      final accessToken = result.data;
      print('Access token: $accessToken');

      // Optionally: Store or use it to fetch transactions
      await fetchTransactions(accessToken);
    } catch (e) {
      print('Failed to exchange token: $e');
    }
  }

  Future<void> fetchTransactions(String accessToken) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getTransactions');
      final result = await callable.call({'access_token': accessToken});

      List<dynamic> transactions = result.data;
      for (var txn in transactions) {
        print('${txn['date']}: ${txn['name']} - \$${txn['amount']}');
      }

      // You can now display this in your Flutter UI
    } catch (e) {
      print('Failed to fetch transactions: $e');
    }
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

const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const functions = require('firebase-functions');

const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');

// Initialize Firebase Admin SDK
initializeApp();

// Initialize Plaid client
const configuration = new Configuration({
  basePath: PlaidEnvironments.sandbox, // Change to 'development' or 'production' as needed
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': "67d8d31e4ec72d00221c7015",
      'PLAID-SECRET': "9069aaf27c70989df0368ab48df0b2",
    },
  },
});

const plaidClient = new PlaidApi(configuration);

exports.exchangePublicToken = functions.https.onCall(async (data, context) => {
  const { public_token } = data;

  try {
    const response = await plaidClient.itemPublicTokenExchange({ public_token });
    const access_token = response.data.access_token;

    // Store this securely associated with the user (in Firestore or Firebase Auth)
    return { access_token };
  } catch (error) {
    logger.error('Error exchanging public token:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.getTransactions = functions.https.onCall(async (data, context) => {
  const { access_token } = data;

  const today = new Date();
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(today.getDate() - 30);

  try {
    const response = await plaidClient.transactionsGet({
      access_token,
      start_date: thirtyDaysAgo.toISOString().split('T')[0],
      end_date: today.toISOString().split('T')[0],
    });

    return response.data.transactions;
  } catch (error) {
    logger.error('Error fetching transactions:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
// Create Firebase Function
exports.createLinkToken = functions.https.onCall(async (data, context) => {
  const request = {
    user: {
      client_user_id: context.auth?.uid || 'user-id',
      phone_number: '+1 415 5550123',
    },
    client_name: 'Finsafe',
    products: ['transactions'],
    transactions: {
      days_requested: 730,
    },
    country_codes: ['US'],
    language: 'en',
    webhook: 'https://sample-web-hook.com',
    android_package_name: 'com.example.fbla_finance',
    account_filters: {
      depository: {
        account_subtypes: ['checking', 'savings'],
      },
      credit: {
        account_subtypes: ['credit card'],
      },
    },
  };
  try {
    const response = await plaidClient.linkTokenCreate(request);
    return response.data.link_token;
  } catch (error) {
    logger.error('Error creating Plaid link token:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});


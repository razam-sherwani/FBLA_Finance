/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require('firebase-functions');
const { PlaidApi, Configuration, PlaidEnvironments } = require('plaid');

const config = new Configuration({
  basePath: PlaidEnvironments.sandbox, // or 'development' / 'production'
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': '67d8d31e4ec72d00221c7015',
      'PLAID-SECRET': '9069aaf27c70989df0368ab48df0b2',
    },
  },
});

const plaidClient = new PlaidApi(config);

exports.createLinkToken = functions.https.onCall(async (data, context) => {
  const request = {
    user: { client_user_id: context.auth.uid },
    client_name: "Finsafe",
    products: ['auth', 'transactions'],
    country_codes: ['US'],
    language: 'en',
    android_package_name: 'com.example.fbla_finance',
  };

  try {
    const response = await plaidClient.linkTokenCreate(request);
    return { link_token: response.data.link_token };
  } catch (error) {
    console.error(error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.exchangePublicToken = functions.https.onCall(async (data, context) => {
  const publicToken = data.public_token;

  try {
    const response = await plaidClient.itemPublicTokenExchange({ public_token: publicToken });
    return {
      access_token: response.data.access_token,
      item_id: response.data.item_id,
    };
  } catch (error) {
    console.error(error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});


// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

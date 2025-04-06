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

// Create Firebase Function
exports.createLinkToken = functions.https.onCall(async (data, context) => {
  const request = {
    user: {
      client_user_id: 'user-id',
      phone_number: '+1 415 5550123',
    },
    client_name: 'Personal Finance App',
    products: ['transactions'],
    transactions: {
      days_requested: 730,
    },
    country_codes: ['US'],
    language: 'en',
    webhook: 'https://sample-web-hook.com',
    //redirect_uri: 'https://domainname.com/oauth-page.html',
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
    const linkToken = response.data.link_token;
    //res.status(200).send({ linkToken });
    return linkToken;
  } catch (error) {
    logger.error('Error creating Plaid link token:', error);
    //res.status(500).send({ error: error.message });
  }
});

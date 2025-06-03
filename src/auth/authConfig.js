const { ConfidentialClientApplication } = require('@azure/msal-node');

// MSAL configuration
const msalConfig = {
    auth: {
        clientId: process.env.CLIENT_ID,
        clientSecret: process.env.CLIENT_SECRET,
        authority: `https://login.microsoftonline.com/${process.env.TENANT_ID}`
    },
    system: {
        loggerOptions: {
            loggerCallback(loglevel, message, containsPii) {
                if (process.env.NODE_ENV === 'development') {
                    console.log(message);
                }
            },
            piiLoggingEnabled: false,
            logLevel: 'Info',
        }
    }
};

// Create MSAL instance
const cca = new ConfidentialClientApplication(msalConfig);

// Scopes for Microsoft Graph API
const graphScopes = [
    'User.Read',
    'Group.Read.All',
    'Tasks.Read'
];

// Authentication request configuration
const authCodeUrlParameters = {
    scopes: graphScopes,
    redirectUri: process.env.REDIRECT_URI,
    prompt: 'select_account'
};

const tokenRequest = {
    scopes: graphScopes,
    redirectUri: process.env.REDIRECT_URI
};

module.exports = {
    cca,
    graphScopes,
    authCodeUrlParameters,
    tokenRequest
};
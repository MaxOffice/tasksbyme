const express = require('express');
const { cca, authCodeUrlParameters, tokenRequest } = require('../auth/authConfig');
const { registerUserForUpdates, unregisterUser } = require('../services/schedulerService');

const router = express.Router();

/**
 * Login route - redirects to Microsoft login
 */
router.get('/login', async (req, res) => {
    try {
        const authCodeUrl = await cca.getAuthCodeUrl(authCodeUrlParameters);
        res.redirect(authCodeUrl);
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).send('Authentication error');
    }
});

/**
 * Callback route - handles the response from Microsoft
 */
router.get('/callback', async (req, res) => {
    const tokenRequestWithCode = {
        ...tokenRequest,
        code: req.query.code,
    };

    try {
        const response = await cca.acquireTokenByCode(tokenRequestWithCode);
        
        // Store account info in session
        req.session.account = response.account;
        req.session.accessToken = response.accessToken;
        
        // Register user for background updates
        registerUserForUpdates(response.account.localAccountId, response.account);
        
        console.log('User authenticated:', response.account.username);
        res.redirect('/');
    } catch (error) {
        console.error('Callback error:', error);
        res.status(500).send('Authentication failed');
    }
});

/**
 * Logout route
 */
router.get('/logout', (req, res) => {
    // Unregister user from background updates
    if (req.session && req.session.account) {
        unregisterUser(req.session.account.localAccountId);
    }
    
    req.session.destroy((err) => {
        if (err) {
            console.error('Logout error:', err);
        }
        
        // Redirect to Microsoft logout
        const logoutUrl = `https://login.microsoftonline.com/${process.env.TENANT_ID}/oauth2/v2.0/logout?post_logout_redirect_uri=${encodeURIComponent('http://localhost:3000')}`;
        res.redirect(logoutUrl);
    });
});

/**
 * Status route - check authentication status
 */
router.get('/status', (req, res) => {
    if (req.session && req.session.account) {
        res.json({
            authenticated: true,
            user: {
                name: req.session.account.name,
                username: req.session.account.username
            }
        });
    } else {
        res.json({ authenticated: false });
    }
});

module.exports = router;
const { cca, tokenRequest } = require('./authConfig');

/**
 * Middleware to check if user is authenticated
 */
const requireAuth = (req, res, next) => {
    if (req.session && req.session.account) {
        return next();
    } else {
        return res.redirect('/auth/login');
    }
};

const requireAuthApi = (req, res, next) => {
    if (req.session && req.session.account) {
        return next();
    } else {
        return res.status(401).json({ error: 'Authentication required' });
    }
}

/**
 * Get valid access token for the current user
 */
const getAccessToken = async (req) => {
    if (!req.session || !req.session.account) {
        throw new Error('User not authenticated');
    }

    const silentRequest = {
        ...tokenRequest,
        account: req.session.account,
    };

    try {
        // Try to get token silently first
        const response = await cca.acquireTokenSilent(silentRequest);
        return response.accessToken;
    } catch (error) {
        console.error('Silent token acquisition failed:', error);
        
        // If silent fails, we need to redirect to login
        throw new Error('Token refresh required - redirect to login');
    }
};

/**
 * Middleware to ensure we have a valid access token
 */
const ensureAccessToken = async (req, res, next) => {
    try {
        const accessToken = await getAccessToken(req);
        req.accessToken = accessToken;
        next();
    } catch (error) {
        console.error('Access token error:', error);
        // Clear session and redirect to login
        req.session.destroy();
        res.redirect('/auth/login');
    }
};

module.exports = {
    requireAuth,
    requireAuthApi,
    getAccessToken,
    ensureAccessToken
};
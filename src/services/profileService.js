const { getOtherUserProfile } = require('./graphService');

const userCache = new Map();

// Define the cache expiration time in milliseconds (1 hour)
const CACHE_EXPIRATION_TIME = 60 * 60 * 1000; // 1 hour in milliseconds

/**
 * Helper function to get or refresh user details from cache or API.
 * This function encapsulates the caching logic.
 *
 * @param {string} userId - The ID of the user.
 * @returns {Promise<Object>} A promise that resolves with the user details.
 */
const getUserDetails = async (accessToken, userId) => {
    const cachedEntry = userCache.get(userId);
    const currentTime = Date.now();

    if (cachedEntry && (currentTime - cachedEntry.timestamp < CACHE_EXPIRATION_TIME)) {
        console.log(`[CACHE HIT] Returning cached details for user: ${userId}`);
        return cachedEntry.userDetails;
    } else {
        try {
            console.log(`[CACHE MISS/EXPIRED] Fetching fresh details for user: ${userId}`);
            const freshUserDetails = await getOtherUserProfile(accessToken, userId);
            userCache.set(userId, {
                userDetails: freshUserDetails,
                timestamp: currentTime,
            });
            console.log(`[CACHE UPDATE] Cached fresh details for user: ${userId}`);
            return freshUserDetails;
        }
        catch (e) {
            console.error('Error while fetching details for user %s: %s', userId, e);
            const unknownUserDetails = {
                id: userId,
                displayName: 'Former Member',
                mail: ''
            };
            userCache.set(userId, {
                userDetails: unknownUserDetails,
                timestamp: Date.now()
            })
            console.log(`[CACHE UPDATE] Cached generic details for unknown user: ${userId}`);
            return unknownUserDetails;
        }
    }
};

module.exports = {
    getUserDetails
}
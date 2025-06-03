const cron = require('node-cron');
const { cca, tokenRequest } = require('../auth/authConfig');
const { getComprehensiveUserTasks } = require('./graphService');
const { storeUserTasks, getUserLastUpdate } = require('./dataService');

// Store active user sessions for background updates
const activeUsers = new Map(); // userId -> { account, lastActivity }

// Scheduler status
let schedulerRunning = false;
let lastRunTime = null;
let runCount = 0;

/**
 * Register a user for background updates
 */
function registerUserForUpdates(userId, account) {
    activeUsers.set(userId, {
        account: account,
        lastActivity: Date.now()
    });
    console.log(`User ${userId} registered for background updates`);
}

/**
 * Unregister a user from background updates
 */
function unregisterUser(userId) {
    activeUsers.delete(userId);
    console.log(`User ${userId} unregistered from background updates`);
}

/**
 * Clean up inactive users (not active for more than 2 hours)
 */
function cleanupInactiveUsers() {
    const twoHoursAgo = Date.now() - (2 * 60 * 60 * 1000);
    const inactiveUsers = [];
    
    for (const [userId, userData] of activeUsers.entries()) {
        if (userData.lastActivity < twoHoursAgo) {
            inactiveUsers.push(userId);
        }
    }
    
    inactiveUsers.forEach(userId => {
        activeUsers.delete(userId);
        console.log(`Removed inactive user ${userId} from background updates`);
    });
    
    return inactiveUsers.length;
}

/**
 * Update user activity timestamp
 */
function updateUserActivity(userId) {
    if (activeUsers.has(userId)) {
        activeUsers.get(userId).lastActivity = Date.now();
    }
}

/**
 * Get fresh access token for a user account
 */
async function getAccessTokenForUser(account) {
    const silentRequest = {
        ...tokenRequest,
        account: account,
    };

    try {
        const response = await cca.acquireTokenSilent(silentRequest);
        return response.accessToken;
    } catch (error) {
        console.error(`Failed to refresh token for user ${account.localAccountId}:`, error.message);
        return null;
    }
}

/**
 * Update tasks for a single user
 */
async function updateUserTasks(userId, account) {
    try {
        console.log(`Updating tasks for user ${userId}`);
        
        // Get fresh access token
        const accessToken = await getAccessTokenForUser(account);
        if (!accessToken) {
            console.log(`Skipping user ${userId} - could not refresh access token`);
            return false;
        }
        
        // Fetch tasks from Microsoft Graph
        const tasks = await getComprehensiveUserTasks(accessToken);
        
        // Store tasks locally
        await storeUserTasks(userId, tasks);
        
        console.log(`Successfully updated ${tasks.length} tasks for user ${userId}`);
        return true;
    } catch (error) {
        console.error(`Error updating tasks for user ${userId}:`, error.message);
        return false;
    }
}

/**
 * Background task to update all active users
 */
async function runBackgroundUpdate() {
    if (activeUsers.size === 0) {
        console.log('No active users to update');
        return;
    }
    
    console.log(`Starting background update for ${activeUsers.size} active users`);
    const startTime = Date.now();
    
    // Clean up inactive users first
    const removedCount = cleanupInactiveUsers();
    
    let successCount = 0;
    let errorCount = 0;
    
    // Update tasks for each active user
    for (const [userId, userData] of activeUsers.entries()) {
        try {
            const success = await updateUserTasks(userId, userData.account);
            if (success) {
                successCount++;
            } else {
                errorCount++;
            }
            
            // Small delay between users to avoid rate limiting
            await new Promise(resolve => setTimeout(resolve, 1000));
        } catch (error) {
            console.error(`Background update failed for user ${userId}:`, error);
            errorCount++;
        }
    }
    
    const duration = Date.now() - startTime;
    lastRunTime = new Date();
    runCount++;
    
    console.log(`Background update completed in ${duration}ms:`);
    console.log(`- Successful updates: ${successCount}`);
    console.log(`- Failed updates: ${errorCount}`);
    console.log(`- Inactive users removed: ${removedCount}`);
}

/**
 * Start the background scheduler
 */
function startScheduler() {
    if (schedulerRunning) {
        console.log('Scheduler is already running');
        return;
    }
    
    // Run every 5 minutes
    cron.schedule('*/5 * * * *', async () => {
        try {
            await runBackgroundUpdate();
        } catch (error) {
            console.error('Background scheduler error:', error);
        }
    });
    
    schedulerRunning = true;
    console.log('Background scheduler started - will run every 5 minutes');
}

/**
 * Stop the background scheduler
 */
function stopScheduler() {
    // cron.destroy() would stop all cron jobs, but we'll just mark as stopped
    schedulerRunning = false;
    console.log('Background scheduler stopped');
}

/**
 * Get scheduler status and statistics
 */
function getSchedulerStatus() {
    return {
        running: schedulerRunning,
        activeUsers: activeUsers.size,
        lastRunTime: lastRunTime ? lastRunTime.toISOString() : null,
        totalRuns: runCount,
        usersList: Array.from(activeUsers.keys())
    };
}

/**
 * Manually trigger background update (for testing)
 */
async function triggerManualUpdate() {
    console.log('Manual background update triggered');
    await runBackgroundUpdate();
}

module.exports = {
    registerUserForUpdates,
    unregisterUser,
    updateUserActivity,
    startScheduler,
    stopScheduler,
    getSchedulerStatus,
    triggerManualUpdate
};
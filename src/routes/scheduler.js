const express = require('express');
const { requireAuthApi } = require('../auth/authMiddleware');
const { 
    getSchedulerStatus, 
    triggerManualUpdate,
    updateUserActivity 
} = require('../services/schedulerService');

const router = express.Router();

/**
 * Get scheduler status
 */
router.get('/status', requireAuthApi, (req, res) => {
    try {
        const status = getSchedulerStatus();
        res.json({
            success: true,
            scheduler: status
        });
    } catch (error) {
        console.error('Error getting scheduler status:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to get scheduler status'
        });
    }
});

/**
 * Manually trigger background update
 */
router.post('/trigger', requireAuthApi, async (req, res) => {
    try {
        console.log(`Manual scheduler trigger by user ${req.session.account.localAccountId}`);
        
        // Update user activity
        updateUserActivity(req.session.account.localAccountId);
        
        // Trigger update (this runs asynchronously)
        triggerManualUpdate().catch(error => {
            console.error('Manual trigger failed:', error);
        });
        
        res.json({
            success: true,
            message: 'Background update triggered',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('Error triggering manual update:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to trigger update'
        });
    }
});

/**
 * Update user activity (called by frontend to keep user active)
 */
router.post('/heartbeat', requireAuthApi, (req, res) => {
    try {
        const userId = req.session.account.localAccountId;
        updateUserActivity(userId);
        
        res.json({
            success: true,
            message: 'Activity updated'
        });
    } catch (error) {
        console.error('Error updating user activity:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to update activity'
        });
    }
});

module.exports = router;
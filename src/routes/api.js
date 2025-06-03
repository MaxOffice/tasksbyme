const express = require('express');
const { requireAuth, requireAuthApi, ensureAccessToken } = require('../auth/authMiddleware');
const { getComprehensiveUserTasks } = require('../services/graphService');
const { storeUserTasks, getFilteredTasks, getUserDataStats } = require('../services/dataService');
const { updateUserActivity } = require('../services/schedulerService');

const router = express.Router();

/**
 * Get user's tasks (from local storage)
 */
router.get('/tasks', requireAuthApi, async (req, res) => {
    try {
        const userId = req.session.account.localAccountId;
        
        // Update user activity
        updateUserActivity(userId);
        
        // Parse query parameters
        const options = {
            status: req.query.status,
            planId: req.query.planId,
            search: req.query.search,
            sortBy: req.query.sortBy || 'createdDateTime',
            sortOrder: req.query.sortOrder || 'desc'
        };
        
        const tasks = await getFilteredTasks(userId, options);
        res.json({
            success: true,
            tasks,
            count: tasks.length
        });
    } catch (error) {
        console.error('Error fetching tasks:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch tasks'
        });
    }
});

/**
 * Manually refresh tasks from Microsoft Graph
 */
router.post('/refresh', requireAuth, ensureAccessToken, async (req, res) => {
    try {
        const userId = req.session.account.localAccountId;
        const accessToken = req.accessToken;
        
        console.log(`Manual refresh triggered for user ${userId}`);
        
        // Fetch fresh data from Microsoft Graph
        const tasks = await getComprehensiveUserTasks(accessToken);
        
        // Store in local storage
        await storeUserTasks(userId, tasks);
        
        res.json({
            success: true,
            message: 'Tasks refreshed successfully',
            count: tasks.length,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('Error refreshing tasks:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to refresh tasks',
            details: error.message
        });
    }
});

/**
 * Get user data statistics
 */
router.get('/stats', requireAuthApi, async (req, res) => {
    try {
        const userId = req.session.account.localAccountId;
        const stats = await getUserDataStats(userId);
        
        res.json({
            success: true,
            stats
        });
    } catch (error) {
        console.error('Error fetching stats:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch statistics'
        });
    }
});

/**
 * Get available filter options
 */
router.get('/filters', requireAuthApi, async (req, res) => {
    try {
        const userId = req.session.account.localAccountId;
        const tasks = await getFilteredTasks(userId);
        
        // Extract unique values for filters
        const plans = [...new Set(tasks.map(t => ({ id: t.planId, title: t.planTitle })))];
        const statuses = [
            { value: 'notStarted', label: 'Not Started', count: tasks.filter(t => t.percentComplete === 0).length },
            { value: 'inProgress', label: 'In Progress', count: tasks.filter(t => t.percentComplete > 0 && t.percentComplete < 100).length },
            { value: 'completed', label: 'Completed', count: tasks.filter(t => t.percentComplete === 100).length }
        ];
        
        res.json({
            success: true,
            filters: {
                plans: plans.filter(p => p.id), // Remove any null/undefined plan IDs
                statuses
            }
        });
    } catch (error) {
        console.error('Error fetching filters:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch filter options'
        });
    }
});

module.exports = router;
const fs = require('fs').promises;
const path = require('path');

// In-memory storage for fast access
const dataStore = {
    users: new Map(), // userId -> user data
    lastUpdate: new Map() // userId -> timestamp
};

const DATA_DIR = path.join(__dirname, '../../data');

/**
 * Ensure data directory exists
 */
async function ensureDataDir() {
    try {
        await fs.access(DATA_DIR);
    } catch (error) {
        await fs.mkdir(DATA_DIR, { recursive: true });
    }
}

/**
 * Get file path for user data
 */
function getUserDataFilePath(userId) {
    return path.join(DATA_DIR, `user_${userId}.json`);
}

/**
 * Load user data from file to memory
 */
async function loadUserDataFromFile(userId) {
    try {
        const filePath = getUserDataFilePath(userId);
        const data = await fs.readFile(filePath, 'utf8');
        const userData = JSON.parse(data);
        
        // Store in memory
        dataStore.users.set(userId, userData.tasks || []);
        dataStore.lastUpdate.set(userId, userData.lastUpdate || 0);
        
        return userData.tasks || [];
    } catch (error) {
        // File doesn't exist or is corrupted, return empty array
        console.log(`No existing data file for user ${userId}`);
        return [];
    }
}

/**
 * Save user data from memory to file
 */
async function saveUserDataToFile(userId) {
    try {
        await ensureDataDir();
        
        const tasks = dataStore.users.get(userId) || [];
        const lastUpdate = dataStore.lastUpdate.get(userId) || Date.now();
        
        const userData = {
            userId,
            tasks,
            lastUpdate,
            savedAt: new Date().toISOString()
        };
        
        const filePath = getUserDataFilePath(userId);
        await fs.writeFile(filePath, JSON.stringify(userData, null, 2));
        
        console.log(`Data saved for user ${userId}: ${tasks.length} tasks`);
    } catch (error) {
        console.error(`Error saving data for user ${userId}:`, error);
    }
}

/**
 * Store tasks for a user
 */
async function storeUserTasks(userId, tasks) {
    try {
        // Store in memory
        dataStore.users.set(userId, tasks);
        dataStore.lastUpdate.set(userId, Date.now());
        
        // Save to file asynchronously
        await saveUserDataToFile(userId);
        
        return true;
    } catch (error) {
        console.error(`Error storing tasks for user ${userId}:`, error);
        return false;
    }
}

/**
 * Get tasks for a user
 */
async function getUserTasks(userId) {
    try {
        // Check if data is in memory
        if (dataStore.users.has(userId)) {
            return dataStore.users.get(userId);
        }
        
        // Load from file if not in memory
        return await loadUserDataFromFile(userId);
    } catch (error) {
        console.error(`Error getting tasks for user ${userId}:`, error);
        return [];
    }
}

/**
 * Get last update timestamp for user
 */
function getUserLastUpdate(userId) {
    return dataStore.lastUpdate.get(userId) || 0;
}

/**
 * Get filtered and sorted tasks
 */
async function getFilteredTasks(userId, options = {}) {
    try {
        let tasks = await getUserTasks(userId);
        
        // Apply filters
        if (options.status) {
            tasks = tasks.filter(task => task.percentComplete === getStatusPercentage(options.status));
        }
        
        if (options.planId) {
            tasks = tasks.filter(task => task.planId === options.planId);
        }
        
        if (options.search) {
            const searchLower = options.search.toLowerCase();
            tasks = tasks.filter(task => 
                task.title.toLowerCase().includes(searchLower) ||
                (task.description && task.description.toLowerCase().includes(searchLower))
            );
        }
        
        // Apply sorting
        if (options.sortBy) {
            tasks.sort((a, b) => {
                let aVal = a[options.sortBy];
                let bVal = b[options.sortBy];
                
                // Handle date fields
                if (options.sortBy === 'createdDateTime' || options.sortBy === 'dueDateTime') {
                    aVal = new Date(aVal || 0);
                    bVal = new Date(bVal || 0);
                }
                
                // Handle string fields
                if (typeof aVal === 'string') {
                    aVal = aVal.toLowerCase();
                    bVal = (bVal || '').toLowerCase();
                }
                
                if (aVal < bVal) return options.sortOrder === 'desc' ? 1 : -1;
                if (aVal > bVal) return options.sortOrder === 'desc' ? -1 : 1;
                return 0;
            });
        }
        
        return tasks;
    } catch (error) {
        console.error(`Error filtering tasks for user ${userId}:`, error);
        return [];
    }
}

/**
 * Convert status string to percentage
 */
function getStatusPercentage(status) {
    switch (status) {
        case 'notStarted': return 0;
        case 'inProgress': return 50;
        case 'completed': return 100;
        default: return null;
    }
}

/**
 * Get data statistics for user
 */
async function getUserDataStats(userId) {
    try {
        const tasks = await getUserTasks(userId);
        const lastUpdate = getUserLastUpdate(userId);
        
        const stats = {
            totalTasks: tasks.length,
            notStarted: tasks.filter(t => t.percentComplete === 0).length,
            inProgress: tasks.filter(t => t.percentComplete > 0 && t.percentComplete < 100).length,
            completed: tasks.filter(t => t.percentComplete === 100).length,
            lastUpdate: new Date(lastUpdate).toISOString(),
            plans: [...new Set(tasks.map(t => t.planTitle))].length
        };
        
        return stats;
    } catch (error) {
        console.error(`Error getting stats for user ${userId}:`, error);
        return null;
    }
}

module.exports = {
    storeUserTasks,
    getUserTasks,
    getFilteredTasks,
    getUserLastUpdate,
    getUserDataStats,
    loadUserDataFromFile,
    saveUserDataToFile
};
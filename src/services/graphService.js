const { Client } = require('@microsoft/microsoft-graph-client');

/**
 * Create Graph API client with access token
 */
function getGraphClient(accessToken) {
    const client = Client.init({
        authProvider: (done) => {
            done(null, accessToken);
        }
    });
    return client;
}

/**
 * Get current user's profile information
 */
async function getUserProfile(accessToken) {
    try {
        const client = getGraphClient(accessToken);
        const user = await client.api('/me?$select=id,displayName,userPrincipalName,mail').get();
        return {
            id: user.id,
            displayName: user.displayName,
            mail: user.mail,
            userPrincipalName: user.userPrincipalName
        };
    } catch (error) {
        console.error('Error fetching user profile:', error);
        throw error;
    }
}

/**
 * Get another user's profile information
 */
async function getOtherUserProfile(accessToken, userId) {
    try {
        const client = getGraphClient(accessToken);
        const user = await client.api(`/users/${userId}?$select=id,displayName,mail`).get();
        return {
            id: user.id,
            displayName: user.displayName,
            mail: user.mail
        };
    } catch (error) {
        console.error('Error fetching user profile:', error);
        throw error;
    }
}

/**
 * Get all plans available to the current user
 */
async function getUserPlans(accessToken) {
    try {
        const client = getGraphClient(accessToken);
        
        const plans = [];
        
        // Fetch all plans shared with the current user.
        // See:
        //   https://learn.microsoft.com/en-us/graph/api/planneruser-list-plans
        const plannerPlans = await client.api('/me/planner/plans?$select=id,title').get();
        plans.push(...plannerPlans.value);
        
        return plans;
    } catch (error) {
        console.error('Error fetching user plans:', error);
        throw error;
    }
}

/**
 * Get all tasks for a specific plan
 */
async function getPlanTasks(accessToken, planId) {
    try {
        const client = getGraphClient(accessToken);
        const tasks = await client.api(`/planner/plans/${planId}/tasks`).get();
        return tasks.value;
    } catch (error) {
        console.error(`Error fetching tasks for plan ${planId}:`, error);
        throw error;
    }
}

/**
 * Get tasks created by current user across all their plans
 */
async function getUserCreatedTasks(accessToken) {
    try {
        const userProfile = await getUserProfile(accessToken);
        const plans = await getUserPlans(accessToken);
        const allTasks = [];
        
        // Fetch tasks from all plans
        for (const plan of plans) {
            try {
                const planTasks = await getPlanTasks(accessToken, plan.id);
                
                // Filter tasks created by current user
                const userTasks = planTasks.filter(task => 
                    task.createdBy && task.createdBy.user && 
                    task.createdBy.user.id === userProfile.id
                );
                
                // Add plan information to each task
                const tasksWithPlanInfo = userTasks.map(task => ({
                    ...task,
                    planId: plan.id,
                    planTitle: plan.title
                }));
                
                allTasks.push(...tasksWithPlanInfo);
            } catch (error) {
                console.error(`Error processing plan ${plan.id}:`, error);
                // Continue with other plans
            }
        }
        
        return allTasks;
    } catch (error) {
        console.error('Error fetching user created tasks:', error);
        throw error;
    }
}

/**
 * Get task details including buckets and categories
 * Not using this in current version.
 */
// async function getTaskDetails(accessToken, taskId) {
//     try {
//         const client = getGraphClient(accessToken);
//         const taskDetails = await client.api(`/planner/tasks/${taskId}/details`).get();
//         return taskDetails;
//     } catch (error) {
//         console.error(`Error fetching task details for ${taskId}:`, error);
//         throw error;
//     }
// }

/**
 * Get comprehensive task data for user
 */
async function getComprehensiveUserTasks(accessToken) {
    try {
        const tasks = await getUserCreatedTasks(accessToken);
        
        return tasks;
        // Enhance tasks with additional details
        // Not doing this in the current version.
        // const enhancedTasks = await Promise.all(
        //     tasks.map(async (task) => {
        //         try {
        //             const details = await getTaskDetails(accessToken, task.id);
        //             return {
        //                 ...task,
        //                 description: details.description,
        //                 checklist: details.checklist,
        //                 references: details.references
        //             };
        //         } catch (error) {
        //             // If details fail, return task without enhanced info
        //             console.log(`Could not fetch details for task ${task.id}`);
        //             return task;
        //         }
        //     })
        // );
        
        // return enhancedTasks;
    } catch (error) {
        console.error('Error fetching comprehensive user tasks:', error);
        throw error;
    }
}

module.exports = {
    getUserProfile,
    getOtherUserProfile,
    getUserPlans,
    getPlanTasks,
    getUserCreatedTasks,
    // getTaskDetails,
    getComprehensiveUserTasks
};
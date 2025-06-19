// Define the cache expiration time in milliseconds (1 hour)
const CACHE_EXPIRATION_TIME = 60 * 60 * 1000; // 1 hour in milliseconds

class TaskTracker {
    constructor() {
        this.tasks = [];
        this.filteredTasks = [];

        this.filters = {
            plan: '',
            status: 'notcomplete',
            search: '',
            sortBy: 'dueDate'
        };

        this.userCache = new Map();

        this.init();
    }

    async init () {
        this.bindEvents();
        this.showLoading(true);
        await this.loadTasks();
        await this.loadStats();
        this.updateLastRefreshTime();
        this.startHeartbeat();
    }

    async checkAuthStatus () {
        try {
            const response = await this.makeAuthenticatedRequest('/api/auth/status');
            return response.ok;
        } catch (error) {
            return false;
        }
    }

    async makeAuthenticatedRequest (url, options = {}) {
        try {
            const response = await fetch(url, options);

            if (response.status === 401 || response.status === 403) {
                // Authentication failed
                return null;
            }

            if (!response.ok) {
                // Server error
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            return response;
        } catch (error) {
            console.error('API request failed:', error);
            throw error;
        }
    }

    async fetchUserDetails (userId) {
        const response = await this.makeAuthenticatedRequest(`/api/users/${userId}`);
        if (!response.ok) {
            console.log(`[ERROR]: Could not fetch details for user id ${userId}`);
            return;
        }
        const freshUserDetails = await response.json();

        this.userCache.set(userId, {
            userDetails: freshUserDetails,
            timestamp: Date.now(),
        });
    }

    getUserDetails (userId) {
        const cachedEntry = this.userCache.get(userId);
        const currentTime = Date.now();

        if (cachedEntry && (currentTime - cachedEntry.timestamp < CACHE_EXPIRATION_TIME)) {
            return {
                id: userId,
                userDetails: cachedEntry.userDetails,
                status: 'cached'
            };
        } else {
            this.fetchUserDetails(userId);
            return {
                id: userId,
                userDetails: { displayName: 'Unknown' },
                status: 'requested'
            };
        }
    }

    bindEvents () {
        // Refresh button
        document.getElementById('refreshBtn').addEventListener('click', () => {
            this.refreshTasks();
        });

        // Filters
        document.getElementById('planFilter').addEventListener('change', (e) => {
            this.filters.plan = e.target.value;
            this.applyFilters();
        });

        document.getElementById('statusFilter').addEventListener('change', (e) => {
            this.filters.status = e.target.value;
            this.applyFilters();
        });

        document.getElementById('sortBy').addEventListener('change', (e) => {
            this.filters.sortBy = e.target.value;
            this.applyFilters();
        });

        document.getElementById('searchInput').addEventListener('input', (e) => {
            this.filters.search = e.target.value.toLowerCase();
            this.applyFilters();
        });

        document.getElementById('clearFilters').addEventListener('click', () => {
            this.clearFilters();
        });
    }

    async loadTasks () {
        try {
            this.updateSyncStatus('updating', 'Loading tasks...');

            const response = await this.makeAuthenticatedRequest('/api/tasks');
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            this.tasks = data.tasks || [];

            this.populateFilters();
            this.applyFilters();
            this.updateSyncStatus('ready', 'Ready');

        } catch (error) {
            console.error('Error loading tasks:', error);
            this.updateSyncStatus('error', 'Error loading tasks');
            this.showError('Failed to load tasks. Please try refreshing.');
        } finally {
            this.showLoading(false);
        }
    }

    async loadStats () {
        try {
            const response = await this.makeAuthenticatedRequest('/api/stats');
            if (!response.ok) return;

            const stats = await response.json();
            this.updateStats(stats);
        } catch (error) {
            console.error('Error loading stats:', error);
        }
    }

    async refreshTasks () {
        const refreshBtn = document.getElementById('refreshBtn');
        const originalText = refreshBtn.innerHTML;

        refreshBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Refreshing...';
        refreshBtn.disabled = true;

        try {
            this.updateSyncStatus('updating', 'Refreshing...');

            // Trigger manual refresh
            await this.makeAuthenticatedRequest('/api/refresh', { method: 'POST' });

            // Reload tasks
            await this.loadTasks();
            await this.loadStats();
            this.updateLastRefreshTime();

        } catch (error) {
            console.error('Error refreshing tasks:', error);
            this.showError('Failed to refresh tasks');
        } finally {
            refreshBtn.innerHTML = originalText;
            refreshBtn.disabled = false;
        }
    }

    populateFilters () {
        const planFilter = document.getElementById('planFilter');
        const plans = [...new Set(this.tasks.map(task => task.planTitle))].sort();

        // Clear existing options (except "All Plans")
        planFilter.innerHTML = '<option value="">All Plans</option>';

        plans.forEach(plan => {
            const option = document.createElement('option');
            option.value = plan;
            option.textContent = plan;
            planFilter.appendChild(option);
        });
    }

    applyFilters () {
        let filtered = [...this.tasks];

        // Apply plan filter
        if (this.filters.plan) {
            filtered = filtered.filter(task => task.planTitle === this.filters.plan);
        }

        // Apply status filter
        if (this.filters.status) {
            filtered = filtered.filter(
                this.filters.status === "notcomplete"
                    ? task => task.percentComplete !== 100
                    : task => task.percentComplete === this.getStatusValue(this.filters.status)
            );
        }

        // Apply search filter
        if (this.filters.search) {
            filtered = filtered.filter(task =>
                task.title.toLowerCase().includes(this.filters.search) ||
                task.planTitle.toLowerCase().includes(this.filters.search)
            );
        }

        // Apply sorting
        filtered.sort((a, b) => {
            switch (this.filters.sortBy) {
                case 'title':
                    return a.title.localeCompare(b.title);
                case 'createdDate':
                    return new Date(b.createdDateTime) - new Date(a.createdDateTime);
                case 'createdDateDesc':
                    return new Date(a.createdDateTime) - new Date(b.createdDateTime);
                case 'dueDate':
                    if (!a.dueDateTime && !b.dueDateTime) return 0;
                    if (!a.dueDateTime) return 1;
                    if (!b.dueDateTime) return -1;
                    return new Date(a.dueDateTime) - new Date(b.dueDateTime);
                case 'dueDateDesc':
                    if (!a.dueDateTime && !b.dueDateTime) return 0;
                    if (!b.dueDateTime) return 1;
                    if (!a.dueDateTime) return -1;
                    return new Date(b.dueDateTime) - new Date(a.dueDateTime);
                case 'priority':
                    return (a.priority || 0) - (b.priority || 0);
                default:
                    return 0;
            }
        });

        this.filteredTasks = filtered;
        this.renderTasks();
        this.updateTaskCount();
    }

    renderTasks () {
        const container = document.getElementById('tasksContainer');
        const emptyState = document.getElementById('emptyState');

        if (this.filteredTasks.length === 0) {
            container.innerHTML = '';
            emptyState.style.display = 'block';
            return;
        }

        emptyState.style.display = 'none';

        this.renderTableView(container);
    }

    renderTableView (container) {
        container.className = 'tasks-container table-view';
        container.innerHTML = `
            <div class="tasks-table">
                <table>
                    <thead>
                        <tr>
                            <th>Task</th>
                            <th>Priority</th>
                            <th>Status</th>
                            <th>Due Date</th>
                            <th>Assigned to</th>           
                            <th>Plan</th>                             
                        </tr>
                    </thead>
                    <tbody>
                        ${this.filteredTasks.map(task => this.createTaskRow(task)).join('')}
                    </tbody>
                </table>
            </div>
        `;
    }

    createTaskRow (task) {
        const dueDateView = this.formatDueDate(task);

        return `
            <tr>
                <td>${this.formatTitle(task)}</td>
                <td>${this.formatPriority(task.priority)}</td>
                <td>${this.formatStatus(task)}</td>
                <td title="${dueDateView.title}">
                    ${dueDateView.content}
                </td>
                <td>${this.formatAssignedTo(task)}</td>
                <td title="${this.escapeHtml(task.planTitle)}">
                    ${this.escapeHtml(task.planTitle)}
                </td>        
            </tr>
        `;
    }

    formatTitle (task) {
        return `<a href="/planner/go/${task.id}" target="_blank" title="${this.escapeHtml(task.title)}">${this.escapeHtml(task.title)}</a>`
    }

    formatStatus (task) {
        const status = this.getTaskStatus(task.percentComplete);
        const formattedStatus = status === 'notStarted' ? 'Not Started'
            : status === 'inProgress' ? 'In Progress'
                : status === 'completed' ? 'Completed' : 'Unknown';


        return `<span class="task-status status-${status}">${formattedStatus}</span>`
    }

    formatPriority (priority) {
        return priority === 1 ? 'Urgent'
            : priority === 9 ? 'Low'
                : priority === 3 ? 'Important'
                    : priority === 5 ? 'Medium'
                        : priority.toString()
    }

    formatDateTimeWithIntl (date) {
        // Options for the desired date and time format
        const options = {
            day: '2-digit',
            month: 'short', // 'short' for Mmm (e.g., Jun)
            year: 'numeric',
            hour: 'numeric',
            minute: '2-digit',
            hour12: true // true for AM/PM
        };

        // Create a formatter for 'en-US' locale
        const formatter = new Intl.DateTimeFormat('en-US', options);

        // Format the date
        let formattedString = formatter.format(date);

        // Intl.DateTimeFormat might output "8 PM" or "8 AM". We need to ensure "pm" or "am".
        // This step is a small adjustment for the exact "8:50pm" format.
        // Intl.DateTimeFormat might also add a comma after the day, depending on locale.
        // Let's re-assemble for precise control over the output structure.

        const day = new Intl.DateTimeFormat('en-US', { day: '2-digit' }).format(date);
        const month = new Intl.DateTimeFormat('en-US', { month: 'short' }).format(date);
        const year = new Intl.DateTimeFormat('en-US', { year: 'numeric' }).format(date);

        // let hours = date.getHours();
        // const minutes = String(date.getMinutes()).padStart(2, '0');
        // const ampm = hours >= 12 ? 'pm' : 'am';

        // hours = hours % 12;
        // hours = hours ? String(hours).padStart(2, '0') : '12'; // The hour '0' should be '12', padded.

        return `${day} ${month} ${year}`;
    }

    formatDate (dateString) {
        const date = new Date(dateString);
        //return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        return this.formatDateTimeWithIntl(date);
    }

    formatDueDate (task) {
        if ((!task.dueDateTime) || task.percentComplete === 100) {
            return {
                title: '',
                content: '-'
            };
        }

        const variance = (Date.now() - new Date(task.dueDateTime)) / (1000 * 60 * 60 * 24); // in days
        const due = variance > 0 ? Math.ceil(variance) : Math.ceil(-variance);
        const title = variance > 0
            ? `Overdue by ${due} days`
            : variance < 0
                ? `Due in ${due} days` : '';
        const dueString = variance > 0
            ? ` <span class="overdue">⮝${due}d</span>`
            : variance < 0
                ? ` <span class="due">⮞${due}d</span>`
                : '';
        const content = this.formatDate(task.dueDateTime) + dueString;

        return {
            title,
            content
        }
    }

    formatAssignedTo (task) {
        return Object.keys(task.assignments).map(key => {
            const user = this.getUserDetails(key);
            if (user.userDetails.displayName === 'Unknown') {
                user.userDetails.displayName = "Loading...";
            }
            return `<span data-id="${key}" data-status="${user.status}" class="task-status aduser">${user.userDetails.displayName}</span>`;
        }).join('');
    }

    clearFilters () {
        this.filters = {
            plan: '',
            status: 'notcomplete',
            search: '',
            sortBy: 'dueDate'
        };

        document.getElementById('planFilter').value = '';
        document.getElementById('statusFilter').value = 'notcomplete';
        document.getElementById('searchInput').value = '';
        document.getElementById('sortBy').value = 'dueDate';

        this.applyFilters();
    }

    updateStats (statsData) {
        console.log(statsData)
        const stats = statsData.stats
        const totalTasks = stats.totalTasks || 0;
        const completed = stats.completed || 0;
        const inprogress = stats.inProgress || 0;
        const notstarted = stats.notStarted || 0;
        const notcomplete = notstarted + inprogress;

        const allStatusOption = document.querySelector('select#statusFilter option[value=""]');
        const notCompleteOption = document.querySelector('select#statusFilter option[value="notcomplete"]')
        const notStartedOption = document.querySelector('select#statusFilter option[value="notStarted"]');
        const inProgressOption = document.querySelector('select#statusFilter option[value="inProgress"]');
        const completedOption = document.querySelector('select#statusFilter option[value="completed"]');

        document.getElementById('totalTasks').textContent = totalTasks;
        document.getElementById('completedTasks').textContent = completed;
        document.getElementById('inProgressTasks').textContent = inprogress;
        document.getElementById('notStartedTasks').textContent = notstarted;

        allStatusOption.textContent = `All (${totalTasks})`;
        notCompleteOption.textContent = `All not completed (${notcomplete})`;
        notStartedOption.textContent = `Not Started (${notstarted})`;
        inProgressOption.textContent = `In Progress (${inprogress})`;
        completedOption.textContent = `Completed (${completed})`;
    }

    updateTaskCount () {
        document.getElementById('taskCount').textContent =
            `${this.filteredTasks.length} of ${this.tasks.length} tasks`;
    }

    updateSyncStatus (status, text) {
        const icon = document.getElementById('syncIcon');
        const textEl = document.getElementById('syncText');

        icon.className = `fas fa-circle sync-${status}`;
        textEl.textContent = text;
    }

    updateLastRefreshTime () {
        document.getElementById('lastUpdate').textContent =
            `Last updated: ${new Date().toLocaleTimeString()}`;
    }

    showLoading (show) {
        document.getElementById('loadingState').style.display = show ? 'block' : 'none';
        document.getElementById('tasksContainer').style.display = show ? 'none' : 'block';
    }

    showError (message) {
        // Simple error display - you could enhance this with a proper notification system
        alert(message);
    }

    startHeartbeat () {
        // Send heartbeat every 30 seconds to maintain session
        setInterval(async () => {
            try {
                await this.makeAuthenticatedRequest('/scheduler/heartbeat', { method: 'POST' });
            } catch (error) {
                console.warn('Heartbeat failed:', error);
            }
        }, 30000);

        // Load pending user details every 10 seconds
        setInterval(async () => {
            const pendingUsers = document.querySelectorAll('span.aduser[data-status="requested"]');
            pendingUsers.forEach(e => {
                const userId = e.getAttribute('data-id');
                const details = this.getUserDetails(userId);
                if (details.status === 'cached') {
                    e.setAttribute('data-status', 'cached');
                    e.textContent = details.userDetails.displayName;
                }
            });
        }, 10000);
    }

    // Utility methods
    getTaskStatus (percentComplete) {
        if (percentComplete === 100) return 'completed';
        if (percentComplete > 0) return 'inProgress';
        return 'notStarted';
    }

    getStatusValue (status) {
        switch (status) {
            case 'completed': return 100;
            case 'inProgress': return 50; // This is approximate
            case 'notStarted': return 0;
            default: return null;
        }
    }

    isTaskOverdue (task) {
        if (!task.dueDateTime) return false;
        return new Date(task.dueDateTime) < new Date() && task.percentComplete < 100;
    }

    escapeHtml (text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    const app = new TaskTracker();
    app.refreshTasks();
});

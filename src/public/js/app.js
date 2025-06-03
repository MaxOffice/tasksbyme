class TaskTracker {
    constructor() {
        this.tasks = [];
        this.filteredTasks = [];
        this.currentView = 'card';
        this.filters = {
            plan: '',
            status: '',
            search: '',
            sortBy: 'dueDate'
        };

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
                // Authentication failed - redirect to login
                // window.location.href = '/auth/login';
                return null;
            }

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            return response;
        } catch (error) {
            console.error('API request failed:', error);
            throw error;
        }
    }

    bindEvents () {
        // Refresh button
        document.getElementById('refreshBtn').addEventListener('click', () => {
            this.refreshTasks();
        });

        // View toggle
        document.getElementById('cardView').addEventListener('click', () => {
            this.switchView('card');
        });

        document.getElementById('tableView').addEventListener('click', () => {
            this.switchView('table');
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
            filtered = filtered.filter(task => task.percentComplete === this.getStatusValue(this.filters.status));
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
                case 'dueDate':
                    if (!a.dueDateTime && !b.dueDateTime) return 0;
                    if (!a.dueDateTime) return 1;
                    if (!b.dueDateTime) return -1;
                    return new Date(a.dueDateTime) - new Date(b.dueDateTime);
                case 'priority':
                    const priorityOrder = { 'urgent': 0, 'important': 1, 'medium': 2, 'low': 3 };
                    return (priorityOrder[a.priority] || 4) - (priorityOrder[b.priority] || 4);
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

        if (this.currentView === 'card') {
            this.renderCardView(container);
        } else {
            this.renderTableView(container);
        }
    }

    renderCardView (container) {
        container.className = 'tasks-container card-view';
        container.innerHTML = this.filteredTasks.map(task => this.createTaskCard(task)).join('');
    }

    renderTableView (container) {
        container.className = 'tasks-container table-view';
        container.innerHTML = `
            <div class="tasks-table">
                <table>
                    <thead>
                        <tr>
                            <th>Task</th>
                            <th>Plan</th>
                            <th>Status</th>
                            <th>Due Date</th>
                            <th>Created</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${this.filteredTasks.map(task => this.createTaskRow(task)).join('')}
                    </tbody>
                </table>
            </div>
        `;
    }

    createTaskCard (task) {
        const status = this.getTaskStatus(task.percentComplete);
        const isOverdue = this.isTaskOverdue(task);
        const cardClass = `task-card ${status === 'completed' ? 'completed' : ''} ${isOverdue ? 'overdue' : ''}`;

        return `
            <div class="${cardClass}">
                <div class="task-header">
                    <div>
                        <div class="task-title">${this.escapeHtml(task.title)}</div>
                        <span class="task-status status-${status}">${this.formatStatus(status)}</span>
                    </div>
                </div>
                <div class="task-meta">
                    ${task.dueDateTime ? `
                        <div class="task-meta-item">
                            <i class="fas fa-calendar-alt"></i>
                            <span>Due: ${this.formatDate(task.dueDateTime)}</span>
                        </div>
                    ` : ''}
                    <div class="task-meta-item">
                        <i class="fas fa-clock"></i>
                        <span>Created: ${this.formatDate(task.createdDateTime)}</span>
                    </div>
                    ${task.priority ? `
                        <div class="task-meta-item">
                            <i class="fas fa-flag"></i>
                            <span>Priority: ${this.formatPriority(task.priority)}</span>
                        </div>
                    ` : ''}
                </div>
                <div class="task-plan">${this.escapeHtml(task.planTitle)}</div>
            </div>
        `;
    }

    createTaskRow (task) {
        const status = this.getTaskStatus(task.percentComplete);

        return `
            <tr>
                <td>
                    <strong>${this.escapeHtml(task.title)}</strong>
                    ${task.priority ? `<br><small><i class="fas fa-flag"></i> ${this.formatPriority(task.priority)}</small>` : ''}
                </td>
                <td>${this.escapeHtml(task.planTitle)}</td>
                <td><span class="task-status status-${status}">${this.formatStatus(status)}</span></td>
                <td>${task.dueDateTime ? this.formatDate(task.dueDateTime) : '-'}</td>
                <td>${this.formatDate(task.createdDateTime)}</td>
            </tr>
        `;
    }

    switchView (view) {
        this.currentView = view;

        // Update button states
        document.getElementById('cardView').classList.toggle('active', view === 'card');
        document.getElementById('tableView').classList.toggle('active', view === 'table');

        this.renderTasks();
    }

    clearFilters () {
        this.filters = {
            plan: '',
            status: '',
            search: '',
            sortBy: 'dueDate'
        };

        document.getElementById('planFilter').value = '';
        document.getElementById('statusFilter').value = '';
        document.getElementById('searchInput').value = '';
        document.getElementById('sortBy').value = 'dueDate';

        this.applyFilters();
    }

    updateStats (stats) {
        document.getElementById('totalTasks').textContent = stats.total || 0;
        document.getElementById('completedTasks').textContent = stats.completed || 0;
        document.getElementById('inProgressTasks').textContent = stats.inProgress || 0;
        document.getElementById('overdueTasks').textContent = stats.overdue || 0;
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

    formatStatus (status) {
        switch (status) {
            case 'notStarted': return 'Not Started';
            case 'inProgress': return 'In Progress';
            case 'completed': return 'Completed';
            default: return status;
        }
    }

    formatPriority (priority) {
        return priority //? priority.charAt(0).toUpperCase() + priority.slice(1) : "NONE";
    }

    formatDate (dateString) {
        const date = new Date(dateString);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    escapeHtml (text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new TaskTracker();
});

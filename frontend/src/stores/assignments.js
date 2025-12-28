import { defineStore } from 'pinia'
import { createResource } from 'frappe-ui'
import { reactive, computed, ref } from 'vue'
import { teamsStore } from './teams'

export const assignmentsStore = defineStore('crm-assignments', () => {
  const teams = teamsStore()

  // Reactive state
  let assignmentsById = reactive({})
  let projectAssignments = reactive({}) // projectId -> assignments[]
  let userAssignments = reactive({}) // userId -> assignments[]
  const isLoading = ref(false)
  const activeFilters = ref({
    status: 'active',
    priority: null,
    team_id: null,
    user_id: null,
  })

  // Project assignments resource
  const assignments = createResource({
    url: 'crm.api.assignments.get_assignments',
    cache: 'crm-assignments',
    initialData: [],
    transform(data) {
      for (let assignment of data) {
        assignmentsById[assignment.id] = assignment

        // Index by project
        if (!projectAssignments[assignment.project_id]) {
          projectAssignments[assignment.project_id] = []
        }
        projectAssignments[assignment.project_id].push(assignment)

        // Index by user
        if (!userAssignments[assignment.user_id]) {
          userAssignments[assignment.user_id] = []
        }
        userAssignments[assignment.user_id].push(assignment)
      }
      return data
    },
  })

  // Create assignment
  const createAssignment = createResource({
    url: 'crm.api.assignments.create_assignment',
    onSuccess(data) {
      assignmentsById[data.id] = data
      assignments.reload()
    },
  })

  // Update assignment
  const updateAssignment = createResource({
    url: 'crm.api.assignments.update_assignment',
    onSuccess(data) {
      assignmentsById[data.id] = data
      assignments.reload()
    },
  })

  // Delete assignment
  const deleteAssignment = createResource({
    url: 'crm.api.assignments.delete_assignment',
    onSuccess(_, params) {
      delete assignmentsById[params.assignment_id]
      assignments.reload()
    },
  })

  // Batch assign users to project
  const batchAssign = createResource({
    url: 'crm.api.assignments.batch_assign',
    onSuccess() {
      assignments.reload()
    },
  })

  // Update assignment status
  const updateStatus = createResource({
    url: 'crm.api.assignments.update_status',
    onSuccess(data) {
      if (assignmentsById[data.id]) {
        assignmentsById[data.id].status = data.status
      }
    },
  })

  // Log hours
  const logHours = createResource({
    url: 'crm.api.assignments.log_hours',
    onSuccess(data) {
      if (assignmentsById[data.id]) {
        assignmentsById[data.id].actual_hours = data.actual_hours
      }
    },
  })

  // Computed properties
  const allAssignments = computed(() => assignments.data || [])

  const activeAssignments = computed(() =>
    allAssignments.value.filter((a) => a.status === 'active')
  )

  const pendingAssignments = computed(() =>
    allAssignments.value.filter((a) => a.status === 'pending')
  )

  const completedAssignments = computed(() =>
    allAssignments.value.filter((a) => a.status === 'completed')
  )

  const filteredAssignments = computed(() => {
    let result = allAssignments.value

    if (activeFilters.value.status) {
      result = result.filter((a) => a.status === activeFilters.value.status)
    }
    if (activeFilters.value.priority !== null) {
      result = result.filter((a) => a.priority === activeFilters.value.priority)
    }
    if (activeFilters.value.team_id) {
      result = result.filter((a) => a.team_id === activeFilters.value.team_id)
    }
    if (activeFilters.value.user_id) {
      result = result.filter((a) => a.user_id === activeFilters.value.user_id)
    }

    return result
  })

  // Helper functions
  function getAssignment(id) {
    return assignmentsById[id] || null
  }

  function getProjectAssignments(projectId) {
    return projectAssignments[projectId] || []
  }

  function getUserAssignments(userId) {
    return userAssignments[userId] || []
  }

  function getUserActiveAssignments(userId) {
    return (userAssignments[userId] || []).filter((a) => a.status === 'active')
  }

  function getUserWorkload(userId) {
    const active = getUserActiveAssignments(userId)
    return active.reduce((sum, a) => {
      const hours = a.estimated_hours || 0
      const allocation = a.allocation_percentage || 100
      return sum + (hours * allocation) / 100
    }, 0)
  }

  function getTeamAssignments(teamId) {
    return allAssignments.value.filter((a) => a.team_id === teamId)
  }

  function getTeamActiveAssignments(teamId) {
    return getTeamAssignments(teamId).filter((a) => a.status === 'active')
  }

  function getAssignmentsByPriority(priority) {
    return allAssignments.value.filter((a) => a.priority === priority)
  }

  function getOverdueAssignments() {
    const now = new Date()
    return activeAssignments.value.filter((a) => {
      if (!a.end_date) return false
      return new Date(a.end_date) < now
    })
  }

  function getUpcomingDeadlines(days = 7) {
    const now = new Date()
    const futureDate = new Date()
    futureDate.setDate(now.getDate() + days)

    return activeAssignments.value.filter((a) => {
      if (!a.end_date) return false
      const endDate = new Date(a.end_date)
      return endDate >= now && endDate <= futureDate
    })
  }

  function setFilters(filters) {
    activeFilters.value = { ...activeFilters.value, ...filters }
  }

  function clearFilters() {
    activeFilters.value = {
      status: 'active',
      priority: null,
      team_id: null,
      user_id: null,
    }
  }

  // Priority helpers
  const priorityLabels = {
    0: 'Low',
    1: 'Medium',
    2: 'High',
    3: 'Urgent',
  }

  const priorityColors = {
    0: '#22c55e', // green
    1: '#3b82f6', // blue
    2: '#f59e0b', // amber
    3: '#ef4444', // red
  }

  function getPriorityLabel(priority) {
    return priorityLabels[priority] || 'Unknown'
  }

  function getPriorityColor(priority) {
    return priorityColors[priority] || '#6b7280'
  }

  // Role labels
  const roleLabels = {
    owner: 'Project Owner',
    manager: 'Project Manager',
    contributor: 'Contributor',
    reviewer: 'Reviewer',
    viewer: 'Viewer',
  }

  function getRoleLabel(role) {
    return roleLabels[role] || role
  }

  // Status labels
  const statusLabels = {
    pending: 'Pending',
    active: 'Active',
    completed: 'Completed',
    on_hold: 'On Hold',
    removed: 'Removed',
  }

  const statusColors = {
    pending: '#f59e0b',
    active: '#22c55e',
    completed: '#3b82f6',
    on_hold: '#6b7280',
    removed: '#ef4444',
  }

  function getStatusLabel(status) {
    return statusLabels[status] || status
  }

  function getStatusColor(status) {
    return statusColors[status] || '#6b7280'
  }

  // Load data
  async function loadAssignments(filters = {}) {
    isLoading.value = true
    try {
      await assignments.fetch({ ...activeFilters.value, ...filters })
    } finally {
      isLoading.value = false
    }
  }

  return {
    // State
    assignments,
    activeFilters,
    isLoading,

    // Computed
    allAssignments,
    activeAssignments,
    pendingAssignments,
    completedAssignments,
    filteredAssignments,

    // Actions
    createAssignment,
    updateAssignment,
    deleteAssignment,
    batchAssign,
    updateStatus,
    logHours,
    loadAssignments,
    setFilters,
    clearFilters,

    // Helpers
    getAssignment,
    getProjectAssignments,
    getUserAssignments,
    getUserActiveAssignments,
    getUserWorkload,
    getTeamAssignments,
    getTeamActiveAssignments,
    getAssignmentsByPriority,
    getOverdueAssignments,
    getUpcomingDeadlines,
    getPriorityLabel,
    getPriorityColor,
    getRoleLabel,
    getStatusLabel,
    getStatusColor,
  }
})

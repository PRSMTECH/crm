import { defineStore } from 'pinia'
import { createResource } from 'frappe-ui'
import { reactive, computed, ref } from 'vue'
import { sessionStore } from './session'

export const teamsStore = defineStore('crm-teams', () => {
  const session = sessionStore()

  // Reactive state
  let teamsById = reactive({})
  let teamMembersById = reactive({})
  let rolesById = reactive({})
  const activeTeamId = ref(null)
  const isLoading = ref(false)

  // Teams resource
  const teams = createResource({
    url: 'crm.api.teams.get_teams',
    cache: 'crm-teams',
    initialData: [],
    auto: true,
    transform(data) {
      for (let team of data) {
        teamsById[team.id] = team
      }
      return data
    },
  })

  // Team members resource
  const teamMembers = createResource({
    url: 'crm.api.teams.get_all_team_members',
    cache: 'crm-team-members',
    initialData: [],
    transform(data) {
      for (let member of data) {
        if (!teamMembersById[member.team_id]) {
          teamMembersById[member.team_id] = []
        }
        teamMembersById[member.team_id].push(member)
      }
      return data
    },
  })

  // Roles resource
  const roles = createResource({
    url: 'crm.api.teams.get_roles',
    cache: 'crm-roles',
    initialData: [],
    auto: true,
    transform(data) {
      for (let role of data) {
        rolesById[role.id] = role
      }
      return data
    },
  })

  // Create team
  const createTeam = createResource({
    url: 'crm.api.teams.create_team',
    onSuccess(data) {
      teamsById[data.id] = data
      teams.reload()
    },
  })

  // Update team
  const updateTeam = createResource({
    url: 'crm.api.teams.update_team',
    onSuccess(data) {
      teamsById[data.id] = data
      teams.reload()
    },
  })

  // Delete team
  const deleteTeam = createResource({
    url: 'crm.api.teams.delete_team',
    onSuccess(_, params) {
      const teamId = params.team_id
      delete teamsById[teamId]
      teams.reload()
    },
  })

  // Add team member
  const addTeamMember = createResource({
    url: 'crm.api.teams.add_team_member',
    onSuccess(data) {
      if (!teamMembersById[data.team_id]) {
        teamMembersById[data.team_id] = []
      }
      teamMembersById[data.team_id].push(data)
      teamMembers.reload()
    },
  })

  // Remove team member
  const removeTeamMember = createResource({
    url: 'crm.api.teams.remove_team_member',
    onSuccess(_, params) {
      const { team_id, user_id } = params
      if (teamMembersById[team_id]) {
        teamMembersById[team_id] = teamMembersById[team_id].filter(
          (m) => m.user_id !== user_id
        )
      }
      teamMembers.reload()
    },
  })

  // Update member role
  const updateMemberRole = createResource({
    url: 'crm.api.teams.update_member_role',
    onSuccess() {
      teamMembers.reload()
    },
  })

  // Computed properties
  const allTeams = computed(() => teams.data || [])
  const activeTeams = computed(() => allTeams.value.filter((t) => t.is_active))
  const allRoles = computed(() => roles.data || [])

  // Helper functions
  function getTeam(id) {
    return teamsById[id] || null
  }

  function getTeamMembers(teamId) {
    return teamMembersById[teamId] || []
  }

  function getRole(id) {
    return rolesById[id] || null
  }

  function getRoleByName(name) {
    return allRoles.value.find((r) => r.name === name) || null
  }

  function getUserTeams(userId) {
    const userTeams = []
    for (const teamId in teamMembersById) {
      const members = teamMembersById[teamId]
      const member = members.find((m) => m.user_id === userId && m.is_active)
      if (member) {
        userTeams.push({
          team: teamsById[teamId],
          role: member.role,
          joinedAt: member.joined_at,
        })
      }
    }
    return userTeams
  }

  function isTeamManager(teamId, userId) {
    const members = getTeamMembers(teamId)
    const member = members.find((m) => m.user_id === userId)
    return member?.role === 'manager'
  }

  function isTeamMember(teamId, userId) {
    const members = getTeamMembers(teamId)
    return members.some((m) => m.user_id === userId && m.is_active)
  }

  function getTeamWorkloadPercentage(teamId) {
    const team = getTeam(teamId)
    if (!team || !team.capacity) return 0
    return Math.round((team.current_workload / team.capacity) * 100)
  }

  function setActiveTeam(teamId) {
    activeTeamId.value = teamId
  }

  // Load initial data
  async function loadTeamData() {
    isLoading.value = true
    try {
      await Promise.all([teams.fetch(), roles.fetch()])
    } finally {
      isLoading.value = false
    }
  }

  return {
    // State
    teams,
    teamMembers,
    roles,
    activeTeamId,
    isLoading,

    // Computed
    allTeams,
    activeTeams,
    allRoles,

    // Actions
    createTeam,
    updateTeam,
    deleteTeam,
    addTeamMember,
    removeTeamMember,
    updateMemberRole,
    loadTeamData,
    setActiveTeam,

    // Helpers
    getTeam,
    getTeamMembers,
    getRole,
    getRoleByName,
    getUserTeams,
    isTeamManager,
    isTeamMember,
    getTeamWorkloadPercentage,
  }
})

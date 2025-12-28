import { defineStore } from 'pinia'
import { createResource } from 'frappe-ui'
import { reactive, computed, ref } from 'vue'
import { usersStore } from './users'

export const projectNotesStore = defineStore('crm-project-notes', () => {
  const users = usersStore()

  // Reactive state
  let notesById = reactive({})
  let notesByProject = reactive({}) // projectId -> notes[]
  const isLoading = ref(false)
  const activeNoteId = ref(null)
  const searchQuery = ref('')
  const activeFilters = ref({
    note_type: null,
    priority: null,
    status: null,
    is_pinned: null,
    author_id: null,
  })

  // Notes resource
  const notes = createResource({
    url: 'crm.api.notes.get_project_notes',
    cache: 'crm-project-notes',
    initialData: [],
    transform(data) {
      for (let note of data) {
        notesById[note.id] = note

        if (!notesByProject[note.project_id]) {
          notesByProject[note.project_id] = []
        }
        notesByProject[note.project_id].push(note)
      }
      return data
    },
  })

  // Create note
  const createNote = createResource({
    url: 'crm.api.notes.create_project_note',
    onSuccess(data) {
      notesById[data.id] = data
      if (!notesByProject[data.project_id]) {
        notesByProject[data.project_id] = []
      }
      notesByProject[data.project_id].unshift(data)
    },
  })

  // Update note
  const updateNote = createResource({
    url: 'crm.api.notes.update_project_note',
    onSuccess(data) {
      notesById[data.id] = data
      const projectNotes = notesByProject[data.project_id] || []
      const index = projectNotes.findIndex((n) => n.id === data.id)
      if (index !== -1) {
        projectNotes[index] = data
      }
    },
  })

  // Delete note
  const deleteNote = createResource({
    url: 'crm.api.notes.delete_project_note',
    onSuccess(_, params) {
      const note = notesById[params.note_id]
      if (note) {
        delete notesById[params.note_id]
        notesByProject[note.project_id] = (
          notesByProject[note.project_id] || []
        ).filter((n) => n.id !== params.note_id)
      }
    },
  })

  // Reply to note
  const replyToNote = createResource({
    url: 'crm.api.notes.reply_to_note',
    onSuccess(data) {
      notesById[data.id] = data
      // Update parent's thread count
      if (data.parent_id && notesById[data.parent_id]) {
        notesById[data.parent_id].thread_count++
      }
    },
  })

  // Toggle pin
  const togglePin = createResource({
    url: 'crm.api.notes.toggle_pin',
    onSuccess(data) {
      if (notesById[data.id]) {
        notesById[data.id].is_pinned = data.is_pinned
      }
    },
  })

  // Resolve note
  const resolveNote = createResource({
    url: 'crm.api.notes.resolve_note',
    onSuccess(data) {
      if (notesById[data.id]) {
        notesById[data.id].status = 'resolved'
        notesById[data.id].resolved_by = data.resolved_by
        notesById[data.id].resolved_at = data.resolved_at
      }
    },
  })

  // Add reaction
  const addReaction = createResource({
    url: 'crm.api.notes.add_reaction',
    onSuccess(data) {
      if (notesById[data.note_id]) {
        notesById[data.note_id].reactions = data.reactions
      }
    },
  })

  // Mark as read
  const markAsRead = createResource({
    url: 'crm.api.notes.mark_as_read',
    onSuccess(data) {
      if (notesById[data.note_id]) {
        if (!notesById[data.note_id].read_by) {
          notesById[data.note_id].read_by = []
        }
        notesById[data.note_id].read_by.push(data.user_id)
      }
    },
  })

  // Computed properties
  const allNotes = computed(() => Object.values(notesById))

  const pinnedNotes = computed(() => allNotes.value.filter((n) => n.is_pinned))

  const unreadNotes = computed(() => {
    const currentUserId = users.getUser()?.id
    return allNotes.value.filter(
      (n) => !n.read_by || !n.read_by.includes(currentUserId)
    )
  })

  const filteredNotes = computed(() => {
    let result = allNotes.value

    if (searchQuery.value) {
      const query = searchQuery.value.toLowerCase()
      result = result.filter(
        (n) =>
          n.title?.toLowerCase().includes(query) ||
          n.content?.toLowerCase().includes(query)
      )
    }

    if (activeFilters.value.note_type) {
      result = result.filter(
        (n) => n.note_type === activeFilters.value.note_type
      )
    }
    if (activeFilters.value.priority) {
      result = result.filter((n) => n.priority === activeFilters.value.priority)
    }
    if (activeFilters.value.status) {
      result = result.filter((n) => n.status === activeFilters.value.status)
    }
    if (activeFilters.value.is_pinned !== null) {
      result = result.filter(
        (n) => n.is_pinned === activeFilters.value.is_pinned
      )
    }
    if (activeFilters.value.author_id) {
      result = result.filter(
        (n) => n.author_id === activeFilters.value.author_id
      )
    }

    return result
  })

  // Helper functions
  function getNote(id) {
    return notesById[id] || null
  }

  function getProjectNotes(projectId) {
    return notesByProject[projectId] || []
  }

  function getPinnedProjectNotes(projectId) {
    return getProjectNotes(projectId).filter((n) => n.is_pinned)
  }

  function getNoteReplies(noteId) {
    return allNotes.value.filter((n) => n.parent_id === noteId)
  }

  function getNotesByType(projectId, noteType) {
    return getProjectNotes(projectId).filter((n) => n.note_type === noteType)
  }

  function getMentionedNotes(userId) {
    return allNotes.value.filter(
      (n) => n.mentions && n.mentions.includes(userId)
    )
  }

  function getUnresolvedBlockers(projectId) {
    return getProjectNotes(projectId).filter(
      (n) => n.note_type === 'blocker' && n.status !== 'resolved'
    )
  }

  function setSearch(query) {
    searchQuery.value = query
  }

  function setFilters(filters) {
    activeFilters.value = { ...activeFilters.value, ...filters }
  }

  function clearFilters() {
    activeFilters.value = {
      note_type: null,
      priority: null,
      status: null,
      is_pinned: null,
      author_id: null,
    }
    searchQuery.value = ''
  }

  function setActiveNote(noteId) {
    activeNoteId.value = noteId
  }

  // Note type helpers
  const noteTypeLabels = {
    general: 'General',
    update: 'Update',
    blocker: 'Blocker',
    decision: 'Decision',
    milestone: 'Milestone',
    question: 'Question',
    announcement: 'Announcement',
  }

  const noteTypeIcons = {
    general: 'file-text',
    update: 'refresh-cw',
    blocker: 'alert-circle',
    decision: 'check-circle',
    milestone: 'flag',
    question: 'help-circle',
    announcement: 'megaphone',
  }

  const noteTypeColors = {
    general: '#6b7280',
    update: '#3b82f6',
    blocker: '#ef4444',
    decision: '#22c55e',
    milestone: '#8b5cf6',
    question: '#f59e0b',
    announcement: '#ec4899',
  }

  function getNoteTypeLabel(type) {
    return noteTypeLabels[type] || type
  }

  function getNoteTypeIcon(type) {
    return noteTypeIcons[type] || 'file-text'
  }

  function getNoteTypeColor(type) {
    return noteTypeColors[type] || '#6b7280'
  }

  // Priority helpers
  const priorityLabels = {
    low: 'Low',
    normal: 'Normal',
    high: 'High',
    urgent: 'Urgent',
  }

  const priorityColors = {
    low: '#22c55e',
    normal: '#6b7280',
    high: '#f59e0b',
    urgent: '#ef4444',
  }

  function getPriorityLabel(priority) {
    return priorityLabels[priority] || priority
  }

  function getPriorityColor(priority) {
    return priorityColors[priority] || '#6b7280'
  }

  // Parse @mentions from content
  function parseMentions(content) {
    const mentionRegex = /@\[([^\]]+)\]\(([^)]+)\)/g
    const mentions = []
    let match
    while ((match = mentionRegex.exec(content)) !== null) {
      mentions.push({
        name: match[1],
        id: match[2],
      })
    }
    return mentions
  }

  // Convert plain text mentions to HTML
  function formatMentions(content) {
    return content.replace(
      /@\[([^\]]+)\]\(([^)]+)\)/g,
      '<span class="mention" data-id="$2">@$1</span>'
    )
  }

  // Load notes for a project
  async function loadProjectNotes(projectId) {
    isLoading.value = true
    try {
      await notes.fetch({ project_id: projectId })
    } finally {
      isLoading.value = false
    }
  }

  // Alias for consistency with component naming
  async function fetchProjectNotes(projectId) {
    return loadProjectNotes(projectId)
  }

  return {
    // State
    notes,
    activeNoteId,
    searchQuery,
    activeFilters,
    isLoading,

    // Computed
    allNotes,
    pinnedNotes,
    unreadNotes,
    filteredNotes,

    // Actions
    createNote,
    updateNote,
    deleteNote,
    replyToNote,
    togglePin,
    resolveNote,
    addReaction,
    markAsRead,
    loadProjectNotes,
    fetchProjectNotes,
    setSearch,
    setFilters,
    clearFilters,
    setActiveNote,

    // Helpers
    getNote,
    getProjectNotes,
    getPinnedProjectNotes,
    getNoteReplies,
    getNotesByType,
    getMentionedNotes,
    getUnresolvedBlockers,
    getNoteTypeLabel,
    getNoteTypeIcon,
    getNoteTypeColor,
    getPriorityLabel,
    getPriorityColor,
    parseMentions,
    formatMentions,
  }
})

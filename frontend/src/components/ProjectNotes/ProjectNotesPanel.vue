<template>
  <div class="flex h-full flex-col">
    <!-- Header -->
    <div class="flex items-center justify-between border-b border-outline-gray-2 px-4 py-3">
      <div class="flex items-center gap-3">
        <h3 class="text-lg font-semibold text-ink-gray-9">{{ __('Project Notes') }}</h3>
        <span
          v-if="filteredNotes.length"
          class="rounded-full bg-surface-gray-3 px-2 py-0.5 text-xs font-medium text-ink-gray-6"
        >
          {{ filteredNotes.length }}
        </span>
      </div>
      <div class="flex items-center gap-2">
        <Button
          variant="solid"
          :label="__('Add Note')"
          @click="openCreateModal"
        >
          <template #prefix>
            <FeatherIcon name="plus" class="h-4 w-4" />
          </template>
        </Button>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap items-center gap-3 border-b border-outline-gray-2 px-4 py-2">
      <!-- Search -->
      <div class="relative flex-1 min-w-[200px] max-w-[300px]">
        <FeatherIcon
          name="search"
          class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-gray-4"
        />
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="__('Search notes...')"
          class="w-full rounded-lg border border-outline-gray-2 bg-surface-white py-1.5 pl-9 pr-3 text-sm placeholder:text-ink-gray-4 focus:border-outline-gray-4 focus:outline-none"
        />
      </div>

      <!-- Type Filter -->
      <Dropdown :options="typeFilterOptions">
        <template #default="{ open }">
          <Button variant="outline" class="gap-2">
            <span class="text-ink-gray-7">{{ selectedTypeLabel }}</span>
            <FeatherIcon
              name="chevron-down"
              class="h-4 w-4 text-ink-gray-5 transition-transform"
              :class="{ 'rotate-180': open }"
            />
          </Button>
        </template>
      </Dropdown>

      <!-- Priority Filter -->
      <Dropdown :options="priorityFilterOptions">
        <template #default="{ open }">
          <Button variant="outline" class="gap-2">
            <span class="text-ink-gray-7">{{ selectedPriorityLabel }}</span>
            <FeatherIcon
              name="chevron-down"
              class="h-4 w-4 text-ink-gray-5 transition-transform"
              :class="{ 'rotate-180': open }"
            />
          </Button>
        </template>
      </Dropdown>

      <!-- Show Pinned Toggle -->
      <label class="flex cursor-pointer items-center gap-2">
        <input
          type="checkbox"
          v-model="showPinnedOnly"
          class="h-4 w-4 rounded border-outline-gray-3 text-blue-600 focus:ring-blue-500"
        />
        <span class="text-sm text-ink-gray-6">{{ __('Pinned only') }}</span>
      </label>

      <!-- Clear Filters -->
      <Button
        v-if="hasActiveFilters"
        variant="ghost"
        size="sm"
        :label="__('Clear filters')"
        @click="clearFilters"
      />
    </div>

    <!-- Notes List -->
    <div class="flex-1 overflow-y-auto p-4">
      <!-- Loading State -->
      <div v-if="loading" class="flex items-center justify-center py-12">
        <LoadingIndicator class="h-6 w-6" />
      </div>

      <!-- Empty State -->
      <div
        v-else-if="!filteredNotes.length"
        class="flex flex-col items-center justify-center py-12 text-center"
      >
        <FeatherIcon name="file-text" class="mb-4 h-12 w-12 text-ink-gray-4" />
        <h4 class="text-lg font-medium text-ink-gray-7">
          {{ searchQuery || hasActiveFilters ? __('No matching notes') : __('No notes yet') }}
        </h4>
        <p class="mt-1 text-sm text-ink-gray-5">
          {{
            searchQuery || hasActiveFilters
              ? __('Try adjusting your search or filters')
              : __('Create your first note to start collaborating')
          }}
        </p>
        <Button
          v-if="!searchQuery && !hasActiveFilters"
          variant="solid"
          :label="__('Create Note')"
          class="mt-4"
          @click="openCreateModal"
        />
      </div>

      <!-- Notes Grid -->
      <div v-else class="space-y-4">
        <!-- Pinned Notes Section -->
        <div v-if="pinnedNotes.length && !showPinnedOnly">
          <h4 class="mb-3 flex items-center gap-2 text-sm font-medium text-ink-gray-6">
            <FeatherIcon name="star" class="h-4 w-4 text-amber-500" />
            {{ __('Pinned') }}
          </h4>
          <div class="space-y-3">
            <ProjectNoteCard
              v-for="note in pinnedNotes"
              :key="note.id"
              :note="note"
              @edit="openEditModal"
              @delete="confirmDelete"
              @reply="openReplyModal"
              @toggle-pin="togglePin"
              @resolve="resolveNote"
              @react="addReaction"
            />
          </div>
        </div>

        <!-- All/Unpinned Notes Section -->
        <div v-if="unpinnedNotes.length || showPinnedOnly">
          <h4
            v-if="pinnedNotes.length && !showPinnedOnly"
            class="mb-3 text-sm font-medium text-ink-gray-6"
          >
            {{ __('All Notes') }}
          </h4>
          <div class="space-y-3">
            <ProjectNoteCard
              v-for="note in showPinnedOnly ? filteredNotes : unpinnedNotes"
              :key="note.id"
              :note="note"
              @edit="openEditModal"
              @delete="confirmDelete"
              @reply="openReplyModal"
              @toggle-pin="togglePin"
              @resolve="resolveNote"
              @react="addReaction"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Create/Edit Modal -->
    <ProjectNoteModal
      v-model="showModal"
      :note="selectedNote"
      :project-id="projectId"
      :parent-id="replyToId"
      @after="handleModalClose"
    />

    <!-- Delete Confirmation Dialog -->
    <Dialog v-model="showDeleteDialog" :options="{ title: __('Delete Note') }">
      <template #body-content>
        <p class="text-ink-gray-7">
          {{ __('Are you sure you want to delete this note? This action cannot be undone.') }}
        </p>
      </template>
      <template #actions>
        <div class="flex justify-end gap-2">
          <Button variant="subtle" :label="__('Cancel')" @click="showDeleteDialog = false" />
          <Button
            variant="solid"
            theme="red"
            :label="__('Delete')"
            :loading="deleting"
            @click="deleteNote"
          />
        </div>
      </template>
    </Dialog>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { FeatherIcon, Dropdown, Dialog, LoadingIndicator } from 'frappe-ui'
import ProjectNoteCard from './ProjectNoteCard.vue'
import ProjectNoteModal from './ProjectNoteModal.vue'
import { projectNotesStore } from '@/stores/projectNotes'

const props = defineProps({
  projectId: {
    type: String,
    required: true,
  },
})

const notesStore = projectNotesStore()

// State
const loading = ref(false)
const searchQuery = ref('')
const selectedType = ref('all')
const selectedPriority = ref('all')
const showPinnedOnly = ref(false)
const showModal = ref(false)
const showDeleteDialog = ref(false)
const selectedNote = ref(null)
const replyToId = ref(null)
const noteToDelete = ref(null)
const deleting = ref(false)

// Filter options
const typeFilterOptions = computed(() => [
  { label: 'All Types', onClick: () => (selectedType.value = 'all') },
  { label: 'General', onClick: () => (selectedType.value = 'general') },
  { label: 'Update', onClick: () => (selectedType.value = 'update') },
  { label: 'Blocker', onClick: () => (selectedType.value = 'blocker') },
  { label: 'Decision', onClick: () => (selectedType.value = 'decision') },
  { label: 'Milestone', onClick: () => (selectedType.value = 'milestone') },
  { label: 'Question', onClick: () => (selectedType.value = 'question') },
  { label: 'Announcement', onClick: () => (selectedType.value = 'announcement') },
])

const priorityFilterOptions = computed(() => [
  { label: 'All Priorities', onClick: () => (selectedPriority.value = 'all') },
  { label: 'Low', onClick: () => (selectedPriority.value = 'low') },
  { label: 'Normal', onClick: () => (selectedPriority.value = 'normal') },
  { label: 'High', onClick: () => (selectedPriority.value = 'high') },
  { label: 'Urgent', onClick: () => (selectedPriority.value = 'urgent') },
])

const selectedTypeLabel = computed(() => {
  if (selectedType.value === 'all') return 'All Types'
  return notesStore.getNoteTypeLabel(selectedType.value)
})

const selectedPriorityLabel = computed(() => {
  if (selectedPriority.value === 'all') return 'All Priorities'
  return notesStore.getPriorityLabel(selectedPriority.value)
})

const hasActiveFilters = computed(() => {
  return searchQuery.value || selectedType.value !== 'all' || selectedPriority.value !== 'all' || showPinnedOnly.value
})

// Filtered notes
const filteredNotes = computed(() => {
  let notes = notesStore.getProjectNotes(props.projectId)

  // Search filter
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    notes = notes.filter(
      (note) =>
        note.title?.toLowerCase().includes(query) ||
        note.content?.toLowerCase().includes(query) ||
        note.tags?.some((tag) => tag.toLowerCase().includes(query))
    )
  }

  // Type filter
  if (selectedType.value !== 'all') {
    notes = notes.filter((note) => note.note_type === selectedType.value)
  }

  // Priority filter
  if (selectedPriority.value !== 'all') {
    notes = notes.filter((note) => note.priority === selectedPriority.value)
  }

  // Pinned filter
  if (showPinnedOnly.value) {
    notes = notes.filter((note) => note.is_pinned)
  }

  // Sort: pinned first, then by created date
  return notes.sort((a, b) => {
    if (a.is_pinned !== b.is_pinned) return b.is_pinned ? 1 : -1
    return new Date(b.created_at) - new Date(a.created_at)
  })
})

const pinnedNotes = computed(() => filteredNotes.value.filter((note) => note.is_pinned))
const unpinnedNotes = computed(() => filteredNotes.value.filter((note) => !note.is_pinned))

// Methods
function clearFilters() {
  searchQuery.value = ''
  selectedType.value = 'all'
  selectedPriority.value = 'all'
  showPinnedOnly.value = false
}

function openCreateModal() {
  selectedNote.value = null
  replyToId.value = null
  showModal.value = true
}

function openEditModal(note) {
  selectedNote.value = note
  replyToId.value = null
  showModal.value = true
}

function openReplyModal(note) {
  selectedNote.value = null
  replyToId.value = note.id
  showModal.value = true
}

function confirmDelete(note) {
  noteToDelete.value = note
  showDeleteDialog.value = true
}

async function deleteNote() {
  if (!noteToDelete.value) return

  deleting.value = true
  try {
    await notesStore.deleteNote.submit({ note_id: noteToDelete.value.id })
    showDeleteDialog.value = false
    noteToDelete.value = null
  } catch (error) {
    console.error('Failed to delete note:', error)
  } finally {
    deleting.value = false
  }
}

async function togglePin(note) {
  try {
    await notesStore.togglePin.submit({ note_id: note.id })
  } catch (error) {
    console.error('Failed to toggle pin:', error)
  }
}

async function resolveNote(note) {
  try {
    await notesStore.resolveNote.submit({ note_id: note.id })
  } catch (error) {
    console.error('Failed to resolve note:', error)
  }
}

async function addReaction(note, emoji) {
  try {
    await notesStore.addReaction.submit({ note_id: note.id, emoji })
  } catch (error) {
    console.error('Failed to add reaction:', error)
  }
}

function handleModalClose() {
  selectedNote.value = null
  replyToId.value = null
  loadNotes()
}

async function loadNotes() {
  loading.value = true
  try {
    await notesStore.fetchProjectNotes(props.projectId)
  } catch (error) {
    console.error('Failed to load notes:', error)
  } finally {
    loading.value = false
  }
}

// Load notes on mount and when project changes
onMounted(loadNotes)
watch(() => props.projectId, loadNotes)
</script>

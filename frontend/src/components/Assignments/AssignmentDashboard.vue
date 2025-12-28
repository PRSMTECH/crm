<template>
  <div class="flex h-full flex-col">
    <!-- Header -->
    <div class="flex items-center justify-between border-b border-outline-gray-2 px-6 py-4">
      <div>
        <h2 class="text-xl font-semibold text-ink-gray-9">{{ __('Assignment Dashboard') }}</h2>
        <p class="mt-1 text-sm text-ink-gray-5">
          {{ __('Track team workload and project assignments') }}
        </p>
      </div>
      <div class="flex items-center gap-3">
        <Button
          variant="subtle"
          :label="__('Refresh')"
          @click="refreshData"
        >
          <template #prefix>
            <FeatherIcon name="refresh-cw" class="h-4 w-4" />
          </template>
        </Button>
        <Button
          variant="solid"
          :label="__('New Assignment')"
          @click="openAssignmentModal"
        >
          <template #prefix>
            <FeatherIcon name="plus" class="h-4 w-4" />
          </template>
        </Button>
      </div>
    </div>

    <!-- Content -->
    <div class="flex-1 overflow-y-auto p-6">
      <!-- Loading State -->
      <div v-if="loading" class="flex items-center justify-center py-12">
        <LoadingIndicator class="h-8 w-8" />
      </div>

      <template v-else>
        <!-- Stats Overview -->
        <div class="grid grid-cols-2 gap-4 sm:grid-cols-4 mb-6">
          <div class="rounded-lg border border-outline-gray-2 bg-surface-white p-4">
            <div class="flex items-center gap-3">
              <div class="rounded-full bg-blue-100 p-2">
                <FeatherIcon name="activity" class="h-5 w-5 text-blue-600" />
              </div>
              <div>
                <p class="text-2xl font-semibold text-ink-gray-9">{{ stats.active }}</p>
                <p class="text-sm text-ink-gray-5">{{ __('Active') }}</p>
              </div>
            </div>
          </div>

          <div class="rounded-lg border border-outline-gray-2 bg-surface-white p-4">
            <div class="flex items-center gap-3">
              <div class="rounded-full bg-amber-100 p-2">
                <FeatherIcon name="clock" class="h-5 w-5 text-amber-600" />
              </div>
              <div>
                <p class="text-2xl font-semibold text-ink-gray-9">{{ stats.pending }}</p>
                <p class="text-sm text-ink-gray-5">{{ __('Pending') }}</p>
              </div>
            </div>
          </div>

          <div class="rounded-lg border border-outline-gray-2 bg-surface-white p-4">
            <div class="flex items-center gap-3">
              <div class="rounded-full bg-green-100 p-2">
                <FeatherIcon name="check-circle" class="h-5 w-5 text-green-600" />
              </div>
              <div>
                <p class="text-2xl font-semibold text-ink-gray-9">{{ stats.completed }}</p>
                <p class="text-sm text-ink-gray-5">{{ __('Completed') }}</p>
              </div>
            </div>
          </div>

          <div class="rounded-lg border border-outline-gray-2 bg-surface-white p-4">
            <div class="flex items-center gap-3">
              <div class="rounded-full bg-red-100 p-2">
                <FeatherIcon name="alert-triangle" class="h-5 w-5 text-red-600" />
              </div>
              <div>
                <p class="text-2xl font-semibold text-ink-gray-9">{{ stats.overdue }}</p>
                <p class="text-sm text-ink-gray-5">{{ __('Overdue') }}</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Two Column Layout -->
        <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <!-- Left Column: Workload & Deadlines -->
          <div class="lg:col-span-1 space-y-6">
            <!-- Team Workload -->
            <WorkloadChart :loading="loading" />

            <!-- Upcoming Deadlines -->
            <div class="rounded-lg border border-outline-gray-2 bg-surface-white p-4">
              <h4 class="text-sm font-medium text-ink-gray-7 mb-4">
                {{ __('Upcoming Deadlines') }}
              </h4>
              <div v-if="!upcomingDeadlines.length" class="text-center py-4">
                <FeatherIcon name="calendar" class="mx-auto h-6 w-6 text-ink-gray-4" />
                <p class="mt-2 text-sm text-ink-gray-5">{{ __('No upcoming deadlines') }}</p>
              </div>
              <div v-else class="space-y-3">
                <div
                  v-for="assignment in upcomingDeadlines.slice(0, 5)"
                  :key="assignment.id"
                  class="flex items-center justify-between text-sm"
                >
                  <div class="flex items-center gap-2 min-w-0">
                    <div
                      class="h-2 w-2 rounded-full flex-shrink-0"
                      :style="{ backgroundColor: assignmentsStore.getPriorityColor(assignment.priority) }"
                    />
                    <span class="truncate text-ink-gray-7">{{ assignment.project_name }}</span>
                  </div>
                  <span
                    class="text-xs font-medium flex-shrink-0 ml-2"
                    :class="getDaysUntilClass(assignment.end_date)"
                  >
                    {{ formatDaysUntil(assignment.end_date) }}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- Right Column: Assignments List -->
          <div class="lg:col-span-2">
            <div class="rounded-lg border border-outline-gray-2 bg-surface-white">
              <!-- Filters -->
              <div class="flex flex-wrap items-center gap-3 border-b border-outline-gray-2 p-4">
                <!-- Search -->
                <div class="relative flex-1 min-w-[200px]">
                  <FeatherIcon
                    name="search"
                    class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-gray-4"
                  />
                  <input
                    v-model="searchQuery"
                    type="text"
                    :placeholder="__('Search assignments...')"
                    class="w-full rounded-lg border border-outline-gray-2 bg-surface-white py-1.5 pl-9 pr-3 text-sm placeholder:text-ink-gray-4 focus:border-outline-gray-4 focus:outline-none"
                  />
                </div>

                <!-- Status Filter -->
                <Dropdown :options="statusFilterOptions">
                  <template #default="{ open }">
                    <Button variant="outline" class="gap-2">
                      <span class="text-ink-gray-7">{{ selectedStatusLabel }}</span>
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

                <!-- User Filter -->
                <Dropdown :options="userFilterOptions">
                  <template #default="{ open }">
                    <Button variant="outline" class="gap-2">
                      <span class="text-ink-gray-7">{{ selectedUserLabel }}</span>
                      <FeatherIcon
                        name="chevron-down"
                        class="h-4 w-4 text-ink-gray-5 transition-transform"
                        :class="{ 'rotate-180': open }"
                      />
                    </Button>
                  </template>
                </Dropdown>

                <!-- Clear Filters -->
                <Button
                  v-if="hasActiveFilters"
                  variant="ghost"
                  size="sm"
                  :label="__('Clear')"
                  @click="clearFilters"
                />
              </div>

              <!-- Assignments List -->
              <div class="p-4">
                <div v-if="!filteredAssignments.length" class="text-center py-8">
                  <FeatherIcon name="inbox" class="mx-auto h-10 w-10 text-ink-gray-4" />
                  <h4 class="mt-3 text-lg font-medium text-ink-gray-7">
                    {{ searchQuery || hasActiveFilters ? __('No matching assignments') : __('No assignments yet') }}
                  </h4>
                  <p class="mt-1 text-sm text-ink-gray-5">
                    {{ searchQuery || hasActiveFilters
                      ? __('Try adjusting your filters')
                      : __('Create your first assignment to get started')
                    }}
                  </p>
                </div>

                <div v-else class="grid gap-4 sm:grid-cols-2">
                  <AssignmentCard
                    v-for="assignment in filteredAssignments"
                    :key="assignment.id"
                    :assignment="assignment"
                    @update-status="handleStatusUpdate"
                    @log-hours="openLogHoursModal"
                    @edit="openEditModal"
                    @delete="confirmDelete"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- Assignment Modal -->
    <AssignmentModal
      v-model="showAssignmentModal"
      :assignment="selectedAssignment"
      @saved="handleAssignmentSaved"
    />

    <!-- Log Hours Modal -->
    <Dialog v-model="showLogHoursModal" :options="{ title: __('Log Hours') }">
      <template #body-content>
        <div class="space-y-4">
          <FormControl
            v-model="logHoursForm.hours"
            type="number"
            :label="__('Hours Worked')"
            :placeholder="__('Enter hours')"
            min="0"
            step="0.5"
          />
          <FormControl
            v-model="logHoursForm.notes"
            type="textarea"
            :label="__('Notes (optional)')"
            :placeholder="__('What did you work on?')"
            :rows="3"
          />
        </div>
      </template>
      <template #actions>
        <div class="flex justify-end gap-2">
          <Button variant="subtle" :label="__('Cancel')" @click="showLogHoursModal = false" />
          <Button
            variant="solid"
            :label="__('Log Hours')"
            :loading="loggingHours"
            @click="submitLogHours"
          />
        </div>
      </template>
    </Dialog>

    <!-- Delete Confirmation -->
    <Dialog v-model="showDeleteDialog" :options="{ title: __('Delete Assignment') }">
      <template #body-content>
        <p class="text-ink-gray-7">
          {{ __('Are you sure you want to delete this assignment? This action cannot be undone.') }}
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
            @click="deleteAssignment"
          />
        </div>
      </template>
    </Dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { FeatherIcon, Dropdown, Dialog, FormControl, LoadingIndicator } from 'frappe-ui'
import AssignmentCard from './AssignmentCard.vue'
import WorkloadChart from './WorkloadChart.vue'
import AssignmentModal from './AssignmentModal.vue'
import { assignmentsStore } from '@/stores/assignments'
import { usersStore } from '@/stores/users'

const assignments = assignmentsStore()
const users = usersStore()

// State
const loading = ref(false)
const searchQuery = ref('')
const selectedStatus = ref('all')
const selectedPriority = ref('all')
const selectedUser = ref('all')
const showAssignmentModal = ref(false)
const showLogHoursModal = ref(false)
const showDeleteDialog = ref(false)
const selectedAssignment = ref(null)
const assignmentToDelete = ref(null)
const deleting = ref(false)
const loggingHours = ref(false)
const logHoursForm = ref({
  hours: null,
  notes: '',
})

// Computed
const stats = computed(() => ({
  active: assignments.allAssignments.filter((a) => a.status === 'active').length,
  pending: assignments.allAssignments.filter((a) => a.status === 'pending').length,
  completed: assignments.allAssignments.filter((a) => a.status === 'completed').length,
  overdue: assignments.getOverdueAssignments().length,
}))

const upcomingDeadlines = computed(() => assignments.getUpcomingDeadlines(7))

const statusFilterOptions = computed(() => [
  { label: 'All Status', onClick: () => (selectedStatus.value = 'all') },
  { label: 'Active', onClick: () => (selectedStatus.value = 'active') },
  { label: 'Pending', onClick: () => (selectedStatus.value = 'pending') },
  { label: 'Completed', onClick: () => (selectedStatus.value = 'completed') },
  { label: 'On Hold', onClick: () => (selectedStatus.value = 'on_hold') },
])

const priorityFilterOptions = computed(() => [
  { label: 'All Priorities', onClick: () => (selectedPriority.value = 'all') },
  { label: 'Low', onClick: () => (selectedPriority.value = 'low') },
  { label: 'Normal', onClick: () => (selectedPriority.value = 'normal') },
  { label: 'High', onClick: () => (selectedPriority.value = 'high') },
  { label: 'Urgent', onClick: () => (selectedPriority.value = 'urgent') },
])

const userFilterOptions = computed(() => {
  const userOptions = (users.options?.data || []).map((user) => ({
    label: user.full_name || user.name,
    onClick: () => (selectedUser.value = user.name),
  }))
  return [{ label: 'All Users', onClick: () => (selectedUser.value = 'all') }, ...userOptions]
})

const selectedStatusLabel = computed(() => {
  if (selectedStatus.value === 'all') return 'All Status'
  return assignments.getStatusLabel(selectedStatus.value)
})

const selectedPriorityLabel = computed(() => {
  if (selectedPriority.value === 'all') return 'All Priorities'
  return assignments.getPriorityLabel(selectedPriority.value)
})

const selectedUserLabel = computed(() => {
  if (selectedUser.value === 'all') return 'All Users'
  const user = users.getUser(selectedUser.value)
  return user?.full_name || selectedUser.value
})

const hasActiveFilters = computed(() => {
  return (
    searchQuery.value ||
    selectedStatus.value !== 'all' ||
    selectedPriority.value !== 'all' ||
    selectedUser.value !== 'all'
  )
})

const filteredAssignments = computed(() => {
  let result = assignments.allAssignments

  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    result = result.filter(
      (a) =>
        a.project_name?.toLowerCase().includes(query) ||
        a.role?.toLowerCase().includes(query) ||
        a.notes?.toLowerCase().includes(query)
    )
  }

  if (selectedStatus.value !== 'all') {
    result = result.filter((a) => a.status === selectedStatus.value)
  }

  if (selectedPriority.value !== 'all') {
    result = result.filter((a) => a.priority === selectedPriority.value)
  }

  if (selectedUser.value !== 'all') {
    result = result.filter((a) => a.user_id === selectedUser.value)
  }

  // Sort by priority, then by end date
  return result.sort((a, b) => {
    const priorityOrder = { urgent: 0, high: 1, normal: 2, low: 3 }
    if (priorityOrder[a.priority] !== priorityOrder[b.priority]) {
      return priorityOrder[a.priority] - priorityOrder[b.priority]
    }
    if (a.end_date && b.end_date) {
      return new Date(a.end_date) - new Date(b.end_date)
    }
    return 0
  })
})

// Methods
function clearFilters() {
  searchQuery.value = ''
  selectedStatus.value = 'all'
  selectedPriority.value = 'all'
  selectedUser.value = 'all'
}

function openAssignmentModal() {
  selectedAssignment.value = null
  showAssignmentModal.value = true
}

function openEditModal(assignment) {
  selectedAssignment.value = assignment
  showAssignmentModal.value = true
}

function openLogHoursModal(assignment) {
  selectedAssignment.value = assignment
  logHoursForm.value = { hours: null, notes: '' }
  showLogHoursModal.value = true
}

function confirmDelete(assignment) {
  assignmentToDelete.value = assignment
  showDeleteDialog.value = true
}

async function handleStatusUpdate(assignment, newStatus) {
  try {
    await assignments.updateStatus.submit({
      assignment_id: assignment.id,
      status: newStatus,
    })
  } catch (error) {
    console.error('Failed to update status:', error)
  }
}

async function submitLogHours() {
  if (!selectedAssignment.value || !logHoursForm.value.hours) return

  loggingHours.value = true
  try {
    await assignments.logHours.submit({
      assignment_id: selectedAssignment.value.id,
      hours: parseFloat(logHoursForm.value.hours),
      notes: logHoursForm.value.notes,
    })
    showLogHoursModal.value = false
    selectedAssignment.value = null
  } catch (error) {
    console.error('Failed to log hours:', error)
  } finally {
    loggingHours.value = false
  }
}

async function deleteAssignment() {
  if (!assignmentToDelete.value) return

  deleting.value = true
  try {
    await assignments.deleteAssignment.submit({
      assignment_id: assignmentToDelete.value.id,
    })
    showDeleteDialog.value = false
    assignmentToDelete.value = null
  } catch (error) {
    console.error('Failed to delete assignment:', error)
  } finally {
    deleting.value = false
  }
}

function handleAssignmentSaved() {
  showAssignmentModal.value = false
  selectedAssignment.value = null
  refreshData()
}

async function refreshData() {
  loading.value = true
  try {
    await assignments.assignments.fetch()
  } finally {
    loading.value = false
  }
}

function getDaysUntilClass(dateStr) {
  if (!dateStr) return 'text-ink-gray-5'
  const days = Math.ceil((new Date(dateStr) - new Date()) / (1000 * 60 * 60 * 24))
  if (days < 0) return 'text-red-600'
  if (days <= 2) return 'text-amber-600'
  return 'text-ink-gray-6'
}

function formatDaysUntil(dateStr) {
  if (!dateStr) return ''
  const days = Math.ceil((new Date(dateStr) - new Date()) / (1000 * 60 * 60 * 24))
  if (days < 0) return `${Math.abs(days)}d overdue`
  if (days === 0) return 'Today'
  if (days === 1) return 'Tomorrow'
  return `${days}d left`
}

// Expose store for child components
const assignmentsStore = assignments

// Load data on mount
onMounted(() => {
  refreshData()
})
</script>

<template>
  <div
    class="group rounded-lg border border-outline-gray-2 bg-surface-white p-4 transition-all hover:border-outline-gray-3 hover:shadow-sm"
    :class="{ 'border-l-4': true }"
    :style="{ borderLeftColor: getPriorityColor(assignment.priority) }"
  >
    <!-- Header -->
    <div class="flex items-start justify-between gap-3">
      <div class="flex-1 min-w-0">
        <h4 class="font-medium text-ink-gray-9 truncate">{{ assignment.project_name || 'Project Assignment' }}</h4>
        <div class="flex items-center gap-2 mt-1">
          <span
            class="text-xs font-medium px-1.5 py-0.5 rounded"
            :style="{
              backgroundColor: getStatusColor(assignment.status) + '15',
              color: getStatusColor(assignment.status)
            }"
          >
            {{ getStatusLabel(assignment.status) }}
          </span>
          <span
            class="text-xs font-medium px-1.5 py-0.5 rounded"
            :style="{
              backgroundColor: getPriorityColor(assignment.priority) + '15',
              color: getPriorityColor(assignment.priority)
            }"
          >
            {{ getPriorityLabel(assignment.priority) }}
          </span>
          <span class="text-xs text-ink-gray-5">
            {{ getRoleLabel(assignment.role) }}
          </span>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
        <Dropdown :options="statusOptions">
          <template #default>
            <button class="rounded p-1.5 text-ink-gray-5 hover:bg-surface-gray-2 hover:text-ink-gray-7">
              <FeatherIcon name="more-vertical" class="h-4 w-4" />
            </button>
          </template>
        </Dropdown>
      </div>
    </div>

    <!-- Progress & Hours -->
    <div class="mt-4 space-y-2">
      <!-- Progress Bar -->
      <div v-if="assignment.progress !== undefined">
        <div class="flex items-center justify-between text-xs text-ink-gray-5 mb-1">
          <span>{{ __('Progress') }}</span>
          <span>{{ assignment.progress }}%</span>
        </div>
        <div class="h-1.5 w-full rounded-full bg-surface-gray-3 overflow-hidden">
          <div
            class="h-full rounded-full transition-all"
            :style="{
              width: `${assignment.progress}%`,
              backgroundColor: getProgressColor(assignment.progress)
            }"
          />
        </div>
      </div>

      <!-- Hours -->
      <div class="flex items-center justify-between text-sm">
        <div class="flex items-center gap-2 text-ink-gray-6">
          <FeatherIcon name="clock" class="h-3.5 w-3.5" />
          <span>
            {{ assignment.actual_hours || 0 }}h / {{ assignment.estimated_hours || 0 }}h
          </span>
        </div>
        <div v-if="assignment.allocation_percentage" class="text-xs text-ink-gray-5">
          {{ assignment.allocation_percentage }}% allocation
        </div>
      </div>
    </div>

    <!-- Dates -->
    <div class="mt-3 flex items-center justify-between text-xs text-ink-gray-5">
      <div v-if="assignment.start_date" class="flex items-center gap-1">
        <FeatherIcon name="calendar" class="h-3.5 w-3.5" />
        <span>{{ formatDate(assignment.start_date) }}</span>
      </div>
      <div
        v-if="assignment.end_date"
        class="flex items-center gap-1"
        :class="{ 'text-red-500': isOverdue }"
      >
        <FeatherIcon name="flag" class="h-3.5 w-3.5" />
        <span>{{ formatDate(assignment.end_date) }}</span>
        <span v-if="isOverdue" class="text-red-500 font-medium">(Overdue)</span>
      </div>
    </div>

    <!-- Assigned User -->
    <div class="mt-3 pt-3 border-t border-outline-gray-1 flex items-center gap-2">
      <UserAvatar :user="assignment.user_id" size="xs" />
      <span class="text-sm text-ink-gray-6">{{ getUserName(assignment.user_id) }}</span>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { FeatherIcon, Dropdown } from 'frappe-ui'
import UserAvatar from '@/components/UserAvatar.vue'
import { assignmentsStore } from '@/stores/assignments'
import { usersStore } from '@/stores/users'

const props = defineProps({
  assignment: {
    type: Object,
    required: true,
  },
})

const emit = defineEmits(['update-status', 'log-hours', 'edit', 'delete'])

const assignments = assignmentsStore()
const users = usersStore()

const { getPriorityLabel, getPriorityColor, getStatusLabel, getStatusColor, getRoleLabel } = assignments

const isOverdue = computed(() => {
  if (!props.assignment.end_date || props.assignment.status === 'completed') return false
  return new Date(props.assignment.end_date) < new Date()
})

const statusOptions = computed(() => [
  {
    group: 'Update Status',
    items: [
      { label: 'Set Active', onClick: () => emit('update-status', props.assignment, 'active') },
      { label: 'Set Pending', onClick: () => emit('update-status', props.assignment, 'pending') },
      { label: 'Mark Completed', onClick: () => emit('update-status', props.assignment, 'completed') },
      { label: 'Put On Hold', onClick: () => emit('update-status', props.assignment, 'on_hold') },
    ],
  },
  {
    group: 'Actions',
    items: [
      { label: 'Log Hours', onClick: () => emit('log-hours', props.assignment) },
      { label: 'Edit Assignment', onClick: () => emit('edit', props.assignment) },
      { label: 'Remove Assignment', onClick: () => emit('delete', props.assignment), variant: 'destructive' },
    ],
  },
])

function getProgressColor(progress) {
  if (progress >= 80) return '#22c55e' // green
  if (progress >= 50) return '#3b82f6' // blue
  if (progress >= 25) return '#f59e0b' // amber
  return '#ef4444' // red
}

function formatDate(dateStr) {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

function getUserName(userId) {
  const user = users.getUser(userId)
  return user?.full_name || userId
}
</script>

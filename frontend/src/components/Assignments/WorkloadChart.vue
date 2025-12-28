<template>
  <div class="rounded-lg border border-outline-gray-2 bg-surface-white p-4">
    <h4 class="text-sm font-medium text-ink-gray-7 mb-4">{{ __('Team Workload') }}</h4>

    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-8">
      <LoadingIndicator class="h-6 w-6" />
    </div>

    <!-- Empty State -->
    <div v-else-if="!teamMembers.length" class="text-center py-8">
      <FeatherIcon name="users" class="mx-auto h-8 w-8 text-ink-gray-4" />
      <p class="mt-2 text-sm text-ink-gray-5">{{ __('No team members to display') }}</p>
    </div>

    <!-- Workload Bars -->
    <div v-else class="space-y-4">
      <div
        v-for="member in sortedMembers"
        :key="member.id"
        class="flex items-center gap-3"
      >
        <!-- User Avatar & Name -->
        <div class="flex items-center gap-2 w-32 flex-shrink-0">
          <UserAvatar :user="member.id" size="xs" />
          <span class="text-sm text-ink-gray-7 truncate">{{ member.name }}</span>
        </div>

        <!-- Workload Bar Container -->
        <div class="flex-1">
          <div class="relative h-6 rounded-full bg-surface-gray-2 overflow-hidden">
            <!-- Workload Fill -->
            <div
              class="absolute left-0 top-0 h-full rounded-full transition-all"
              :style="{
                width: `${Math.min(member.workloadPercentage, 100)}%`,
                backgroundColor: getWorkloadColor(member.workloadPercentage)
              }"
            />
            <!-- Overload indicator -->
            <div
              v-if="member.workloadPercentage > 100"
              class="absolute right-0 top-0 h-full w-2 bg-red-500 rounded-r-full animate-pulse"
            />
            <!-- Label -->
            <div class="absolute inset-0 flex items-center justify-center">
              <span
                class="text-xs font-medium"
                :class="member.workloadPercentage > 50 ? 'text-white' : 'text-ink-gray-7'"
              >
                {{ member.activeCount }} {{ __('assignments') }} · {{ member.totalHours }}h
              </span>
            </div>
          </div>
        </div>

        <!-- Workload Percentage -->
        <div class="w-16 text-right">
          <span
            class="text-sm font-medium"
            :style="{ color: getWorkloadColor(member.workloadPercentage) }"
          >
            {{ member.workloadPercentage }}%
          </span>
        </div>
      </div>
    </div>

    <!-- Legend -->
    <div class="mt-4 pt-4 border-t border-outline-gray-1 flex flex-wrap gap-4 text-xs text-ink-gray-5">
      <div class="flex items-center gap-1">
        <div class="w-3 h-3 rounded-full bg-green-500" />
        <span>{{ __('Under capacity') }} (&lt;70%)</span>
      </div>
      <div class="flex items-center gap-1">
        <div class="w-3 h-3 rounded-full bg-amber-500" />
        <span>{{ __('Optimal') }} (70-90%)</span>
      </div>
      <div class="flex items-center gap-1">
        <div class="w-3 h-3 rounded-full bg-red-500" />
        <span>{{ __('Overloaded') }} (&gt;90%)</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { FeatherIcon, LoadingIndicator } from 'frappe-ui'
import UserAvatar from '@/components/UserAvatar.vue'
import { assignmentsStore } from '@/stores/assignments'
import { usersStore } from '@/stores/users'

const props = defineProps({
  teamId: {
    type: String,
    default: null,
  },
  loading: {
    type: Boolean,
    default: false,
  },
  maxHoursPerWeek: {
    type: Number,
    default: 40,
  },
})

const assignments = assignmentsStore()
const users = usersStore()

const teamMembers = computed(() => {
  const usersList = users.options?.data || []
  return usersList.map((user) => {
    const userAssignments = assignments.getUserActiveAssignments(user.name)
    const totalHours = assignments.getUserWorkload(user.name)
    const workloadPercentage = Math.round((totalHours / props.maxHoursPerWeek) * 100)

    return {
      id: user.name,
      name: user.full_name || user.name,
      activeCount: userAssignments.length,
      totalHours: Math.round(totalHours * 10) / 10,
      workloadPercentage,
      assignments: userAssignments,
    }
  }).filter((m) => m.activeCount > 0 || m.totalHours > 0)
})

const sortedMembers = computed(() => {
  return [...teamMembers.value].sort((a, b) => b.workloadPercentage - a.workloadPercentage)
})

function getWorkloadColor(percentage) {
  if (percentage > 90) return '#ef4444' // red
  if (percentage > 70) return '#f59e0b' // amber
  return '#22c55e' // green
}
</script>

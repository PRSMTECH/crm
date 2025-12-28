<template>
  <div
    class="group relative rounded-lg border border-outline-gray-2 bg-surface-white p-4 transition-all hover:border-outline-gray-3 hover:shadow-md"
    :style="{ borderLeftColor: team.color, borderLeftWidth: '4px' }"
  >
    <!-- Header -->
    <div class="flex items-start justify-between">
      <div class="flex items-center gap-3">
        <div
          class="flex h-10 w-10 items-center justify-center rounded-full text-white font-semibold text-sm"
          :style="{ backgroundColor: team.color || '#3b82f6' }"
        >
          {{ getInitials(team.name) }}
        </div>
        <div>
          <h3 class="font-semibold text-ink-gray-9">{{ team.name }}</h3>
          <p class="text-sm text-ink-gray-5">{{ memberCount }} members</p>
        </div>
      </div>

      <!-- Status Badge -->
      <span
        class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium"
        :class="team.is_active ? 'bg-green-50 text-green-700' : 'bg-gray-100 text-gray-600'"
      >
        {{ team.is_active ? __('Active') : __('Inactive') }}
      </span>
    </div>

    <!-- Description -->
    <p v-if="team.description" class="mt-3 text-sm text-ink-gray-6 line-clamp-2">
      {{ team.description }}
    </p>

    <!-- Stats -->
    <div class="mt-4 grid grid-cols-2 gap-3">
      <div class="rounded-md bg-surface-gray-2 p-2">
        <p class="text-xs text-ink-gray-5">{{ __('Capacity') }}</p>
        <p class="font-semibold text-ink-gray-8">{{ team.capacity || 0 }} hrs/wk</p>
      </div>
      <div class="rounded-md bg-surface-gray-2 p-2">
        <p class="text-xs text-ink-gray-5">{{ __('Projects') }}</p>
        <p class="font-semibold text-ink-gray-8">{{ team.project_count || 0 }}</p>
      </div>
    </div>

    <!-- Member Avatars -->
    <div v-if="team.members?.length" class="mt-4 flex items-center gap-1">
      <div class="flex -space-x-2">
        <div
          v-for="(member, index) in displayMembers"
          :key="member.id"
          class="relative inline-flex h-7 w-7 items-center justify-center rounded-full border-2 border-white bg-surface-gray-3 text-xs font-medium text-ink-gray-7"
          :title="member.full_name"
        >
          <img
            v-if="member.user_image"
            :src="member.user_image"
            :alt="member.full_name"
            class="h-full w-full rounded-full object-cover"
          />
          <span v-else>{{ getInitials(member.full_name) }}</span>
        </div>
        <div
          v-if="remainingMembers > 0"
          class="relative inline-flex h-7 w-7 items-center justify-center rounded-full border-2 border-white bg-ink-gray-3 text-xs font-medium text-white"
        >
          +{{ remainingMembers }}
        </div>
      </div>
    </div>

    <!-- Actions (visible on hover) -->
    <div class="absolute right-2 top-2 flex gap-1 opacity-0 transition-opacity group-hover:opacity-100">
      <button
        class="rounded p-1.5 text-ink-gray-5 hover:bg-surface-gray-2 hover:text-ink-gray-7"
        :title="__('Manage Members')"
        @click.stop="$emit('manage-members', team)"
      >
        <FeatherIcon name="users" class="h-4 w-4" />
      </button>
      <button
        class="rounded p-1.5 text-ink-gray-5 hover:bg-surface-gray-2 hover:text-ink-gray-7"
        :title="__('Edit Team')"
        @click.stop="$emit('edit', team)"
      >
        <FeatherIcon name="edit-2" class="h-4 w-4" />
      </button>
      <button
        class="rounded p-1.5 text-ink-gray-5 hover:bg-red-50 hover:text-red-600"
        :title="__('Delete Team')"
        @click.stop="$emit('delete', team)"
      >
        <FeatherIcon name="trash-2" class="h-4 w-4" />
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { FeatherIcon } from 'frappe-ui'

const props = defineProps({
  team: {
    type: Object,
    required: true,
  },
})

defineEmits(['edit', 'delete', 'manage-members'])

const memberCount = computed(() => props.team.members?.length || 0)

const displayMembers = computed(() => {
  return (props.team.members || []).slice(0, 4)
})

const remainingMembers = computed(() => {
  const total = props.team.members?.length || 0
  return total > 4 ? total - 4 : 0
})

function getInitials(name) {
  if (!name) return '?'
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2)
}
</script>

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>

<template>
  <div class="space-y-6">
    <!-- Add Member Section -->
    <div class="rounded-lg border border-outline-gray-2 p-4">
      <h4 class="mb-3 font-medium text-ink-gray-8">{{ __('Add Team Member') }}</h4>
      <div class="flex gap-3">
        <div class="flex-1">
          <Autocomplete
            v-model="selectedUser"
            :options="availableUsers"
            :placeholder="__('Search users...')"
            option-label="full_name"
            option-value="name"
          />
        </div>
        <div class="w-40">
          <select
            v-model="selectedRole"
            class="w-full rounded border border-outline-gray-2 px-3 py-2 text-base focus:border-outline-gray-4 focus:outline-none"
          >
            <option value="member">{{ __('Member') }}</option>
            <option value="lead">{{ __('Lead') }}</option>
            <option value="manager">{{ __('Manager') }}</option>
            <option value="owner">{{ __('Owner') }}</option>
            <option value="viewer">{{ __('Viewer') }}</option>
          </select>
        </div>
        <Button
          variant="solid"
          :label="__('Add')"
          :loading="adding"
          :disabled="!selectedUser"
          @click="addMember"
        />
      </div>
    </div>

    <!-- Current Members -->
    <div>
      <h4 class="mb-3 font-medium text-ink-gray-8">
        {{ __('Current Members') }} ({{ team.members?.length || 0 }})
      </h4>

      <div v-if="!team.members?.length" class="rounded-lg border border-dashed border-outline-gray-3 p-6 text-center">
        <UsersIcon class="mx-auto h-8 w-8 text-ink-gray-4" />
        <p class="mt-2 text-sm text-ink-gray-5">{{ __('No members yet') }}</p>
      </div>

      <div v-else class="space-y-2">
        <div
          v-for="member in sortedMembers"
          :key="member.id"
          class="flex items-center justify-between rounded-lg border border-outline-gray-2 p-3 hover:bg-surface-gray-1"
        >
          <div class="flex items-center gap-3">
            <!-- Avatar -->
            <div
              class="flex h-10 w-10 items-center justify-center rounded-full bg-surface-gray-3 text-sm font-medium text-ink-gray-7"
            >
              <img
                v-if="member.user_image"
                :src="member.user_image"
                :alt="member.full_name"
                class="h-full w-full rounded-full object-cover"
              />
              <span v-else>{{ getInitials(member.full_name) }}</span>
            </div>

            <!-- Info -->
            <div>
              <p class="font-medium text-ink-gray-8">{{ member.full_name }}</p>
              <p class="text-sm text-ink-gray-5">{{ member.user_id }}</p>
            </div>
          </div>

          <div class="flex items-center gap-3">
            <!-- Role Badge -->
            <span
              class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium"
              :class="getRoleBadgeClass(member.role)"
            >
              {{ getRoleLabel(member.role) }}
            </span>

            <!-- Role Dropdown -->
            <select
              v-model="member.role"
              class="rounded border border-outline-gray-2 px-2 py-1 text-sm focus:border-outline-gray-4 focus:outline-none"
              @change="updateMemberRole(member)"
            >
              <option value="member">{{ __('Member') }}</option>
              <option value="lead">{{ __('Lead') }}</option>
              <option value="manager">{{ __('Manager') }}</option>
              <option value="owner">{{ __('Owner') }}</option>
              <option value="viewer">{{ __('Viewer') }}</option>
            </select>

            <!-- Remove Button -->
            <button
              class="rounded p-1.5 text-ink-gray-5 hover:bg-red-50 hover:text-red-600"
              :title="__('Remove member')"
              @click="confirmRemoveMember(member)"
            >
              <FeatherIcon name="x" class="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Capacity Overview -->
    <div class="rounded-lg border border-outline-gray-2 p-4">
      <h4 class="mb-3 font-medium text-ink-gray-8">{{ __('Team Capacity') }}</h4>
      <div class="grid grid-cols-3 gap-4 text-center">
        <div>
          <p class="text-2xl font-semibold text-ink-gray-9">{{ team.capacity || 0 }}</p>
          <p class="text-sm text-ink-gray-5">{{ __('Hours/Week') }}</p>
        </div>
        <div>
          <p class="text-2xl font-semibold text-ink-gray-9">{{ team.members?.length || 0 }}</p>
          <p class="text-sm text-ink-gray-5">{{ __('Members') }}</p>
        </div>
        <div>
          <p class="text-2xl font-semibold text-ink-gray-9">{{ avgCapacityPerMember }}</p>
          <p class="text-sm text-ink-gray-5">{{ __('Avg hrs/member') }}</p>
        </div>
      </div>
    </div>

    <!-- Remove Confirmation Dialog -->
    <Dialog
      v-model="showRemoveConfirm"
      :options="{
        title: __('Remove Member'),
        size: 'sm',
      }"
    >
      <template #body-content>
        <p class="text-ink-gray-6">
          {{ __('Are you sure you want to remove {0} from this team?', [memberToRemove?.full_name]) }}
        </p>
      </template>
      <template #actions>
        <div class="flex justify-end gap-2">
          <Button variant="subtle" :label="__('Cancel')" @click="showRemoveConfirm = false" />
          <Button
            variant="solid"
            theme="red"
            :label="__('Remove')"
            :loading="removing"
            @click="removeMember"
          />
        </div>
      </template>
    </Dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { FeatherIcon, Dialog, Autocomplete } from 'frappe-ui'
import { teamsStore } from '@/stores/teams'
import { usersStore } from '@/stores/users'
import UsersIcon from '@/components/Icons/UsersIcon.vue'

const props = defineProps({
  team: {
    type: Object,
    required: true,
  },
})

const emit = defineEmits(['close'])

const teams = teamsStore()
const users = usersStore()

// State
const selectedUser = ref(null)
const selectedRole = ref('member')
const adding = ref(false)
const removing = ref(false)
const showRemoveConfirm = ref(false)
const memberToRemove = ref(null)

// Computed
const availableUsers = computed(() => {
  const memberIds = (props.team.members || []).map((m) => m.user_id)
  return (users.options?.data || []).filter((u) => !memberIds.includes(u.name))
})

const sortedMembers = computed(() => {
  const roleOrder = { owner: 0, manager: 1, lead: 2, member: 3, viewer: 4 }
  return [...(props.team.members || [])].sort((a, b) => {
    return (roleOrder[a.role] || 5) - (roleOrder[b.role] || 5)
  })
})

const avgCapacityPerMember = computed(() => {
  const memberCount = props.team.members?.length || 0
  if (memberCount === 0) return 0
  return Math.round((props.team.capacity || 0) / memberCount)
})

// Methods
function getInitials(name) {
  if (!name) return '?'
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2)
}

function getRoleLabel(role) {
  const labels = {
    owner: 'Owner',
    manager: 'Manager',
    lead: 'Lead',
    member: 'Member',
    viewer: 'Viewer',
  }
  return labels[role] || role
}

function getRoleBadgeClass(role) {
  const classes = {
    owner: 'bg-purple-50 text-purple-700',
    manager: 'bg-blue-50 text-blue-700',
    lead: 'bg-green-50 text-green-700',
    member: 'bg-gray-100 text-gray-700',
    viewer: 'bg-orange-50 text-orange-700',
  }
  return classes[role] || 'bg-gray-100 text-gray-700'
}

async function addMember() {
  if (!selectedUser.value) return

  adding.value = true
  try {
    await teams.addTeamMember.submit({
      team_id: props.team.id,
      user_id: selectedUser.value.name || selectedUser.value,
      role: selectedRole.value,
    })
    selectedUser.value = null
    selectedRole.value = 'member'
  } catch (error) {
    console.error('Error adding member:', error)
  } finally {
    adding.value = false
  }
}

function confirmRemoveMember(member) {
  memberToRemove.value = member
  showRemoveConfirm.value = true
}

async function removeMember() {
  if (!memberToRemove.value) return

  removing.value = true
  try {
    await teams.removeTeamMember.submit({
      team_id: props.team.id,
      user_id: memberToRemove.value.user_id,
    })
    showRemoveConfirm.value = false
    memberToRemove.value = null
  } catch (error) {
    console.error('Error removing member:', error)
  } finally {
    removing.value = false
  }
}

async function updateMemberRole(member) {
  try {
    await teams.updateTeamMember.submit({
      team_id: props.team.id,
      user_id: member.user_id,
      role: member.role,
    })
  } catch (error) {
    console.error('Error updating role:', error)
  }
}

onMounted(() => {
  // Ensure users list is loaded
  if (!users.options?.data?.length) {
    users.options?.fetch?.()
  }
})
</script>

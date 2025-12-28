<template>
  <LayoutHeader>
    <template #left-header>
      <div class="flex items-center gap-2">
        <TeamsIcon class="h-5 w-5 text-ink-gray-5" />
        <h1 class="text-xl font-semibold text-ink-gray-9">{{ __('Teams') }}</h1>
      </div>
    </template>
    <template #right-header>
      <Button
        variant="solid"
        :label="__('Create Team')"
        iconLeft="plus"
        @click="showTeamModal = true"
      />
    </template>
  </LayoutHeader>

  <div class="flex-1 overflow-auto p-4">
    <!-- Loading State -->
    <div v-if="teams.isLoading" class="flex items-center justify-center h-64">
      <LoadingIndicator class="h-8 w-8" />
    </div>

    <!-- Teams Grid -->
    <div v-else-if="allTeams.length" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <TeamCard
        v-for="team in allTeams"
        :key="team.id"
        :team="team"
        @edit="editTeam"
        @delete="confirmDeleteTeam"
        @manage-members="manageMembersFor"
      />
    </div>

    <!-- Empty State -->
    <div v-else class="flex h-full items-center justify-center">
      <div class="flex flex-col items-center gap-3 text-xl font-medium text-ink-gray-4">
        <TeamsIcon class="h-10 w-10" />
        <span>{{ __('No Teams Found') }}</span>
        <Button
          :label="__('Create Team')"
          iconLeft="plus"
          @click="showTeamModal = true"
        />
      </div>
    </div>
  </div>

  <!-- Team Modal (Create/Edit) -->
  <Dialog
    v-model="showTeamModal"
    :options="{
      title: editingTeam ? __('Edit Team') : __('Create Team'),
      size: 'lg',
    }"
  >
    <template #body-content>
      <div class="space-y-4">
        <FormControl
          v-model="teamForm.name"
          :label="__('Team Name')"
          type="text"
          :placeholder="__('Enter team name')"
          required
        />
        <FormControl
          v-model="teamForm.description"
          :label="__('Description')"
          type="textarea"
          :placeholder="__('Team description')"
          :rows="3"
        />
        <div class="grid grid-cols-2 gap-4">
          <FormControl
            v-model="teamForm.capacity"
            :label="__('Capacity (hours/week)')"
            type="number"
            :placeholder="__('40')"
          />
          <div>
            <label class="text-sm font-medium text-ink-gray-5 mb-1.5 block">
              {{ __('Status') }}
            </label>
            <select
              v-model="teamForm.is_active"
              class="w-full rounded border border-outline-gray-2 px-3 py-2 text-base focus:border-outline-gray-4 focus:outline-none"
            >
              <option :value="true">{{ __('Active') }}</option>
              <option :value="false">{{ __('Inactive') }}</option>
            </select>
          </div>
        </div>
        <FormControl
          v-model="teamForm.color"
          :label="__('Team Color')"
          type="color"
        />
      </div>
    </template>
    <template #actions>
      <div class="flex justify-end gap-2">
        <Button variant="subtle" :label="__('Cancel')" @click="closeTeamModal" />
        <Button
          variant="solid"
          :label="editingTeam ? __('Update') : __('Create')"
          :loading="saving"
          @click="saveTeam"
        />
      </div>
    </template>
  </Dialog>

  <!-- Members Modal -->
  <Dialog
    v-model="showMembersModal"
    :options="{
      title: selectedTeam ? __('Manage Members - {0}', [selectedTeam.name]) : __('Manage Members'),
      size: 'xl',
    }"
  >
    <template #body-content>
      <TeamMembersManager
        v-if="selectedTeam"
        :team="selectedTeam"
        @close="showMembersModal = false"
      />
    </template>
  </Dialog>

  <!-- Delete Confirmation -->
  <Dialog
    v-model="showDeleteConfirm"
    :options="{
      title: __('Delete Team'),
      size: 'sm',
    }"
  >
    <template #body-content>
      <p class="text-ink-gray-6">
        {{ __('Are you sure you want to delete this team? This action cannot be undone.') }}
      </p>
    </template>
    <template #actions>
      <div class="flex justify-end gap-2">
        <Button variant="subtle" :label="__('Cancel')" @click="showDeleteConfirm = false" />
        <Button
          variant="solid"
          theme="red"
          :label="__('Delete')"
          :loading="deleting"
          @click="deleteTeam"
        />
      </div>
    </template>
  </Dialog>
</template>

<script setup>
import LayoutHeader from '@/components/LayoutHeader.vue'
import TeamCard from '@/components/Teams/TeamCard.vue'
import TeamMembersManager from '@/components/Teams/TeamMembersManager.vue'
import TeamsIcon from '@/components/Icons/TeamsIcon.vue'
import LoadingIndicator from '@/components/Icons/LoadingIndicator.vue'
import { teamsStore } from '@/stores/teams'
import { Dialog, FormControl } from 'frappe-ui'
import { ref, reactive, computed, onMounted } from 'vue'

const teams = teamsStore()
const allTeams = computed(() => teams.allTeams)

// Modal states
const showTeamModal = ref(false)
const showMembersModal = ref(false)
const showDeleteConfirm = ref(false)
const saving = ref(false)
const deleting = ref(false)

// Form state
const editingTeam = ref(null)
const selectedTeam = ref(null)
const teamToDelete = ref(null)

const teamForm = reactive({
  name: '',
  description: '',
  capacity: 40,
  is_active: true,
  color: '#3b82f6',
})

function resetForm() {
  teamForm.name = ''
  teamForm.description = ''
  teamForm.capacity = 40
  teamForm.is_active = true
  teamForm.color = '#3b82f6'
  editingTeam.value = null
}

function editTeam(team) {
  editingTeam.value = team
  teamForm.name = team.name
  teamForm.description = team.description || ''
  teamForm.capacity = team.capacity || 40
  teamForm.is_active = team.is_active !== false
  teamForm.color = team.color || '#3b82f6'
  showTeamModal.value = true
}

function closeTeamModal() {
  showTeamModal.value = false
  resetForm()
}

async function saveTeam() {
  if (!teamForm.name) return

  saving.value = true
  try {
    if (editingTeam.value) {
      await teams.updateTeam.submit({
        team_id: editingTeam.value.id,
        name: teamForm.name,
        description: teamForm.description,
        capacity: teamForm.capacity,
        is_active: teamForm.is_active,
        color: teamForm.color,
      })
    } else {
      await teams.createTeam.submit({
        name: teamForm.name,
        description: teamForm.description,
        capacity: teamForm.capacity,
        color: teamForm.color,
      })
    }
    closeTeamModal()
  } catch (error) {
    console.error('Error saving team:', error)
  } finally {
    saving.value = false
  }
}

function confirmDeleteTeam(team) {
  teamToDelete.value = team
  showDeleteConfirm.value = true
}

async function deleteTeam() {
  if (!teamToDelete.value) return

  deleting.value = true
  try {
    await teams.deleteTeam.submit({
      team_id: teamToDelete.value.id,
    })
    showDeleteConfirm.value = false
    teamToDelete.value = null
  } catch (error) {
    console.error('Error deleting team:', error)
  } finally {
    deleting.value = false
  }
}

function manageMembersFor(team) {
  selectedTeam.value = team
  showMembersModal.value = true
}

onMounted(() => {
  teams.loadTeamData()
})
</script>

<template>
  <Dialog
    :modelValue="modelValue"
    @update:modelValue="$emit('update:modelValue', $event)"
    :options="{
      title: assignment ? __('Edit Assignment') : __('New Assignment'),
      size: 'lg',
    }"
  >
    <template #body-content>
      <div class="space-y-4">
        <!-- Project Selection -->
        <div>
          <label class="mb-1.5 block text-sm font-medium text-ink-gray-7">
            {{ __('Project') }} <span class="text-red-500">*</span>
          </label>
          <Autocomplete
            v-model="form.project_id"
            :placeholder="__('Select project...')"
            :options="projectOptions"
          />
        </div>

        <!-- User Selection -->
        <div>
          <label class="mb-1.5 block text-sm font-medium text-ink-gray-7">
            {{ __('Assign To') }} <span class="text-red-500">*</span>
          </label>
          <Autocomplete
            v-model="form.user_id"
            :placeholder="__('Select team member...')"
            :options="userOptions"
          />
        </div>

        <!-- Role -->
        <FormControl
          v-model="form.role"
          type="select"
          :label="__('Role')"
          :options="roleOptions"
        />

        <!-- Priority & Status -->
        <div class="grid grid-cols-2 gap-4">
          <FormControl
            v-model="form.priority"
            type="select"
            :label="__('Priority')"
            :options="priorityOptions"
          />
          <FormControl
            v-model="form.status"
            type="select"
            :label="__('Status')"
            :options="statusOptions"
          />
        </div>

        <!-- Dates -->
        <div class="grid grid-cols-2 gap-4">
          <FormControl
            v-model="form.start_date"
            type="date"
            :label="__('Start Date')"
          />
          <FormControl
            v-model="form.end_date"
            type="date"
            :label="__('End Date')"
          />
        </div>

        <!-- Hours -->
        <div class="grid grid-cols-2 gap-4">
          <FormControl
            v-model="form.estimated_hours"
            type="number"
            :label="__('Estimated Hours')"
            :placeholder="__('e.g., 40')"
            min="0"
            step="0.5"
          />
          <FormControl
            v-model="form.allocation_percentage"
            type="number"
            :label="__('Allocation %')"
            :placeholder="__('e.g., 50')"
            min="0"
            max="100"
          />
        </div>

        <!-- Progress -->
        <div>
          <label class="mb-1.5 block text-sm font-medium text-ink-gray-7">
            {{ __('Progress') }}: {{ form.progress }}%
          </label>
          <input
            v-model="form.progress"
            type="range"
            min="0"
            max="100"
            step="5"
            class="w-full h-2 bg-surface-gray-3 rounded-lg appearance-none cursor-pointer"
          />
        </div>

        <!-- Notes -->
        <FormControl
          v-model="form.notes"
          type="textarea"
          :label="__('Notes')"
          :placeholder="__('Add any additional notes...')"
          :rows="3"
        />
      </div>
    </template>

    <template #actions>
      <div class="flex justify-end gap-2">
        <Button
          variant="subtle"
          :label="__('Cancel')"
          @click="$emit('update:modelValue', false)"
        />
        <Button
          variant="solid"
          :label="assignment ? __('Update') : __('Create')"
          :loading="saving"
          @click="saveAssignment"
        />
      </div>
    </template>
  </Dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { Dialog, FormControl, Autocomplete } from 'frappe-ui'
import { assignmentsStore } from '@/stores/assignments'
import { usersStore } from '@/stores/users'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false,
  },
  assignment: {
    type: Object,
    default: null,
  },
})

const emit = defineEmits(['update:modelValue', 'saved'])

const assignments = assignmentsStore()
const users = usersStore()

// Form state
const saving = ref(false)
const form = ref({
  project_id: '',
  user_id: '',
  role: 'contributor',
  priority: 'normal',
  status: 'pending',
  start_date: '',
  end_date: '',
  estimated_hours: null,
  allocation_percentage: 100,
  progress: 0,
  notes: '',
})

// Options
const projectOptions = computed(() => {
  // This would typically come from a projects store
  return []
})

const userOptions = computed(() => {
  return (users.options?.data || []).map((user) => ({
    label: user.full_name || user.name,
    value: user.name,
  }))
})

const roleOptions = [
  { label: 'Lead', value: 'lead' },
  { label: 'Contributor', value: 'contributor' },
  { label: 'Reviewer', value: 'reviewer' },
  { label: 'Consultant', value: 'consultant' },
  { label: 'Observer', value: 'observer' },
]

const priorityOptions = [
  { label: 'Low', value: 'low' },
  { label: 'Normal', value: 'normal' },
  { label: 'High', value: 'high' },
  { label: 'Urgent', value: 'urgent' },
]

const statusOptions = [
  { label: 'Pending', value: 'pending' },
  { label: 'Active', value: 'active' },
  { label: 'On Hold', value: 'on_hold' },
  { label: 'Completed', value: 'completed' },
]

// Watch for assignment changes
watch(
  () => props.assignment,
  (newVal) => {
    if (newVal) {
      form.value = {
        project_id: newVal.project_id || '',
        user_id: newVal.user_id || '',
        role: newVal.role || 'contributor',
        priority: newVal.priority || 'normal',
        status: newVal.status || 'pending',
        start_date: newVal.start_date || '',
        end_date: newVal.end_date || '',
        estimated_hours: newVal.estimated_hours || null,
        allocation_percentage: newVal.allocation_percentage || 100,
        progress: newVal.progress || 0,
        notes: newVal.notes || '',
      }
    } else {
      resetForm()
    }
  },
  { immediate: true }
)

// Watch modal visibility
watch(
  () => props.modelValue,
  (visible) => {
    if (!visible) {
      resetForm()
    }
  }
)

function resetForm() {
  form.value = {
    project_id: '',
    user_id: '',
    role: 'contributor',
    priority: 'normal',
    status: 'pending',
    start_date: '',
    end_date: '',
    estimated_hours: null,
    allocation_percentage: 100,
    progress: 0,
    notes: '',
  }
}

async function saveAssignment() {
  if (!form.value.project_id || !form.value.user_id) {
    return
  }

  saving.value = true
  try {
    const data = {
      ...form.value,
      estimated_hours: form.value.estimated_hours ? parseFloat(form.value.estimated_hours) : null,
      allocation_percentage: form.value.allocation_percentage
        ? parseInt(form.value.allocation_percentage)
        : 100,
      progress: parseInt(form.value.progress),
    }

    if (props.assignment) {
      await assignments.updateAssignment.submit({
        assignment_id: props.assignment.id,
        ...data,
      })
    } else {
      await assignments.createAssignment.submit(data)
    }

    emit('saved')
  } catch (error) {
    console.error('Failed to save assignment:', error)
  } finally {
    saving.value = false
  }
}
</script>

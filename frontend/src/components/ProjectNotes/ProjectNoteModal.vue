<template>
  <Dialog v-model="show" :options="{ size: 'xl' }">
    <template #body-title>
      <div class="flex items-center gap-3">
        <h3 class="text-2xl font-semibold leading-6 text-ink-gray-9">
          {{ editMode ? __('Edit Note') : isReply ? __('Reply to Note') : __('Create Note') }}
        </h3>
      </div>
    </template>
    <template #body-content>
      <div class="flex flex-col gap-4">
        <!-- Title -->
        <div>
          <FormControl
            ref="titleRef"
            :label="__('Title')"
            v-model="noteData.title"
            :placeholder="__('Enter note title...')"
            required
          />
        </div>

        <!-- Note Type and Priority -->
        <div class="grid grid-cols-2 gap-4">
          <div>
            <div class="mb-1.5 text-xs text-ink-gray-5">{{ __('Type') }}</div>
            <select
              v-model="noteData.note_type"
              class="w-full rounded border border-outline-gray-2 px-3 py-2 text-base focus:border-outline-gray-4 focus:outline-none"
            >
              <option v-for="(label, key) in noteTypes" :key="key" :value="key">
                {{ label }}
              </option>
            </select>
          </div>
          <div>
            <div class="mb-1.5 text-xs text-ink-gray-5">{{ __('Priority') }}</div>
            <select
              v-model="noteData.priority"
              class="w-full rounded border border-outline-gray-2 px-3 py-2 text-base focus:border-outline-gray-4 focus:outline-none"
            >
              <option v-for="(label, key) in priorities" :key="key" :value="key">
                {{ label }}
              </option>
            </select>
          </div>
        </div>

        <!-- Content with @mention support -->
        <div>
          <div class="mb-1.5 text-xs text-ink-gray-5">{{ __('Content') }}</div>
          <div class="relative">
            <TextEditor
              variant="outline"
              ref="contentRef"
              editor-class="!prose-sm overflow-auto min-h-[180px] max-h-80 py-1.5 px-2 rounded border border-[--surface-gray-2] bg-surface-gray-2 placeholder-ink-gray-4 hover:border-outline-gray-modals hover:bg-surface-gray-3 hover:shadow-sm focus:bg-surface-white focus:border-outline-gray-4 focus:shadow-sm focus:ring-0 focus-visible:ring-2 focus-visible:ring-outline-gray-3 text-ink-gray-8 transition-colors"
              :bubbleMenu="true"
              :content="noteData.content"
              @change="handleContentChange"
              :placeholder="__('Type @ to mention team members...')"
            />

            <!-- Mention Autocomplete Dropdown -->
            <div
              v-if="showMentionDropdown"
              class="absolute left-0 right-0 z-50 mt-1 max-h-48 overflow-y-auto rounded-lg border border-outline-gray-2 bg-surface-white shadow-lg"
              :style="{ top: mentionPosition.top + 'px', left: mentionPosition.left + 'px', width: '250px' }"
            >
              <div
                v-for="(user, index) in filteredUsers"
                :key="user.name"
                class="flex cursor-pointer items-center gap-2 px-3 py-2 hover:bg-surface-gray-2"
                :class="{ 'bg-surface-gray-2': index === selectedMentionIndex }"
                @click="insertMention(user)"
              >
                <UserAvatar :user="user.name" size="xs" />
                <div>
                  <p class="text-sm font-medium text-ink-gray-8">{{ user.full_name }}</p>
                  <p class="text-xs text-ink-gray-5">{{ user.name }}</p>
                </div>
              </div>
              <div v-if="!filteredUsers.length" class="px-3 py-2 text-sm text-ink-gray-5">
                {{ __('No users found') }}
              </div>
            </div>
          </div>
          <p class="mt-1 text-xs text-ink-gray-5">
            {{ __('Tip: Type @ followed by a name to mention team members') }}
          </p>
        </div>

        <!-- Tags -->
        <div>
          <div class="mb-1.5 text-xs text-ink-gray-5">{{ __('Tags') }}</div>
          <div class="flex flex-wrap gap-2">
            <div
              v-for="(tag, index) in noteData.tags"
              :key="index"
              class="flex items-center gap-1 rounded-full bg-surface-gray-3 px-2.5 py-1"
            >
              <span class="text-sm text-ink-gray-7">{{ tag }}</span>
              <button
                class="rounded-full p-0.5 hover:bg-surface-gray-4"
                @click="removeTag(index)"
              >
                <FeatherIcon name="x" class="h-3 w-3 text-ink-gray-5" />
              </button>
            </div>
            <input
              v-model="newTag"
              type="text"
              class="min-w-[100px] rounded border-none bg-transparent text-sm outline-none placeholder:text-ink-gray-4"
              :placeholder="__('Add tag...')"
              @keydown.enter.prevent="addTag"
              @keydown.comma.prevent="addTag"
            />
          </div>
        </div>

        <!-- Attachments -->
        <div>
          <div class="mb-1.5 text-xs text-ink-gray-5">{{ __('Attachments') }}</div>
          <div class="rounded-lg border border-dashed border-outline-gray-3 p-4">
            <div v-if="!noteData.attachments?.length" class="text-center">
              <FeatherIcon name="paperclip" class="mx-auto h-8 w-8 text-ink-gray-4" />
              <p class="mt-2 text-sm text-ink-gray-5">{{ __('No attachments yet') }}</p>
              <Button
                variant="subtle"
                size="sm"
                :label="__('Add Attachment')"
                class="mt-2"
                @click="triggerFileUpload"
              />
              <input
                ref="fileInputRef"
                type="file"
                multiple
                class="hidden"
                @change="handleFileUpload"
              />
            </div>
            <div v-else class="space-y-2">
              <div
                v-for="(attachment, index) in noteData.attachments"
                :key="index"
                class="flex items-center justify-between rounded bg-surface-gray-2 px-3 py-2"
              >
                <div class="flex items-center gap-2">
                  <FeatherIcon name="file" class="h-4 w-4 text-ink-gray-5" />
                  <span class="text-sm text-ink-gray-7">{{ attachment.name }}</span>
                </div>
                <button
                  class="rounded p-1 hover:bg-surface-gray-3"
                  @click="removeAttachment(index)"
                >
                  <FeatherIcon name="x" class="h-4 w-4 text-ink-gray-5" />
                </button>
              </div>
              <Button
                variant="subtle"
                size="sm"
                :label="__('Add More')"
                @click="triggerFileUpload"
              />
            </div>
          </div>
        </div>

        <ErrorMessage class="mt-2" v-if="error" :message="__(error)" />
      </div>
    </template>
    <template #actions>
      <div class="flex justify-end gap-2">
        <Button variant="subtle" :label="__('Cancel')" @click="show = false" />
        <Button
          :label="editMode ? __('Update') : __('Create')"
          variant="solid"
          :loading="saving"
          @click="saveNote"
        />
      </div>
    </template>
  </Dialog>
</template>

<script setup>
import { ref, computed, watch, nextTick } from 'vue'
import { FeatherIcon, TextEditor, Dialog, ErrorMessage } from 'frappe-ui'
import UserAvatar from '@/components/UserAvatar.vue'
import { projectNotesStore } from '@/stores/projectNotes'
import { usersStore } from '@/stores/users'

const props = defineProps({
  note: {
    type: Object,
    default: null,
  },
  projectId: {
    type: String,
    required: true,
  },
  parentId: {
    type: String,
    default: null,
  },
})

const show = defineModel()
const emit = defineEmits(['after'])

const notesStore = projectNotesStore()
const users = usersStore()

const titleRef = ref(null)
const contentRef = ref(null)
const fileInputRef = ref(null)
const saving = ref(false)
const error = ref(null)
const newTag = ref('')

// Mention state
const showMentionDropdown = ref(false)
const mentionQuery = ref('')
const mentionPosition = ref({ top: 0, left: 0 })
const selectedMentionIndex = ref(0)

const noteTypes = {
  general: 'General',
  update: 'Update',
  blocker: 'Blocker',
  decision: 'Decision',
  milestone: 'Milestone',
  question: 'Question',
  announcement: 'Announcement',
}

const priorities = {
  low: 'Low',
  normal: 'Normal',
  high: 'High',
  urgent: 'Urgent',
}

const noteData = ref({
  title: '',
  content: '',
  note_type: 'general',
  priority: 'normal',
  tags: [],
  attachments: [],
  mentions: [],
})

const editMode = computed(() => !!props.note?.id)
const isReply = computed(() => !!props.parentId)

const filteredUsers = computed(() => {
  if (!mentionQuery.value) {
    return users.options?.data?.slice(0, 5) || []
  }
  const query = mentionQuery.value.toLowerCase()
  return (users.options?.data || [])
    .filter(
      (u) =>
        u.full_name?.toLowerCase().includes(query) ||
        u.name?.toLowerCase().includes(query)
    )
    .slice(0, 5)
})

function handleContentChange(content) {
  noteData.value.content = content

  // Check for @ mention trigger
  const lastAtIndex = content.lastIndexOf('@')
  if (lastAtIndex !== -1) {
    const textAfterAt = content.slice(lastAtIndex + 1)
    // Check if we're in the middle of typing a mention
    if (!textAfterAt.includes(' ') && !textAfterAt.includes(']')) {
      mentionQuery.value = textAfterAt
      showMentionDropdown.value = true
      selectedMentionIndex.value = 0
    } else {
      showMentionDropdown.value = false
    }
  } else {
    showMentionDropdown.value = false
  }
}

function insertMention(user) {
  const lastAtIndex = noteData.value.content.lastIndexOf('@')
  if (lastAtIndex !== -1) {
    const beforeMention = noteData.value.content.slice(0, lastAtIndex)
    const afterMention = noteData.value.content.slice(
      lastAtIndex + mentionQuery.value.length + 1
    )
    noteData.value.content = `${beforeMention}@[${user.full_name}](${user.name})${afterMention} `

    // Add to mentions array
    if (!noteData.value.mentions.includes(user.name)) {
      noteData.value.mentions.push(user.name)
    }
  }
  showMentionDropdown.value = false
}

function addTag() {
  const tag = newTag.value.trim()
  if (tag && !noteData.value.tags.includes(tag)) {
    noteData.value.tags.push(tag)
  }
  newTag.value = ''
}

function removeTag(index) {
  noteData.value.tags.splice(index, 1)
}

function triggerFileUpload() {
  fileInputRef.value?.click()
}

function handleFileUpload(event) {
  const files = Array.from(event.target.files)
  files.forEach((file) => {
    noteData.value.attachments.push({
      name: file.name,
      file: file,
    })
  })
}

function removeAttachment(index) {
  noteData.value.attachments.splice(index, 1)
}

async function saveNote() {
  if (!noteData.value.title) {
    error.value = 'Title is required'
    return
  }

  saving.value = true
  error.value = null

  try {
    // Parse mentions from content
    const { parseMentions } = notesStore
    const mentions = parseMentions(noteData.value.content)
    noteData.value.mentions = mentions.map((m) => m.id)

    if (editMode.value) {
      await notesStore.updateNote.submit({
        note_id: props.note.id,
        ...noteData.value,
      })
    } else if (isReply.value) {
      await notesStore.replyToNote.submit({
        parent_id: props.parentId,
        project_id: props.projectId,
        ...noteData.value,
      })
    } else {
      await notesStore.createNote.submit({
        project_id: props.projectId,
        ...noteData.value,
      })
    }

    emit('after')
    show.value = false
  } catch (err) {
    error.value = err.message || 'Failed to save note'
  } finally {
    saving.value = false
  }
}

watch(
  () => show.value,
  (value) => {
    if (!value) return
    nextTick(() => {
      titleRef.value?.el?.focus()
      if (props.note) {
        noteData.value = {
          title: props.note.title || '',
          content: props.note.content || '',
          note_type: props.note.note_type || 'general',
          priority: props.note.priority || 'normal',
          tags: props.note.tags || [],
          attachments: props.note.attachments || [],
          mentions: props.note.mentions || [],
        }
      } else {
        noteData.value = {
          title: '',
          content: '',
          note_type: 'general',
          priority: 'normal',
          tags: [],
          attachments: [],
          mentions: [],
        }
      }
    })
  }
)
</script>

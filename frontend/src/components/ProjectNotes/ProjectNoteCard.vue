<template>
  <div
    class="group relative rounded-lg border border-outline-gray-2 bg-surface-white p-4 transition-all hover:border-outline-gray-3 hover:shadow-sm"
    :class="{ 'border-l-4': note.note_type !== 'general' }"
    :style="{ borderLeftColor: note.note_type !== 'general' ? getNoteTypeColor(note.note_type) : undefined }"
  >
    <!-- Header -->
    <div class="flex items-start justify-between gap-3">
      <div class="flex items-center gap-2">
        <!-- Note Type Icon -->
        <div
          class="flex h-7 w-7 items-center justify-center rounded-full"
          :style="{ backgroundColor: getNoteTypeColor(note.note_type) + '20' }"
        >
          <FeatherIcon
            :name="getNoteTypeIcon(note.note_type)"
            class="h-3.5 w-3.5"
            :style="{ color: getNoteTypeColor(note.note_type) }"
          />
        </div>

        <!-- Title and Type Badge -->
        <div>
          <h4 class="font-medium text-ink-gray-9">{{ note.title }}</h4>
          <div class="flex items-center gap-2 mt-0.5">
            <span
              class="text-xs font-medium px-1.5 py-0.5 rounded"
              :style="{
                backgroundColor: getNoteTypeColor(note.note_type) + '15',
                color: getNoteTypeColor(note.note_type)
              }"
            >
              {{ getNoteTypeLabel(note.note_type) }}
            </span>
            <span
              v-if="note.priority && note.priority !== 'normal'"
              class="text-xs font-medium px-1.5 py-0.5 rounded"
              :style="{
                backgroundColor: getPriorityColor(note.priority) + '15',
                color: getPriorityColor(note.priority)
              }"
            >
              {{ getPriorityLabel(note.priority) }}
            </span>
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
        <button
          v-if="note.is_pinned"
          class="rounded p-1.5 text-amber-500 hover:bg-amber-50"
          :title="__('Unpin')"
          @click="$emit('toggle-pin', note)"
        >
          <FeatherIcon name="star" class="h-4 w-4 fill-current" />
        </button>
        <button
          v-else
          class="rounded p-1.5 text-ink-gray-5 hover:bg-surface-gray-2 hover:text-amber-500"
          :title="__('Pin')"
          @click="$emit('toggle-pin', note)"
        >
          <FeatherIcon name="star" class="h-4 w-4" />
        </button>

        <button
          class="rounded p-1.5 text-ink-gray-5 hover:bg-surface-gray-2 hover:text-ink-gray-7"
          :title="__('Reply')"
          @click="$emit('reply', note)"
        >
          <FeatherIcon name="corner-up-left" class="h-4 w-4" />
        </button>

        <button
          class="rounded p-1.5 text-ink-gray-5 hover:bg-surface-gray-2 hover:text-ink-gray-7"
          :title="__('Edit')"
          @click="$emit('edit', note)"
        >
          <FeatherIcon name="edit-2" class="h-4 w-4" />
        </button>

        <button
          v-if="note.note_type === 'blocker' && note.status !== 'resolved'"
          class="rounded p-1.5 text-ink-gray-5 hover:bg-green-50 hover:text-green-600"
          :title="__('Resolve')"
          @click="$emit('resolve', note)"
        >
          <FeatherIcon name="check-circle" class="h-4 w-4" />
        </button>

        <button
          class="rounded p-1.5 text-ink-gray-5 hover:bg-red-50 hover:text-red-600"
          :title="__('Delete')"
          @click="$emit('delete', note)"
        >
          <FeatherIcon name="trash-2" class="h-4 w-4" />
        </button>
      </div>
    </div>

    <!-- Content -->
    <div class="mt-3">
      <div
        class="prose prose-sm max-w-none text-ink-gray-7"
        v-html="formattedContent"
      />
    </div>

    <!-- Mentions -->
    <div v-if="mentions.length" class="mt-3 flex flex-wrap gap-1">
      <span
        v-for="mention in mentions"
        :key="mention.id"
        class="inline-flex items-center gap-1 rounded-full bg-blue-50 px-2 py-0.5 text-xs font-medium text-blue-700"
      >
        <FeatherIcon name="at-sign" class="h-3 w-3" />
        {{ mention.name }}
      </span>
    </div>

    <!-- Status Badge for Blockers -->
    <div
      v-if="note.note_type === 'blocker' && note.status === 'resolved'"
      class="mt-3 flex items-center gap-2 rounded-md bg-green-50 px-3 py-2 text-sm text-green-700"
    >
      <FeatherIcon name="check-circle" class="h-4 w-4" />
      <span>{{ __('Resolved by') }} {{ note.resolved_by }}</span>
      <span class="text-green-600">{{ formatDate(note.resolved_at) }}</span>
    </div>

    <!-- Reactions -->
    <div v-if="note.reactions && Object.keys(note.reactions).length" class="mt-3 flex gap-1">
      <button
        v-for="(users, emoji) in note.reactions"
        :key="emoji"
        class="flex items-center gap-1 rounded-full border border-outline-gray-2 px-2 py-0.5 text-sm hover:bg-surface-gray-2"
        @click="$emit('react', note, emoji)"
      >
        <span>{{ emoji }}</span>
        <span class="text-xs text-ink-gray-5">{{ users.length }}</span>
      </button>
    </div>

    <!-- Footer -->
    <div class="mt-3 flex items-center justify-between border-t border-outline-gray-1 pt-3">
      <div class="flex items-center gap-2">
        <UserAvatar :user="note.author_id" size="xs" />
        <span class="text-sm text-ink-gray-6">{{ getAuthorName(note.author_id) }}</span>
      </div>
      <div class="flex items-center gap-3 text-xs text-ink-gray-5">
        <Tooltip :text="formatDate(note.created_at)">
          <span>{{ timeAgo(note.created_at) }}</span>
        </Tooltip>
        <span v-if="note.thread_count" class="flex items-center gap-1">
          <FeatherIcon name="message-circle" class="h-3.5 w-3.5" />
          {{ note.thread_count }}
        </span>
      </div>
    </div>

    <!-- Thread/Replies -->
    <div v-if="showReplies && replies.length" class="mt-4 border-t border-outline-gray-1 pt-4">
      <div class="space-y-3">
        <ProjectNoteCard
          v-for="reply in replies"
          :key="reply.id"
          :note="reply"
          :is-reply="true"
          @edit="$emit('edit', $event)"
          @delete="$emit('delete', $event)"
          @react="$emit('react', $event.note, $event.emoji)"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { FeatherIcon, Tooltip } from 'frappe-ui'
import UserAvatar from '@/components/UserAvatar.vue'
import { projectNotesStore } from '@/stores/projectNotes'
import { usersStore } from '@/stores/users'
import { timeAgo, formatDate } from '@/utils'

const props = defineProps({
  note: {
    type: Object,
    required: true,
  },
  isReply: {
    type: Boolean,
    default: false,
  },
  showReplies: {
    type: Boolean,
    default: true,
  },
})

defineEmits(['edit', 'delete', 'reply', 'toggle-pin', 'resolve', 'react'])

const notesStore = projectNotesStore()
const users = usersStore()

const {
  getNoteTypeLabel,
  getNoteTypeIcon,
  getNoteTypeColor,
  getPriorityLabel,
  getPriorityColor,
  parseMentions,
  formatMentions,
  getNoteReplies,
} = notesStore

const formattedContent = computed(() => {
  return formatMentions(props.note.content || '')
})

const mentions = computed(() => {
  return parseMentions(props.note.content || '')
})

const replies = computed(() => {
  if (props.isReply) return []
  return getNoteReplies(props.note.id)
})

function getAuthorName(userId) {
  const user = users.getUser(userId)
  return user?.full_name || userId
}
</script>

<style scoped>
.prose :deep(.mention) {
  color: #3b82f6;
  font-weight: 500;
  background-color: #eff6ff;
  padding: 0 4px;
  border-radius: 4px;
}
</style>

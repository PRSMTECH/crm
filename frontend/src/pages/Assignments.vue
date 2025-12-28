<template>
  <LayoutHeader>
    <template #left-header>
      <Breadcrumbs :items="breadcrumbs" />
    </template>
  </LayoutHeader>
  <AssignmentDashboard />
</template>

<script setup>
import LayoutHeader from '@/components/LayoutHeader.vue'
import Breadcrumbs from '@/components/Breadcrumbs.vue'
import { AssignmentDashboard } from '@/components/Assignments'
import { computed } from 'vue'

const breadcrumbs = computed(() => [
  { label: 'Assignments', route: { name: 'Assignments' } },
])
</script>

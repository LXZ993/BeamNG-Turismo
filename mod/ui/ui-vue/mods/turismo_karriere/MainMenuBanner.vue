<template>
  <div class="turismo-banner" @click="start">
    <span class="t">T</span>URISMO <small>KARRIERE ▸</small>
  </div>
</template>

<script>
const modInfo = {
  uiSlots: ["mainmenu.top"],
}
</script>

<script setup>
import { useBridge } from "@/bridge"

function start() {
  const { api } = useBridge()
  api.engineLua("if extensions.turismo_core then extensions.turismo_core.startCareer() end")
}
</script>

<style lang="scss" scoped>
.turismo-banner {
  display: inline-block;
  margin: 0.5rem auto;
  padding: 0.5rem 1.25rem;
  border: 1px solid rgba(54, 209, 255, 0.6);
  border-radius: 2rem;
  background: rgba(8, 16, 34, 0.85);
  color: #fff;
  font-weight: 800;
  letter-spacing: 0.2em;
  cursor: pointer;
  pointer-events: auto;
  .t { color: #36d1ff; }
  small { font-weight: 600; letter-spacing: 0.1em; color: #cfe6ff; margin-left: 0.5rem; }
  &:hover { background: rgba(20, 60, 110, 0.95); }
}
</style>

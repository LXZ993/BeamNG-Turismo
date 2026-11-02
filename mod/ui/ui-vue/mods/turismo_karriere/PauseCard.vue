<template>
  <div class="turismo-pause">
    <div class="logo"><span class="t">T</span>URISMO</div>
    <p>World-Menü der Karriere: Garage, Händler, Werkstatt, Lizenzen, Rennen, Café.</p>
    <button class="go" @click="open">Turismo-Menü öffnen ▸</button>
  </div>
</template>

<script setup>
import { useBridge } from "@/bridge"

function open() {
  const { api } = useBridge()
  api.engineLua("if extensions.turismo_core then extensions.turismo_core.openFromPause() end")
}
</script>

<style lang="scss" scoped>
.turismo-pause {
  padding: 1.5rem;
  color: #e8eefc;
  .logo { font-size: 2rem; font-weight: 900; letter-spacing: 0.25em; .t { color: #36d1ff; } }
  p { color: #93a3c7; margin: 0.75rem 0 1.25rem; }
  .go {
    padding: 0.75rem 1.5rem; border-radius: 2rem; border: 1px solid rgba(54, 209, 255, 0.6);
    background: rgba(20, 60, 110, 0.9); color: #fff; font-weight: 700; cursor: pointer;
    &:hover { background: rgba(54, 140, 220, 0.95); }
  }
}
</style>

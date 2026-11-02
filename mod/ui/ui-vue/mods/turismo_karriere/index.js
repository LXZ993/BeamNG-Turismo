// Turismo Karriere – entry point for BeamNG's Vue UI mod runtime (0.40+)
// * adds "Turismo Karriere" to the main menu (More / Mehr)
// * mounts the Turismo interface (world menu, HUD, results, music) on the page,
//   so no UI app has to be dragged into a layout
import { useBridge } from "@/bridge"

const BASE = "/ui/modules/apps/TurismoHub/"
const STREAMS = ["electrics", "engineInfo"]

let host = null // { root, offs: [], streamsAdded }

function bridgeOrNull() {
  try { return useBridge() } catch (e) { return null }
}

function engineLua(cmd) {
  const b = bridgeOrNull()
  if (b && b.api && b.api.engineLua) b.api.engineLua(cmd)
  else if (typeof bngApi !== "undefined") bngApi.engineLua(cmd)
}

function toLua(v) {
  if (v === null || v === undefined) return "nil"
  if (typeof v === "boolean" || typeof v === "number") return String(v)
  if (typeof v === "string") return JSON.stringify(v)
  if (Array.isArray(v)) return "{" + v.map(toLua).join(",") + "}"
  return "{" + Object.keys(v).map(k => "[" + JSON.stringify(k) + "]=" + toLua(v[k])).join(",") + "}"
}

function loadOnce(id, tag, attrs) {
  return new Promise((resolve, reject) => {
    if (document.getElementById(id)) { resolve(); return }
    const el = document.createElement(tag)
    el.id = id
    Object.keys(attrs).forEach(k => { el[k] = attrs[k] })
    el.onload = resolve
    el.onerror = reject
    document.head.appendChild(el)
  })
}

export function openCareer() {
  engineLua("if extensions.turismo_core then extensions.turismo_core.startCareer() end")
}

function addMenuButton(addButton) {
  addButton({ title: "Turismo Karriere", iconId: "stopwatchArrows02", action: openCareer })
}

function makeTurismoBridge(b, offs) {
  let reqId = 0
  const pending = {}
  const listen = (name, fn) => { b.events.on(name, fn); offs.push(() => b.events.off(name, fn)) }
  let streamCb = null

  listen("TurismoResult", res => {
    const p = res && pending[res.reqId]
    if (!p) return
    clearTimeout(p.t)
    delete pending[res.reqId]
    if (res.ok) p.resolve(res.data)
    else p.reject(new Error(res.error || "Fehler"))
  })
  const onStreams = s => { if (streamCb) streamCb(s) }
  listen("onStreamsUpdate", onStreams)

  return {
    call(action, args) {
      const id = ++reqId
      return new Promise((resolve, reject) => {
        pending[id] = {
          resolve, reject,
          t: setTimeout(() => { delete pending[id]; reject(new Error("Keine Antwort von Lua (" + action + ")")) }, 15000),
        }
        engineLua("if extensions.turismo_core then extensions.turismo_core.uiCall(" + toLua(action) + "," + toLua(args || {}) + "," + id + ") end")
      })
    },
    on(name, cb) {
      listen(name, data => { try { cb(data) } catch (e) { console.error(e) } })
    },
    stream(cb) { streamCb = cb },
    typing(on) { engineLua("setCEFTyping(" + (on ? "true" : "false") + ")") },
  }
}

async function mountUi() {
  const b = bridgeOrNull()
  if (!b || !b.events) { console.error("Turismo: Vue-Bridge nicht verfügbar"); return }
  window.__turismoVueHost = true
  await Promise.all([
    loadOnce("turismo-css", "link", { rel: "stylesheet", href: BASE + "app.css" }),
    loadOnce("turismo-js", "script", { src: BASE + "turismo-ui.js", charset: "utf-8" }),
  ])
  const old = document.getElementById("turismo-root")
  if (old && old.parentNode) old.parentNode.removeChild(old)
  const offs = []
  const root = document.createElement("div")
  root.id = "turismo-root"
  document.body.appendChild(root)
  if (b.streams) b.streams.add(STREAMS)
  window.TurismoUI.mount(root, makeTurismoBridge(b, offs))
  host = { root, offs, streamsAdded: !!b.streams }
}

export async function onLoad() {
  const b = bridgeOrNull()
  if (b && b.events) {
    b.events.on("MainMenuButtons", addMenuButton)
    // ask the main menu to collect its buttons again (it may already be open)
    b.events.emit("BroadcastMainMenuButtons")
  }
  try { await mountUi() } catch (e) { console.error("Turismo UI konnte nicht geladen werden", e) }
}

export async function onUnload() {
  const b = bridgeOrNull()
  if (b && b.events) b.events.off("MainMenuButtons", addMenuButton)
  if (host) {
    host.offs.forEach(f => { try { f() } catch (e) {} })
    if (host.streamsAdded && b && b.streams) b.streams.remove(STREAMS)
    if (host.root && host.root.parentNode) host.root.parentNode.removeChild(host.root)
    host = null
  }
  window.__turismoVueHost = false
}

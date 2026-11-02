/* Turismo Karriere - UI (World-Menü, HUD, Ergebnisse, Audio)
 * Framework-free so it runs inside BeamNG's CEF (via app.js) and in a plain
 * browser preview with a mocked bridge.
 *   window.TurismoUI.mount(rootElement, bridge)
 *   bridge = { call(action, args) -> Promise, on(event, cb), stream(cb) }
 */
(function () {
  'use strict';

  var BASE = '/ui/modules/apps/TurismoHub/';

  // ------------------------------------------------------------------ helpers
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function money(v) { v = Math.round(v || 0); return v.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.') + ' Cr.'; }
  function num(v, d) { return (v == null || isNaN(v)) ? '--' : Number(v).toFixed(d || 0).replace('.', ','); }
  function km(v) { return Math.round(v || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.') + ' km'; }
  function time(t) {
    if (t == null || !isFinite(t)) return '--:--.---';
    var m = Math.floor(t / 60), s = t - m * 60;
    return m + ':' + (s < 10 ? '0' : '') + s.toFixed(3).replace('.', ',');
  }
  function gap(t) { return t == null ? '' : (t >= 0 ? '+' : '−') + Math.abs(t).toFixed(1).replace('.', ',') + ' s'; }
  function arr(x) { if (!x) return []; if (Array.isArray(x)) return x; return Object.keys(x).map(function (k) { return x[k]; }); }
  function medalOf(m) { return '<i class="tz-medal ' + esc(m || 'none') + '"></i>'; }
  var MEDAL_DE = { gold: 'Gold', silver: 'Silber', bronze: 'Bronze', none: '—' };
  var TYPE_DE = { circuit: 'Rundstrecke', elimination: 'K.O.-Rennen', pursuit: 'Verfolgung', timeAttack: 'Zeitfahren', touge: 'Touge', drift: 'Drift',
    derby: 'Derby', trucking: 'Transport', crawl: 'Crawling', drag: 'Drag', hillclimb: 'Bergrennen' };
  var DIFF_DE = { easy: 'Leicht', normal: 'Normal', hard: 'Schwer', pro: 'Profi' };
  function liBadge(r, eff) {
    if (!r) return '';
    var li = eff || r.li;
    return '<span class="tz-li cls-' + esc(r['class']) + '">' + esc(li) + '<small>LI · ' + esc(r['class']) + '</small></span>';
  }

  // tiny inline icons (own drawings)
  var ICONS = {
    cafe: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M10 24h36v14a14 14 0 0 1-14 14h-8A14 14 0 0 1 10 38z"/><path d="M46 28h4a6 6 0 0 1 0 12h-5"/><path d="M20 8c0 5 4 5 4 10M30 8c0 5 4 5 4 10"/></svg>',
    lic: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><rect x="8" y="14" width="48" height="34" rx="4"/><circle cx="24" cy="31" r="7"/><path d="M36 26h14M36 34h10"/></svg>',
    race: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M14 56V8"/><path d="M14 10h34l-6 9 6 9H14"/></svg>',
    car: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M6 40l6-14h30l10 8h6v8H6z"/><circle cx="18" cy="44" r="5"/><circle cx="46" cy="44" r="5"/></svg>',
    used: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M8 44l5-12h26l8 6h7v6H8z"/><circle cx="18" cy="46" r="4"/><circle cx="44" cy="46" r="4"/><path d="M40 10l12 12M52 10L40 22"/></svg>',
    star: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M32 6l8 17 18 2-13 12 4 18-17-9-17 9 4-18L6 25l18-2z"/></svg>',
    wrench: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M40 8a14 14 0 0 0-12 19L8 47l9 9 20-20A14 14 0 0 0 56 24l-9 5-8-4-4-8 5-9z"/></svg>',
    garage: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M6 26L32 8l26 18v30H6z"/><path d="M16 56V34h32v22M16 42h32M16 49h32"/></svg>',
    cone: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M24 50L32 8l8 42M18 50h28M26 30h12M28 20h8"/><path d="M10 56h44"/></svg>',
    map: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M6 14l16-6 20 6 16-6v42l-16 6-20-6-16 6z"/><path d="M22 8v42M42 14v42"/></svg>',
    ticket: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M6 20h52v8a5 5 0 0 0 0 10v8H6v-8a5 5 0 0 0 0-10z"/><path d="M40 20v26" stroke-dasharray="3 4"/></svg>',
    rec: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><circle cx="32" cy="32" r="22"/><circle cx="32" cy="32" r="8" fill="#ff5d6c" stroke="none"/></svg>',
    gear: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><circle cx="32" cy="32" r="9"/><path d="M32 6v9M32 49v9M6 32h9M49 32h9M13 13l7 7M44 44l7 7M13 51l7-7M44 20l7-7"/></svg>',
    wash: '<svg viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3"><path d="M32 8c8 12 14 20 14 28a14 14 0 0 1-28 0c0-8 6-16 14-28z"/></svg>'
  };

  // ------------------------------------------------------------------ audio
  var Audio_ = {
    sfxVol: 0.7, musicVol: 0.45, enabled: true, ctx: null, current: null, playlist: null, ctxName: 'off', idx: 0, fadeTimer: null,
    sfx: function (file) {
      if (!this.enabled || !file) return;
      try {
        var a = new Audio(BASE + 'audio/sfx/' + file + '.ogg');
        a.volume = this.sfxVol;
        var p = a.play(); if (p && p.catch) p.catch(function () {});
      } catch (e) { /* no audio in this environment */ }
    },
    loadPlaylist: function () {
      var self = this;
      if (self.playlist) return Promise.resolve(self.playlist);
      return fetch(BASE + 'audio/music/playlist.json').then(function (r) { return r.json(); }).then(function (j) { self.playlist = j; return j; })
        .catch(function () { self.playlist = { contexts: {} }; return self.playlist; });
    },
    music: function (context) {
      var self = this;
      if (context === self.ctxName) return;
      self.ctxName = context;
      self.loadPlaylist().then(function (pl) {
        var list = (pl.contexts && pl.contexts[context]) || [];
        self.fadeOut(function () {
          if (!list.length || !self.enabled || context === 'off') return;
          self.idx = Math.floor(Math.random() * list.length);
          self.playTrack(list, context);
        });
      });
    },
    playTrack: function (list, context) {
      var self = this;
      if (self.ctxName !== context) return;
      var tr = list[self.idx % list.length];
      var file = (self.playlist.tracks && self.playlist.tracks[tr]) ? self.playlist.tracks[tr].file : tr;
      try {
        var a = new Audio(BASE + 'audio/music/' + file);
        a.volume = 0; self.current = a;
        a.onended = function () { self.idx++; self.playTrack(list, context); };
        var p = a.play(); if (p && p.catch) p.catch(function () {});
        var v = 0, target = self.musicVol;
        var iv = setInterval(function () { v = Math.min(target, v + target / 20); a.volume = v; if (v >= target) clearInterval(iv); }, 60);
      } catch (e) { }
    },
    fadeOut: function (done) {
      var a = this.current; this.current = null;
      if (!a) { done(); return; }
      var iv = setInterval(function () {
        a.volume = Math.max(0, a.volume - 0.04);
        if (a.volume <= 0.001) { clearInterval(iv); try { a.pause(); } catch (e) { } done(); }
      }, 40);
    },
    setMusicVolume: function (v) { this.musicVol = v; if (this.current) this.current.volume = v; }
  };

  // ------------------------------------------------------------------ app
  function App(root, bridge) {
    this.root = root; this.bridge = bridge;
    this.state = { loaded: false };
    this.stack = [];          // screen stack [{name, params}]
    this.data = {};           // cached screen data
    this.hubVisible = false;
    this.hud = {};            // latest HUD payloads
    this.phase = 'idle';
    this.results = null;
    this.modal = null;
    this.ui = { tab: {} };
    this.build();
    this.wire();
  }

  App.prototype.build = function () {
    this.root.classList.add('tz-root');
    this.root.innerHTML =
      '<div class="tz-hud" data-el="hud"></div>' +
      '<div class="tz-hub tz-hidden" data-el="hub">' +
      '  <div class="tz-top" data-el="top"></div>' +
      '  <div class="tz-main"><div class="tz-screen" data-el="screen"></div></div>' +
      '</div>' +
      '<div data-el="overlay"></div>' +
      '<div class="tz-modal tz-hidden" data-el="modal"><div></div></div>' +
      '<div class="tz-toasts" data-el="toasts"></div>';
    var q = this.root.querySelector.bind(this.root);
    this.el = { hud: q('[data-el=hud]'), hub: q('[data-el=hub]'), top: q('[data-el=top]'), screen: q('[data-el=screen]'),
      overlay: q('[data-el=overlay]'), modal: q('[data-el=modal]'), toasts: q('[data-el=toasts]') };
  };

  App.prototype.call = function (action, args) {
    var self = this;
    return this.bridge.call(action, args || {}).catch(function (err) {
      self.toast(String(err && err.message || err), 'error'); Audio_.sfx('ui_error'); throw err;
    });
  };

  App.prototype.wire = function () {
    var self = this, b = this.bridge;
    b.on('TurismoState', function (s) { self.state = s || { loaded: false }; self.renderTop(); if (self.cur() && self.cur().name === 'world') self.render(); });
    b.on('TurismoHubToggle', function (d) { self.showHub(d && d.visible); });
    b.on('TurismoToast', function (d) { self.toast(d.msg, d.kind); });
    b.on('TurismoSound', function (d) { Audio_.sfx(d.file || d.cue); });
    b.on('TurismoMusic', function (d) { Audio_.music(d.context); });
    b.on('TurismoRacePhase', function (d) { self.onPhase(d); });
    b.on('TurismoHud', function (d) { self.trackDelta(d); self.hud.race = d; self.renderHud(); });
    b.on('TurismoTrackMap', function (d) { self.trackMap = prepMap(d); self.renderHud(); });
    b.on('TurismoSessionHud', function (d) { self.hud.session = d; self.renderHud(); });
    b.on('TurismoModeHud', function (d) { self.hud.mode = d; self.renderHud(); });
    b.on('TurismoCountdown', function (d) { self.onCountdown(d); });
    b.on('TurismoQualiResults', function (d) { self.showResults({ kind: 'quali', list: arr(d) }); });
    b.on('TurismoRaceResults', function (d) { self.showResults({ kind: 'race', data: d }); });
    b.on('TurismoTestPhase', function (d) { self.onTestPhase(d); });
    b.on('TurismoTestHud', function (d) { self.hud.test = d; self.renderHud(); });
    b.on('TurismoTestResult', function (d) { self.showResults({ kind: 'test', data: d }); });
    b.on('TurismoDragPhase', function (d) { self.hud.drag = d; self.phase = d.phase === 'idle' ? 'idle' : 'drag'; self.renderHud(); });
    b.on('TurismoDragTree', function (d) { self.onTree(d); });
    b.on('TurismoDragHud', function (d) { self.hud.dragRun = d; self.renderHud(); });
    b.on('TurismoDragResult', function (d) { self.showResults({ kind: 'dragRun', data: d }); });
    b.on('TurismoDragLadder', function (d) { self.hud.ladder = d; });
    b.on('TurismoRaceMenu', function (d) { if (d.active) self.showRaceMenu(d.kind); });
    b.on('TurismoSkip', function () { if (self.results) self.closeResults(); });
    b.stream(function (s) { self.onStream(s); });

    // event delegation
    this.root.addEventListener('click', function (ev) {
      var t = ev.target.closest('[data-act]');
      if (!t || t.hasAttribute('disabled')) return;
      ev.preventDefault();
      var act = t.getAttribute('data-act');
      var arg = t.getAttribute('data-arg');
      var arg2 = t.getAttribute('data-arg2');
      Audio_.sfx(act === 'back' ? 'ui_back' : 'ui_click');
      self.act(act, arg, arg2, t);
    });
    // text fields: tell the game to route the keyboard to the UI while typing
    // (otherwise BeamNG uses the keys as driving/camera input)
    function isText(el) { return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA'); }
    this.root.addEventListener('focusin', function (ev) { if (isText(ev.target) && b.typing) b.typing(true); });
    this.root.addEventListener('focusout', function (ev) { if (isText(ev.target) && b.typing) b.typing(false); });
    b.on('CEFTypingLostFocus', function () { var a = document.activeElement; if (isText(a)) a.blur(); });
    this.root.addEventListener('mouseover', function (ev) {
      var t = ev.target.closest('.tz-tile,.tz-btn,.tz-tab');
      if (t && t !== self._hover) { self._hover = t; Audio_.sfx('ui_hover'); }
    });
    document.addEventListener('keydown', function (ev) {
      if (!self.hubVisible) return;
      if (ev.key === 'Escape' || ev.key === 'Backspace') {
        if (ev.target && ev.target.tagName === 'INPUT') return;
        if (self.modal) self.closeModal(); else self.back();
      }
    });

    this.call('ping').catch(function () {});
    this.call('state').then(function (s) { self.state = s; self.renderTop(); }).catch(function () {});
  };

  // ------------------------------------------------------------------ navigation
  App.prototype.cur = function () { return this.stack[this.stack.length - 1]; };
  App.prototype.go = function (name, params) {
    this.stack.push({ name: name, params: params || {} });
    Audio_.sfx('ui_open');
    this.load();
  };
  App.prototype.back = function () {
    if (this.stack.length > 1) { this.stack.pop(); this.load(); }
    else if (this.state.loaded) { this.call('hub', { visible: false }); }
  };
  App.prototype.home = function () { this.stack = [{ name: this.state.loaded ? 'world' : 'title', params: {} }]; this.load(); };

  App.prototype.showHub = function (visible) {
    this.hubVisible = !!visible;
    this.el.hub.classList.toggle('tz-hidden', !this.hubVisible);
    if (!this.hubVisible && this.modal) this.closeModal();
    this.root.style.pointerEvents = 'none';
    if (this.hubVisible) {
      var self = this;
      this.call('state').then(function (s) { self.state = s; self.renderTop(); self.home(); });
    }
    this.renderHud();
  };

  // loaders per screen: which handler(s) feed it
  var LOADERS = {
    title: function (a) { return a.call('getSlots').then(function (d) { return { slots: d }; }); },
    newProfile: function () { return Promise.resolve({}); },
    world: function () { return Promise.resolve({}); },
    garage: function (a) { return a.call('garage').then(function (d) { return { cars: arr(d) }; }); },
    car: function (a, p) { return a.call('carDetails', { carId: p.carId }).then(function (d) { return { car: d }; }); },
    workshop: function (a, p) {
      return Promise.all([a.call('services', { carId: p.carId }), a.call('conversions', { carId: p.carId || (a.state.activeCar && a.state.activeCar.id) })])
        .then(function (r) { return { svc: r[0], conv: arr(r[1]) }; });
    },
    dealers: function (a) { return a.call('dealerRegions').then(function (d) { return { regions: arr(d) }; }); },
    showroom: function (a, p) { return a.call('showroom', { brand: p.brand }).then(function (d) { return { offers: arr(d) }; }); },
    used: function (a) { return a.call('usedOffers').then(function (d) { return { offers: arr(d) }; }); },
    legends: function (a) { return a.call('legendOffers').then(function (d) { return { offers: arr(d) }; }); },
    licenses: function (a) { return a.call('licenses').then(function (d) { return { lics: arr(d) }; }); },
    trainings: function (a) { return a.call('trainings').then(function (d) { return { list: arr(d) }; }); },
    events: function (a) { return Promise.all([a.call('events'), a.call('garage')]).then(function (r) { return { halls: arr(r[0]), cars: arr(r[1]) }; }); },
    series: function (a) { return Promise.all([a.call('events'), a.call('garage')]).then(function (r) { return { halls: arr(r[0]), cars: arr(r[1]) }; }); },
    cafe: function (a) { return a.call('cafe').then(function (d) { return { cafe: d }; }); },
    tickets: function (a) { return a.call('tickets').then(function (d) { return { tickets: arr(d) }; }); },
    world2: function (a) { return Promise.all([a.call('levels'), a.call('tracks'), a.call('recorderState')]).then(function (r) { return { levels: arr(r[0]), tracks: arr(r[1]), rec: r[2] }; }); },
    settings: function () { return Promise.resolve({}); },
    diag: function (a) { return a.call('diagnostics').then(function (d) { return { diag: d }; }); }
  };

  App.prototype.load = function () {
    var self = this, c = this.cur();
    if (!c) return;
    var loader = LOADERS[c.name] || LOADERS.world;
    this.el.screen.innerHTML = '<div style="opacity:.5;padding:40px">Lädt …</div>';
    loader(this, c.params).then(function (d) { self.data = d || {}; self.render(); }).catch(function (e) {
      self.el.screen.innerHTML = '<div class="tz-panel">Fehler: ' + esc(e && e.message || e) + '</div>';
    });
  };

  App.prototype.render = function () {
    var c = this.cur(); if (!c) return;
    var fn = this['scr_' + c.name];
    this.el.screen.innerHTML = fn ? fn.call(this, this.data, c.params) : '';
    this.el.screen.scrollTop = c.params._scroll || 0;
    this.el.top.classList.toggle('tz-hidden', c.name === 'title' || c.name === 'newProfile');
  };
  App.prototype.reload = function () { var c = this.cur(); if (c) c.params._scroll = this.el.screen.scrollTop; this.load(); };

  App.prototype.head = function (title, sub) {
    return '<div class="tz-head"><button class="tz-back" data-act="back">‹</button><div><h1>' + esc(title) + '</h1>' + (sub ? '<p>' + sub + '</p>' : '') + '</div></div>';
  };

  // ------------------------------------------------------------------ top bar
  App.prototype.renderTop = function () {
    var s = this.state;
    if (!s || !s.loaded) { this.el.top.innerHTML = ''; return; }
    var col = s.collector || {};
    var frac = col.next ? Math.max(0, Math.min(1, (col.points - (col.current || 0)) / (col.next - (col.current || 0)))) : 1;
    var car = s.activeCar;
    this.el.top.innerHTML =
      '<div class="tz-logo" data-act="home"><b>T</b>URISMO<small>KARRIERE</small></div>' +
      '<div class="tz-stat"><label>Fahrer</label><span>' + esc(s.meta && s.meta.playerName) + '</span></div>' +
      '<div class="tz-stat"><label>Tag</label><span class="tz-num">' + esc(s.day) + '</span></div>' +
      '<div class="tz-stat"><label>Guthaben</label><span class="tz-money tz-num">' + money(s.money) + '</span></div>' +
      '<div class="tz-stat tz-collector"><label>Sammlerstufe ' + esc(col.level || 0) + '</label><div class="tz-bar"><i style="width:' + (frac * 100).toFixed(0) + '%"></i></div></div>' +
      '<div class="tz-stat"><label>Tagesziel</label><span class="tz-num">' + num(s.dailyKm, 1) + ' / ' + esc(s.dailyGoal) + ' km</span></div>' +
      '<div class="tz-spacer"></div>' +
      (car ? '<div class="tz-carchip" data-act="go" data-arg="garage">' + liBadge(car.rating, car.effectiveLI) +
        '<div><div style="font-weight:700">' + esc(car.nickname || car.name) + '</div><div class="meta" style="color:var(--dim);font-size:12px">' +
        km(car.mileageKm) + (car.damage > 0.02 ? ' · <span style="color:var(--bad)">Schaden ' + Math.round(car.damage * 100) + '%</span>' : '') + '</div></div></div>'
        : '<div class="tz-carchip" data-act="go" data-arg="used"><span class="tz-li cls-E">–<small>KEIN AUTO</small></span><div>Kein Auto – zum Händler</div></div>') +
      '<button class="tz-btn" data-act="close">Fahren ▸</button>';
  };

  // ------------------------------------------------------------------ screens
  App.prototype.scr_title = function (d) {
    var slots = arr(d.slots);
    var html = '<div class="tz-title"><div class="tz-bigLogo"><b>T</b>URISMO</div><div class="tz-sub">DIE KARRIERE · FÜR BEAMNG.DRIVE</div><div class="tz-slots">';
    slots.forEach(function (s) {
      if (s.exists) {
        html += '<div class="tz-slot" data-act="loadSlot" data-arg="' + s.slot + '"><h4>' + esc(s.playerName) + '</h4>' +
          '<div class="tz-money tz-num">' + money(s.money) + '</div><div style="color:var(--dim);font-size:13px;margin-top:6px">Tag ' + esc(s.day) +
          ' · ' + esc(s.cars) + ' Autos · ' + esc(s.progress) + ' Hefte</div>' +
          '<div style="margin-top:12px"><span class="tz-btn" data-act="deleteSlot" data-arg="' + s.slot + '">Löschen</span></div></div>';
      } else {
        html += '<div class="tz-slot" data-act="go" data-arg="newProfile" data-arg2="' + s.slot + '" style="display:flex;align-items:center;justify-content:center;flex-direction:column;color:var(--dim)">' +
          '<div style="font-size:40px">+</div>Neue Karriere<br><small>Platz ' + s.slot + '</small></div>';
      }
    });
    html += '</div><div><button class="tz-btn" data-act="close">◂ Zurück</button></div><div style="color:var(--dim);font-size:12px;margin-top:8px">Esc: zurück</div></div>';
    return html;
  };

  App.prototype.scr_newProfile = function (d, p) {
    var f = this.ui.newProfile = this.ui.newProfile || { name: 'Fahrer', progressionMode: 'menu', damageMode: 'realistic', hardcore: false };
    function choice(key, opts) {
      return '<div class="tz-choice">' + opts.map(function (o) {
        return '<div class="' + (String(f[key]) === String(o[0]) ? 'on' : '') + '" data-act="npSet" data-arg="' + key + '" data-arg2="' + o[0] + '">' + esc(o[1]) + '<small>' + esc(o[2]) + '</small></div>';
      }).join('') + '</div>';
    }
    return this.head('Neue Karriere', 'Platz ' + esc(p.arg2 || p.slot || 1)) +
      '<div class="tz-panel tz-form" style="max-width:900px">' +
      '<label>Fahrername</label><input data-el="npName" maxlength="24" value="' + esc(f.name) + '">' +
      '<div class="tz-note">Die Gegner passen sich automatisch an dein Können an: Wer oft gewinnt, bekommt stärkere Gegner, wer hinterherfährt, leichtere.</div>' +
      '<label>Spielweise</label>' + choice('progressionMode', [['menu', 'Geführt (empfohlen)', 'Im Café bekommst du Aufgabenhefte, die dich Schritt für Schritt durch die Karriere führen und neue Bereiche freischalten'], ['classic', 'Frei', 'Alles ist sofort offen, nur Lizenzen begrenzen die Rennen']]) +
      '<label>Schäden</label>' + choice('damageMode', [['realistic', 'Realistisch', 'Jeder Schaden bleibt bis zur Werkstatt'], ['mechanical', 'Nur Mechanik', 'Defekte bleiben, Blech wird gerichtet'], ['off', 'Aus', 'Auto ist vor jedem Rennen heil']]) +
      '<label>Hardcore-Modus</label>' + choice('hardcore', [['false', 'Aus', 'Schnelle Rennen möglich'], ['true', 'An', 'Immer Rennwochenende mit Training, Qualifying und Einführungsrunde, kein Neustart']]) +
      '<div style="margin-top:20px;display:flex;gap:10px"><button class="tz-btn primary" data-act="createProfile" data-arg="' + esc(p.arg2 || 1) + '">Karriere starten</button>' +
      '<button class="tz-btn" data-act="back">Abbrechen</button></div></div>';
  };

  App.prototype.scr_world = function () {
    var s = this.state, u = (s.unlocks || {});
    if (s.firstVisit && !this._guideShown) { this._guideShown = true; var self0 = this; setTimeout(function () { self0.showGuide(); }, 300); }
    function locked(key) { return u[key] === false; }
    var cafeSub = s.cafe ? ('Heft: ' + esc(s.cafe.name) + ' · ' + s.cafe.done + '/' + s.cafe.total) : 'Neue Hefte warten';
    var lic = (s.licenses || []).length ? 'Erhalten: ' + esc(s.licenses.join(', ')) : 'Noch keine Lizenz';
    function tile(cls, span, act, arg, title, sub, icon, key) {
      return '<div class="tz-tile ' + cls + ' ' + span + (key && locked(key) ? ' locked' : '') + '" data-act="' + act + '" data-arg="' + (arg || '') + '">' +
        '<h3>' + title + '</h3><p>' + sub + '</p><div class="tz-ico">' + (ICONS[icon] || '') + '</div></div>';
    }
    return '<div class="tz-world">' +
      '<div class="tz-district">Stadtzentrum</div>' +
      tile('c-cafe big', 's4 r2', 'go', 'cafe', 'Boxenstopp-Café', '<b>Hier startest du.</b> Der Wirt gibt dir Aufgabenhefte (z. B. „Gewinne drei Rennen“ oder „Sammle diese Autos“). Jedes erledigte Heft bringt Belohnungen und schaltet neue Bereiche frei.<br><br>' + cafeSub, 'cafe') +
      tile('c-race big', 's4 r2', 'go', 'events', 'Rennen', 'Rennserien von Einsteiger bis Profi: Preisgeld verdienen, Trophäen und Autos gewinnen. Manche Serien brauchen eine Lizenz oder eine bestimmte Fahrzeugklasse.', 'race') +
      tile('c-lic', 's4', 'go', 'licenses', 'Lizenzzentrum', 'Fahrprüfungen (Anfahren, Bremsen, Kurven …). Lizenzen öffnen höhere Rennserien. ' + lic, 'lic') +
      tile('c-lic', 's4', 'go', 'trainings', 'Fahrschule', 'Üben ohne Prüfung: Bremspunkte, Ideallinie, Drift, Gelände', 'cone') +
      '<div class="tz-district">Händlerviertel</div>' +
      tile('c-dealer', 's4', 'go', 'dealers', 'Neuwagen', 'Neue Autos aller Marken deiner Installation kaufen', 'car', 'dealer_new') +
      tile('c-dealer', 's4', 'go', 'used', 'Gebrauchtwagen', 'Günstige Autos mit Kilometern – ideal zum Start. Angebote wechseln alle paar Tage', 'used', 'dealer_used') +
      tile('c-dealer', 's4', 'go', 'legends', 'Klassiker-Galerie', 'Seltene Legenden – öffnet, wenn du genug Autos gesammelt hast (Sammlerstufe 4)', 'star', 'dealer_legend') +
      '<div class="tz-district">Boxengasse</div>' +
      tile('c-garage', 's4', 'go', 'garage', 'Garage', 'Deine Autos auswählen, ansehen, verkaufen · ' + esc(s.carCount || 0) + ' Fahrzeuge', 'garage') +
      tile('c-garage', 's4', 'goWorkshop', '', 'Werkstatt & Waschanlage', 'Schäden aus Rennen bleiben am Auto! Hier reparieren, Öl wechseln, waschen, umbauen', 'wrench', 'services') +
      tile('c-fun', 's4', 'go', 'tickets', 'Bonuslose', 'Gewinnlose aus Heften und Rennen – öffnen für Geld oder Autos · ' + esc(s.tickets || 0) + ' ungeöffnet', 'ticket') +
      '<div class="tz-district">Unterwegs</div>' +
      tile('c-fun', 's4', 'go', 'world2', 'Freie Fahrt & Strecken', 'Mit deinem Auto frei fahren, Tagesziel (Kilometer) schaffen, eigene Strecken aufnehmen', 'map', 'freeDrive') +
      tile('c-garage', 's4', 'guide', '', 'So funktioniert’s', 'Kurze Einführung in die Karriere', 'star') +
      tile('c-garage', 's4', 'go', 'settings', 'Einstellungen', 'Renndauer, Intro, Musik, Schäden', 'gear') +
      tile('c-garage', 's4', 'go', 'diag', 'Diagnose', 'Autos, Strecken und Inhalte prüfen', 'rec') +
      '</div>';
  };

  App.prototype.carCard = function (c, actions) {
    var dmg = c.damage || 0;
    return '<div class="tz-card' + (c.active ? ' active' : '') + '">' +
      '<div style="display:flex;gap:12px;align-items:center">' + liBadge(c.rating, c.effectiveLI) +
      '<div style="flex:1"><h4>' + esc(c.nickname || c.name) + (c.favorite ? ' ★' : '') + '</h4><div class="meta">' + esc(c.brand) + ' · ' + esc(c.rating && c.rating.categoryName) + (c.active ? ' · <b style="color:var(--accent)">Aktiv</b>' : '') + '</div></div></div>' +
      '<div class="tz-specs"><div>Kilometer<b>' + km(c.mileageKm) + '</b></div><div>Zustand<b style="color:' + (dmg > 0.15 ? 'var(--bad)' : dmg > 0.02 ? 'var(--money)' : 'var(--good)') + '">' + Math.round((1 - dmg) * 100) + '%</b></div>' +
      '<div>Wert<b>' + money(c.value) + '</b></div><div>Motor<b>' + Math.round((1 - (c.engineWear || 0)) * 100) + '%</b></div><div>Rennen<b>' + esc(c.races || 0) + ' / ' + esc(c.wins || 0) + ' Siege</b></div>' +
      '<div>Sauberkeit<b>' + Math.round(c.cleanliness || 0) + '%</b></div></div>' +
      '<div class="row">' + actions + '</div></div>';
  };

  App.prototype.scr_garage = function (d) {
    var self = this;
    var cars = arr(d.cars);
    if (!cars.length) return this.head('Garage') + '<div class="tz-panel">Deine Garage ist leer. Beim Gebrauchtwagenhändler findest du günstige Einstiegsautos.<div style="margin-top:12px"><button class="tz-btn primary" data-act="go" data-arg="used">Zum Gebrauchtwagenhändler</button></div></div>';
    return this.head('Garage', cars.length + ' Fahrzeuge') + '<div class="tz-grid">' + cars.map(function (c) {
      return self.carCard(c,
        (c.active ? '' : '<button class="tz-btn primary" data-act="setActive" data-arg="' + c.id + '">Auswählen</button>') +
        '<button class="tz-btn" data-act="goWorkshop" data-arg="' + c.id + '">Werkstatt</button>' +
        '<button class="tz-btn" data-act="go" data-arg="car" data-arg2="' + c.id + '">Details</button>');
    }).join('') + '</div>';
  };

  App.prototype.scr_car = function (d) {
    var c = d.car || {}, info = c.info || {}, sum = c.summary || {};
    var hist = arr(c.history).slice(-12).reverse();
    return this.head(c.nickname || c.name, esc(c.brand) + ' · ' + esc(info.configName || '')) +
      '<div class="tz-book"><div class="tz-panel"><div style="display:flex;gap:14px;align-items:center">' + liBadge(c.rating, c.effectiveLI) +
      '<div><b>' + esc(c.rating && c.rating.className) + '</b> · ' + esc(c.rating && c.rating.categoryName) + ' · ' + esc(c.rating && c.rating.eraName) + '</div></div>' +
      '<div class="tz-specs" style="grid-template-columns:repeat(4,1fr);margin-top:14px"><div>Leistung<b>' + num(info.power_hp) + ' PS</b></div><div>Gewicht<b>' + num(info.weight_kg) + ' kg</b></div>' +
      '<div>Antrieb<b>' + esc(info.drivetrain || '?') + '</b></div><div>0-100<b>' + num(info.accel0100, 1) + ' s</b></div>' +
      '<div>Kilometer<b>' + km(c.mileageKm) + '</b></div><div>Defekte Teile<b>' + esc(sum.brokenParts || 0) + '</b></div><div>Beschädigt<b>' + esc(sum.damagedParts || 0) + '</b></div><div>Wert<b>' + money(c.value) + '</b></div></div>' +
      '<div class="tz-form" style="margin-top:14px"><label>Spitzname</label><input data-el="nick" value="' + esc(c.nickname || '') + '" maxlength="30"></div>' +
      '<div class="row" style="display:flex;gap:8px;margin-top:12px"><button class="tz-btn" data-act="renameCar" data-arg="' + c.id + '">Umbenennen</button>' +
      '<button class="tz-btn" data-act="favCar" data-arg="' + c.id + '">' + (c.favorite ? '★ Favorit' : '☆ Favorit') + '</button>' +
      '<button class="tz-btn danger" data-act="sellCar" data-arg="' + c.id + '" data-arg2="' + esc(c.value) + '">Verkaufen (' + money(c.value) + ')</button></div></div>' +
      '<div class="tz-panel"><h3 style="margin-top:0">Fahrtenbuch</h3>' + (hist.length ? '<table class="tz-table"><tr><th>Tag</th><th>Ereignis</th><th>Platz</th></tr>' + hist.map(function (h) {
        return '<tr><td>' + esc(h.day) + '</td><td>' + esc(h.series || h.text || h.kind || '') + (h.race ? ' #' + esc(h.race) : '') + '</td><td>' + esc(h.position || '') + '</td></tr>';
      }).join('') + '</table>' : '<div style="color:var(--dim)">Noch keine Einträge.</div>') + '</div></div>';
  };

  App.prototype.scr_workshop = function (d) {
    var svc = d.svc, conv = arr(d.conv);
    if (!svc) return this.head('Werkstatt') + '<div class="tz-panel">Kein Fahrzeug ausgewählt.</div>';
    var c = svc.car, s = svc.summary || {};
    var html = this.head('Werkstatt & Waschanlage', esc(c.nickname || c.name)) +
      '<div class="tz-panel" style="display:flex;gap:30px;align-items:center;flex-wrap:wrap">' + liBadge(c.rating, c.effectiveLI) +
      '<div class="tz-stat"><label>Kilometer</label><span>' + km(s.odometerKm || c.mileageKm) + '</span></div>' +
      '<div class="tz-stat"><label>Defekte Teile</label><span style="color:' + (s.brokenParts ? 'var(--bad)' : 'inherit') + '">' + esc(s.brokenParts || 0) + '</span></div>' +
      '<div class="tz-stat"><label>Beschädigte Teile</label><span>' + esc(s.damagedParts || 0) + '</span></div>' +
      '<div class="tz-stat"><label>Motorverschleiß</label><span>' + Math.round((s.engineWear || 0) * 100) + '%</span></div>' +
      '<div class="tz-stat"><label>Ölalter</label><span>' + Math.round((s.oilAge || 0) * 100) + '%</span></div>' +
      '<div class="tz-stat"><label>Sauberkeit</label><span>' + Math.round(c.cleanliness || 0) + '%</span></div></div>';
    if (s.brokenList && arr(s.brokenList).length) html += '<div class="tz-panel" style="color:#ffb3ba">Defekt: ' + arr(s.brokenList).map(esc).join(', ') + '</div>';
    html += '<div class="tz-grid">' + arr(svc.quotes).map(function (q) {
      return '<div class="tz-card' + (q.available ? '' : ' dim') + '"><h4>' + esc(q.name) + '</h4><div class="meta">' + esc(q.desc) + '</div>' +
        '<div class="row"><span class="tz-price">' + money(q.price) + '</span><span class="tz-spacer" style="flex:1"></span>' +
        (q.available ? '<button class="tz-btn primary" data-act="service" data-arg="' + c.id + '" data-arg2="' + q.id + '">Beauftragen</button>' : '<span class="tz-tag">Nicht nötig</span>') + '</div></div>';
    }).join('') + '</div>';
    if (conv.length) {
      html += '<h2 style="margin:24px 0 10px">Umbauten</h2><p style="color:var(--dim);margin-top:-6px">Werksvarianten desselben Modells – vom Sportpaket bis zur Rennversion.</p><div class="tz-grid">' + conv.map(function (o) {
        return '<div class="tz-card"><div style="display:flex;gap:10px;align-items:center">' + liBadge(o.rating) + '<div><h4>' + esc(o.name || o.configName) + '</h4><div class="meta">' +
          (o.liDelta >= 0 ? '+' : '') + esc(o.liDelta) + ' LI</div></div></div><div class="row"><span class="tz-price">' + money(o.price) + '</span><span style="flex:1"></span>' +
          '<button class="tz-btn" data-act="convert" data-arg="' + c.id + '" data-arg2="' + esc(o.key) + '">Umbauen</button></div></div>';
      }).join('') + '</div>';
    }
    return html;
  };

  App.prototype.offerCard = function (o, kind) {
    var tags = '';
    if (!o.licenseOk) tags += '<span class="tz-tag warn">Lizenz ' + esc(o.licenseRequired) + ' nötig</span>';
    if (o.soldOut) tags += '<span class="tz-tag warn">Verkauft</span>';
    if (o.daysLeft != null && kind !== 'new') tags += '<span class="tz-tag">noch ' + esc(o.daysLeft) + ' Tage</span>';
    var canBuy = o.licenseOk && !o.soldOut && (this.state.money || 0) >= o.price;
    return '<div class="tz-card' + (o.soldOut ? ' dim' : '') + '"><div style="display:flex;gap:12px;align-items:center">' + liBadge(o.rating) +
      '<div style="flex:1"><h4>' + esc(o.name) + '</h4><div class="meta">' + esc(o.brand) + ' · ' + esc(o.year || '') + ' · ' + esc(o.country || '') + '</div></div></div>' +
      '<div class="tz-specs"><div>Leistung<b>' + num(o.power) + ' PS</b></div><div>Gewicht<b>' + num(o.weight) + ' kg</b></div><div>Antrieb<b>' + esc(o.drivetrain || '?') + '</b></div>' +
      (o.mileageKm ? '<div>Kilometer<b>' + km(o.mileageKm) + '</b></div>' : '') + '</div>' +
      '<div style="margin-top:8px">' + tags + '</div>' +
      '<div class="row"><span class="tz-price">' + money(o.price) + '</span><span style="flex:1"></span>' +
      '<button class="tz-btn primary" ' + (canBuy ? '' : 'disabled') + ' data-act="buy" data-arg="' + kind + '" data-arg2="' + esc(o.id) + '">Kaufen</button></div></div>';
  };

  App.prototype.scr_dealers = function (d) {
    var regions = arr(d.regions);
    var tab = this.ui.tab.dealer || (regions[0] && regions[0].id);
    var region = regions.filter(function (r) { return r.id === tab; })[0] || regions[0];
    return this.head('Neuwagen', 'Händler nach Region') +
      '<div class="tz-tabs">' + regions.map(function (r) { return '<div class="tz-tab' + (r.id === tab ? ' on' : '') + '" data-act="tab" data-arg="dealer" data-arg2="' + r.id + '">' + esc(r.name) + '</div>'; }).join('') + '</div>' +
      '<div class="tz-grid">' + (region ? arr(region.brands).map(function (b) {
        return '<div class="tz-tile c-dealer" style="height:110px" data-act="go" data-arg="showroom" data-arg2="' + esc(b.name) + '"><h3>' + esc(b.name) + '</h3><p>' + esc(b.count) + ' Modelle</p><div class="tz-ico">' + ICONS.car + '</div></div>';
      }).join('') : '') + '</div>';
  };
  App.prototype.scr_showroom = function (d, p) { var self = this; return this.head(p.arg2 || p.brand, 'Schauraum') + '<div class="tz-grid">' + arr(d.offers).map(function (o) { return self.offerCard(o, 'new'); }).join('') + '</div>'; };
  App.prototype.scr_used = function (d) { var self = this; return this.head('Gebrauchtwagen', 'Neue Angebote alle paar Tage. Gebrauchte haben Verschleiß – ein Werkstattbesuch lohnt sich.') + '<div class="tz-grid">' + arr(d.offers).map(function (o) { return self.offerCard(o, 'used'); }).join('') + '</div>'; };
  App.prototype.scr_legends = function (d) {
    var self = this, s = this.state, lvl = (s.collector && s.collector.level) || 0;
    var offers = arr(d.offers);
    var gate = offers[0] && offers[0].collectorLevel && lvl < offers[0].collectorLevel;
    return this.head('Klassiker-Galerie', 'Seltene Fahrzeuge bis Baujahr 1995. Jedes Stück gibt es nur einmal pro Ausstellung.') +
      (gate ? '<div class="tz-panel">Die Galerie verkauft erst ab Sammlerstufe ' + esc(offers[0].collectorLevel) + '. Du bist auf Stufe ' + lvl + '.</div>' : '') +
      '<div class="tz-grid">' + offers.map(function (o) { return self.offerCard(o, 'legend'); }).join('') + '</div>';
  };

  App.prototype.scr_licenses = function (d) {
    var lics = arr(d.lics);
    var tab = this.ui.tab.lic || (lics[0] && lics[0].id);
    var lic = lics.filter(function (l) { return l.id === tab; })[0] || lics[0];
    if (!lic) return this.head('Lizenzzentrum');
    var html = this.head('Lizenzzentrum', 'Bestehe jeden Test mindestens mit Bronze, um die Lizenz zu erhalten. Alles Gold bringt ein Geschenk.') +
      '<div class="tz-tabs">' + lics.map(function (l) {
        return '<div class="tz-tab' + (l.id === tab ? ' on' : '') + '" data-act="tab" data-arg="lic" data-arg2="' + l.id + '">' + esc(l.short || l.id) + ' ' + (l.owned ? '✓' : (l.available ? '' : '🔒')) + '</div>';
      }).join('') + '</div>' +
      '<div class="tz-panel" style="display:flex;align-items:center;gap:20px"><div style="flex:1"><h2 style="margin:0">' + esc(lic.name) + '</h2><div style="color:var(--dim)">' + esc(lic.desc || '') + '</div></div>' +
      '<div class="tz-stat"><label>Bestanden</label><span>' + lic.done + ' / ' + lic.total + '</span></div><div class="tz-stat"><label>Gold</label><span style="color:var(--gold)">' + lic.gold + '</span></div></div>';
    if (!lic.available) html += '<div class="tz-panel" style="color:#ffb3ba">' + esc(lic.reason) + '</div>';
    html += '<div class="tz-grid">' + arr(lic.tests).map(function (t, i) {
      var tg = t.targets || {};
      var fmt = t.scoring === 'score' ? function (v) { return v == null ? '--' : Math.round(v); } : time;
      return '<div class="tz-card"><div style="display:flex;gap:10px;align-items:center"><div style="font-size:22px;font-weight:800;color:var(--dim);width:34px">' + (i + 1) + '</div>' +
        '<div style="flex:1"><h4>' + esc(t.name) + '</h4><div class="meta">' + esc(t.desc) + '</div></div>' + medalOf(t.medal) + '</div>' +
        '<div class="tz-targets" style="justify-content:flex-start;margin-top:10px">' + ['gold', 'silver', 'bronze'].map(function (m) { return '<span>' + medalOf(m) + fmt(tg[m]) + '</span>'; }).join('') + '</div>' +
        '<div class="meta" style="margin-top:6px">Auto: ' + esc(t.ownCar ? 'eigenes Fahrzeug' : t.carName) + ' · Bestwert: ' + fmt(t.best) + (tg.source === 'estimate' ? ' · <i>Zielzeiten geschätzt</i>' : '') + '</div>' +
        '<div class="row">' + (lic.available ? '<button class="tz-btn primary" data-act="startTest" data-arg="' + t.id + '">Starten</button><button class="tz-btn" data-act="startTest" data-arg="' + t.id + '" data-arg2="demo">Vorführung</button>' : '') + '</div></div>';
    }).join('') + '</div>';
    return html;
  };

  App.prototype.scr_trainings = function (d) {
    return this.head('Fahrschule', 'Freiwillige Übungen. Jede Medaille wird bezahlt.') + '<div class="tz-grid">' + arr(d.list).map(function (t) {
      var fmt = t.scoring === 'score' ? function (v) { return v == null ? '--' : Math.round(v); } : time;
      var tg = t.targets || {};
      return '<div class="tz-card"><div style="display:flex;gap:10px"><div style="flex:1"><h4>' + esc(t.name) + '</h4><div class="meta">' + esc(t.desc) + '</div></div>' + medalOf(t.medal) + '</div>' +
        '<div class="tz-targets" style="justify-content:flex-start;margin-top:10px">' + ['gold', 'silver', 'bronze'].map(function (m) { return '<span>' + medalOf(m) + fmt(tg[m]) + '</span>'; }).join('') + '</div>' +
        '<div class="row"><button class="tz-btn primary" data-act="startTest" data-arg="' + t.id + '">Starten</button><span class="meta">Bestwert: ' + fmt(t.best) + '</span></div></div>';
    }).join('') + '</div>';
  };

  App.prototype.scr_events = function (d) {
    var halls = arr(d.halls);
    return this.head('Rennen', 'Wähle eine Halle') + '<div class="tz-world">' + halls.map(function (h, i) {
      var series = arr(h.series), won = series.filter(function (s) { return s.won; }).length, open = series.filter(function (s) { return s.available; }).length;
      return '<div class="tz-tile c-race s4" style="animation-delay:' + (i * 0.03) + 's" data-act="go" data-arg="series" data-arg2="' + h.id + '"><h3>' + esc(h.name) + '</h3><p>' + esc(h.desc || '') + '<br>' +
        series.length + ' Serien · ' + open + ' offen · ' + won + ' gewonnen</p><div class="tz-ico">' + ICONS.race + '</div></div>';
    }).join('') + '</div>';
  };

  App.prototype.scr_series = function (d, p) {
    var self = this;
    var hall = arr(d.halls).filter(function (h) { return h.id === p.arg2; })[0];
    if (!hall) return this.head('Rennen');
    var cars = {}; arr(d.cars).forEach(function (c) { cars[c.id] = c; });
    var activeId = this.state.activeCar && this.state.activeCar.id;
    var hardcore = this.state.meta && this.state.meta.hardcore;
    return this.head(hall.name, esc(hall.desc || '')) + arr(hall.series).map(function (s) {
      var elig = arr(s.eligibleCars);
      var useCar = elig.indexOf(activeId) >= 0 ? activeId : elig[0];
      var races = arr(s.races);
      var html = '<div class="tz-panel' + (s.available ? '' : ' dim') + '" style="' + (s.available ? '' : 'opacity:.6') + '">' +
        '<div style="display:flex;gap:16px;align-items:center;flex-wrap:wrap"><div style="flex:1;min-width:260px"><h2 style="margin:0">' + esc(s.name) + (s.won ? ' 🏆' : s.done ? ' ✓' : '') + '</h2>' +
        '<div style="color:var(--dim)">' + esc(s.desc) + '</div></div>' +
        '<span class="tz-tag">' + esc(TYPE_DE[s.type] || s.type) + '</span>' + (s.championship ? '<span class="tz-tag ok">Meisterschaft · Saison ' + esc(s.season) + '</span>' : '') +
        (s.format === 'weekend' || hardcore ? '<span class="tz-tag">Rennwochenende</span>' : s.format === 'choice' ? '<span class="tz-tag">Schnell oder Wochenende</span>' : '') + (s.startType === 'rolling' || (hardcore && s.type === 'circuit') ? '<span class="tz-tag">Einführungsrunde</span>' : '') +
        '<span class="tz-tag">Empf. LI ' + esc(s.recommendedLI || '?') + '</span></div>' +
        '<div style="margin:8px 0;color:var(--dim);font-size:13px">Teilnahme: ' + esc(s.requirement || 'offen') + '</div>';
      if (!s.available) html += '<div style="color:#ffb3ba">' + esc(s.reason) + '</div>';
      else if (!elig.length) html += '<div style="color:var(--money)">Kein passendes Auto in deiner Garage.</div>';
      html += '<table class="tz-table"><tr><th>#</th><th>Lauf</th><th>Strecke</th><th>Runden</th><th>Bestes</th><th></th></tr>' + races.map(function (r) {
        var canStart = s.available && useCar && r.trackOk && (!s.championship || r.idx === s.raceIndex);
        return '<tr><td>' + r.idx + '</td><td>' + esc(r.name || ('Lauf ' + r.idx)) + '</td><td>' + esc(r.track) + (r.level ? ' <span class="tz-tag">' + esc(r.level) + '</span>' : '') + '</td><td>' + esc(r.laps) + '</td>' +
          '<td>' + (r.trophy ? 'P' + esc(r.trophy) : '–') + '</td><td style="text-align:right">' +
          (canStart ? (s.format === 'choice' && !hardcore
            ? '<button class="tz-btn" data-act="startRace" data-arg="' + esc(s.id) + '" data-arg2="' + r.idx + '|' + esc(useCar) + '|quick">Schnelles Rennen</button> ' +
              '<button class="tz-btn primary" data-act="startRace" data-arg="' + esc(s.id) + '" data-arg2="' + r.idx + '|' + esc(useCar) + '|weekend">Rennwochenende</button>'
            : '<button class="tz-btn primary" data-act="startRace" data-arg="' + esc(s.id) + '" data-arg2="' + r.idx + '|' + esc(useCar) + '">Start</button>') : '') + '</td></tr>';
      }).join('') + '</table>';
      if (s.championship && s.points) {
        var pts = Object.keys(s.points).map(function (k) { return { k: k, v: s.points[k] }; }).sort(function (a, b) { return b.v - a.v; }).slice(0, 8);
        if (pts.length) html += '<div style="margin-top:10px;color:var(--dim);font-size:13px">Punktestand: ' + pts.map(function (x) { return (x.k === 'player' ? '<b style="color:var(--accent)">Du</b>' : esc(x.k)) + ' ' + x.v; }).join(' · ') + '</div>';
      }
      if (elig.length > 1) html += '<div style="margin-top:8px;font-size:13px;color:var(--dim)">Passende Autos: ' + elig.map(function (id) { return esc(cars[id] ? (cars[id].nickname || cars[id].name) : id); }).join(', ') + '</div>';
      var rw = s.rewards || {};
      if (rw.positions) html += '<div style="margin-top:6px;font-size:13px;color:var(--dim)">Preisgeld: 1. ' + money(arr(rw.positions)[0]) + (rw.car ? ' · Siegerauto für alle Siege' : '') + '</div>';
      return html + '</div>';
    }).join('');
  };

  App.prototype.scr_cafe = function (d) {
    var cafe = d.cafe || {}, books = arr(cafe.books);
    var cur = books.filter(function (b) { return b.status === 'active'; })[0] || books.filter(function (b) { return b.status === 'next'; })[0];
    var html = this.head('Boxenstopp-Café', esc(cafe.completedCount || 0) + ' von ' + books.length + ' Menüheften abgeschlossen');
    if (!cur) return html + '<div class="tz-panel">Alle Hefte erledigt. Respekt – du hast die Karriere gemeistert!</div>';
    var steps = arr(cur.steps);
    var allDone = steps.length && steps.every(function (s) { return s.done; });
    var rw = cur.reward || {};
    html += '<div class="tz-book"><div class="tz-paper"><div class="no">MENÜHEFT ' + esc(cur.number) + ' · KAPITEL ' + esc(cur.chapter) + '</div><h2>' + esc(cur.name) + '</h2><p>' + esc(cur.intro) + '</p>' +
      steps.map(function (s) {
        return '<div class="step"><span class="chk' + (s.done ? ' on' : '') + '">' + (s.done ? '✓' : '') + '</span><div style="flex:1">' + esc(s.label) +
          (s.need > 1 ? ' <b>(' + esc(Math.min(s.have, s.need)) + '/' + esc(s.need) + ')</b>' : '') + (s.hint && !s.done ? '<div class="hint">' + esc(s.hint) + '</div>' : '') + '</div></div>';
      }).join('') +
      '<p style="margin-top:16px;font-size:14px">Belohnung: ' + [rw.money ? money(rw.money) : null, rw.car ? 'ein Auto' : null, rw.ticket ? 'Bonuslos' : null].filter(Boolean).join(' · ') +
      (arr(cur.unlocks).length ? '<br>Schaltet frei: ' + arr(cur.unlocks).map(esc).join(', ') : '') + '</p>' +
      (cur.status === 'next' ? '<button class="tz-btn primary" data-act="cafeAccept" data-arg="' + cur.id + '">Heft annehmen</button>' : '') +
      (cur.status === 'active' && allDone ? '<button class="tz-btn primary" data-act="cafeComplete" data-arg="' + cur.id + '">Heft abgeben</button>' : '') +
      '</div><div><div class="tz-panel"><h3 style="margin-top:0">Alle Hefte</h3><div class="tz-bookList">' + books.map(function (b) {
        return '<div class="' + esc(b.status) + '">' + esc(b.number) + '<br>' + (b.status === 'locked' ? '???' : esc(b.name)) + '</div>';
      }).join('') + '</div></div></div></div>';
    return html;
  };

  App.prototype.scr_tickets = function (d) {
    var t = arr(d.tickets);
    return this.head('Bonuslose', 'Gewonnen für Siege, Hefte und Tagesziele') +
      (t.length ? '<div class="tz-grid">' + t.map(function (x) {
        return '<div class="tz-card"><h4>' + '★'.repeat(x.tier || 1) + ' Los</h4><div class="meta">' + esc(x.source || '') + ' · Tag ' + esc(x.day) + '</div><div class="row"><button class="tz-btn primary" data-act="openTicket" data-arg="' + esc(x.id) + '">Öffnen</button></div></div>';
      }).join('') + '</div>' : '<div class="tz-panel">Keine Lose. Fahre täglich 42 km, gewinne Rennen oder schließe Hefte ab.</div>');
  };

  App.prototype.scr_world2 = function (d) {
    var levels = arr(d.levels), tracks = arr(d.tracks), rec = d.rec;
    var html = this.head('Freie Fahrt & Strecken', 'Kilometer zählen fürs Tagesziel (' + esc(this.state.dailyGoal || 42) + ' km = Bonuslos).') +
      '<div class="tz-grid">' + levels.map(function (l) {
        return '<div class="tz-tile c-fun" style="height:110px" data-act="freeDrive" data-arg="' + esc(l.level) + '"><h3>' + esc(l.level) + '</h3><p>' + esc(l.tracks) + ' Strecken</p><div class="tz-ico">' + ICONS.map + '</div></div>';
      }).join('') + '</div>' +
      '<h2 style="margin:24px 0 10px">Streckenrekorder</h2><div class="tz-panel">' +
      (rec ? '<b>Aufnahme läuft: ' + esc(rec.name) + '</b> · ' + esc(rec.cps) + ' Checkpoints · ' + esc(rec.grid) + ' Startplätze<div class="row" style="display:flex;gap:8px;margin-top:10px">' +
        '<button class="tz-btn" data-act="rec" data-arg="recorderCheckpoint">Checkpoint hier</button><button class="tz-btn" data-act="rec" data-arg="recorderGrid">Startplatz hier</button>' +
        '<button class="tz-btn primary" data-act="rec" data-arg="recorderSave">Speichern</button><button class="tz-btn danger" data-act="rec" data-arg="recorderCancel">Verwerfen</button></div>'
        : 'Fahre eine Strecke ab und setze Checkpoints (eigene Taste belegbar). Gespeicherte Strecken stehen für Rennen mit Platzhalter-Strecken zur Verfügung.<div class="row" style="display:flex;gap:8px;margin-top:10px">' +
        '<button class="tz-btn" data-act="recStart" data-arg="1">Rundkurs aufnehmen</button><button class="tz-btn" data-act="recStart" data-arg="0">Sprint aufnehmen</button></div>') + '</div>' +
      '<h2 style="margin:24px 0 10px">Bekannte Strecken (' + tracks.length + ')</h2><div class="tz-panel"><table class="tz-table"><tr><th>Name</th><th>Karte</th><th>Art</th><th>Länge</th><th>Bestzeit</th></tr>' +
      tracks.map(function (t) { return '<tr><td>' + esc(t.name) + '</td><td>' + esc(t.level) + '</td><td>' + (t.closed ? 'Rundkurs' : 'Sprint') + ' · ' + esc(t.surface) + '</td><td>' + num((t.lengthM || 0) / 1000, 2) + ' km</td><td>' + (t.best ? time(t.best) : '–') + '</td></tr>'; }).join('') +
      '</table></div>';
    return html;
  };

  App.prototype.scr_settings = function () {
    var s = this.state, m = s.meta || {}, st = s.settings || {};
    function opt(key, val, label, cur) { return '<div class="' + (String(cur) === String(val) ? 'on' : '') + '" data-act="setting" data-arg="' + key + '" data-arg2="' + val + '">' + label + '</div>'; }
    return this.head('Einstellungen') + '<div class="tz-panel tz-form" style="max-width:900px">' +
      '<label>Gegnerstärke</label><div class="tz-note">Automatisch – passt sich deinen Ergebnissen an. Aktuell: <b>' + esc(s.aiLevel || 'Fortgeschritten') + '</b></div>' +
      '<label>Renndauer</label><div class="tz-choice">' + opt('raceLength', 'short', 'Kurz', m.raceLength) + opt('raceLength', 'normal', 'Normal', m.raceLength || 'normal') + opt('raceLength', 'long', 'Lang', m.raceLength) + '</div>' +
      '<label>Schäden</label><div class="tz-choice">' + opt('damageMode', 'realistic', 'Realistisch', m.damageMode) + opt('damageMode', 'mechanical', 'Nur Mechanik', m.damageMode) + opt('damageMode', 'off', 'Aus', m.damageMode) + '</div>' +
      '<label>Startkamera-Flug</label><div class="tz-choice">' + opt('skipIntro', 'false', 'Zeigen', !!m.skipIntro) + opt('skipIntro', 'true', 'Überspringen', !!m.skipIntro) + '</div>' +

      '<label>Hardcore</label><div class="tz-choice">' + opt('hardcore', 'false', 'Aus', !!m.hardcore) + opt('hardcore', 'true', 'An (immer Rennwochenende, kein Neustart)', !!m.hardcore) + '</div>' +
      '<label>Spiel pausieren im Menü</label><div class="tz-choice">' + opt('pauseInHub', 'true', 'Ja', st.pauseInHub !== false) + opt('pauseInHub', 'false', 'Nein', st.pauseInHub !== false) + '</div>' +
      '<label>Musik-Lautstärke</label><div class="tz-choice">' + [0, 0.2, 0.45, 0.7].map(function (v) { return '<div class="' + (Math.abs(Audio_.musicVol - v) < 0.01 ? 'on' : '') + '" data-act="musicVol" data-arg="' + v + '">' + (v === 0 ? 'Aus' : Math.round(v * 100) + '%') + '</div>'; }).join('') + '</div>' +
      '<div style="margin-top:20px;display:flex;gap:10px"><button class="tz-btn" data-act="save">Jetzt speichern</button><button class="tz-btn" data-act="toTitle">Spielstand wechseln</button></div></div>';
  };

  App.prototype.scr_diag = function (d) {
    var x = d.diag || {};
    return this.head('Diagnose', 'Version ' + esc(x.version) + ' · Karte: ' + esc(x.level || '–')) +
      '<div class="tz-panel" style="display:flex;gap:30px"><div class="tz-stat"><label>Autos</label><span>' + esc(x.cars) + '</span></div><div class="tz-stat"><label>Marken</label><span>' + esc(x.brands) + '</span></div>' +
      '<div class="tz-stat"><label>Strecken</label><span>' + esc(x.tracks) + '</span></div><div class="tz-spacer" style="flex:1"></div><button class="tz-btn" data-act="rescan">Neu einlesen</button></div>' +
      '<div class="tz-panel"><h3 style="margin-top:0">Datenprobleme (' + arr(x.problems).length + ')</h3>' + (arr(x.problems).map(function (p) { return '<div>' + esc(p) + '</div>'; }).join('') || '<div style="color:var(--good)">Keine</div>') + '</div>' +
      '<div class="tz-panel"><h3 style="margin-top:0">Nicht gefundene Strecken (' + arr(x.missingTracks).length + ')</h3>' + (arr(x.missingTracks).map(function (p) { return '<div>' + esc(p) + '</div>'; }).join('') || '<div style="color:var(--good)">Keine</div>') + '</div>';
  };

  // ------------------------------------------------------------------ actions
  App.prototype.act = function (act, arg, arg2, el) {
    var self = this;
    switch (act) {
      case 'back': this.back(); break;
      case 'home': this.home(); break;
      case 'close': this.call('hub', { visible: false }); break;
      case 'guide': this.showGuide(); break;
      case 'guideDone': this.closeModal(); if (this.state && this.state.firstVisit) { this.state.firstVisit = false; this.call('setting', { key: 'introSeen', value: true }).catch(function () {}); } break;
      case 'go': this.go(arg, { arg2: arg2, carId: arg === 'car' ? arg2 : undefined, brand: arg === 'showroom' ? arg2 : undefined }); break;
      case 'goWorkshop':
        var id = arg || (this.state.activeCar && this.state.activeCar.id);
        if (!id) { this.toast('Kein Fahrzeug ausgewählt', 'error'); return; }
        this.go('workshop', { carId: id }); break;
      case 'tab': this.ui.tab[arg] = arg2; this.render(); break;
      case 'loadSlot': this.call('loadProfile', { slot: +arg }).then(function (s) { self.state = s; self.renderTop(); Audio_.music('menu'); self.home(); }); break;
      case 'deleteSlot':
        this.confirm('Spielstand löschen?', 'Platz ' + arg + ' wird endgültig gelöscht.', function () { self.call('deleteProfile', { slot: +arg }).then(function () { self.load(); }); });
        break;
      case 'npSet': this.readNp(); this.ui.newProfile[arg] = arg2 === 'true' ? true : arg2 === 'false' ? false : arg2; this.render(); break;
      case 'createProfile':
        this.readNp();
        var f = this.ui.newProfile;
        this.call('newProfile', { slot: +arg, name: f.name || 'Fahrer', progressionMode: f.progressionMode, damageMode: f.damageMode, hardcore: !!f.hardcore })
          .then(function (s) { self.state = s; self.renderTop(); Audio_.music('menu'); self.stack = [{ name: 'world', params: {} }]; self.load(); });
        break;
      case 'setActive': this.call('setActiveCar', { carId: arg }).then(function () { return self.refreshState(); }).then(function () { self.reload(); }); break;
      case 'renameCar': var n = this.root.querySelector('[data-el=nick]'); this.call('renameCar', { carId: arg, name: n ? n.value : '' }).then(function () { self.reload(); }); break;
      case 'favCar': this.call('favoriteCar', { carId: arg }).then(function () { self.reload(); }); break;
      case 'sellCar':
        this.confirm('Fahrzeug verkaufen?', 'Du erhältst ' + money(+arg2) + '. Das kann nicht rückgängig gemacht werden.', function () {
          self.call('sellCar', { carId: arg }).then(function () { return self.refreshState(); }).then(function () { self.back(); });
        });
        break;
      case 'service': this.call('service', { carId: arg, service: arg2 }).then(function () { return self.refreshState(); }).then(function () { self.reload(); }); break;
      case 'convert':
        this.confirm('Umbau beauftragen?', 'Das Fahrzeug wird in die gewählte Werksvariante umgebaut.', function () {
          self.call('convert', { carId: arg, key: arg2 }).then(function () { return self.refreshState(); }).then(function () { self.reload(); });
        });
        break;
      case 'buy':
        this.confirm('Kaufen?', 'Das Fahrzeug wird in deine Garage gestellt.', function () {
          self.call('buy', { kind: arg, id: arg2 }).then(function (car) {
            self.toast((car && car.name || 'Fahrzeug') + ' gehört jetzt dir!', 'money');
            return self.refreshState();
          }).then(function () { self.reload(); });
        });
        break;
      case 'startTest': this.call('startTest', { testId: arg, demo: arg2 === 'demo' }); break;
      case 'startRace':
        var parts = (arg2 || '').split('|');
        this.call('startRace', { seriesId: arg, raceIndex: +parts[0], carId: parts[1] || undefined, format: parts[2] || undefined });
        break;
      case 'cafeAccept': this.call('cafeAccept', { bookId: arg }).then(function () { self.reload(); }); break;
      case 'cafeComplete':
        this.call('cafeComplete', { bookId: arg }).then(function (r) {
          self.modalShow('<h2>Heft abgeschlossen!</h2><p>' + esc(r.book) + '</p><div class="tz-rewards">' +
            (r.money ? '<div>Preisgeld<b>' + money(r.money) + '</b></div>' : '') + (r.car ? '<div>Geschenk<b>' + esc(r.car) + '</b></div>' : '') +
            (r.ticket ? '<div>Bonuslos<b>' + '★'.repeat(r.ticket) + '</b></div>' : '') + '</div>' +
            (arr(r.unlocks).length ? '<p>Neu freigeschaltet: ' + arr(r.unlocks).map(esc).join(', ') + '</p>' : '') +
            '<div class="actions"><button class="tz-btn primary" data-act="modalClose">Weiter</button></div>');
          return self.refreshState();
        }).then(function () { self.reload(); });
        break;
      case 'openTicket':
        this.call('openTicket', { id: arg }).then(function (r) {
          self.modalShow('<h2>' + '★'.repeat(r.tier || 1) + ' Bonuslos</h2><div class="tz-rewards">' + (r.money ? '<div>Gewinn<b>' + money(r.money) + '</b></div>' : '') +
            (r.car ? '<div>Auto gewonnen<b>' + esc(r.car) + '</b></div>' : '') + '</div><div class="actions"><button class="tz-btn primary" data-act="modalClose">Super!</button></div>');
          return self.refreshState();
        }).then(function () { self.reload(); });
        break;
      case 'freeDrive': this.call('freeDrive', { level: arg }); break;
      case 'rec': this.call(arg, {}).then(function (r) { if (arg === 'recorderSave') self.toast('Strecke gespeichert: ' + r, 'info'); self.reload(); }); break;
      case 'recStart': this.call('recorderStart', { name: arg === '1' ? 'Eigener Rundkurs' : 'Eigener Sprint', closed: arg === '1' }).then(function () { self.reload(); }); break;
      case 'setting':
        var v = arg2 === 'true' ? true : arg2 === 'false' ? false : arg2;
        this.call('setting', { key: arg, value: v }).then(function (s) { self.state = s; self.render(); });
        break;
      case 'musicVol': Audio_.setMusicVolume(+arg); this.render(); break;
      case 'save': this.call('save').then(function () { self.toast('Gespeichert', 'info'); }); break;
      case 'toTitle': this.stack = [{ name: 'title', params: {} }]; this.load(); break;
      case 'rescan': this.call('rescan').then(function () { self.reload(); }); break;
      case 'modalClose': this.closeModal(); break;
      case 'modalOk': var cb = this._modalCb; this.closeModal(); if (cb) cb(); break;
      // race / results
      case 'resClose': this.closeResults(); this.call('raceClose'); break;
      case 'resRestart': this.closeResults(); this.call('raceRestart'); break;
      case 'resContinue': this.closeResults(); break;
      case 'resSkipIntro': this.call('raceSkipIntro'); break;
      case 'resEndSession': this.closeResults(); this.call('raceEndSession'); break;
      case 'menuResume': this.el.overlay.innerHTML = ''; break;
      case 'menuRestart': this.el.overlay.innerHTML = ''; this.call('raceRestart'); break;
      case 'menuAbort': this.el.overlay.innerHTML = ''; this.call('raceAbort'); break;
      case 'testRetry': this.closeResults(); this.call('retryTest'); break;
      case 'testClose': this.closeResults(); this.call('closeTest'); this.call('hub', { visible: true }); break;
      case 'dragDial': var inp = this.root.querySelector('[data-el=dial]'); this.call('dragDial', { value: inp ? +String(inp.value).replace(',', '.') : 0 }); break;
    }
  };

  App.prototype.readNp = function () { var i = this.root.querySelector('[data-el=npName]'); if (i && this.ui.newProfile) this.ui.newProfile.name = i.value; };
  App.prototype.refreshState = function () { var self = this; return this.call('state').then(function (s) { self.state = s; self.renderTop(); }); };

  // ------------------------------------------------------------------ modal & toasts
  App.prototype.modalShow = function (html) { this.modal = true; this.el.modal.firstChild.innerHTML = html; this.el.modal.classList.remove('tz-hidden'); };
  App.prototype.showGuide = function () {
    this.modalShow('<div class="tz-guide"><h2>Willkommen bei Turismo</h2>' +
      '<p>Du startest mit wenig Geld und ohne Auto. Ziel: dir eine Garage voller Autos erfahren und die großen Meisterschaften gewinnen.</p>' +
      '<ol><li><b>Boxenstopp-Café</b> – hol dir dein erstes Aufgabenheft. Die Hefte sagen dir immer, was als Nächstes sinnvoll ist.</li>' +
      '<li><b>Gebrauchtwagen</b> – kauf ein günstiges erstes Auto.</li>' +
      '<li><b>Lizenzzentrum</b> – mach die erste Lizenz (C). Gelbe Pfosten zeigen das Ziel, eine gelbe Linie den Weg.</li>' +
      '<li><b>Rennen</b> – fahr Einsteigerserien und verdiene Preisgeld.</li>' +
      '<li><b>Werkstatt</b> – Schäden bleiben, bis du sie reparierst.</li></ol>' +
      '<p class="hint">Die Gegner passen sich automatisch an dein Können an. Während der Fahrt kommst du über <b>Esc → Mods → Turismo-Menü</b> zurück.</p>' +
      '<div style="margin-top:16px;text-align:right"><button class="tz-btn primary" data-act="guideDone">Los geht’s</button></div></div>');
  };
  App.prototype.closeModal = function () { this.modal = null; this._modalCb = null; this.el.modal.classList.add('tz-hidden'); };
  App.prototype.confirm = function (title, text, cb) {
    this._modalCb = cb;
    this.modalShow('<h2>' + esc(title) + '</h2><p>' + esc(text) + '</p><div class="actions"><button class="tz-btn" data-act="modalClose">Abbrechen</button><button class="tz-btn primary" data-act="modalOk">Bestätigen</button></div>');
  };
  App.prototype.toast = function (msg, kind) {
    var t = document.createElement('div');
    t.className = 'tz-toast ' + (kind || 'info'); t.textContent = msg;
    this.el.toasts.appendChild(t);
    setTimeout(function () { t.style.transition = 'opacity .4s'; t.style.opacity = 0; setTimeout(function () { t.remove(); }, 450); }, 4200);
  };

  // ------------------------------------------------------------------ HUD
  App.prototype.onStream = function (s) {
    if (!s || !s.electrics) return;
    var e = s.electrics;
    this.tele = { speed: Math.abs(e.wheelspeed != null ? e.wheelspeed : (e.airspeed || 0)) * 3.6, rpm: e.rpmTacho || e.rpm || 0,
      maxrpm: e.maxrpm || (s.engineInfo && s.engineInfo[1]) || 7000, gear: e.gear != null ? e.gear : e.gearIndex };
    if (this.phase !== 'idle' && !this.hubVisible) this.renderSpeedo();
  };

  App.prototype.onPhase = function (d) {
    var self = this;
    this.phase = d.phase;
    if (d.phase === 'idle' || d.phase === 'loading') { this.trackMap = null; this._delta = null; }
    if (d.phase === 'idle') { this.hud = {}; this.banner = null; this.lights = null; this.renderHud(); return; }
    var titles = {
      loading: [d.title || 'Rennen', 'Strecke wird geladen …'], intro: [d.track || d.title, (d.laps ? d.laps + (d.laps === 1 ? ' Runde' : ' Runden') + ' · ' : '') + (d.title || '')],
      formation: ['Einführungsrunde', 'Position halten · nicht überholen · fliegender Start'], practice: ['Freies Training', (d.minutes || '') + ' Minuten'],
      qualifying: ['Qualifying', (d.minutes || '') + ' Minuten · schnellste Runde zählt'], racing: ['', ''],
      finished: ['Ziel!', d.pos ? 'Platz ' + d.pos : ''], timeAttack: [d.title || 'Zeitfahren', 'Lauf ' + (d.run || 1) + ' von ' + (d.runs || 1)],
      touge: [d.title || 'Touge', 'Lauf ' + d.run + ' · ' + (d.playerLeads ? 'Du führst' : 'Du jagst')], drift: [d.title || 'Drift', 'Punkte für Winkel und Tempo'],
      derby: [d.title || 'Derby', (d.cars || '') + ' Fahrzeuge · Letzter Fahrender gewinnt'], trucking: [d.title || 'Transport', 'Pünktlich und ohne Ladungsschaden']
    };
    var t = titles[d.phase];
    this.banner = t && t[0] ? { t1: t[0], t2: t[1], intro: d.phase === 'intro' } : null;
    if (this.banner && d.phase !== 'intro' && d.phase !== 'loading') {
      clearTimeout(this._bannerT);
      this._bannerT = setTimeout(function () { self.banner = null; self.renderHud(); }, 4500);
    }
    if (d.phase === 'intro') Audio_.music('race');
    this.renderHud();
  };

  App.prototype.onCountdown = function (d) {
    var self = this;
    if (d.green) {
      this.lights = { go: true }; // sound comes from Lua (turismo_audio)
      this.banner = null;
      clearTimeout(this._lightsT); this._lightsT = setTimeout(function () { self.lights = null; self.renderHud(); }, 1300);
    } else {
      this.lights = { n: Math.max(0, 4 - d.value) };
    }
    this.renderHud();
  };

  App.prototype.onTestPhase = function (d) {
    var self = this;
    if (d.phase === 'idle') { this.phase = 'idle'; this.hud = {}; this.banner = null; if (d.message) this.toast(d.message, 'error'); this.renderHud(); return; }
    this.phase = 'test';
    this.banner = { t1: d.name, t2: (d.demo ? 'Vorführung · ' : '') + (d.desc || '') };
    clearTimeout(this._bannerT); this._bannerT = setTimeout(function () { self.banner = null; self.renderHud(); }, 3500);
    this.hud.testIntro = d; this.hud.test = null;
    Audio_.music('license');
    this.renderHud();
  };

  App.prototype.onTree = function (d) {
    var self = this;
    if (d.phase === 'ambers') {
      this.tree = { stage: true, amber: 0 };
      var n = 0;
      clearInterval(this._treeIv);
      var step = d.tree === 'pro' ? 0 : 500;
      if (step === 0) { this.tree.amber = 3; }
      else this._treeIv = setInterval(function () { n++; self.tree.amber = n; Audio_.sfx('race_count'); self.renderHud(); if (n >= 3) clearInterval(self._treeIv); }, step);
    } else if (d.phase === 'green') { clearInterval(this._treeIv); this.tree = { stage: true, amber: 3, green: true }; setTimeout(function () { self.tree = null; self.renderHud(); }, 2000); }
    else if (d.phase === 'red') { this.tree = { stage: true, red: true }; }
    this.renderHud();
  };

  App.prototype.renderHud = function () {
    var h = this.hud, html = '';
    var show = this.phase !== 'idle' && !this.hubVisible;
    if (!show) { this.el.hud.innerHTML = ''; this._speedoBuilt = false; return; }
    if (this.banner) html += '<div class="tz-banner"><div class="t1">' + esc(this.banner.t1) + '</div><div class="t2">' + esc(this.banner.t2) + '</div>' +
      (this.banner.intro ? '<div style="margin-top:14px;pointer-events:auto"><button class="tz-btn" data-act="resSkipIntro">Überspringen</button></div>' : '') + '</div>';
    if (this.lights) {
      html += '<div class="tz-lights' + (this.lights.go ? ' go' : '') + '">' + [0, 1, 2, 3].map(function (i) { return '<i class="' + (this.lights.go || i < this.lights.n ? 'on' : '') + '"></i>'; }, this).join('') + '</div>';
    }
    var r = h.race;
    if (r && (this.phase === 'racing' || this.phase === 'formation' || this.phase === 'finished' || this.phase === 'timeAttack' || this.phase === 'trucking')) {
      if (r.pos) html += '<div class="tz-hbox tz-hpos"><div><div class="lab">Position</div><div class="big tz-num">' + r.pos + '<small>/' + (r.total || '?') + '</small></div></div>' +
        '<div><div class="lab">Runde</div><div class="lap tz-num">' + (r.lap || 1) + '/' + (r.laps || 1) + '</div></div></div>';
      html += '<div class="tz-hbox tz-htimes" style="' + (r.pos ? '' : 'top:22px') + '"><div><span>Runde</span><span class="cur tz-num">' + time(r.lapTime) + '</span></div>' +
        (r.delta != null ? '<div><span>Δ Beste</span><span class="tz-num ' + (r.delta > 0 ? 'bad' : 'good') + '">' + (r.delta > 0 ? '+' : '−') + num(Math.abs(r.delta), 2) + '</span></div>' : '') +
        '<div><span>Letzte</span><span class="tz-num">' + time(r.lastLap) + '</span></div><div><span>Beste</span><span class="tz-num" style="color:var(--accent2)">' + time(r.bestLap) + '</span></div>' +
        (r.target ? '<div><span>Ziel</span><span class="tz-num">' + time(r.target) + '</span></div>' : '') + '</div>';
      var st = arr(r.standings);
      if (st.length > 1) {
        var me = 0; st.forEach(function (x, i) { if (x.isPlayer) me = i; });
        var rows = 5, from = Math.max(0, Math.min(st.length - rows, me - 2));
        html += '<div class="tz-hbox tz-hstand">' + st.slice(from, from + rows).map(function (x) {
          return '<div class="' + (x.isPlayer ? 'me' : '') + '"><span class="tz-num">' + x.pos + '</span><span>' + esc(x.isPlayer ? 'Du' : x.name) + '</span><b class="tz-num">' + (x.pos === 1 ? 'Führung' : (x.gap != null ? gap(x.gap) : '')) + '</b></div>';
        }).join('') + '</div>';
      }
      if (r.gapAhead != null || r.gapBehind != null) {
        html += '<div class="tz-hbox tz-hgaps">' + (r.gapAhead != null ? '<div class="g ahead"><b class="tz-num">' + gap(-r.gapAhead) + '</b>' + esc(r.nameAhead || '') + '</div>' : '') +
          (r.gapBehind != null ? '<div class="g behind"><b class="tz-num">' + gap(r.gapBehind) + '</b>' + esc(r.nameBehind || '') + '</div>' : '') + '</div>';
      }
      if (r.delta != null && this.phase !== 'formation') html += '<div class="tz-hdelta tz-num ' + (r.delta > 0 ? 'bad' : 'good') + '">' + (r.delta > 0 ? '+' : '−') + num(Math.abs(r.delta), 2) + '</div>';
      if (this.trackMap) html += minimapSvg(this.trackMap, arr(r.cars));
      if (r.progress != null) html += '<div class="tz-hbox tz-hprog"><i style="width:' + (r.progress * 100).toFixed(1) + '%"></i></div>';
    }
    if (h.session && (this.phase === 'practice' || this.phase === 'qualifying')) {
      html += '<div class="tz-hbox tz-modehud"><div class="s">' + (this.phase === 'practice' ? 'Training' : 'Qualifying') + ' · verbleibend</div><div class="v tz-num">' + time(h.session.remaining).slice(0, -4) +
        '</div><div class="s">Beste Runde ' + time(h.session.best) + '</div><div style="pointer-events:auto;margin-top:8px"><button class="tz-btn" data-act="resEndSession">Sitzung beenden</button></div></div>';
    }
    var m = h.mode;
    if (m) {
      if (m.mode === 'drift') html += '<div class="tz-hbox tz-modehud"><div class="s">Driftpunkte</div><div class="v tz-num">' + Math.round(m.score || 0).toLocaleString('de-DE') + '</div>' +
        '<div class="s" style="color:var(--money)">' + (m.pending ? '+' + Math.round(m.pending) + ' × ' + num(m.combo, 1) : '&nbsp;') + '</div>' + (m.remaining != null ? '<div class="s">' + time(m.remaining).slice(0, -4) + '</div>' : '') + '</div>';
      else if (m.mode === 'derby') html += '<div class="tz-hbox tz-modehud"><div class="s">Noch im Spiel</div><div class="v tz-num">' + m.alive + ' / ' + m.total + '</div><div class="s">Zeit ' + time(m.remaining).slice(0, -4) +
        (m.stillFor ? ' · <span style="color:var(--bad)">Beweg dich! ' + Math.ceil(m.stillFor) + '</span>' : '') + '</div></div>';
      else if (m.mode === 'touge') html += '<div class="tz-hbox tz-modehud"><div class="s">Lauf ' + m.run + ' · ' + (m.playerLeads ? 'Abstand zum Verfolger' : 'Abstand zum Führenden') + '</div><div class="v tz-num">' + num(m.gapM, 0) + ' m</div></div>';
      else if (m.mode === 'trucking') html += '<div class="tz-hbox tz-modehud"><div class="s">Ladung intakt</div><div class="v tz-num" style="color:' + (m.cargo < 0.5 ? 'var(--bad)' : 'inherit') + '">' + Math.round((m.cargo || 0) * 100) + '%</div>' +
        '<div class="s">' + time(m.time) + ' / Ziel ' + time(m.target) + '</div></div>';
    }
    var t = h.test;
    if (t && this.phase === 'test') {
      var tg = t.targets || {}, cur = (t.time || 0) + (t.penalty || 0);
      html += '<div class="tz-hbox tz-modehud"><div class="s">' + esc(t.name) + '</div><div class="v tz-num">' + time(cur) + '</div>' +
        (t.penalty ? '<div class="s" style="color:var(--bad)">+' + num(t.penalty, 1) + ' s Strafe</div>' : '') +
        '<div class="tz-targets">' + ['gold', 'silver', 'bronze'].map(function (k) { return tg[k] ? '<span class="' + (cur > tg[k] ? 'lost' : '') + '">' + medalOf(k) + time(tg[k]) + '</span>' : ''; }).join('') + '</div>' +
        (t.gates ? '<div class="s">Tor ' + Math.min(t.gate, t.gates) + ' / ' + t.gates + '</div>' : '') + '</div>';
      if (t.nextLabel) html += '<div class="tz-hbox tz-nextgate"><div class="s">Nächstes Ziel · folge der gelben Linie</div><div class="v">' + esc(t.nextLabel) +
        (t.nextDist != null ? ' <small class="tz-num">' + Math.round(t.nextDist) + ' m</small>' : '') + '</div></div>';
    }
    // briefing until the test starts: what to do, where to go
    var ti = h.testIntro;
    if (ti && this.phase === 'test' && !t) {
      html += '<div class="tz-hbox tz-brief"><div class="s">Lizenzprüfung</div><div class="v">' + esc(ti.name) + '</div>' +
        '<p>' + esc(ti.desc || '') + '</p><p class="hint">Die <b>gelben Pfosten</b> markieren das nächste Ziel, die gelbe Linie am Boden zeigt den Weg. Grün = geschafft.</p></div>';
    }
    if (this.phase === 'drag') {
      var tr = this.tree;
      if (tr) html += '<div class="tz-tree"><i class="stage on"></i><i class="amber' + (tr.amber >= 1 ? ' on' : '') + '"></i><i class="amber' + (tr.amber >= 2 ? ' on' : '') + '"></i><i class="amber' + (tr.amber >= 3 ? ' on' : '') + '"></i>' +
        '<i class="green' + (tr.green ? ' on' : '') + '"></i><i class="red' + (tr.red ? ' on' : '') + '"></i></div>';
      var dr = h.drag || {}, run = h.dragRun;
      html += '<div class="tz-hbox tz-hpos"><div><div class="lab">' + esc(dr.title || 'Drag') + '</div><div class="lap">' + esc(dr.roundName || (dr.round ? 'Runde ' + dr.round : 'Qualifying')) + '</div>' +
        (dr.opponent ? '<div style="color:var(--dim)">gegen ' + esc(dr.opponent) + '</div>' : '') + '</div></div>';
      if (run) {
        var sp = run.splits || {};
        html += '<div class="tz-hbox tz-htimes" style="top:120px"><div><span>Zeit</span><span class="cur tz-num">' + num(run.time, 3) + '</span></div><div><span>Reaktion</span><span class="tz-num">' + num(run.reaction, 3) + '</span></div>' +
          [['sixty', '60 ft'], ['t330', '330 ft'], ['eighth', '1/8 Meile'], ['t1000', '1000 ft'], ['quarter', '1/4 Meile']].map(function (k) { return sp[k[0]] ? '<div><span>' + k[1] + '</span><span class="tz-num">' + num(sp[k[0]], 3) + '</span></div>' : ''; }).join('') + '</div>';
      }
      if (dr.bracket && dr.phase === 'staging') html += '<div class="tz-hbox" style="left:22px;bottom:30px;pointer-events:auto">Dial-In <input data-el="dial" style="width:80px" value="' + esc(dr.dial || '') + '"> <button class="tz-btn" data-act="dragDial">Setzen</button></div>';
    }
    html += '<div class="tz-speedo" data-el="speedo"></div>';
    this.el.hud.innerHTML = html;
    this._speedoBuilt = false;
    this.renderSpeedo();
  };

  var SEGS = 32;
  App.prototype.renderSpeedo = function () {
    var box = this.el.hud.querySelector('[data-el=speedo]');
    if (!box) return;
    var t = this.tele || { speed: (this.hud.test && this.hud.test.speed) || (this.hud.dragRun && this.hud.dragRun.speed) || 0, rpm: 0, maxrpm: 7000, gear: '' };
    var maxrpm = t.maxrpm || 7000, red = 0.88;
    if (!this._speedoBuilt || this._speedoMax !== maxrpm) {
      var segs = '', marks = '', k1 = Math.ceil(maxrpm / 1000);
      for (var i = 0; i < SEGS; i++) segs += '<i class="' + ((i + 1) / SEGS > red ? 'red' : '') + '"></i>';
      for (var k = 0; k <= k1; k++) if (k * 1000 <= maxrpm) marks += '<span style="left:' + (k * 1000 / maxrpm * 100).toFixed(1) + '%">' + k + '</span>';
      box.innerHTML = '<div class="row"><div class="gear" data-el="gear">N</div><div class="spdbox"><div class="spd tz-num" data-el="spd">0</div><div class="unit">km/h</div></div></div>' +
        '<div class="revs" data-el="revs">' + segs + '</div><div class="marks">' + marks + '</div><div class="rpm tz-num"><b data-el="rpm">0</b> U/min ×1000</div>';
      this._speedoBuilt = true; this._speedoMax = maxrpm;
    }
    var frac = Math.max(0, Math.min(1, (t.rpm || 0) / maxrpm));
    var lit = Math.round(frac * SEGS), cells = box.querySelector('[data-el=revs]').children;
    for (var j = 0; j < cells.length; j++) cells[j].classList.toggle('on', j < lit);
    box.querySelector('[data-el=spd]').textContent = Math.round(t.speed || 0);
    box.querySelector('[data-el=rpm]').textContent = num((t.rpm || 0) / 1000, 1);
    var g = box.querySelector('[data-el=gear]');
    var gear = t.gear;
    if (typeof gear === 'number') gear = gear === 0 ? 'N' : gear < 0 ? 'R' : String(gear);
    g.textContent = gear == null ? '' : gear;
    box.classList.toggle('shift', frac > red);
  };

  // live delta to the best lap: record (lap progress -> lap time) samples, keep the best lap's samples as reference
  App.prototype.trackDelta = function (d) {
    if (!d || d.phase !== 'racing' || d.progress == null || d.lapTime == null) { if (d) d.delta = null; return; }
    var D = this._delta || (this._delta = { lap: d.lap, cur: [], ref: null, refTime: null });
    if (d.lap !== D.lap) {
      // previous lap just finished: keep its samples if it is the new best
      if (d.lastLap != null && d.bestLap != null && Math.abs(d.lastLap - d.bestLap) < 0.002 && D.cur.length > 10 && (D.refTime == null || d.bestLap < D.refTime)) {
        D.ref = D.cur; D.refTime = d.bestLap;
      }
      D.lap = d.lap; D.cur = [];
    }
    var last = D.cur[D.cur.length - 1];
    // ignore the wrap-around jitter near the line (progress still ~1 right after the lap counter switched)
    if (!(d.lapTime < 4 && d.progress > 0.5) && (!last || d.progress > last[0])) D.cur.push([d.progress, d.lapTime]);
    d.delta = null;
    if (D.ref && d.lapTime > 2 && !(d.lapTime < 4 && d.progress > 0.5)) {
      var ref = D.ref, lo = 0, hi = ref.length - 1;
      if (d.progress < ref[0][0] || d.progress > ref[hi][0]) return;
      while (hi - lo > 1) { var mid = (lo + hi) >> 1; if (ref[mid][0] <= d.progress) lo = mid; else hi = mid; }
      var a = ref[lo], b = ref[hi], f = b[0] > a[0] ? (d.progress - a[0]) / (b[0] - a[0]) : 0;
      d.delta = d.lapTime - (a[1] + (b[1] - a[1]) * f);
    }
  };

  function prepMap(d) {
    var pts = arr(d && d.pts);
    if (pts.length < 2) return null;
    var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    pts.forEach(function (p) { x0 = Math.min(x0, p[0]); x1 = Math.max(x1, p[0]); y0 = Math.min(y0, p[1]); y1 = Math.max(y1, p[1]); });
    var size = Math.max(x1 - x0, y1 - y0, 1), pad = 12, S = 176 - 2 * pad;
    var ox = pad + (S - (x1 - x0) / size * S) / 2, oy = pad + (S - (y1 - y0) / size * S) / 2;
    // world y points north, screen y points down
    var tf = function (x, y) { return [ox + (x - x0) / size * S, 176 - (oy + (y - y0) / size * S)]; };
    var path = pts.map(function (p, i) { var q = tf(p[0], p[1]); return (i ? 'L' : 'M') + q[0].toFixed(1) + ' ' + q[1].toFixed(1); }).join('') + (d.closed ? 'Z' : '');
    var st = tf(pts[0][0], pts[0][1]);
    return { path: path, tf: tf, start: st };
  }
  function minimapSvg(m, cars) {
    var dots = cars.slice().sort(function (a, b) { return a[2] - b[2]; }).map(function (c) {
      var q = m.tf(c[0], c[1]);
      return c[2] ? '<circle cx="' + q[0].toFixed(1) + '" cy="' + q[1].toFixed(1) + '" r="6.5" class="me"/>'
        : '<circle cx="' + q[0].toFixed(1) + '" cy="' + q[1].toFixed(1) + '" r="4.5" class="ai"/>';
    }).join('');
    return '<div class="tz-hbox tz-minimap"><svg viewBox="0 0 176 176"><path d="' + m.path + '" class="trk2"/><path d="' + m.path + '" class="trk"/>' +
      '<rect x="' + (m.start[0] - 4).toFixed(1) + '" y="' + (m.start[1] - 4).toFixed(1) + '" width="8" height="8" class="sf"/>' + dots + '</svg></div>';
  }

  function arcPath(cx, cy, r, a0, a1) {
    function pt(a) { var rad = (a - 90) * Math.PI / 180; return [cx + r * Math.cos(rad), cy + r * Math.sin(rad)]; }
    var p0 = pt(a0), p1 = pt(a1), large = (a1 - a0) > 180 ? 1 : 0;
    return 'M' + p0[0].toFixed(1) + ' ' + p0[1].toFixed(1) + ' A' + r + ' ' + r + ' 0 ' + large + ' 1 ' + p1[0].toFixed(1) + ' ' + p1[1].toFixed(1);
  }

  // ------------------------------------------------------------------ results
  App.prototype.showResults = function (r) {
    this.results = r;
    var html = '', d = r.data || {};
    var hardcore = this.state.meta && this.state.meta.hardcore;
    if (r.kind === 'quali') {
      html = '<h1>Startaufstellung</h1><div class="tz-panel" style="margin-top:14px"><table class="tz-table"><tr><th>Pos</th><th>Fahrer</th><th>Zeit</th></tr>' + r.list.map(function (x) {
        return '<tr class="' + (x.isPlayer ? 'me' : '') + '"><td>' + x.pos + '</td><td>' + esc(x.name) + '</td><td class="tz-num">' + time(x.time) + '</td></tr>';
      }).join('') + '</table></div><div class="actions" style="display:flex;justify-content:flex-end"><button class="tz-btn primary" data-act="resContinue">Weiter zum Rennen</button></div>';
      Audio_.sfx('ui_confirm');
    } else if (r.kind === 'race') {
      var list = arr(d.list), me = list.filter(function (x) { return x.isPlayer; })[0] || {};
      var rw = d.rewards || {};
      var lines = [];
      if (rw.money) lines.push('<div>Preisgeld<b>' + money(rw.money) + '</b></div>');
      arr(rw.bonus).forEach(function (b) { lines.push('<div>' + esc(b.name) + '<b>' + money(b.money) + '</b></div>'); });
      if (rw.prizeCar) lines.push('<div>Siegerauto<b>' + esc(rw.prizeCar) + '</b></div>');
      if (rw.ticket) lines.push('<div>Bonuslos<b>' + '★'.repeat(rw.ticket) + '</b></div>');
      if (rw.seriesComplete) lines.push('<div>Serie<b>abgeschlossen</b></div>');
      if (rw.championship) lines.push('<div>Meisterschaft<b>Platz ' + esc(rw.championship.position || '?') + '</b></div>');
      var isTime = list.some(function (x) { return x.time != null; });
      html = '<div style="display:flex;align-items:flex-end;gap:24px"><div class="pos">' + (me.dnf && !me.time && !me.score ? 'DNF' : (me.pos || '–')) + '</div><div><h1>' + (me.pos === 1 ? 'Sieg!' : me.pos <= 3 ? 'Podium!' : 'Rennende') + '</h1>' +
        '<div style="color:var(--dim)">' + (d.cleanRace ? 'Saubere Fahrt' : 'Kontakt registriert') + '</div></div></div>' +
        '<div class="tz-rewards">' + lines.join('') + '</div>' +
        '<div class="tz-panel"><table class="tz-table"><tr><th>Pos</th><th>Fahrer</th><th>Auto</th><th>' + (isTime ? 'Zeit' : 'Wertung') + '</th><th>Beste Runde</th></tr>' + list.map(function (x) {
          var val = x.time != null ? time(x.time) : (x.score != null ? Math.round(x.score) : (x.dnf ? 'DNF' : ''));
          return '<tr class="' + (x.isPlayer ? 'me' : '') + '"><td>' + x.pos + '</td><td>' + esc(x.isPlayer ? 'Du' : x.name) + '</td><td>' + esc(x.car || '') + '</td><td class="tz-num">' + val + '</td><td class="tz-num">' + (x.bestLap ? time(x.bestLap) : '') + '</td></tr>';
        }).join('') + '</table></div>' +
        '<div style="display:flex;gap:10px;justify-content:flex-end">' + (hardcore ? '' : '<button class="tz-btn" data-act="resRestart">Neustart</button>') + '<button class="tz-btn primary" data-act="resClose">Zurück zum Menü</button></div>';
      Audio_.music('results');
    } else if (r.kind === 'test') {
      var tg = d.targets || {};
      html = '<div style="text-align:center"><h1>' + esc(d.name || 'Test') + '</h1>' +
        (d.failed ? '<div class="pos" style="font-size:72px;background:linear-gradient(180deg,#fff,#ff5d6c);-webkit-background-clip:text">Nicht bestanden</div><p>' + esc(d.reason || '') + '</p>'
          : '<div class="medalBig">' + bigMedal(d.medal || 'none') + '</div><div class="pos" style="font-size:72px">' + time(d.value) + '</div><h2>' + (d.demo ? 'Vorführung' : (MEDAL_DE[d.medal] || 'Keine Medaille')) + (d.newBest ? ' · Neuer Bestwert' : '') + '</h2>') +
        '<div class="tz-targets" style="font-size:16px">' + ['gold', 'silver', 'bronze'].map(function (k) { return tg[k] ? '<span>' + medalOf(k) + time(tg[k]) + '</span>' : ''; }).join('') + '</div>' +
        '<div class="tz-rewards" style="justify-content:center">' + (d.reward ? '<div>Belohnung<b>' + money(d.reward) + '</b></div>' : '') + (d.licenseGranted ? '<div>Lizenz erhalten<b>' + esc(d.licenseGranted) + '</b></div>' : '') +
        (d.giftCar ? '<div>Geschenk<b>' + esc(d.giftCar) + '</b></div>' : '') + '</div>' +
        '<div style="display:flex;gap:10px;justify-content:center"><button class="tz-btn" data-act="testRetry">Nochmal</button><button class="tz-btn primary" data-act="testClose">Zum Lizenzzentrum</button></div></div>';
      Audio_.music('results');
    } else if (r.kind === 'dragRun') {
      var lanes = arr(d.lanes), a = lanes[0] || {}, b = lanes[1];
      function laneCol(l, who) {
        if (!l) return '';
        var sp = l.splits || {};
        return '<div class="tz-panel" style="flex:1"><h3 style="margin-top:0">' + who + (l.foul ? ' <span class="tz-tag warn">Rotlicht</span>' : '') + '</h3><table class="tz-table">' +
          '<tr><td>Reaktion</td><td class="tz-num">' + num(l.reaction, 3) + '</td></tr>' +
          [['sixty', '60 ft'], ['t330', '330 ft'], ['eighth', '1/8 Meile'], ['t1000', '1000 ft'], ['quarter', '1/4 Meile']].map(function (k) { return sp[k[0]] ? '<tr><td>' + k[1] + '</td><td class="tz-num">' + num(sp[k[0]], 3) + '</td></tr>' : ''; }).join('') +
          '<tr><td><b>ET</b></td><td class="tz-num"><b>' + num(l.et, 3) + '</b></td></tr><tr><td>Endgeschw.</td><td class="tz-num">' + num(l.trap, 1) + ' km/h</td></tr></table></div>';
      }
      html = '<h1>' + (d.playerWins == null ? 'Lauf beendet' : d.playerWins ? 'Lauf gewonnen!' : 'Lauf verloren') + '</h1><div style="display:flex;gap:14px;margin-top:14px">' + laneCol(a, 'Du') + laneCol(b, 'Gegner') + '</div>' +
        '<div style="color:var(--dim)">Nächster Lauf startet gleich …</div>';
      var self = this; clearTimeout(this._dragResT); this._dragResT = setTimeout(function () { if (self.results === r) self.closeResults(); }, 5000);
    }
    this.el.overlay.innerHTML = '<div class="tz-results"><div>' + html + '</div></div>';
  };
  App.prototype.closeResults = function () { this.results = null; this.el.overlay.innerHTML = ''; };
  App.prototype.showRaceMenu = function (kind) {
    var hardcore = this.state.meta && this.state.meta.hardcore;
    this.el.overlay.innerHTML = '<div class="tz-racemenu"><div><h2 style="margin:0 0 8px">Pause</h2><button class="tz-btn primary" data-act="menuResume">Weiterfahren</button>' +
      (hardcore ? '' : '<button class="tz-btn" data-act="menuRestart">Neustart</button>') + '<button class="tz-btn danger" data-act="menuAbort">Aufgeben</button></div></div>';
  };

  function bigMedal(m) {
    var c = { gold: ['#fff3b0', '#ffd34d', '#a07800'], silver: ['#ffffff', '#cfd8e6', '#7d8899'], bronze: ['#ffd2a8', '#d58a4a', '#6b3f14'], none: ['#555', '#333', '#222'] }[m] || ['#555', '#333', '#222'];
    return '<svg viewBox="0 0 160 160"><defs><radialGradient id="mg" cx=".35" cy=".3"><stop offset="0" stop-color="' + c[0] + '"/><stop offset=".55" stop-color="' + c[1] + '"/><stop offset="1" stop-color="' + c[2] + '"/></radialGradient></defs>' +
      '<circle cx="80" cy="80" r="70" fill="url(#mg)"/><circle cx="80" cy="80" r="56" fill="none" stroke="rgba(255,255,255,.5)" stroke-width="2"/>' +
      '<path d="M80 40l11 23 25 3-18 17 5 25-23-12-23 12 5-25-18-17 25-3z" fill="rgba(255,255,255,.55)"/></svg>';
  }

  // ------------------------------------------------------------------ export
  window.TurismoUI = {
    mount: function (root, bridge) { var app = new App(root, bridge); window.__turismoApp = app; return app; },
    audio: Audio_,
    _fmt: { time: time, money: money }
  };
})();

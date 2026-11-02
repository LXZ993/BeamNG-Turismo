/* Turismo Karriere - BeamNG UI app (AngularJS wrapper around turismo-ui.js).
 * The visible UI is mounted on document.body as a full-screen layer, so the
 * small app box in the layout only shows a status pill. */
angular.module('beamng.apps').directive('turismoHub', ['$injector', function ($injector) {
  // 0.40: StreamsManager is a global (vanilla apps use it without injection);
  // older builds provided it as an Angular service
  var SM = (typeof StreamsManager !== 'undefined' && StreamsManager) ||
    ($injector.has && $injector.has('StreamsManager') ? $injector.get('StreamsManager') : { add: function () {}, remove: function () {} });
  var BASE = '/ui/modules/apps/TurismoHub/';
  function loadOnce(id, tag, attrs) {
    return new Promise(function (resolve, reject) {
      if (document.getElementById(id)) { resolve(); return; }
      var el = document.createElement(tag);
      el.id = id;
      Object.keys(attrs).forEach(function (k) { el[k] = attrs[k]; });
      el.onload = resolve; el.onerror = reject;
      document.head.appendChild(el);
    });
  }
  function toLua(v) {
    if (typeof bngApi !== 'undefined' && bngApi.serializeToLua) return bngApi.serializeToLua(v);
    if (v === null || v === undefined) return 'nil';
    if (typeof v === 'boolean' || typeof v === 'number') return String(v);
    if (typeof v === 'string') return JSON.stringify(v);
    if (Array.isArray(v)) return '{' + v.map(toLua).join(',') + '}';
    return '{' + Object.keys(v).map(function (k) { return '[' + JSON.stringify(k) + ']=' + toLua(v[k]); }).join(',') + '}';
  }
  return {
    restrict: 'E',
    template: '<div class="tz-pill" style="font:600 12px Segoe UI,Arial;color:#cfe6ff;background:rgba(8,16,34,.8);border:1px solid rgba(54,209,255,.4);' +
      'border-radius:20px;padding:8px 12px;cursor:pointer;text-align:center;pointer-events:auto" ng-click="toggle()">TURISMO ▸ Menü</div>',
    link: function (scope) {
      var streams = ['electrics', 'engineInfo'];
      SM.add(streams);
      var reqId = 0, pending = {}, listeners = {}, streamCb = null, root = null;

      var bridge = {
        call: function (action, args) {
          var id = ++reqId;
          return new Promise(function (resolve, reject) {
            pending[id] = { resolve: resolve, reject: reject, t: setTimeout(function () { delete pending[id]; reject(new Error('Keine Antwort von Lua (' + action + ')')); }, 15000) };
            bngApi.engineLua('if extensions.turismo_core then extensions.turismo_core.uiCall(' + toLua(action) + ',' + toLua(args || {}) + ',' + id + ') end');
          });
        },
        on: function (name, cb) {
          (listeners[name] = listeners[name] || []).push(cb);
          if (listeners[name].length === 1) scope.$on(name, function (ev, data) { listeners[name].forEach(function (f) { try { f(data); } catch (e) { console.error(e); } }); });
        },
        stream: function (cb) { streamCb = cb; }
      };
      scope.$on('TurismoResult', function (ev, res) {
        var p = res && pending[res.reqId];
        if (!p) return;
        clearTimeout(p.t); delete pending[res.reqId];
        if (res.ok) p.resolve(res.data); else p.reject(new Error(res.error || 'Fehler'));
      });
      scope.$on('streamsUpdate', function (ev, s) { if (streamCb) streamCb(s); });
      scope.toggle = function () { bngApi.engineLua('if extensions.turismo_core then extensions.turismo_core.toggleHub() end'); };

      Promise.all([
        loadOnce('turismo-css', 'link', { rel: 'stylesheet', href: BASE + 'app.css' }),
        loadOnce('turismo-js', 'script', { src: BASE + 'turismo-ui.js' })
      ]).then(function () {
        root = document.createElement('div');
        root.id = 'turismo-root';
        document.body.appendChild(root);
        window.TurismoUI.mount(root, bridge);
      }).catch(function (e) { console.error('Turismo UI konnte nicht geladen werden', e); });

      scope.$on('$destroy', function () {
        SM.remove(streams);
        if (root && root.parentNode) root.parentNode.removeChild(root);
      });
    }
  };
}]);

#!/usr/bin/env python3
"""Puts the licence centre / driving school screens into turismo-ui.js and
app.css. Written as a patch because several threads edit these two files in
parallel (repo branch and Alex's PC copy differ): it replaces only the licence
and driving-school screens, adds the briefing window and the test HUD lines.

  python3 tools/patches/ui_licenses.py <path to TurismoHub folder>
Running it twice is safe (it checks for its own marker).
"""
import os
import re
import sys

MARK = '// [turismo-lizenzen v2]'

JS_SCREENS = r'''  // ------------------------------------------------------------ Lizenzzentrum & Fahrschule
  // [turismo-lizenzen v2]
  // Aufbau wie in GT: oben die Lizenzen, darunter die gewählte Lizenz mit
  // Fortschritt und ihre Prüfungen als Kacheln mit Vorschaubild
  // (previews/tests/<id>.jpg, fehlt es, steht eine farbige Kachel mit der
  // Prüfungsnummer da). Ein Klick öffnet das Briefing.
  function lcPreview(t, color, code) {
    return '<div class="tz-lcpv" style="--lc:' + esc(color || '#c8102e') + '"><div class="code">' + esc(code) + '</div>' +
      '<img src="' + BASE + 'previews/tests/' + esc(t.id) + '.jpg" alt="" onerror="this.remove()"></div>';
  }
  function lcFmt(t) { return t.scoring === 'score' ? function (v) { return v == null ? '--' : Math.round(v); } : time; }

  App.prototype.scr_licenses = function (d) {
    var lics = arr(d.lics);
    var tab = this.ui.tab.lic || (lics.filter(function (l) { return l.available && !l.owned; })[0] || lics[0] || {}).id;
    var lic = lics.filter(function (l) { return l.id === tab; })[0] || lics[0];
    if (!lic) return this.head('Lizenzzentrum');
    var tests = arr(lic.tests);
    return this.head('Lizenzzentrum', 'Bestehe jede Prüfung mindestens mit Bronze, dann gehört dir die Lizenz. Alles Gold bringt ein Geschenk.') +
      '<div class="tz-lcrow">' + lics.map(function (l) {
        return '<div class="tz-lcbadge' + (l.id === lic.id ? ' on' : '') + (l.available ? '' : ' locked') + '" style="--lc:' + esc(l.color) + '" data-act="tab" data-arg="lic" data-arg2="' + l.id + '">' +
          '<b>' + esc(l.short || l.id) + '</b><span>' + (l.owned ? 'Erhalten' : l.available ? l.done + ' / ' + l.total : 'Gesperrt') + '</span></div>';
      }).join('') + '</div>' +
      '<div class="tz-lchead" style="--lc:' + esc(lic.color) + '"><div class="plate"><b>' + esc(lic.short || '') + '</b></div>' +
      '<div class="txt"><h2>' + esc(lic.name) + '</h2><p>' + esc(lic.desc || '') + '</p>' + (lic.available ? '' : '<p class="lock">' + esc(lic.reason || '') + '</p>') + '</div>' +
      '<div class="prog"><div><label>Bestanden</label><span>' + lic.done + ' / ' + lic.total + '</span></div><div><label>Gold</label><span>' + lic.gold + '</span></div>' +
      (lic.owned ? '<div class="own">Lizenz erhalten</div>' : '') + '</div></div>' +
      '<div class="tz-lcgrid">' + tests.map(function (t, i) {
        var code = (lic.short || lic.id) + '-' + (i + 1);
        return '<div class="tz-lctest' + (t.medal && t.medal !== 'none' ? ' done' : '') + (t.missing ? ' missing' : '') + '" data-act="testInfo" data-arg="lic" data-arg2="' + t.id + '">' +
          lcPreview(t, lic.color, code) + '<div class="body"><div class="nr">' + esc(code) + '</div><div class="nm">' + esc(t.name) + '</div>' +
          '<div class="pl">' + esc(t.place || '') + '</div></div><div class="md">' + medalOf(t.medal) + '</div></div>';
      }).join('') + '</div>';
  };

  App.prototype.scr_trainings = function (d) {
    var list = arr(d.list), groups = [], idx = {};
    list.forEach(function (t) {
      var k = t.category || 'Fahrschule';
      if (!idx[k]) { idx[k] = { name: k, place: t.place, tests: [] }; groups.push(idx[k]); }
      idx[k].tests.push(t);
    });
    return this.head('Fahrschule · Streckenkunde', 'Lerne jede Strecke Sektor für Sektor kennen, dann die ganze Runde. Jede Medaille wird einmal bezahlt.') +
      groups.map(function (g) {
        var gold = g.tests.filter(function (t) { return t.medal === 'gold'; }).length;
        return '<div class="tz-schead"><h3>' + esc(g.name) + '</h3><span>' + esc(g.place || '') + ' · Gold ' + gold + ' / ' + g.tests.length + '</span></div>' +
          '<div class="tz-lcgrid sc">' + g.tests.map(function (t) {
            var code = /lap$/.test(t.id) ? 'RUNDE' : 'S' + String(t.id).split('-').pop();
            return '<div class="tz-lctest' + (t.medal && t.medal !== 'none' ? ' done' : '') + (t.missing ? ' missing' : '') + '" data-act="testInfo" data-arg="school" data-arg2="' + t.id + '">' +
              lcPreview(t, '#15181e', code) + '<div class="body"><div class="nm">' + esc(t.name) + '</div><div class="pl">' + esc(t.desc || '') + '</div></div>' +
              '<div class="md">' + medalOf(t.medal) + '</div></div>';
          }).join('') + '</div>';
      }).join('');
  };

  // Briefing (helles Fenster wie beim Händler): Ziel, Tipp, Ort, Auto, Medaillenzeiten
  App.prototype.showTest = function (kind, id) {
    var t = null, lic = null;
    if (kind === 'lic') arr(this.data.lics).forEach(function (l) { arr(l.tests).forEach(function (x, i) { if (x.id === id) { t = x; lic = l; t._nr = i + 1; } }); });
    else t = arr(this.data.list).filter(function (x) { return x.id === id; })[0];
    if (!t) return;
    var fmt = lcFmt(t), tg = t.targets || {};
    var can = kind !== 'lic' || (lic && lic.available);
    var code = lic ? (lic.short || lic.id) + '-' + t._nr : (/lap$/.test(t.id) ? 'RUNDE' : 'S' + String(t.id).split('-').pop());
    function row(l, v) { return v == null || v === '' ? '' : '<tr><th>' + l + '</th><td>' + v + '</td></tr>'; }
    var src = tg.source === 'demo' ? 'aus der Vorführung' : tg.source === 'route' ? 'auf der echten Strecke berechnet' : 'vorläufig, werden beim ersten Start genauer';
    this.modalShow('<div class="tz-cdetail tz-tbrief">' + lcPreview(t, lic ? lic.color : '#15181e', code) +
      '<div class="info"><div class="br">' + esc(lic ? code : (t.category || 'Fahrschule')) + (t.place ? ' · ' + esc(t.place) : '') + '</div><h2>' + esc(t.name) + '</h2>' +
      '<p class="goal">' + esc(t.goal || t.desc || '') + '</p>' + (t.tip ? '<p class="tip"><b>Tipp:</b> ' + esc(t.tip) + '</p>' : '') +
      '<table>' + row('Auto', esc(t.ownCar ? 'Dein aktives Auto (Schäden bleiben)' : (t.carName || '–'))) + row('Start', t.rolling ? 'Fliegender Start' : 'Stehender Start') +
      row('Aufgabe', esc(t.info || '')) + row('Bestwert', fmt(t.best)) + row('Versuche', t.attempts || 0) + '</table>' +
      '<div class="tz-tmedals">' + ['gold', 'silver', 'bronze'].map(function (m) {
        return '<div class="' + (t.medal === m ? 'got' : '') + '">' + medalOf(m) + '<b class="tz-num">' + fmt(tg[m]) + '</b><span>' + (t.rewards && t.rewards[m] ? money(t.rewards[m]) : '') + '</span></div>';
      }).join('') + '</div><div class="src">Zielzeiten ' + src + '</div>' +
      (t.missing ? '<div class="why">Diese Strecke fehlt auf deiner BeamNG-Installation.</div>' : !can ? '<div class="why">' + esc(lic.reason || 'Gesperrt') + '</div>' : '') +
      '<div class="actions"><button class="tz-btn" data-act="closeModal">Zurück</button>' +
      '<button class="tz-btn" ' + (can && !t.missing ? '' : 'disabled') + ' data-act="startTest" data-arg="' + t.id + '" data-arg2="demo">Vorführung</button>' +
      '<button class="tz-btn primary" ' + (can && !t.missing ? '' : 'disabled') + ' data-act="startTest" data-arg="' + t.id + '">Prüfung starten</button></div></div></div>', 'light');
  };

'''

CSS = r'''
/* ---------------------------------------------------------------- [turismo-lizenzen v2] Lizenzzentrum und Fahrschule
   GT-Aufbau: Lizenzleiste, Lizenzkopf mit Plakette, Prüfungskacheln, helles Briefing */
.tz-lcrow { display: flex; gap: 8px; margin-bottom: 14px; flex-wrap: wrap; }
.tz-lcbadge { min-width: 86px; padding: 8px 14px 7px; border-radius: 3px; cursor: pointer; background: #fff; border: 1px solid #d9dce2; color: #15181e;
  border-top: 4px solid var(--lc); display: flex; flex-direction: column; align-items: center; gap: 1px; transition: box-shadow .15s; }
.tz-lcbadge b { font-size: 22px; line-height: 1.1; color: var(--lc); font-weight: 900; }
.tz-lcbadge span { font-size: 11px; color: #6b7280; letter-spacing: .04em; }
.tz-lcbadge:hover { box-shadow: 0 4px 14px rgba(0,0,0,.18); }
.tz-lcbadge.on { box-shadow: inset 0 0 0 2px #15181e; }
.tz-lcbadge.locked { opacity: .5; }
.tz-lchead { display: flex; align-items: center; gap: 20px; padding: 16px 20px; margin-bottom: 16px; border-radius: 4px; background: #fff; color: #15181e;
  border: 1px solid #d9dce2; border-left: 6px solid var(--lc); box-shadow: 0 4px 16px rgba(0,0,0,.12); }
.tz-lchead .plate { width: 72px; height: 72px; border-radius: 6px; display: grid; place-items: center; background: var(--lc); box-shadow: 0 4px 12px rgba(0,0,0,.25); }
.tz-lchead .plate b { font-size: 40px; font-weight: 900; color: #fff; }
.tz-lchead .txt { flex: 1; }
.tz-lchead h2 { margin: 0 0 4px; font-size: 24px; color: #15181e; }
.tz-lchead p { margin: 0; color: #6b7280; }
.tz-lchead .lock { color: #c8102e; margin-top: 6px; }
.tz-lchead .prog { display: flex; gap: 18px; align-items: center; }
.tz-lchead .prog label { display: block; font-size: 11px; color: #6b7280; text-transform: uppercase; letter-spacing: .08em; }
.tz-lchead .prog span { font-size: 22px; font-weight: 800; font-variant-numeric: tabular-nums; }
.tz-lchead .own { padding: 6px 12px; border-radius: 3px; background: var(--lc); color: #fff; font-weight: 800; }
.tz-lcgrid { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 12px; margin-bottom: 18px; }
.tz-lcgrid.sc { grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); }
.tz-lctest { position: relative; background: #fff; color: #15181e; border: 1px solid #d9dce2; border-radius: 4px; overflow: hidden; cursor: pointer;
  box-shadow: 0 4px 14px rgba(0,0,0,.12); transition: transform .15s, box-shadow .15s; animation: tz-rise .3s ease-out both; }
.tz-lctest:hover { transform: translateY(-3px); box-shadow: 0 0 0 2px #15181e, 0 10px 26px rgba(0,0,0,.25); }
.tz-lcpv { position: relative; aspect-ratio: 16 / 9; overflow: hidden; display: grid; place-items: center; background: var(--lc);
  background-image: linear-gradient(135deg, rgba(255,255,255,.28), rgba(0,0,0,.28)); }
.tz-lcpv .code { font-size: 30px; font-weight: 900; color: #fff; letter-spacing: .04em; text-shadow: 0 2px 8px rgba(0,0,0,.35); }
.tz-lcpv img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.tz-lctest .body { padding: 8px 11px 10px; }
.tz-lctest .nr { font-size: 11px; font-weight: 800; color: #6b7280; letter-spacing: .08em; }
.tz-lctest .nm { font-size: 14px; font-weight: 700; margin: 1px 0 3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.tz-lctest .pl { font-size: 11.5px; color: #6b7280; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.tz-lctest .md { position: absolute; top: 8px; right: 8px; transform: scale(1.3); }
.tz-lctest .md .tz-medal.none { opacity: 0; }
.tz-lctest.missing { opacity: .45; filter: grayscale(.8); }
.tz-schead { display: flex; align-items: baseline; gap: 12px; margin: 4px 0 8px; }
.tz-schead h3 { margin: 0; font-size: 18px; }
.tz-schead span { color: var(--dim); font-size: 13px; }
.tz-tbrief .tz-lcpv { aspect-ratio: auto; min-height: 360px; }
.tz-tbrief .tz-lcpv .code { font-size: 64px; }
.tz-tbrief .goal { font-size: 15px; margin: 10px 0 6px; }
.tz-tbrief .tip { font-size: 13px; color: #374151; margin: 0 0 12px; padding: 8px 10px; background: #f3f4f6; border-left: 3px solid #c8102e; }
.tz-tmedals { display: flex; gap: 8px; margin-top: 14px; }
.tz-tmedals > div { flex: 1; padding: 8px 6px; border-radius: 3px; background: #f3f4f6; display: flex; flex-direction: column; align-items: center; gap: 3px; }
.tz-tmedals > div.got { box-shadow: inset 0 0 0 2px #15181e; }
.tz-tmedals b { font-size: 16px; }
.tz-tmedals span { font-size: 11px; color: #6b7280; }
.tz-tbrief .src { font-size: 11px; color: #6b7280; margin-top: 6px; }
.tz-tbrief .why { font-size: 13px; color: #c8102e; margin-top: 10px; }
.tz-arrow { display: inline-block; color: #ff8c1a; font-style: normal; transition: transform .1s linear; }
.tz-offtrack { position: absolute; top: 34%; left: 50%; transform: translateX(-50%); padding: 10px 22px; font-size: 22px; font-weight: 800; color: #fff;
  background: rgba(200,16,46,.88); border-radius: 3px; animation: tz-fade .2s; }
'''


def patch_js(s):
    if MARK in s:
        s = re.sub(r'  // -{60} Lizenzzentrum & Fahrschule\n  // \[turismo-lizenzen v2\].*?\n(?=  // preview image with placeholder|  var HALL_HUE)', lambda m: JS_SCREENS, s, flags=re.S)
    else:
        a = s.index('  App.prototype.scr_licenses = function (d) {')
        ends = [i for i in (s.find('  // preview image with placeholder', a), s.find('  var HALL_HUE', a)) if i > 0]
        b = min(ends)
        s = s[:a] + JS_SCREENS + s[b:]
    old = "      case 'startTest': this.call('startTest', { testId: arg, demo: arg2 === 'demo' }); break;"
    if old in s:
        s = s.replace(old, "      case 'startTest': this.closeModal(); this.call('startTest', { testId: arg, demo: arg2 === 'demo' }); break;\n      case 'testInfo': this.showTest(arg, arg2); break;")
    # test HUD: arrow to the next gate, off-track warning, rolling start
    old = re.search(r"      if \(t\.nextLabel\) html \+= '<div class=\"tz-hbox tz-nextgate\">.*?</div></div>';\n", s, flags=re.S)
    if old and 'tz-offtrack' not in s:
        s = s.replace(old.group(0), '''      if (t.nextLabel) html += '<div class="tz-hbox tz-nextgate"><div class="s">' + (t.runup ? 'Anlauf · die Zeit startet am ersten Tor' : 'Nächstes Tor · folge den orangen Pfeilen') + '</div><div class="v">' +
        (t.nextAngle != null ? '<i class="tz-arrow" style="transform:rotate(' + Math.round(t.nextAngle) + 'deg)">▲</i> ' : '') + esc(t.nextLabel) +
        (t.nextDist != null ? ' <small class="tz-num">' + Math.round(t.nextDist) + ' m</small>' : '') + '</div></div>';
      if (t.offTrack) html += '<div class="tz-hbox tz-offtrack">Zurück auf die Strecke!</div>';
''')
    old = re.search(r"        '<p>' \+ esc\(ti\.desc \|\| ''\) \+ '</p><p class=\"hint\">.*?</p></div>';\n", s, flags=re.S)
    if old:
        s = s.replace(old.group(0), '''        (ti.place ? '<div class="s">' + esc(ti.place) + '</div>' : '') + '<p>' + esc(ti.desc || '') + '</p>' + (ti.tip ? '<p class="hint"><b>Tipp:</b> ' + esc(ti.tip) + '</p>' : '') +
        '<p class="hint">Fahre durch die <b>orangen Tore</b>. Die Pfeile auf der Straße zeigen den Weg zum nächsten Tor, grün = geschafft.' + (ti.rolling ? ' Fliegender Start: die Zeit läuft ab dem ersten Tor.' : '') + '</p></div>';
''')
    s = s.replace('<button class="tz-btn primary" data-act="testClose">Zum Lizenzzentrum</button>', '<button class="tz-btn primary" data-act="testClose">Zurück zum Menü</button>')
    return s


def patch_css(s):
    if '[turismo-lizenzen v2]' in s:
        s = s[:s.index('\n/* ---------------------------------------------------------------- [turismo-lizenzen v2]')]
    return s.rstrip('\n') + '\n' + CSS


def main():
    d = sys.argv[1]
    js = os.path.join(d, 'turismo-ui.js')
    css = os.path.join(d, 'app.css')
    s = open(js, encoding='utf-8').read()
    open(js, 'w', encoding='utf-8', newline='\n').write(patch_js(s))
    s = open(css, encoding='utf-8').read()
    open(css, 'w', encoding='utf-8', newline='\n').write(patch_css(s))
    print('patched', d)


if __name__ == '__main__':
    main()

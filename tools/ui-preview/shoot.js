// Renders the UI preview in Chromium and saves screenshots: node tools/ui-preview/shoot.js <outdir>
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const out = process.argv[2] || '.';
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.route('file:///ui/**', r => r.fulfill({ path: path.resolve(__dirname, '../../mod' + new URL(r.request().url()).pathname) }));
  await page.addInitScript(t => { window.TURISMO_CHANGELOG = t; }, require('fs').readFileSync(path.resolve(__dirname, '../../CHANGELOG.md'), 'utf8'));
  await page.goto('file://' + path.resolve(__dirname, 'preview.html'));
  await page.waitForTimeout(300);
  const shots = [
    ['01_title', 'preview.title()'],
    ['02_world', 'window.TURISMO_NIGHT = false; preview.hub()'],
    ['02b_world_night', 'window.TURISMO_NIGHT = true; preview.hub(); setTimeout(function () { window.__turismoApp.mapSelect("events"); }, 50)'],
    ['02c_world_locked', 'window.TURISMO_NIGHT = false; preview.hub(); setTimeout(function () { window.__turismoApp.mapSelect("legends"); }, 50)'],
    ['03_cafe', 'preview.hub("cafe")'],
    ['04_licenses', 'preview.hub("licenses")'],
    ['05_events', 'preview.hub("events")'],
    ['06_series', 'preview.hub("series", {arg2: "einsteiger"})'],
    ['07_used', 'preview.hub("used")'],
    ['07b_used_detail', 'preview.hub("used"); setTimeout(function () { var a = window.__turismoApp; a.showOffer("used", a.data.offers[0].id); }, 200)'],
    ['08_garage', 'preview.hub("garage")'],
    ['09_workshop', 'preview.hub("workshop", {carId: window.TURISMO_MOCK.garage[0].id})'],
    ['10_dealers', 'preview.hub("dealers")'],
    ['11_settings', 'preview.hub("settings")'],
    ['12_race_hud', 'preview.race()'],
    ['13_intro', 'preview.intro()'],
    ['14_countdown', 'preview.countdown()'],
    ['15_results', 'preview.results()'],
    ['16_test_hud', 'preview.test()'],
    ['17_test_result', 'preview.testResult()'],
    ['18_drag', 'preview.drag()'],
    ['19_drift', 'preview.drift()'],
    ['20_newprofile', 'preview.hub("newProfile", {arg2: 2})'],
    ['21_car', 'preview.hub("car", {carId: window.TURISMO_MOCK.garage[0].id})'],
    ['22_world2', 'preview.hub("world2")'],
    ['24_test_brief', 'preview.testBrief()'],
    ['25_changelog', 'preview.hub("changelog")'],
    ['26_bugreport', 'preview.hub("settings"); window.__turismoApp.showBugReport()'],
    ['27_loading', 'preview.emit("TurismoLoading", {visible: true, text: "Karriere wird geladen …"})'],
    ['23_guide', 'preview.hub(); window.__turismoApp.showGuide()'],
  ];
  for (const [name, js] of shots) {
    await page.evaluate(`document.querySelector("[data-el=overlay]").innerHTML=""; preview.emit("TurismoRacePhase",{phase:"idle"}); preview.emit("TurismoDragPhase",{phase:"idle"}); window.__turismoApp.tree=null; window.__turismoApp._guideShown=true; window.__turismoApp.closeModal(); window.__turismoApp.showLoading(false);`);
    await page.evaluate(js);
    await page.waitForTimeout(name.startsWith('02') ? 1500 : 450);
    await page.screenshot({ path: path.join(out, name + '.png') });
  }
  console.log(errors.length ? 'ERRORS:\n' + errors.join('\n') : 'no page errors');
  await browser.close();
})();

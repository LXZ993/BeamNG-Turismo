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
  await page.goto('file://' + path.resolve(__dirname, 'preview.html'));
  await page.waitForTimeout(300);
  const shots = [
    ['01_title', 'preview.title()'],
    ['02_world', 'preview.hub()'],
    ['03_cafe', 'preview.hub("cafe")'],
    ['04_licenses', 'preview.hub("licenses")'],
    ['05_events', 'preview.hub("events")'],
    ['06_series', 'preview.hub("series", {arg2: "einsteiger"})'],
    ['07_used', 'preview.hub("used")'],
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
    ['23_guide', 'preview.hub(); window.__turismoApp.showGuide()'],
  ];
  for (const [name, js] of shots) {
    await page.evaluate(`document.querySelector("[data-el=overlay]").innerHTML=""; preview.emit("TurismoRacePhase",{phase:"idle"}); preview.emit("TurismoDragPhase",{phase:"idle"}); window.__turismoApp.tree=null; window.__turismoApp._guideShown=true; window.__turismoApp.closeModal();`);
    await page.evaluate(js);
    await page.waitForTimeout(450);
    await page.screenshot({ path: path.join(out, name + '.png') });
  }
  console.log(errors.length ? 'ERRORS:\n' + errors.join('\n') : 'no page errors');
  await browser.close();
})();

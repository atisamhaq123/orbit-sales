import {chromium} from 'playwright-core';
import assert from 'node:assert/strict';
import {demoData} from '../src/lib/demo.ts';

const browser = await chromium.launch({executablePath: process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true});
const base = process.env.TEST_URL || 'http://localhost:3100';
try {
  const page = await browser.newPage({viewport: {width: 1440, height: 1000}});
  let stateRequests = 0;
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.routeWebSocket('**/realtime/v1/**', socket => socket.close());
  await page.route('**/api/state*', async route => {
    stateRequests++;
    const data = demoData();
    data.workspaces.push({...data.workspace, id: 'second-workspace', name: 'Second workspace'});
    if (new URL(route.request().url()).searchParams.get('workspace') === 'second-workspace') data.workspace = data.workspaces[1];
    await route.fulfill({json: data});
  });
  await page.goto(`${base}/app`);
  await page.locator('.app-main').waitFor();
  const initialRequests = stateRequests;
  await page.locator('.sidebar').evaluate(el => { el.dataset.navigationTest = 'retained'; });
  await page.evaluate(() => {
    window.navigationLoadingFlashes = 0;
    new MutationObserver(() => {
      if (document.querySelector('.loading-shell')) window.navigationLoadingFlashes++;
    }).observe(document.body, {childList: true, subtree: true});
  });
  for (const label of ['Leads', 'Pipeline', 'Follow-ups', 'Knowledge base', 'AI assistant', 'Notifications', 'Overview']) {
    await page.getByRole('navigation', {name: 'Main navigation'}).getByRole('link', {name: new RegExp('^' + label + '(?:\\s|$)')}).click();
    await page.waitForFunction(label => document.querySelector('.breadcrumb strong')?.textContent === label, label);
    assert.equal(await page.locator('.sidebar').getAttribute('data-navigation-test'), 'retained', `${label}: sidebar stays mounted`);
    assert.equal(stateRequests, initialRequests, `${label}: no full data reload`);
  }
  await page.goBack();
  await page.waitForFunction(() => document.querySelector('.breadcrumb strong')?.textContent === 'Notifications');
  assert.equal(await page.evaluate(() => window.navigationLoadingFlashes), 0, 'No loading skeleton during section navigation');
  await page.getByLabel('Switch workspace').selectOption('second-workspace');
  await page.waitForFunction(() => document.querySelector('.workspace-switch strong')?.textContent === 'Second workspace');
  assert.ok(stateRequests > initialRequests, 'Changing workspace still fetches its data');
  await page.goto(`${base}/app?demo=1`);
  await page.locator('.app-main').waitFor();
  const beforeDemo = stateRequests;
  await page.getByRole('navigation', {name: 'Main navigation'}).getByRole('link', {name: 'Leads', exact: true}).click();
  await page.waitForFunction(() => document.querySelector('.breadcrumb strong')?.textContent === 'Leads');
  assert.equal(stateRequests, beforeDemo, 'Demo navigation remains isolated');
  await page.unroute('**/api/state*');
  await page.route('**/api/state*', route => route.fulfill({status: 401, json: {error: 'Log in with a verified email address to continue.'}}));
  await page.goto(`${base}/app/leads`);
  await page.getByRole('heading', {name: 'Good things ahead.'}).waitFor();
  const loginHref = await page.getByRole('link', {name: 'Log in', exact: true}).getAttribute('href');
  assert.equal(new URL(loginHref, base).searchParams.get('next'), '/app/leads', 'Logged-out users retain their destination');
  assert.deepEqual(errors, []);
  console.log('Navigation checks passed: seven live sections, persistent sidebar, no skeleton flashes or repeated state fetches, browser back, workspace switch refresh, isolated demo navigation, logged-out gate with preserved destination. Live workspace data was mocked.');
} finally { await browser.close(); }

const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');
const html = fs.readFileSync('public/index.html', 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
const dart = fs.readFileSync('lib/pages/05_webview/webview_page.dart', 'utf8');
const notification = dart.match(/runJavaScriptReturningResult\('''([\s\S]*?)'''\)/)[1];
const origin = 'https://corp.ex-ture.com';
function page(app = true) {
  const dataLayer = [{event: 'existing'}], inserted = [], messages = [];
  const window = { dataLayer, location: {origin, search: '?installation_id=stable&auth_uid=user'},
    ...(app ? {AppAnalytics: {postMessage: m => messages.push(m)}} : {}) };
  const context = vm.createContext({window, URLSearchParams, document: {
    getElementsByTagName: () => [{parentNode: {insertBefore: n => inserted.push(n)}}],
    createElement: () => ({}),
  }});
  scripts.forEach(s => vm.runInContext(s, context));
  const notify = (id = 'sdk-id') => vm.runInContext(notification
    .replaceAll('$origins', JSON.stringify([origin, 'https://ex-ture.com']))
    .replaceAll('$encodedId', JSON.stringify(id)), context);
  return {window, dataLayer, inserted, messages, notify};
}
test('identity precedes GTM, preserves dataLayer and legacy IDs, once per document', () => {
  const p = page();
  assert.deepEqual(p.messages, ['app_identity_request']);
  assert.equal(p.inserted.length, 0);
  assert.equal(p.notify(), true);
  assert.equal(p.notify(), false);
  assert.equal(p.window.dataLayer, p.dataLayer);
  assert.equal(p.dataLayer.length, 3);
  assert.equal(p.dataLayer[1].event, 'app_identity_ready');
  assert.equal(p.dataLayer[1].app_webview, true);
  assert.equal(p.dataLayer[1].app_instance_id, 'sdk-id');
  assert.equal(p.dataLayer[1].installation_id, 'stable');
  assert.equal(p.dataLayer[1].auth_uid, 'user');
  assert.equal(p.dataLayer[2].event, 'gtm.js');
  assert.equal(p.inserted.length, 1);
  assert.equal(page().notify(), true);
});
test('invalid IDs keep WebView GTM gated; page still renders', () => {
  const p = page();
  for (const id of [null, '', '  ']) assert.equal(p.notify(id), false);
  assert.equal(p.inserted.length, 0);
  assert.equal(p.dataLayer.length, 1);
});
test('external origin receives no identity', () => {
  const p = page(); p.window.location.origin = 'https://evil.test';
  assert.equal(p.notify(), false); assert.equal(p.dataLayer.length, 1);
});
test('browser starts GTM without app identity', () => {
  const p = page(false);
  assert.equal(p.inserted.length, 1);
  assert.equal(p.dataLayer[1].app_webview, false);
  assert.equal('app_instance_id' in p.dataLayer[1], false);
});

const assert = require('node:assert/strict');
const { test } = require('node:test');
require('coffee-script/register');
const WebRequestMonitor = require('../src/module/web_request_monitor.coffee');

function fillCache(monitor, status) {
  const info = monitor.tabInfo[7] = monitor._newTabInfo();
  for (let i = 0; i < 1001; i++) {
    info.requests[String(i)] = { timeStamp: Date.now() };
    info.requestStatus[String(i)] = status;
  }
  info.requestCount = 1001;
  return info;
}

function request(id) {
  return { tabId: 7, requestId: id, type: 'xmlhttprequest',
    url: 'https://example.com/', timeStamp: Date.now() };
}

test('overflow resets the requesting tab and monitoring can continue', () => {
  const monitor = new WebRequestMonitor();
  fillCache(monitor, 'start');
  const otherTab = monitor.tabInfo[8] = monitor._newTabInfo();
  assert.doesNotThrow(() => monitor.setTabRequestInfo('start', request('overflow')));
  assert.equal(monitor.tabInfo[7].requestCount, 0);
  assert.equal(monitor.tabInfo[8], otherTab);
  monitor.setTabRequestInfo('start', request('next'));
  assert.equal(monitor.tabInfo[7].requestCount, 1);
  assert.equal(monitor.tabInfo[7].ongoingCount, 1);
  monitor.setTabRequestInfo('done', request('next'));
  assert.equal(monitor.tabInfo[7].ongoingCount, 0);
  assert.equal(monitor.tabInfo[7].doneCount, 1);
});

test('completed requests are pruned without resetting the tab', () => {
  const monitor = new WebRequestMonitor();
  const info = fillCache(monitor, 'done');
  monitor.setTabRequestInfo('start', request('next'));
  assert.equal(monitor.tabInfo[7], info);
  assert.deepEqual(Object.keys(info.requests), ['next']);
  assert.equal(info.requestCount, 1);
});

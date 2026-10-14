// End-to-end test of MTAT against the digital twin (#47).
// Usage: node tests/twin-e2e.js <scenario.json> [baseUrl]
// Drives the same HTTP API the UI uses (connect -> ranges -> analyze) and checks the scenario's
// "expect" block. Requests carry no Origin header (non-browser client), as allowed by the guard.
const fs = require('fs');
const assert = require('assert');

const scenario = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const base = process.argv[3] || 'http://127.0.0.1:8601';
const exp = scenario.expect || {};

async function post(path, body) {
  const r = await fetch(base + path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  assert.strictEqual(r.status, 200, `${path} -> HTTP ${r.status}`);
  return r.json();
}
const near = (a, b, msg) => assert(Math.abs(Number(a) - Number(b)) <= 0.05 + Math.abs(Number(b)) * 0.001, `${msg}: got ${a}, expected ${b}`);
const list = (x) => (x == null ? [] : Array.isArray(x) ? x : [x]);

(async () => {
  const targets = scenario.vcenters.map((v) => ({ server: v.name, user: 'twin-ro', pass: 'not-a-secret' }));
  const connect = await post('/api/connect', { targets });
  assert(!connect.error, `connect error: ${connect.error}`);
  const clusters = list(connect.clusters).map((c) => c.Value).sort();
  if (exp.connect) {
    assert.deepStrictEqual(clusters, [...exp.connect.clusters].sort(), 'connect clusters');
    const failed = list(connect.failedTargets).map((t) => t.server).sort();
    assert.deepStrictEqual(failed, [...(exp.connect.failedTargets || [])].sort(), 'connect failedTargets');
  }
  console.log(`[${scenario.name}] connect ok: ${clusters.length} cluster(s)`);

  for (const [cluster, ranges] of Object.entries(exp.ranges || {})) {
    const r = await post('/api/get-cluster-ranges', { cluster });
    assert.deepStrictEqual([...list(r.ranges)].sort(), [...ranges].sort(), `ranges for ${cluster}`);
    console.log(`[${scenario.name}] ranges ok: ${cluster} -> ${list(r.ranges).join(', ')}`);
  }

  for (const a of exp.analyze || []) {
    const res = await post('/api/analyze', { cluster: a.cluster, range: a.range });
    assert(!res.error, `analyze error: ${res.error}`);
    const tag = `${a.cluster} / ${a.range}`;
    if (a.dram !== undefined) near(res.dram, a.dram, `${tag} dram`);
    if (a.active !== undefined) near(res.active, a.active, `${tag} active`);
    if (a.vmCount !== undefined) assert.strictEqual(list(res.vms).length, a.vmCount, `${tag} vm count`);
    if (a.failedVms !== undefined) assert.strictEqual(list(res.failedVms).length, a.failedVms, `${tag} failedVms (${list(res.failedVms).join(', ')})`);
    const hosts = Object.fromEntries(list(res.hosts).map((h) => [h.HostName, h]));
    for (const [name, fields] of Object.entries(a.hosts || {})) {
      assert(hosts[name], `${tag}: host ${name} missing`);
      for (const [k, v] of Object.entries(fields)) assert.strictEqual(hosts[name][k], v, `${tag}: ${name}.${k}`);
    }
    for (const [name, fields] of Object.entries(a.hostsNumeric || {})) {
      assert(hosts[name], `${tag}: host ${name} missing`);
      for (const [k, v] of Object.entries(fields)) near(hosts[name][k], v, `${tag}: ${name}.${k}`);
    }
    console.log(`[${scenario.name}] analyze ok: ${tag}`);
  }
  console.log(`[${scenario.name}] ALL OK`);
})().catch((e) => { console.error(`[${scenario.name}] FAILED: ${e.message}`); process.exit(1); });

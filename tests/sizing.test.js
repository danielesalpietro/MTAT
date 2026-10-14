// Unit tests for the DOM-free sizing helpers embedded in MTAT_v3_1.ps1 (#4).
// Run: node tests/sizing.test.js
const fs = require('fs'); const assert = require('assert');
const src = fs.readFileSync(require("path").join(__dirname, "..", "MTAT_v3_1.ps1"), 'utf8');
const start = src.indexOf('function describeTieredSizing(f)');
const end = src.indexOf('function runSimulationMath()');
eval(src.slice(start, end).replace(/\/\/[^\n]*\n\s*$/, ''));
const t = (o) => describeTieredSizing(Object.assign({ consumedGB: 6.46, activeGB: 0.1, haNodes: 1 }, o));
const lab = t({ reqConsumed: 1, reqCpu: 1, reqActive: 1, workloadHosts: 1 });
console.log('lab   :', lab);
assert(/fits on a single host/.test(lab) && /1 HA node/.test(lab) && /2 hosts in total/.test(lab) && !/CPU/.test(lab));
const tie = t({ reqConsumed: 3, reqCpu: 3, reqActive: 2, workloadHosts: 3, haNodes: 2 });
console.log('tie   :', tie);
assert(/needs 3 hosts/.test(tie) && /CPU/.test(tie) && /consume/.test(tie) && !/Active Memory/.test(tie) && /5 hosts in total/.test(tie));
const act = t({ reqConsumed: 2, reqCpu: 1, reqActive: 4, workloadHosts: 4, haNodes: 0 });
console.log('active:', act);
assert(/Active Memory/.test(act) && !/HA node/.test(act) && !/CPU/.test(act));
// Active-memory thresholds (#38, M-WL-01..03).
assert.strictEqual(hostActiveCheck({ Physical_RAM: 512, Active_GB: 256 }), 'PASS');
assert.strictEqual(hostActiveCheck({ Physical_RAM: 512, Active_GB: 256.1 }), 'WARN');
assert.strictEqual(hostActiveCheck({ Physical_RAM: 0, Active_GB: 1 }), 'UNKNOWN');
assert.strictEqual(hostActiveCheck({ Tiering: 'ERROR', Physical_RAM: 512, Active_GB: 500 }), 'UNKNOWN');
assert.strictEqual(hostActiveCheck({ Active_Check: 'PASS', Physical_RAM: 512, Active_GB: 500 }), 'PASS');
const risks = collectActiveRisks(
  [{ HostName: 'h1', Physical_RAM: 512, Active_GB: 307.2, Active_Pct: 60 },
   { HostName: 'h2', Physical_RAM: 512, Active_GB: 10, Active_Pct: 2, Active_Check: 'PASS', VM_Demand_GB: 600, VM_Demand_Check: 'WARN' }],
  [{ VMName: 'v1', Active_Avg_GB: 22.4, DRAM_Share_GB: 16, DRAM_Fit: 'WARN' },
   { VMName: 'v2', DRAM_Fit: 'PASS' }, { VMName: 'v3', DRAM_Fit: 'DRAM-only' }]);
assert.deepStrictEqual(risks, { hostPeak: ['h1 (60%)'], hostDemand: ['h2 (600 of 512 GB)'], vms: ['v1 (22.4 of 16 GB)'] });
const lines = describeActiveRisks(risks);
console.log('risks :', lines.join(' | '));
assert(lines.length === 3 && /M-WL-01/.test(lines[0]) && /M-WL-03/.test(lines[1]) && /M-WL-02/.test(lines[2]));
assert.deepStrictEqual(describeActiveRisks(collectActiveRisks([], [])), []);
const many = describeActiveRisks({ hostPeak: [], hostDemand: [], vms: Array.from({ length: 10 }, (_, i) => 'vm' + i) });
assert(/and 2 more/.test(many[0]) && !/vm9/.test(many[0]));
console.log('ALL OK');

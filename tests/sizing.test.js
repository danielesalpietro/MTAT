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
console.log('ALL OK');

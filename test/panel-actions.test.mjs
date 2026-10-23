import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import test from 'node:test';
const source=await readFile(new URL('../javascripts/discourse/lib/vcai-panel-actions.js',import.meta.url),'utf8');
const {panelActions}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
// DOMTokenList and Set have different APIs; adapt the public DOM contract.
const read=(...names)=>panelActions({contains:name=>names.includes(name)});
test('no panel owner means no toolbar control',()=>assert.deepEqual(read(),{historyAvailable:false,historyOpen:false,memoryAvailable:false,memoryOpen:false}));
test('pinned desktop history is not a redundant action',()=>assert.equal(read('vcai-history','vcai-history--persistent').historyAvailable,false));
test('drawer history remains a close action when open',()=>assert.deepEqual(read('vcai-history','vcai-history--drawer-open'),{historyAvailable:true,historyOpen:true,memoryAvailable:false,memoryOpen:false}));
test('memory reflects its owner without reading stored content',()=>assert.deepEqual(read('vcai-memory','vcai-memory--open'),{historyAvailable:false,historyOpen:false,memoryAvailable:true,memoryOpen:true}));
test('resize from persistent to drawer restores control',()=>{assert.equal(read('vcai-history','vcai-history--persistent').historyAvailable,false);assert.equal(read('vcai-history').historyAvailable,true)});

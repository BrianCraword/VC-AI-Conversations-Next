import test from "node:test";
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {hasDraftContent} from "../javascripts/discourse/lib/vcai-navigation-policy.js";
const source=readFileSync(new URL('../javascripts/discourse/components/vcai-conversation-navigation.gjs',import.meta.url),'utf8');
const methods=source.slice(source.indexOf('  draftState() {'),source.indexOf('  async navigate('));
function fixture({text='draft',attachment=false,otherUpload=false}={}) {
  let removed=0, focused=0, alerted=0, settle;
  const input={value:text,isConnected:true,focus(){focused++},dispatchEvent(){}};
  const hidden={inputValue:text};
  const doc={getElementById:()=>input, querySelectorAll(sel){if(sel.includes('ai-bot-upload__'))return attachment?[{click(){removed++}}]:[];return sel.includes('#ai-bot-conversations-input')?[input]:[]},querySelector(sel){if(sel==='.ai-bot-upload')return attachment?{}:null;return otherUpload?{}:null}};
  const owner={lookup:n=>n.includes('hidden-submit')?hidden:{model:{reply:''}}};
  const C=new Function('document','getOwner','hasDraftContent','i18n','themePrefix',`return class {${methods}}`)(doc,()=>owner,hasDraftContent,x=>x,x=>x);
  const instance=new C();instance.state={landing:true};instance.router={currentURL:'/ai'};instance.dialog={confirm:()=>new Promise(r=>settle=r),alert:async()=>{alerted++}};
  return {instance,input,hidden,choose:v=>settle(v),result:()=>({removed,focused,alerted})};
}
test('cancel preserves exact native text and attachments',async()=>{const f=fixture({attachment:true});const p=f.instance.canLeave();f.choose(false);assert.equal(await p,false);assert.equal(f.hidden.inputValue,'draft');assert.equal(f.input.value,'draft');assert.deepEqual(f.result(),{removed:0,focused:1,alerted:0})});
test('discard clears native service and invokes native attachment action',async()=>{const f=fixture({attachment:true});const p=f.instance.canLeave();f.choose(true);assert.equal(await p,true);assert.equal(f.hidden.inputValue,'');assert.equal(f.input.value,'');assert.equal(f.result().removed,1)});
test('a second pending request is refused',async()=>{const f=fixture();const p=f.instance.canLeave();assert.equal(await f.instance.canLeave(),false);f.choose(false);await p});
test('stale route never discards or authorizes departure',async()=>{const f=fixture();const p=f.instance.canLeave();f.instance.router.currentURL='/other';f.choose(true);assert.equal(await p,false);assert.equal(f.hidden.inputValue,'draft')});
test('unrelated native upload is protected, not discarded',async()=>{const f=fixture({text:'',otherUpload:true});assert.equal(await f.instance.canLeave(),false);assert.equal(f.result().alerted,1)});
test('attachment-only draft is visible to legacy veto predicate',()=>{const f=fixture({text:'',attachment:true});assert.ok(f.instance.draftState().hasDraft)});
test('topic draft retains native protection',async()=>{const f=fixture();f.instance.state.landing=false;assert.equal(await f.instance.canLeave(),false);assert.equal(f.result().alerted,1)});
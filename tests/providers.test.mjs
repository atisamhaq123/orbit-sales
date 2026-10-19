import {test} from 'node:test';
import assert from 'node:assert/strict';
import Stripe from 'stripe';
import {provider,embed} from '../src/lib/provider.ts';
test('Stripe raw-body signatures reject tampering, stale signatures and duplicates keep event identity',()=>{const stripe=new Stripe('sk_test_orbit_fixture'),secret='whsec_orbit_fixture',payload=JSON.stringify({id:'evt_fixture',type:'customer.subscription.updated',data:{object:{id:'sub_fixture'}}});const header=stripe.webhooks.generateTestHeaderString({payload,secret});assert.equal(stripe.webhooks.constructEvent(payload,header,secret).id,'evt_fixture');assert.throws(()=>stripe.webhooks.constructEvent(payload+' ',header,secret),/signature/);const stale=stripe.webhooks.generateTestHeaderString({payload,secret,timestamp:1});assert.throws(()=>stripe.webhooks.constructEvent(payload,stale,secret),/Timestamp/);});
test('unconfigured AI errors explicitly, without simulated provider output',async()=>{const old=process.env.OPENAI_API_KEY;delete process.env.OPENAI_API_KEY;try{await assert.rejects(provider('embeddings',{}),/Configure OPENAI_API_KEY/);}finally{if(old)process.env.OPENAI_API_KEY=old;}});
test('provider HTTP failures and timeouts are bounded; embedding shapes are validated (mocked HTTP)',async()=>{const original=globalThis.fetch,old=process.env.OPENAI_API_KEY;process.env.OPENAI_API_KEY='test-fixture';try{
 globalThis.fetch=async()=>new Response('{}',{status:429});await assert.rejects(provider('chat/completions',{}),/429/);
 globalThis.fetch=async(_url,options)=>new Promise((_,reject)=>{const timer=setTimeout(()=>reject(new Error('Test signal missing')),200);options.signal.addEventListener('abort',()=>{clearTimeout(timer);reject(options.signal.reason);},{once:true});});await assert.rejects(provider('chat/completions',{},5),e=>e.name==='TimeoutError');
 globalThis.fetch=async()=>Response.json({data:[{index:0,embedding:[1,2]}]});await assert.rejects(embed(['sample']),/dimensions/);
 await assert.rejects(embed(Array.from({length:33},()=>'')),/bounds/);
}finally{globalThis.fetch=original;if(old)process.env.OPENAI_API_KEY=old;else delete process.env.OPENAI_API_KEY;}});

import type Stripe from 'stripe';
import {admin,check,failure,env,AppError} from '@/lib/server';
import {stripe,reconcile,withBillingLock} from '@/lib/billing';
export async function POST(request:Request){let event:Stripe.Event;try{const s=stripe();try{event=s.webhooks.constructEvent(await request.text(),request.headers.get('stripe-signature')||'',env('STRIPE_WEBHOOK_SECRET'));}catch(e){if(e instanceof AppError)throw e;return Response.json({error:'Invalid Stripe signature.'},{status:400});}
 if(!['checkout.session.completed','customer.subscription.created','customer.subscription.updated','customer.subscription.deleted','invoice.paid','invoice.payment_failed'].includes(event.type))return Response.json({received:true});
 if(check(await admin().from('stripe_events').select('id').eq('id',event.id).maybeSingle()))return Response.json({received:true});
 const object=event.data.object as unknown as {customer:string|{id:string};metadata?:Record<string,string>};const customer=typeof object.customer==='string'?object.customer:object.customer?.id;if(!customer)throw new Error('Customer absent');
 const w=check(await admin().from('workspaces').select('*').eq('stripe_customer_id',customer).maybeSingle());if(!w)throw new Error('Unmapped Orbit customer');
 await withBillingLock(w.id,token=>reconcile(s,w,token,event.id));return Response.json({received:true});
}catch(e){return failure(e instanceof AppError?e:new AppError('Billing synchronization failed. Retry this event.',500));}}

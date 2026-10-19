import 'server-only';
import Stripe from 'stripe';
import {admin,check,AppError,env} from './server';
export const blockingStatuses=['active','trialing','past_due','unpaid','paused','incomplete'];
export function stripe(){return new Stripe(env('STRIPE_SECRET_KEY'),{timeout:20000,maxNetworkRetries:1});}
export async function withBillingLock<T>(w:string,fn:(token:string)=>Promise<T>){const token=crypto.randomUUID();if(!check(await admin().rpc('billing_lease',{w,token})))throw new AppError('Billing is already being updated. Retry shortly.',409);try{return await fn(token);}finally{await admin().from('billing_locks').delete().eq('workspace_id',w).eq('token',token);}}
export async function reconcile(s:Stripe,w:Record<string,any>,token:string,event=`reconcile:${crypto.randomUUID()}`){
 if(!w.stripe_customer_id)return null;
 const subs=[];for await(const sub of s.subscriptions.list({customer:w.stripe_customer_id,status:'all',limit:100}))subs.push(sub);
 const mapped=subs.filter(x=>x.metadata.orbit_workspace===w.id);
 const active=mapped.filter(x=>blockingStatuses.includes(x.status));if(active.length>1)throw new AppError('Multiple subscriptions need review in Stripe. Contact the workspace owner.',409);
 const sub=active[0]||mapped.find(x=>x.id===w.stripe_subscription_id)||mapped.sort((a,b)=>b.created-a.created)[0];if(!sub)return null;
 const item=sub.items.data[0];if(sub.items.data.length!==1||!item)throw new AppError('Unexpected subscription configuration.',409);
 const plan=item.price.id===env('STRIPE_STARTER_PRICE_ID')?'starter':item.price.id===env('STRIPE_PRO_PRICE_ID')?'pro':null;if(!plan)throw new AppError('The Stripe price is not an Orbit Sales price.',409);
 const customer=typeof sub.customer==='string'?sub.customer:sub.customer.id;if(customer!==w.stripe_customer_id)throw new AppError('Stripe customer mapping mismatch.',409);
 check(await admin().rpc('sync_billing',{w:w.id,token,event,customer,subscription:sub.id,new_plan:plan,new_status:sub.status,start_at:new Date(item.current_period_start*1000).toISOString(),end_at:new Date(item.current_period_end*1000).toISOString(),cancel_pending:sub.cancel_at_period_end}));return sub;
}

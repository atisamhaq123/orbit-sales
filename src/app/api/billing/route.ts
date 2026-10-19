import {context,admin,origin,check,failure,AppError,env} from '@/lib/server';
import {stripe,reconcile,withBillingLock,blockingStatuses} from '@/lib/billing';
export async function POST(request:Request){try{origin(request);const m=await request.json();const {workspace:w,user}=await context(m.workspace,true);const s=stripe();const base=env('NEXT_PUBLIC_APP_URL');
 return await withBillingLock(w.id,async token=>{
  if(!w.stripe_customer_id){const customer=await s.customers.create({name:w.name,email:user.email,metadata:{orbit_workspace:w.id}},{idempotencyKey:`orbit-customer:${w.id}`});check(await admin().from('workspaces').update({stripe_customer_id:customer.id}).eq('id',w.id));w.stripe_customer_id=customer.id;}
  const sub=await reconcile(s,w,token);const return_url=`${base}/app/billing?billing=check`;
  if(m.plan==='sync')return Response.json({ok:true});
  if(m.plan==='portal')return Response.json({url:(await s.billingPortal.sessions.create({customer:w.stripe_customer_id,return_url})).url});
  if(!['starter','pro'].includes(m.plan))throw new AppError('Choose Starter or Pro.');const price=env(m.plan==='pro'?'STRIPE_PRO_PRICE_ID':'STRIPE_STARTER_PRICE_ID');
  if(sub&&['active','trialing'].includes(sub.status)){
    const item=sub.items.data[0];if(item.price.id===price)throw new AppError('This is your current plan.');
    const session=await s.billingPortal.sessions.create({customer:w.stripe_customer_id,return_url,flow_data:{type:'subscription_update_confirm',subscription_update_confirm:{subscription:sub.id,items:[{id:item.id,price,quantity:1}]},after_completion:{type:'redirect',redirect:{return_url}}}});return Response.json({url:session.url});
  }
  if(sub&&blockingStatuses.includes(sub.status))throw new AppError('Manage your existing subscription in the billing portal.',409);
  // Expire existing open Checkout sessions before creating one for a different plan.
  const sessions=await s.checkout.sessions.list({customer:w.stripe_customer_id,status:'open',limit:100});for(const old of sessions.data){if(old.metadata?.orbit_workspace===w.id){if(old.metadata?.plan===m.plan)return Response.json({url:old.url});await s.checkout.sessions.expire(old.id);}}
  const session=await s.checkout.sessions.create({customer:w.stripe_customer_id,mode:'subscription',line_items:[{price,quantity:1}],metadata:{orbit_workspace:w.id,plan:m.plan},client_reference_id:w.id,subscription_data:{metadata:{orbit_workspace:w.id}},success_url:return_url,cancel_url:`${base}/app/billing?billing=cancelled`},{idempotencyKey:`orbit-checkout:${w.id}:${crypto.randomUUID()}`});return Response.json({url:session.url});
 });
}catch(e){return failure(e);}}

// Node-compatible module shared by the server and deployable ingestion worker.
export async function provider(path:string,body:unknown,timeout=45000){
 const key=process.env.OPENAI_API_KEY;if(!key)throw new Error('Configure OPENAI_API_KEY to enable live AI and indexing.');
 const response=await fetch(`https://api.openai.com/v1/${path}`,{method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(timeout)});
 if(!response.ok)throw new Error(`AI provider returned ${response.status}. Check model access, credits and configuration, then retry.`);
 return response.json();
}
export async function embed(inputs:string[]){
 if(inputs.length>32||inputs.some(s=>s.length>4000))throw new Error('Embedding batch exceeds bounds.');
 const result=await provider('embeddings',{model:'text-embedding-3-small',dimensions:1536,input:inputs},30000);
 const vectors=(result.data as {index:number;embedding:number[]}[]).sort((a,b)=>a.index-b.index).map(x=>x.embedding);
 if(vectors.length!==inputs.length||vectors.some(v=>v.length!==1536||v.some(n=>!Number.isFinite(n))))throw new Error('Unexpected embedding dimensions. Reindex only after a deliberate schema migration.');
 return vectors;
}

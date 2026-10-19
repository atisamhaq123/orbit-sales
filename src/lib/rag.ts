export function chunkText(text:string, location='Section 1') {
  if(!text.trim()) throw new Error('No extractable text. Scanned PDFs require OCR and are unsupported.');
  if(text.length>500000) throw new Error('Maximum 500,000 extracted characters.');
  const chunks:{content:string;location:string;ordinal:number}[]=[];
  for(let start=0;start<text.length;){ let end=Math.min(start+1800,text.length); if(end<text.length){const stop=text.lastIndexOf('\n',end);if(stop>start+800)end=stop;} chunks.push({content:text.slice(start,end).trim(),location,ordinal:chunks.length});if(chunks.length>400)throw new Error('Document exceeds 400 chunks.');if(end===text.length)break;start=end-180; }
  return chunks;
}
export function boundEvidence<T extends {content:string;id:string}>(rows:T[],limit=12000) {
 let size=0;const accepted:T[]=[];
 for(const row of rows){let content=row.content;
   if(accepted.some(r=>r.id===row.id||r.content.includes(content)))continue;
   for(const previous of accepted){for(let overlap=Math.min(220,previous.content.length,content.length);overlap>=60;overlap--){if(previous.content.endsWith(content.slice(0,overlap))){content=content.slice(overlap).trimStart();break;}if(content.endsWith(previous.content.slice(0,overlap))){content=content.slice(0,-overlap).trimEnd();break;}}}
   if(!content||size+content.length>limit)continue;accepted.push({...row,content});size+=content.length;
 }return accepted;
}
export function fuseRanks<T extends {id:string}>(vector:T[], lexical:T[], k=60){const scores=new Map<string,{row:T;score:number}>();for(const list of [vector,lexical])list.forEach((row,i)=>{const v=scores.get(row.id)||{row,score:0};v.score+=1/(k+i+1);scores.set(row.id,v);});return [...scores.values()].sort((a,b)=>b.score-a.score).map(v=>v.row);}

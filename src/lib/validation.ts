export function safeNext(value: string | null): string {if(!value||!value.startsWith('/')||/[\\\r\n]/.test(value))return '/app';try{const url=new URL(value,'https://orbit.invalid');return url.origin==='https://orbit.invalid'&&/^\/(app(?:\/|$)|invite(?:\/|$))/.test(url.pathname)?url.pathname+url.search+url.hash:'/app';}catch{return '/app';}}
export function text(value: unknown, max: number, required = false): string { if(typeof value !== 'string' || value.length>max || (required && !value.trim())) throw new Error('Invalid or oversized text input.'); return value.trim(); }
export function validateUpload(name:string, bytes:Uint8Array) {
  if(!bytes.length || bytes.length>10*1024*1024) throw new Error('Choose a non-empty file up to 10 MB.');
  const ext=name.split('.').pop()?.toLowerCase();
  if(!['txt','md','pdf'].includes(ext||'')) throw new Error('Supported formats: text, Markdown, and text-based PDF. Scans require OCR.');
  if(ext==='pdf') { if(new TextDecoder().decode(bytes.slice(0,5))!=='%PDF-') throw new Error('The file is not a valid PDF.'); }
  else { const content=new TextDecoder('utf-8',{fatal:true}).decode(bytes); if(/[\x00-\x08\x0e-\x1f]/.test(content)) throw new Error('Upload UTF-8 text or Markdown, not binary content.'); if(content.length>500000) throw new Error('Maximum 500,000 extracted characters.'); }
  return ext==='pdf'?'application/pdf':'text/plain';
}
export function validCitations(ids:string[], sources:{id:string}[]) { const allowed=new Set(sources.map(s=>s.id)); if(ids.some(id=>!allowed.has(id))) throw new Error('The AI returned an unsupported citation. Retry the request.'); return [...new Set(ids)]; }

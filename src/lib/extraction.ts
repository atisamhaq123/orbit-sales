import {getDocument} from 'pdfjs-dist/legacy/build/pdf.mjs';
import {chunkText} from './rag.ts';
export async function extractDocument(bytes:Uint8Array,mime:string){
 if(bytes.length>10485760)throw new Error('File exceeds 10 MB.');
 let chunks:ReturnType<typeof chunkText>=[];
 if(mime==='application/pdf'){
   const pdf=await getDocument({data:bytes,useSystemFonts:true}).promise;
   try{
     if(pdf.numPages>200)throw new Error('PDF exceeds 200 pages.');let total=0;
     for(let page=1;page<=pdf.numPages;page++){const content=await(await pdf.getPage(page)).getTextContent();const text=content.items.map(item=>'str' in item?item.str:'').join(' ');total+=text.length;if(total>500000)throw new Error('PDF exceeds 500,000 extracted characters.');if(text.trim())chunks.push(...chunkText(text,`Page ${page}`));}
   }finally{await pdf.destroy();}
 }else chunks=chunkText(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
 if(!chunks.length)throw new Error('No extractable text. Scanned PDFs require OCR, which is unsupported.');if(chunks.length>400)throw new Error('Document exceeds 400 chunks.');
 return chunks.map((c,ordinal)=>({...c,ordinal}));
}

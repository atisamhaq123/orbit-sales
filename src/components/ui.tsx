'use client';
import {useEffect,useRef} from 'react';
import {X,Orbit,LoaderCircle,ArrowUpRight} from 'lucide-react';
export function Brand(){return <span className="brand"><span className="brand-symbol"><Orbit size={27}/></span>orbit<span className="brand-sales">sales</span><span className="brand-dot">®</span></span>;}
export function Spinner({label}:{label:string}){return <span className="pending" role="status"><LoaderCircle className="spin" size={16}/>{label}</span>;}
export function Empty({title,children}:{title:string;children?:React.ReactNode}){return <div className="empty"><Orbit size={28}/><h3>{title}</h3><p>{children||'Your next opportunity starts here.'}</p></div>;}
export function Modal({title,children,onClose}:{title:string;children:React.ReactNode;onClose:()=>void}){const ref=useRef<HTMLDialogElement>(null);useEffect(()=>{const active=document.activeElement as HTMLElement;ref.current?.showModal();return ()=>{active?.focus();};},[]);return <dialog ref={ref} onCancel={onClose} onClick={e=>{if(e.target===ref.current)onClose();}} aria-labelledby="dialog-title"><div className="dialog-head"><div><span className="eyebrow">YOUR WORKSPACE</span><h2 id="dialog-title">{title}</h2></div><button className="icon-button" onClick={onClose} aria-label="Close dialog"><X size={20}/></button></div>{children}</dialog>;}
export function Arrow(){return <ArrowUpRight size={17}/>;}
export const money=(value:number)=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(value);
export const initials=(name:string)=>name.split(' ').map(n=>n[0]).slice(0,2).join('');

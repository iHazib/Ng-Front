import {createElement,type ReactNode} from 'react';
import {markdownBlocks,safeMarkdownLink} from '@/lib/catalog/markdown';
function inline(text:string):ReactNode[]{
 const pattern=/!\[[^\]]*\]\([^)]*\)|\[([^\]]+)\]\(([^)]*)\)|\*\*([^*]+)\*\*/g,nodes:ReactNode[]=[];let offset=0;
 for(const match of text.matchAll(pattern)){nodes.push(text.slice(offset,match.index));const key=String(match.index);
  if(match[0].startsWith('!'))nodes.push(match[0]);
  else if(match[3])nodes.push(<strong key={key}>{match[3]}</strong>);
  else{const href=safeMarkdownLink(match[2]);nodes.push(href?<a key={key} href={href} rel="nofollow noopener noreferrer">{match[1]}</a>:match[1]);}
  offset=match.index!+match[0].length;
 }nodes.push(text.slice(offset));return nodes;
}
export function ProductMarkdown({source}:{source:string}){
 return <div className="product-markdown">{markdownBlocks(source).map((block,i)=>block.kind==='heading'?createElement('h'+block.level,{key:i},inline(block.text)):block.items?createElement(block.kind==='steps'?'ol':'ul',{key:i},block.items.map((item,j)=><li key={j}>{inline(item)}</li>)):<p key={i}>{inline(block.text)}</p>)}</div>;
}

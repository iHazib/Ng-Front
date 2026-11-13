/** Deliberately small Markdown subset. Content is never interpreted as HTML. */
export type MarkdownBlock = {kind:'paragraph'|'heading'|'bullet'|'steps';level?:number;text:string;items?:string[]};
export function safeMarkdownLink(value:string):string|null {
 if(/[\u0000-\u0020\u007f\\]/.test(value))return null;
 if(value.startsWith('/')&&!value.startsWith('//'))return value;
 if(value.startsWith('#'))return value;
 try{const url=new URL(value);return ['https:','http:'].includes(url.protocol)&&!url.username&&!url.password?url.href:null;}catch{return null;}
}
export function markdownBlocks(source:string):MarkdownBlock[]{
 const lines=source.replace(/\r\n?/g,'\n').split('\n'),blocks:MarkdownBlock[]=[];
 for(let i=0;i<lines.length;){const line=lines[i];if(!line.trim()){i++;continue;}
  const heading=/^(#{1,6})\s+(.+)$/.exec(line);
  if(heading){blocks.push({kind:'heading',level:Math.max(3,heading[1].length),text:heading[2]});i++;continue;}
  const list=/^\s*(?:[-*+] |\d+\. )/.test(line),ordered=/^\s*\d+\. /.test(line);
  if(list){const pattern=ordered?/^\s*\d+\. (.*)$/:/^\s*[-*+] (.*)$/,items:string[]=[];while(i<lines.length){const match=pattern.exec(lines[i]);if(!match)break;items.push(match[1]);i++;}blocks.push({kind:ordered?'steps':'bullet',text:'',items});continue;}
  const paragraph=[line];i++;while(i<lines.length&&lines[i].trim()&&!/^(#{1,6})\s|^\s*(?:[-*+] |\d+\. )/.test(lines[i]))paragraph.push(lines[i++]);
  blocks.push({kind:'paragraph',text:paragraph.join('\n')});
 }return blocks;
}

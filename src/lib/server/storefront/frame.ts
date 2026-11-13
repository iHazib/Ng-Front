import 'server-only';
import {assets} from '@/config/assets';
const brandArtwork:Readonly<Record<string,string|undefined>>=assets.brands;
import {getApprovedPreview,type ApprovedPreview} from '@/lib/catalog/approved-preview';
import {resolveMedia} from '@/lib/catalog/media';
import {pkrMinor,rootRoutes,scopeRoutes,type PublicNavigation,type PublicProduct} from '@/lib/catalog/public-types';
import type {MarkupNode} from '@/components/storefront/SampleMarkup';
import type {PublicDeal,DealResult} from '@/lib/catalog/deals';
import type {Article} from '@/lib/catalog/content-types';
const all=(node:MarkupNode,predicate:(n:MarkupNode)=>boolean):MarkupNode[]=>[...(predicate(node)?[node]:[]),...node.children.flatMap(c=>typeof c==='string'?[]:all(c,predicate))];
const cls=(node:MarkupNode,name:string)=>all(node,n=>(n.attrs.class??'').split(' ').includes(name));
const tag=(tag:string,children:Array<MarkupNode|string>,attrs:Record<string,string>={}):MarkupNode=>({tag,children,attrs});
export function publicFrame(navigation:PublicNavigation,catalogProducts:PublicProduct[]=[],articles:Article[]=[],deals:PublicDeal[]=[],homeOrder:DealResult['homeOrder']=[]):ApprovedPreview{
 const products:PublicProduct[]=[...catalogProducts,...deals.map(d=>({id:d.id,slug:d.slug,name:d.title,brandId:'',brand:'Assembled deal',categoryId:'',category:'Deals',scope:'assembled-deal',type:'deal',description:d.description,usage:null,priceMinor:d.priceMinor,variants:[{id:'deal:'+d.id,sku:'',label:'',priceMinor:d.priceMinor,available:d.available,attributes:[],media:d.media.map((m,i)=>({...m,id:d.id+':'+i,variantId:null,primary:i===0,position:i}))}]}))].sort((a,b)=>(homeOrder?.find(h=>h.id===a.id&&h.kind===(a.scope==='assembled-deal'?'deal':'product'))?.position??99999)-(homeOrder?.find(h=>h.id===b.id&&h.kind===(b.scope==='assembled-deal'?'deal':'product'))?.position??99999));
 const href=(p:PublicProduct)=>(p.scope==='assembled-deal'?'/deals/':'/products/')+p.slug;
 const frame=structuredClone(getApprovedPreview());frame.kind='published-catalog';
 const tree=tag('div',frame.nodes);frame.catalog=products.flatMap(p=>p.variants.map(v=>({id:v.id,name:p.name+' · '+v.label,brand:p.brand,price:v.priceMinor/100,image:v.media[0]?resolveMedia(v.media[0]).src:'',available:v.available,href:href(p)})));
 const roots=['skincare','makeup','fragrances','bath-body','cutlery'];
 for(const [i,panel] of cls(tree,'category-menu').entries()){
  const route=roots[i],scopes=rootRoutes[route];panel.attrs['data-live']='true';
  const groups=cls(panel,'menu-column');
  for(const [index,column] of groups.entries()){
   const heading=column.children.find(c=>typeof c!=='string'&&c.tag==='h3') as MarkupNode;
   const text=heading?.children.filter(c=>typeof c==='string').join('')??'';
   let links:MarkupNode[]=[];
   if(/concern/i.test(text))links=navigation.concerns.map(c=>tag('a',[c.name],{href:'/skincare?concern='+encodeURIComponent(c.id)}));
   else if(/brand/i.test(text))links=navigation.brands.filter(b=>b.scopes?.some(scope=>scopes.includes(scope))).map(b=>tag('a',[b.name],{href:`/${route}?brand=${encodeURIComponent(b.id)}`}));
   else if(index===0)links=navigation.categories.filter(c=>c.scope&&scopes.includes(c.scope)&&c.id!==route).map(c=>tag('a',[c.name],{href:`/${route}?category=${encodeURIComponent(c.id)}`}));
   else links=navigation.types.filter(t=>scopes.includes(t.scope)).map(t=>tag('a',[t.name],{href:`/${route}?type=${encodeURIComponent(t.id)}`}));
   if(index===0&&route==='fragrances')links=['personal-fragrance','home-fragrance'].filter(s=>navigation.categories.some(c=>c.scope===s)).map(s=>tag('a',[s==='home-fragrance'?'Home Fragrance':'Personal Fragrance'],{href:'/'+scopeRoutes[s]}));
   if(index===0&&route==='bath-body'&&navigation.categories.some(c=>c.scope==='hair-care'))links.push(tag('a',['Hair Care'],{href:'/hair-care'}));
   column.children=[...(heading?[heading]:[]),...links];
  }
  for(const a of cls(panel,'menu-all'))a.attrs.href='/'+route;
 }
 const header=cls(tree,'ng-header')[0];if(header)header.attrs['data-catalog-mode']='published';
 const productSection=all(tree,n=>n.attrs.id==='products')[0],grid=cls(productSection,'products')[0],template=cls(productSection,'product')[0];
 grid.children=products.length?products.map(p=>{
  const card=structuredClone(template),variant=p.variants[0];card.attrs['data-product']=variant.id;
  const gallery=cls(card,'product-gallery')[0];gallery.attrs['aria-label']=p.name+', image gallery';
  const media=variant.media;const retained=gallery.children.filter(c=>typeof c==='string'||!['img'].includes(c.tag)&&!(c.attrs.class??'').startsWith('gallery-'));
  gallery.children=[...retained,...media.map((m,i)=>tag('img',[],{class:`product-slide slide-${i}${i===0?' active':''}`,'data-media':JSON.stringify(m),alt:m.alt,loading:'lazy'})),
   ...(media.length>1?[tag('button',['‹'],{class:'gallery-arrow gallery-prev','aria-label':'Previous product image'}),tag('button',['›'],{class:'gallery-arrow gallery-next','aria-label':'Next product image'}),tag('div',media.map((_,i)=>tag('button',[],{class:'gallery-dot'+(i===0?' active':''),'aria-label':`Show product image ${i+1}`})),{class:'gallery-dots'})]:[])];
  if(!media.length)gallery.children.push(tag('span',['Photo awaiting approval'],{class:'muted'}));
  cls(card,'tag')[0].children=[p.category];
  const copy=cls(card,'product-copy')[0];all(copy,n=>n.tag==='small')[0].children=[p.brand];const heading=all(copy,n=>n.tag==='h3')[0];delete heading.attrs['data-product-href'];heading.children=[tag('a',[p.name],{href:href(p)})];
  all(cls(card,'product-price')[0],n=>n.tag==='p')[0].children=[(p.variants.length>1?'From ':'')+pkrMinor(p.priceMinor)];
  for(const b of all(card,n=>n.attrs['data-add']!==undefined)){
   if(p.variants.length>1){b.tag='a';b.attrs={class:b.attrs.class,href:href(p),'aria-label':'Choose an option for '+p.name};if((b.attrs.class??'').includes('text-add'))b.children=['Choose option ↗'];}
   else{b.attrs['data-add']=variant.id;b.attrs['aria-label']='Add '+p.name+' to bag';if(!variant.available)b.attrs.disabled='';}
  }
  return card;
 }):[tag('p',['Our curated collection is being prepared.'],{class:'muted',role:'status'})];
 const track=all(tree,n=>n.attrs.id==='brand-track')[0];track.children=navigation.brands.map(b=>tag('a',[
  tag('span',brandArtwork[b.id]?[tag('img',[],{src:brandArtwork[b.id]!,alt:b.name+' logo',loading:'lazy'})]:[b.name],{class:'brand-image'}),tag('span',[b.name,tag('span',['↗'],{'aria-hidden':'true'})],{class:'brand-name'})],{class:'brand-card',href:'/brands/'+b.id,'data-route':'/brands/'+b.id,'aria-label':'Explore '+b.name}));
 for(const card of cls(tree,'concern-card')){
  const concern=card.attrs['data-route']?.split('concern=')[1];
  if(!navigation.concerns.some(c=>c.id===concern)){card.tag='div';delete card.attrs.href;delete card.attrs['data-route'];card.attrs['aria-disabled']='true';}
 }
 // Published editorial uses the approved framing and themes.
 // Sample articles and editorial photographs remain exclusive to explicit preview.
 if(articles.length){
 const carousel=cls(tree,'edit-carousel')[0],templates=cls(carousel,'edit-slide');carousel.attrs['data-content-cms']='true';
 const slides=articles.map((a,i)=>{const slide=structuredClone(templates[i%templates.length]);const theme=a.theme==='warm'?1:a.theme==='blush'?2:0;
 slide.attrs.class='edit-slide edit-theme-'+theme+(i===0?' active':'');slide.attrs['data-theme']=a.theme;
 cls(slide,'eyebrow')[0].children=[a.category??'The Edit'];all(slide,n=>n.tag==='h2')[0].children=[a.title];cls(slide,'edit-summary')[0].children=[a.summary??''];
 for(const b of cls(slide,'edit-read')){b.tag='a';b.children=['Read the article ↗'];delete b.attrs['data-blog'];delete b.attrs.disabled;b.attrs.href='/the-edit/'+a.slug;}
 cls(slide,'edit-read-time')[0].children=[];cls(slide,'edit-photo')[0].children=a.cover?[tag('img',[],{'data-media':JSON.stringify(a.cover),alt:a.cover.alt,loading:'lazy'})]:[tag('div',[],{style:'width:100%;height:100%;background:#e7e2db','aria-label':'Editorial image awaiting publication'})];return slide;});
 carousel.children=[...slides,...carousel.children.filter(n=>typeof n==='string'||!(n.attrs.class??'').split(' ').includes('edit-slide'))];
 cls(carousel,'edit-dots')[0].children=articles.map((a,i)=>tag('button',[],{class:'edit-dot'+(i===0?' active':''),'aria-label':'Show article '+(i+1)}));
 }else for(const slide of cls(tree,'edit-slide')){
  cls(slide,'eyebrow')[0].children=['The Edit'];all(slide,n=>n.tag==='h2')[0].children=['Stories are being prepared.'];
  cls(slide,'edit-summary')[0].children=['Our approved journal will appear here.'];
  for(const b of cls(slide,'edit-read')){b.children=['Coming soon'];b.attrs.disabled='';delete b.attrs['data-blog'];}
  cls(slide,'edit-read-time')[0].children=[];
  cls(slide,'edit-photo')[0].children=[tag('div',[],{style:'width:100%;height:100%;background:#e7e2db','aria-label':'Editorial image awaiting publication'})];
 }
 const removeSampleDialog=(n:MarkupNode)=>{n.children=n.children.filter(c=>typeof c==='string'||c.attrs.id!=='article-dialog');n.children.forEach(c=>{if(typeof c!=='string')removeSampleDialog(c);});};removeSampleDialog(tree);frame.nodes=tree.children;
 frame.articles=[{title:'The Edit',category:'Journal',time:'',image:'',summary:'Approved articles are not published yet.',body:[]}];
 return frame;
}



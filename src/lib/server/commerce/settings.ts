import 'server-only';
import {createHash} from 'node:crypto';
import type {CheckoutSettings,ManualMethod} from '@/lib/catalog/commerce';
import {CommerceError} from './validation';
interface Config {mode:'development'|'approved';version:string;taxTreatment:string;paymentSeconds:number;reviewExtensionSeconds:number;shipping:{id:string;label:string;feeMinor:number;cities:string[]}[];payment:ManualMethod[]}
export function commerceConfig():Config|null {
 if(process.env.COMMERCE_ENABLED!=='true'||!process.env.COMMERCE_CONFIG_JSON)return null;
 let c:Config;try{c=JSON.parse(process.env.COMMERCE_CONFIG_JSON);}catch{throw new CommerceError('Checkout configuration needs attention.',503);}
 const dev=process.env.NODE_ENV==='development'&&process.env.MEDIA_ENVIRONMENT==='development';
 if(!c||!['development','approved'].includes(c.mode)||(c.mode==='development'&&!dev)||!c.version||c.version.length>80||!['development-no-additional-tax','included-in-prices','not-applicable'].includes(c.taxTreatment)||(c.mode==='approved'&&c.taxTreatment==='development-no-additional-tax')||!Number.isInteger(c.paymentSeconds)||c.paymentSeconds<60||c.paymentSeconds>604800||!Number.isInteger(c.reviewExtensionSeconds)||c.reviewExtensionSeconds<0||c.reviewExtensionSeconds>86400||!Array.isArray(c.shipping)||!c.shipping.length||c.shipping.length>20||!Array.isArray(c.payment)||c.payment.length>3)throw new CommerceError('Checkout configuration is incomplete. Contact customer care.',503);
 for(const s of c.shipping)if(!/^[a-z0-9-]{1,50}$/.test(s.id)||!s.label||s.label.length>120||!Number.isSafeInteger(s.feeMinor)||s.feeMinor<0||s.feeMinor>1e9||!Array.isArray(s.cities)||s.cities.length<1||s.cities.length>200||s.cities.some(x=>typeof x!=='string'||!x.trim()||x.length>100))throw new CommerceError('Delivery configuration needs attention.',503);
 c.payment=c.payment.filter(p=>p&&p.enabled===true&&['bank-transfer','easypaisa','jazzcash'].includes(p.id)&&[p.label,p.accountTitle,p.destination].every(x=>typeof x==='string'&&x.trim().length>0&&x.length<=120)&&[p.instructions].every(x=>typeof x==='string'&&x.trim().length>0&&x.length<=500)&&(p.id!=='bank-transfer'||(typeof p.bankName==='string'&&p.bankName.trim().length>0&&p.bankName.length<=120)));
 if(new Set(c.shipping.map(x=>x.id)).size!==c.shipping.length||new Set(c.payment.map(x=>x.id)).size!==c.payment.length)throw new CommerceError('Checkout options must be unique.',503);
 return c;
}
export function checkoutSettings():CheckoutSettings{const c=commerceConfig();return c&&c.payment.length?{enabled:true,development:c.mode==='development',message:c.mode==='development'?'Development checkout: synthetic testing only. Do not transfer real funds.':'Advance payment only. Your exact payment and stock-hold deadlines appear after placing the order.',shipping:c.shipping,payment:c.payment,version:c.version}:{enabled:false,development:false,message:'Checkout is unavailable until delivery, receiving-account details and payment deadlines are configured.',shipping:[],payment:[]};}
export function checkoutPolicy(shippingId:unknown,paymentId:unknown,city:string,version:unknown){const c=commerceConfig();if(!c)throw new CommerceError('Checkout is not configured yet.',503);if(version!==c.version)throw new CommerceError('Delivery or payment settings changed. Refresh checkout.',409);
 const shipping=c.shipping.find(x=>x.id===shippingId),method=c.payment.find(x=>x.id===paymentId);if(!shipping||!method)throw new CommerceError('Choose an available delivery and payment option.');if(!shipping.cities.some(x=>x==='*'||x.toLowerCase()===city.toLowerCase()))throw new CommerceError('This delivery option is not configured for your city.');
 const normalize=(s:string)=>s.normalize('NFKC').toUpperCase().replace(/[\s-]+/g,'');
 const accountScope=createHash('sha256').update(JSON.stringify([method.id,method.id==='bank-transfer'?normalize(method.bankName!):'',normalize(method.destination)])).digest('hex');
 return {shipping:{id:shipping.id,label:shipping.label,feeMinor:shipping.feeMinor},payment:{...method,allocation:'temporary',accountScope},config:{mode:c.mode,version:c.version,taxTreatment:c.taxTreatment,paymentSeconds:c.paymentSeconds,reviewExtensionSeconds:c.reviewExtensionSeconds}};
}

'use client';
import {useEffect,useRef,useState,type FormEvent} from 'react';
import type {CommerceOrder} from '@/lib/catalog/commerce';
import {pkrMinor} from '@/lib/catalog/public-types';

const date=(s:string)=>new Date(s).toLocaleString('en-PK',{timeZone:'Asia/Karachi',dateStyle:'medium',timeStyle:'long'});

function copyButton(label:string,value:string){
  return (
    <button
      type="button"
      className="copy-btn"
      onClick={()=>{
        navigator.clipboard.writeText(value);
      }}
      title={`Copy ${label}`}
    >
      {label}
    </button>
  );
}

export function PaymentSubmission({order,onUpdate}:{order:CommerceOrder;onUpdate:(o:CommerceOrder)=>void}){
  const [csrf,setCsrf]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),attempt=useRef<{key:string;payload:string;proofKey:string}|undefined>(undefined);
  const m=order.manualPayment!;
  useEffect(()=>{
    void fetch('/api/commerce',{cache:'no-store'}).then(r=>r.json()).then(d=>setCsrf(d.csrf??'')).catch(()=>setMessage('Refresh this page before submitting.'));
  },[]);

  async function submit(e:FormEvent<HTMLFormElement>){
    e.preventDefault();
    if(busy)return;
    const f=new FormData(e.currentTarget);
    const file=f.get('proof');
    const reference=String(f.get('reference')??'').trim();
    const amount=String(f.get('amount')??'');
    const minor=amount?Math.round(Number(amount)*100):null;

    // Required-field validation
    if(!reference || reference.length<3){
      setMessage('Enter the transaction reference from your SMS or banking receipt.');
      return;
    }
    if(!(file instanceof File)||file.size===0){
      setMessage('Upload a payment-proof image (screenshot or receipt).');
      return;
    }
    if(file.size>5242880){
      setMessage('Choose an image up to 5 MiB.');
      return;
    }
    if(minor!==null&&(!Number.isSafeInteger(minor)||minor<=0)){
      setMessage('Enter a valid transferred amount.');
      return;
    }

    const payload=JSON.stringify([reference,minor,file instanceof File?[file.name,file.size,file.lastModified]:null]);
    if(attempt.current?.payload!==payload)attempt.current={payload,key:crypto.randomUUID(),proofKey:crypto.randomUUID()};
    setBusy(true);
    setMessage('');

    try{
      let proof:string|null=null;
      setMessage('Uploading private proof…');
      const r1=await fetch('/api/commerce/proof?order='+order.id+'&id='+attempt.current!.proofKey,{
        method:'POST',
        headers:{'Content-Type':file.type,'x-commerce-csrf':csrf},
        body:file,
        cache:'no-store',
      });
      const d1=await r1.json();
      if(!r1.ok)throw Error(d1.error);
      proof=d1.id;

      const r2=await fetch('/api/commerce',{
        method:'POST',
        headers:{'Content-Type':'application/json','x-commerce-csrf':csrf},
        body:JSON.stringify({action:'submit-payment',id:order.id,key:attempt.current!.key,reference,amountMinor:minor,proof}),
        cache:'no-store',
      });
      const d2=await r2.json();
      if(!r2.ok)throw Error(d2.error);
      onUpdate(d2);
      attempt.current=undefined;
      setMessage('Payment details submitted for review. Funds are confirmed only after the store checks its receiving account.');
    }catch(e){
      setMessage(e instanceof Error?e.message:'Submission failed. Retry the same details.');
    }finally{
      setBusy(false);
    }
  }

  return (
    <div className="checkout-form">
      <h2>Payment details</h2>
      <p>Order <strong>{order.number}</strong> is in <strong>pending verification</strong>. Your stock is temporarily reserved until {date(m.paymentDeadline)} (Pakistan time).</p>
      <p>To confirm your order, transfer the exact total to the account below, then submit your transaction reference and proof image.</p>

      <div className="account-details">
        <h3>Send payment to</h3>
        <p><strong>Method:</strong> {order.payment.label}</p>
        <p><strong>Account title:</strong> {copyButton('Account title',order.payment.accountTitle??'')} {order.payment.accountTitle}</p>
        {order.payment.bankName&&<p><strong>Bank:</strong> {copyButton('Bank name',order.payment.bankName)} {order.payment.bankName}</p>}
        <p><strong>Account / wallet:</strong> {copyButton('Account number',String(order.payment.destination??''))} {order.payment.destination??''}</p>
        <p><strong>Instructions:</strong> {order.payment.instructions??''}</p>
        <p><strong>Order total:</strong> {pkrMinor(order.totalMinor)}</p>
        <p className="notice">Put your order number <strong>{order.number}</strong> in the transfer reference/remarks field so we can match your payment.</p>
      </div>

      {m.message&&<p role="status">{m.message}</p>}
      {order.paymentStatus==='received_resolution_required'&&<p role="status">Payment received—resolution required. Please contact the store; fulfilment is not confirmed.</p>}
      {m.receivedMinor>0&&<p>Funds recorded: {pkrMinor(m.receivedMinor)}</p>}

      {m.submissions.map(s=>(<p key={s.id}>{s.reference} — submitted {date(s.at)} {s.proofId&&<a className="text-link" href={'/api/commerce/proof?order='+order.id+'&id='+s.proofId} target="_blank" rel="noreferrer">View private proof</a>}</p>))}

      {!['paid'].includes(order.paymentStatus)&&!['cancelled','dispatched','completed'].includes(order.fulfilment)&&(
        <form onSubmit={submit}>
          <label htmlFor="payment-reference">Transaction reference (from your SMS/banking receipt)</label>
          <input id="payment-reference" name="reference" required minLength={3} maxLength={120}/>
          <label htmlFor="payment-amount">Transferred amount in PKR</label>
          <input id="payment-amount" name="amount" type="number" min="0.01" step="0.01" required/>
          <label htmlFor="payment-proof">Payment-proof image (required, private, up to 5 MiB)</label>
          <input id="payment-proof" name="proof" type="file" accept="image/png,image/jpeg,image/webp" required/>
          <p>Upload a screenshot or photo of your banking/wallet receipt showing the transfer to the account above.</p>
          <button className="commerce-button" disabled={busy||!csrf}>{busy?'Submitting…':'Submit payment details'}</button>
        </form>
      )}
      <p role="status" aria-live="polite">{message}</p>
    </div>
  );
}

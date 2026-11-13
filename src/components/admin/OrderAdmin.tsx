'use client';
import {useCallback,useEffect,useRef,useState,type FormEvent} from 'react';
import {PaymentReview} from './PaymentReview';import {adminRequest} from './ProductAdmin';import {pkrMinor} from '@/lib/catalog/public-types';import type {CommerceOrder} from '@/lib/catalog/commerce';

function copyBtn(label:string,value:string){
  return (
    <button type="button" className="copy-btn" onClick={()=>navigator.clipboard.writeText(value)} title={`Copy ${label}`}>
      {label}
    </button>
  );
}

export function OrderAdmin(){
  const [result,setResult]=useState<{rows:CommerceOrder[];total:number;offset:number}|null>(null);
  const [order,setOrder]=useState<CommerceOrder|null>(null);
  const [message,setMessage]=useState('');
  const [busy,setBusy]=useState(false);
  const [query,setQuery]=useState('');
  const [status,setStatus]=useState('');
  const [queue,setQueue]=useState('');
  const [from,setFrom]=useState('');
  const [to,setTo]=useState('');
  const [offset,setOffset]=useState(0);
  const operation=useRef<{id:string;action:string;key:string}|null>(null);

  useEffect(()=>{
    const id=new URLSearchParams(window.location.search).get('order');
    if(id&&/^[a-f0-9-]{36}$/i.test(id)){
      void adminRequest<CommerceOrder>('/admin/api/orders?id='+id).then(setOrder).catch(()=>setMessage('Order could not be opened.'));
    }
  },[]);

  const load=useCallback(async()=>{
    try{
      const d=await adminRequest<{rows:CommerceOrder[];total:number;offset:number}>('/admin/api/orders',{action:'list',query,status,queue,from,to,offset});
      setResult(d);
    }catch(e){
      setMessage(e instanceof Error?e.message:'Orders could not be loaded.');
    }
  },[query,status,queue,from,to,offset]);
  useEffect(()=>{void load();},[load]);

  const action=async(a:string)=>{
    if(!order||busy)return;
    if(a==='cancel'&&!window.confirm('Cancel this order and release its allocation?'))return;
    setBusy(true);setMessage('');
    if(operation.current?.id!==order.id||operation.current.action!==a)operation.current={id:order.id,action:a,key:crypto.randomUUID()};
    try{
      const updated=await adminRequest('/admin/api/orders',{id:order.id,revision:order.revision,action:a,key:operation.current.key});
      setOrder(updated as CommerceOrder);operation.current=null;setMessage('Order updated.');await load();
    }catch{setMessage('Could not update. Refresh the order before retrying; it may have changed.');}finally{setBusy(false);}
  };

  const filters=(e:FormEvent<HTMLFormElement>)=>{
    e.preventDefault();
    const f=new FormData(e.currentTarget);
    setQuery(String(f.get('q')??''));setStatus(String(f.get('status')??''));
    setQueue(String(f.get('queue')??''));setFrom(String(f.get('from')??''));setTo(String(f.get('to')??''));
    setOffset(0);
  };

  const pendingCount=result?.rows.filter(r=>r.paymentStatus!=='paid'&&!['cancelled','dispatched','completed'].includes(r.fulfilment)).length??0;

  return (
    <div>
      <div className="toolbar">
        <h1>Orders</h1>
        <button onClick={()=>{setOrder(null);void load();}}>Refresh list</button>
      </div>
      <p role="status">{message}</p>
      {pendingCount>0&&<p className="notice"><strong>{pendingCount}</strong> order(s) awaiting payment verification.</p>}

      <form onSubmit={filters} className="filter-form">
        <label>Search<input name="q" value={query} onChange={e=>setQuery(e.target.value)} placeholder="Order number, name, phone"/></label>
        <label>Status<select name="status" value={status} onChange={e=>setStatus(e.target.value)}>
          <option value="">All</option><option value="placed">Placed</option><option value="confirmed">Confirmed</option><option value="dispatched">Dispatched</option><option value="completed">Completed</option><option value="cancelled">Cancelled</option><option value="expired">Expired</option>
        </select></label>
        <label>Queue<select name="queue" value={queue} onChange={e=>setQueue(e.target.value)}>
          <option value="">All</option><option value="Awaiting payment">Awaiting payment</option><option value="Proof submitted">Proof submitted</option><option value="Needs attention">Needs attention</option><option value="Paid">Paid</option>
        </select></label>
        <label>From<input name="from" type="date" value={from} onChange={e=>setFrom(e.target.value)}/></label>
        <label>To<input name="to" type="date" value={to} onChange={e=>setTo(e.target.value)}/></label>
        <button type="submit">Apply filters</button>
      </form>

      {result&&(
        <>
          <p>{result.total} order(s)</p>
          <table className="order-table">
            <thead>
              <tr><th>Order</th><th>Customer</th><th>Total</th><th>Payment status</th><th>Fulfilment</th><th>Placed</th><th>Action</th></tr>
            </thead>
            <tbody>
              {result.rows.map(r=>{
                const isPending=r.paymentStatus!=='paid'&&!['cancelled','dispatched','completed'].includes(r.fulfilment);
                return (
                  <tr key={r.id}>
                    <td><a href={`?order=${r.id}`}>{r.number}</a></td>
                    <td>{r.name}<br/><small>{r.phone}</small></td>
                    <td>{pkrMinor(r.totalMinor)}</td>
                    <td>{isPending?<span className="status-pending">{r.paymentStatus.replaceAll('_',' ')}</span>:<span className="status-paid">{r.paymentStatus.replaceAll('_',' ')}</span>}</td>
                    <td>{r.fulfilment}</td>
                    <td>{new Date(r.createdAt).toLocaleString('en-PK',{timeZone:'Asia/Karachi',dateStyle:'medium',timeStyle:'short'})}</td>
                    <td><a href={`?order=${r.id}`}>View</a>{isPending&&<span> · <a href={`?order=${r.id}`}>Verify</a></span>}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {result.rows.length>0&&(
            <div className="pagination">
              <button disabled={offset===0} onClick={()=>setOffset(offset-25)}>Previous</button>
              <span>Page {Math.floor(offset/25)+1} of {Math.max(1,Math.ceil(result.total/25))}</span>
              <button disabled={offset+25>=result.total} onClick={()=>setOffset(offset+25)}>Next</button>
            </div>
          )}
        </>
      )}

      {order&&(
        <>
          <button onClick={()=>setOrder(null)}>Back to orders</button>
          <section className="order-detail">
            <div className="toolbar">
              <h2>{order.number}</h2>
              {order.paymentStatus!=='paid'?<span className="status-pill status-pending">Pending verification</span>:order.paymentStatus==='paid'?<span className="status-pill status-paid">Paid</span>:<span className="status-pill status-rejected">{String(order.paymentStatus??'').replaceAll('_',' ')}</span>}
              <span className="status-pill">{order.fulfilment}</span>
            </div>

            {/* Two-stage verification panel */}
            {order.paymentStatus!=='paid'&&(
              <div className="verification-panel">
                <h3>Payment verification</h3>
                <div className="verification-grid">
                  <div className="verification-item">
                    <label>Order total</label>
                    <p className="amount">{pkrMinor(order.totalMinor)}</p>
                  </div>
                  <div className="verification-item">
                    <label>Transaction reference</label>
                    <p>{order.manualPayment?.submissions?.[0]?.reference??'Not yet submitted'}</p>
                  </div>
                  <div className="verification-item">
                    <label>Proof image</label>
                    {order.manualPayment?.submissions?.[0]?.proofId?(
                      <a href={`/admin/api/orders/proof?id=${order.manualPayment.submissions[0].proofId}`} target="_blank" rel="noopener noreferrer" className="proof-link">View private payment proof</a>
                    ):<span className="missing">No proof uploaded yet</span>}
                  </div>
                </div>
                {(order.manualPayment?.flags??[]).length>0&&(
                  <div className="flags">
                    <h4>Flags</h4>
                    <ul>{(order.manualPayment?.flags??[]).map(f=><li key={f}>{f}</li>)}</ul>
                  </div>
                )}
                {(order.manualPayment?.submissions??[]).map(s=>(
                  <div key={s.id} className="submission-row">
                    <p>Reference: {s.reference}</p>
                    <p>Claimed amount: {s.amountMinor===null?'Not supplied':pkrMinor(s.amountMinor)}</p>
                    <p>Submitted: {new Date(s.at).toLocaleString('en-PK',{timeZone:'Asia/Karachi'})}</p>
                    {s.proofId&&<a href={`/admin/api/orders/proof?id=${s.proofId}`} target="_blank" rel="noopener noreferrer">View private proof</a>}
                  </div>
                ))}
                {order.manualPayment?.receipts.map((r,i)=>(
                  <p key={i}>Verified received: {pkrMinor(r.amountMinor)} · {r.reference} · {new Date(r.at).toLocaleString('en-PK',{timeZone:'Asia/Karachi'})}</p>
                ))}
                <PaymentReview key={order.id} order={order} onUpdate={o=>{setOrder(o);void load();}}/>
              </div>
            )}

            <p>Payment: {order.payment.label}</p>
            {order.payment.accountTitle&&<p>{copyBtn('Account title',order.payment.accountTitle)} {order.payment.accountTitle}</p>}
            {order.payment.bankName&&<p>{copyBtn('Bank name',order.payment.bankName)} {order.payment.bankName}</p>}
            <p>{copyBtn('Account/wallet',String(order.payment.destination??''))} {order.payment.destination??''}</p>
            <p>{order.payment.instructions??''}</p>

            {order.holdExpiresAt&&<p>Temporary hold expires {new Date(order.holdExpiresAt).toLocaleString('en-PK',{timeZone:'Asia/Karachi'})} (Pakistan time). Expired holds are closed by the scheduled expiry check.</p>}

            <div className="grid">
              <div>
                <h3>Delivery details</h3>
                <p>{order.name}<br/>{order.phone}<br/>{order.email}<br/>{order.address.address}<br/>{order.address.city}</p>
                {order.note&&<p>Note: {order.note}</p>}
              </div>
              <div>
                <h3>Order totals</h3>
                <p>Items: {pkrMinor(order.subtotalMinor)}</p>
                <p>Delivery: {pkrMinor(order.shippingMinor)}</p>
                <strong>Total: {pkrMinor(order.totalMinor)}</strong>
              </div>
            </div>

            {order.paymentStatus!=='paid'&&<p className="notice">Payment is awaiting verification. Confirm and Dispatch are unavailable. An unpaid hold expires at its deadline.</p>}

            <h3>Items</h3>
            {order.items.map((i,n)=>(<p key={n}>{i.name}<br/><small>{i.sku??'Assembled deal'}</small> x {i.quantity} - {pkrMinor(i.totalMinor)}{i.kind==='deal'&&i.components?.map(c=><small key={c.sku}>{c.name} · {c.label} · {c.sku} × {c.quantity}</small>)}</p>))}

            <div className="actions">
              {(order.fulfilment==='placed'?['confirm','cancel']:order.fulfilment==='confirmed'?['dispatch','cancel']:order.fulfilment==='dispatched'?['complete']:[]).map(a=>
                <button disabled={busy||(a==='confirm'||a==='dispatch')&&order.paymentStatus!=='paid'} key={a} onClick={()=>void action(a)}>
                  {a[0].toUpperCase()+a.slice(1)}
                </button>
              )}
            </div>
          </section>
        </>
      )}
    </div>
  );
}

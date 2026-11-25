import type {ReactNode} from 'react';

/** Native disclosure keeps product copy server-rendered and works before hydration. */
export function ProductDisclosure({title,children,initiallyOpen=false}:{title:string;children:ReactNode;initiallyOpen?:boolean}){
 return <details className="product-disclosure" open={initiallyOpen}><summary><h2>{title}</h2><svg viewBox="0 0 20 20" width="20" height="20" aria-hidden="true" focusable="false"><path d="m5 8 5 5 5-5" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg></summary><div className="product-disclosure-content">{children}</div></details>;
}

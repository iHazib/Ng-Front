import 'server-only';
export class ReviewError extends Error {readonly status:number;constructor(message:string,status=400){super(message);this.status=status;}}
export function validateReview(data:Record<string,unknown>){
 const name=String(data.name??'').trim(),title=String(data.title??'').trim(),body=String(data.body??'').trim(),email=String(data.email??'').trim(),rating=Number(data.rating);
 if(!name||name.length>80||title.length>160||body.length<10||body.length>4000||!Number.isInteger(rating)||rating<1||rating>5||email.length>254||(email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)))throw new ReviewError('Add a name, a rating from 1–5 and 10–4,000 characters of review text. Check your optional email address.');
 if(/[<>\x00-\x08\x0b\x0c\x0e-\x1f]/.test(name+title+body)||/https?:\/\/|www\./i.test(name+title+body))throw new ReviewError('Use plain review text without links or HTML.');
 if(String(data.website??''))throw new ReviewError('Review could not be accepted.');
 return {name,title,body,email,rating};
}

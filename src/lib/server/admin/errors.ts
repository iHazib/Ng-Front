/** Shared server error without dependencies on Next's request context. */
export class AdminError extends Error {
  status:number;
  constructor(message:string,status=400){super(message);this.status=status;}
}

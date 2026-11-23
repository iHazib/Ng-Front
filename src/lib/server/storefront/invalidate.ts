import 'server-only';
import {revalidatePath,revalidateTag} from 'next/cache';
// Expire shared anonymous navigation immediately after authorized writes.
// Product/stock reads and all private responses remain uncached.
export function invalidatePublicCatalog(){revalidateTag('public-navigation',{expire:0});revalidatePath('/','layout');}

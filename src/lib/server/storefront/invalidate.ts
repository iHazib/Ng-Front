import 'server-only';
import {revalidatePath} from 'next/cache';
// Public reads are no-store and React cache is request-local. Invalidate router
// layout entries after authorized writes; no private response is ever cached.
export function invalidatePublicCatalog(){revalidatePath('/','layout');}

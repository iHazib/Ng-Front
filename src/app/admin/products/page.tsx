import { redirect } from 'next/navigation';
import { adminSession } from '@/lib/server/admin/session';
import { ProductAdmin } from '@/components/admin/ProductAdmin';
export default async function Page() {
  try { await adminSession(); } catch { redirect('/admin/login'); }
  return <ProductAdmin />;
}

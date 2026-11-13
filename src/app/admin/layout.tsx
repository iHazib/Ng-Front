import './admin.css';
import {AdminNavigation} from '@/components/admin/AdminNavigation';
import Link from 'next/link';
export const dynamic = 'force-dynamic';
export const metadata = { title: 'Nook & Glow — Product administration', robots: { index: false, follow: false } };
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return <div className="ng-admin"><header><Link className="admin-brand" href="/admin/products">Nook & Glow <span>Store management</span></Link><AdminNavigation/></header><main>{children}</main></div>;
}


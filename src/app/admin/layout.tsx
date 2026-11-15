import './admin.css';
import {AdminShell} from '@/components/admin/AdminShell';
export const dynamic = 'force-dynamic';
export const metadata = { title: 'Nook & Glow — Product administration', robots: { index: false, follow: false } };
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return <AdminShell>{children}</AdminShell>;
}

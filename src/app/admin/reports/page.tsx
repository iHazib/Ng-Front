import {redirect} from 'next/navigation';import {adminSession} from '@/lib/server/admin/session';import {ReportsAdmin} from '@/components/admin/ReportsAdmin';
export default async function Page(){try{await adminSession();}catch{redirect('/admin/login');}return <ReportsAdmin/>;}

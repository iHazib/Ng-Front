import {redirect} from 'next/navigation';import {adminSession} from '@/lib/server/admin/session';import {OrderAdmin} from '@/components/admin/OrderAdmin';
export default async function Page(){try{await adminSession();}catch{redirect('/admin/login');}return <OrderAdmin/>;}

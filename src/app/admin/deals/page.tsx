import {redirect} from 'next/navigation';import {adminSession} from '@/lib/server/admin/session';import {DealAdmin} from '@/components/admin/DealAdmin';
export default async function Page(){try{await adminSession();}catch{redirect('/admin/login');}return <DealAdmin/>;}

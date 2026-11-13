import {redirect} from 'next/navigation';import {adminSession} from '@/lib/server/admin/session';import {HomepageAdmin} from '@/components/admin/HomepageAdmin';
export default async function Page(){try{await adminSession();}catch{redirect('/admin/login');}return <HomepageAdmin/>;}

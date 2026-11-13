import {redirect} from 'next/navigation';import {adminSession} from '@/lib/server/admin/session';import {ArticleAdmin} from '@/components/admin/ArticleAdmin';
export default async function Page(){try{await adminSession();}catch{redirect('/admin/login');}return <ArticleAdmin/>;}

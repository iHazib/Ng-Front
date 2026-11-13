import {redirect} from 'next/navigation';
import {adminSession} from '@/lib/server/admin/session';
import {ReviewAdmin} from '@/components/admin/ReviewAdmin';
export default async function ReviewsPage(){try{await adminSession();}catch{redirect('/admin/login');}return <ReviewAdmin/>;}

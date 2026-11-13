import type {ContentImage} from '@/lib/server/content/rich-text';
export interface Article {id:string;title:string;slug:string|null;summary:string|null;body:string|null;author:string|null;category:string|null;tags:string[];publishedAt:string|null;seoTitle:string|null;seoDescription:string|null;theme:'sage'|'warm'|'blush';cover:ContentImage|null;images:ContentImage[]}
export interface ArticleResult {total:number;articles:Article[]}

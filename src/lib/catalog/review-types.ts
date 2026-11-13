import type {Media} from './types';
export interface CustomerReview {id:string;name:string;rating:number;title:string|null;body:string;createdAt:string;images:Array<Media&{id:string}>}
export interface ReviewResult {total:number;average:number|null;page:number;reviews:CustomerReview[]}
export interface ModerationReview {id:string;product_id:string;display_name:string;rating:number;title:string|null;body:string;status:string;hidden_at:string|null;revision:number;submission_complete:boolean;products:{name:string};images:Array<{id:string;alt:string;lifecycle:string}>}

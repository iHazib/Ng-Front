export type MediaSource =
  | { kind: 'local-preview'; path: `/assets/${string}` }
  | { kind: 'cloudinary'; cloudName: string; publicId: string; version: number; format: 'webp' | 'jpg' | 'png'; publication: 'published'; width: number; height: number };

export interface Media { source: MediaSource; alt: string }
export interface HeroSample { id: string; className: string; media: Media; title: string; eyebrow?: string; summary?: string; cta: string }
export interface ArticleSample { id: string; theme: 'sage' | 'warm' | 'blush'; title: string; summary: string; media: Media }
export interface ProductSample { id: `sample:${string}`; name: string; media: Media }
export interface SampleHomepage {
  kind: 'sample';
  heroes: readonly [HeroSample, HeroSample, HeroSample, HeroSample];
  articles: readonly ArticleSample[];
  products: readonly ProductSample[];
}

import type { HeroSample } from '@/lib/catalog/types';
import { resolveMedia } from '@/lib/catalog/media';

// Foundation only: the first approved frame, not the later interactive slideshow.
export function HeroFoundation({ hero }: { hero: HeroSample }) {
  const media = resolveMedia(hero.media);
  return <section className="hero-carousel" aria-label="Nook & Glow featured edits">
    <article className={`hero-slide ${hero.className} active`} aria-hidden="false">
      <img className="hero-photo" {...media} fetchPriority="high" />
      <div className="hero-shade" />
      <div className="hero-copy brand-copy"><h1 className="visually-hidden">{hero.title}</h1><a className="button" href="#preview-note">{hero.cta}</a></div>
      <span className="hero-slide-index">01 / 04</span>
    </article>
  </section>;
}

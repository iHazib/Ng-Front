import type { Media } from './types';

// Pure rendering boundary. It accepts only public metadata, never credentials,
// private Storage URLs, unsigned uploads or confidential draft records.
export function resolveMedia(media: Media, options: { widths?: readonly number[]; sizes?: string; crop?: 'fit' | 'fill'; aspectRatio?: number } = {}): { src: string; alt: string; width?: number; height?: number; srcSet?: string; sizes?: string } {
  const source = media.source;
  if (source.kind === 'local-preview') {
    if (!/^\/assets\/[a-z0-9/_-]+\.(png|webp|jpg)$/.test(source.path)) throw new Error('Invalid preview asset path');
    return { src: source.path, alt: media.alt };
  }
  if (source.publication !== 'published' || !/^[a-zA-Z0-9_-]+$/.test(source.cloudName)
    || !/^[a-zA-Z0-9_/-]+$/.test(source.publicId) || source.publicId.includes('..')
    || !Number.isSafeInteger(source.version) || source.version < 1
    || !['webp', 'jpg', 'png'].includes(source.format)
    || !Number.isInteger(source.width) || !Number.isInteger(source.height)
    || source.width <= 0 || source.height <= 0) throw new Error('Invalid published media metadata');
  const requested = [...new Set(options.widths ?? [320, 480, 768, 1024, 1600])].sort((a,b) => a-b);
  if (requested.length < 1 || requested.length > 8 || requested.some(w => !Number.isInteger(w) || w < 16 || w > 2400)) throw new Error('Invalid responsive widths');
  // c_limit never enlarges the original. Its srcset descriptors must therefore
  // reflect delivered widths, including small review images, rather than request sizes.
  const widths = [...new Set(requested.map(w => options.crop === 'fill' ? w : Math.min(w, source.width)))];
  if (options.crop === 'fill' && (!options.aspectRatio || !Number.isFinite(options.aspectRatio) || options.aspectRatio < 0.25 || options.aspectRatio > 4)) throw new Error('Explicit crop aspect ratio required');
  const delivery = (width: number) => {
    const transform = options.crop === 'fill' ? `c_fill,g_center,w_${width},h_${Math.round(width / options.aspectRatio!)}` : `c_limit,w_${width}`;
    return `https://res.cloudinary.com/${source.cloudName}/image/upload/${transform},f_auto,q_auto/v${source.version}/${source.publicId}.${source.format}`;
  };
  return { src: delivery(widths[widths.length - 1]), srcSet: widths.map(w => `${delivery(w)} ${w}w`).join(', '), sizes: options.sizes ?? '100vw',
    alt: media.alt, width: source.width, height: source.height };
}

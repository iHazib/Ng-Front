// Conservative plain-text extraction for metadata and structured data.
// Product and article copy is stored as markdown/rich text. Search engines
// should receive readable text, never markup or HTML entities from a draft.
export function plainText(source: string | null | undefined, limit = 320): string {
  if (!source) return '';
  const withoutBlocks = source
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/[`*_>#~|]/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/\s+/g, ' ')
    .trim();
  return withoutBlocks.slice(0, limit).trim();
}

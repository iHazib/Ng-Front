// Server-rendered JSON-LD. `<` is escaped so user-authored names, titles or
// review bodies cannot close the script element.
export function JsonLd({ data }: { data: Record<string, unknown> | null }) {
  if (!data) return null;
  const json = JSON.stringify(data).replace(/</g, '\\u003c');
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: json }} />;
}

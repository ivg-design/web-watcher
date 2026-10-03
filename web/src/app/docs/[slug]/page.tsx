import { ALL_DOCS } from "@/lib/docs";
export const dynamicParams = false;
export function generateStaticParams() { return ALL_DOCS.map((d) => ({ slug: d.slug })); }
export default function DocPage() { return <p>Doc (stub)</p>; }

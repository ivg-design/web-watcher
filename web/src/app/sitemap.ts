import type { MetadataRoute } from "next";
import { toCanonicalUrl } from "@/lib/seo";
import { ALL_DOCS } from "@/lib/docs";
import { getChangelog } from "@/lib/changelog";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  const latest = getChangelog()[0]?.date;
  const lastModified = latest ? new Date(`${latest}T00:00:00Z`) : new Date();
  return [
    { url: toCanonicalUrl("/"), lastModified, changeFrequency: "weekly", priority: 1 },
    { url: toCanonicalUrl("/docs"), lastModified, changeFrequency: "weekly", priority: 0.8 },
    ...ALL_DOCS.map((d) => ({
      url: toCanonicalUrl(`/docs/${d.slug}`),
      lastModified,
      changeFrequency: "monthly" as const,
      priority: 0.6,
    })),
    { url: toCanonicalUrl("/changelog"), lastModified, changeFrequency: "weekly", priority: 0.5 },
  ];
}

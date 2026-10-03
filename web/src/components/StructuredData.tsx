import { toCanonicalUrl, SITE_DESCRIPTION } from "@/lib/seo";
import { getLatestRelease } from "@/lib/release";
import { FALLBACK_RELEASE, REPO_URL } from "@/lib/config";

export default async function StructuredData() {
  const release = await getLatestRelease();
  const home = toCanonicalUrl("/");
  const author = { "@type": "Organization", name: "IVG Design", url: "https://forge.mograph.life" };
  const graph = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "SoftwareApplication",
        "@id": `${home}#app`,
        name: "WebWatcher",
        description: SITE_DESCRIPTION,
        applicationCategory: "UtilitiesApplication",
        operatingSystem: "macOS 13+",
        softwareVersion: release.version,
        downloadUrl: release.dmgUrl,
        fileSize: `${Math.round((FALLBACK_RELEASE.size / 1048576) * 10) / 10} MB`,
        offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
        isAccessibleForFree: true,
        license: "https://opensource.org/licenses/MIT",
        author,
        codeRepository: REPO_URL,
        image: toCanonicalUrl("/images/webwatcher-icon.png"),
        screenshot: toCanonicalUrl("/shots/popover.png"),
        url: home,
        featureList: [
          "Lives in the macOS menu bar, not the Dock",
          "Uses your Safari sessions, so no re-login is needed",
          "Watches any element with CSS selectors or XPath",
          "Notifies only when a value changes",
          "Gmail sender and domain watchers",
          "Custom icon, title and body per watcher",
          "Check intervals from 15 seconds to 30 minutes",
          "Native macOS notifications, optional Herald delivery",
        ],
      },
      {
        "@type": "WebSite",
        "@id": `${home}#site`,
        name: "WebWatcher",
        url: home,
        description: SITE_DESCRIPTION,
        publisher: author,
      },
    ],
  };
  const json = JSON.stringify(graph).replace(/</g, "\\u003c");
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: json }} />;
}

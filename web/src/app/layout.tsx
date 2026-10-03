import type { Metadata, Viewport } from "next";
import { Archivo, JetBrains_Mono } from "next/font/google";
import StructuredData from "@/components/StructuredData";
import { asset } from "@/lib/config";
import { CANONICAL_HOST, SITE_DESCRIPTION, SITE_TITLE, toCanonicalUrl } from "@/lib/seo";
import "./globals.css";

const archivo = Archivo({
  variable: "--font-archivo",
  subsets: ["latin"],
  axes: ["wdth"],
  display: "swap",
});
const jetbrains = JetBrains_Mono({
  variable: "--font-jetbrains",
  subsets: ["latin"],
  weight: ["400", "500", "700"],
  display: "swap",
});

const ogImage = toCanonicalUrl("/og.png");

export const metadata: Metadata = {
  title: { default: SITE_TITLE, template: "%s | WebWatcher" },
  description: SITE_DESCRIPTION,
  applicationName: "WebWatcher",
  keywords: ["WebWatcher", "macOS menu bar app", "website change notifications", "Safari", "badge count notifier", "Gmail sender notifications", "Herald"],
  authors: [{ name: "IVG Design" }],
  creator: "IVG Design",
  publisher: "IVG Design",
  metadataBase: new URL(CANONICAL_HOST),
  alternates: { canonical: toCanonicalUrl("/") },
  icons: { icon: asset("/images/webwatcher-icon.png"), apple: asset("/images/apple-touch-icon.png") },
  openGraph: {
    title: SITE_TITLE,
    description: SITE_DESCRIPTION,
    type: "website",
    url: toCanonicalUrl("/"),
    siteName: "WebWatcher",
    images: [{ url: ogImage, width: 1200, height: 630, alt: "WebWatcher: Stop refreshing. Start knowing." }],
  },
  twitter: { card: "summary_large_image", title: SITE_TITLE, description: SITE_DESCRIPTION, images: [ogImage] },
  robots: { index: true, follow: true, "max-snippet": -1, "max-image-preview": "large", "max-video-preview": -1 },
};

export const viewport: Viewport = { themeColor: "#1A1C23", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${archivo.variable} ${jetbrains.variable}`}>
      <body>
        {children}
        <StructuredData />
      </body>
    </html>
  );
}

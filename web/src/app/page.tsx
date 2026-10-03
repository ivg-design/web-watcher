import SiteHeader from "@/components/SiteHeader";
import Footer from "@/components/Footer";
import Hero from "@/components/landing/Hero";
import HowItWorks from "@/components/landing/HowItWorks";
import Picker from "@/components/landing/Picker";
import WatchTypes from "@/components/landing/WatchTypes";
import Gmail from "@/components/landing/Gmail";
import Herald from "@/components/landing/Herald";
import Privacy from "@/components/landing/Privacy";
import DownloadSection from "@/components/landing/DownloadSection";
import ChangelogPreview from "@/components/landing/ChangelogPreview";
import { getLatestRelease } from "@/lib/release";
import { recentUpdates } from "@/lib/changelog";
import { WatchProvider } from "@/components/watch/WatchContext";

export default async function Home() {
  const release = await getLatestRelease();
  return (
    <WatchProvider>
      <SiteHeader />
      <main>
        <Hero release={release} />
        <HowItWorks />
        <Picker />
        <WatchTypes />
        <Gmail />
        <Herald />
        <Privacy />
        <DownloadSection release={release} />
        <ChangelogPreview entries={recentUpdates(3)} />
      </main>
      <Footer />
    </WatchProvider>
  );
}

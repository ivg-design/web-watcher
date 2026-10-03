import { Globe, MousePointer2, BellRing } from "lucide-react";
import Reveal from "@/components/motion/Reveal";
import { asset } from "@/lib/config";
import "@/styles/sections-a.css";

function Shot({ name, alt }: { name: string; alt: string }) {
  return (
    <div className="step__shot">
      <img
        src={asset(`/shots/${name}.png`)}
        srcSet={`${asset(`/shots/${name}.png`)} 1x, ${asset(`/shots/${name}@2x.png`)} 2x`}
        alt={alt}
        width={560}
        height={877}
        loading="lazy"
      />
    </div>
  );
}

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="section" aria-labelledby="how-title">
      <div className="container">
        <Reveal>
          <p className="eyebrow">How it works</p>
          <h2 id="how-title" className="h2">Three steps. No DevTools.</h2>
          <p className="lede">
            You never type a selector. WebWatcher reads the page that is already open in Safari and
            walks you to the element.
          </p>
        </Reveal>
        <ol className="steps" style={{ listStyle: "none", padding: 0 }}>
          <Reveal as="li" className="step" delay={0}>
            <Shot name="add-watcher-page" alt="Add Watcher, step 1: the Safari page WebWatcher found" />
            <div className="step__meta">
              <span className="step__num">01</span>
              <Globe size={18} aria-hidden="true" />
            </div>
            <h3>Open the page in Safari</h3>
            <p>
              Keep the tab you already use. WebWatcher talks to Safari through Apple Events — no
              extension, no proxy, no password handed to anyone.
            </p>
          </Reveal>
          <Reveal as="li" className="step" delay={0.1}>
            <Shot name="add-watcher-element" alt="Add Watcher, step 2: candidates found by Scan page, with Pick in Safari" />
            <div className="step__meta">
              <span className="step__num">02</span>
              <MousePointer2 size={18} aria-hidden="true" />
            </div>
            <h3>Point at the element</h3>
            <p>
              Scan page groups what it finds: badges, counters, titles. Or Pick in Safari — click,
              then nudge with the arrow keys until the outline sits on the right thing.
            </p>
          </Reveal>
          <Reveal as="li" className="step" delay={0.2}>
            <Shot name="add-watcher-confirm" alt="Add Watcher, step 3: the live reading before saving" />
            <div className="step__meta">
              <span className="step__num">03</span>
              <BellRing size={18} aria-hidden="true" />
            </div>
            <h3>Get told when it changes</h3>
            <p>
              Checks run on your interval in a background tab. A change posts one notification with
              the count; click it to land on the page, or the email.
            </p>
          </Reveal>
        </ol>
      </div>
    </section>
  );
}

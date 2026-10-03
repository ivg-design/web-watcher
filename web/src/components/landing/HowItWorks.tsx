import { Globe, MousePointer2, BellRing } from "lucide-react";
import Reveal from "@/components/motion/Reveal";
import { asset } from "@/lib/config";
import { PointerMock } from "./a/StepVisuals";
import "@/styles/sections-a.css";

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
            <div className="step__card" role="img" aria-label="A Safari page with a few lines of content">
              <span className="skel" style={{ top: 28 }} />
              <span className="skel" style={{ top: 48, width: 160, right: "auto" }} />
              <span className="skel" style={{ top: 68 }} />
            </div>
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
            <PointerMock />
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
            <div className="step__card" role="img" aria-label="Notification: Rive Community, 3 new. Bell badge went 0 to 3, just now">
              <div className="mini-notif">
                <img src={asset("/images/webwatcher-icon.png")} alt="" width={34} height={34} />
                <div>
                  <strong>Rive Community · 3 new</strong>
                  <small>bell badge went 0 → 3 · just now</small>
                </div>
              </div>
            </div>
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

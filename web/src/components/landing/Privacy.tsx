import "@/styles/sections-b.css";
import { BadgeCheck, KeyRound, Laptop, Lock, SquareCheck } from "lucide-react";
import Reveal from "@/components/motion/Reveal";

const ROWS = [
  { Icon: Laptop, h: "No server, no account", p: "Checks happen in your own Safari session. Nothing is proxied, logged or sent anywhere." },
  { Icon: KeyRound, h: "Your logins stay yours", p: "Pages are read in tabs where you are already signed in. WebWatcher never sees a password." },
  { Icon: Lock, h: "Tokens in Keychain", p: "Gmail access uses Google’s own sign-in with the smallest scope; tokens live in the macOS Keychain." },
  { Icon: BadgeCheck, h: "Signed and notarized", p: "Developer ID signed, notarized by Apple, MIT licensed, source on GitHub." },
];
const SWITCHES = [
  "Safari ▸ Developer ▸ Allow JavaScript from Apple Events",
  "System Settings ▸ Automation ▸ Safari & System Events",
  "Notifications ▸ Allow",
];

export default function Privacy() {
  return (
    <section id="privacy" className="section">
      <div className="container">
        <Reveal>
          <div className="eyebrow">Privacy &amp; permissions</div>
          <h2 className="h2" style={{ fontSize: "clamp(32px, 5.6vw, 56px)", maxWidth: "14em" }}>
            It runs on your Mac, in your Safari, and nowhere else.
          </h2>
        </Reveal>
        <div className="privacy__cols">
          {ROWS.map(({ Icon, h, p }, i) => (
            <Reveal key={h} delay={i * 0.08}>
              <div className="pv">
                <Icon size={20} strokeWidth={1.75} aria-hidden="true" />
                <div>
                  <h3>{h}</h3>
                  <p>{p}</p>
                </div>
              </div>
            </Reveal>
          ))}
        </div>
        <div className="switches">
          <strong>Three switches, once:</strong>
          {SWITCHES.map((s) => (
            <span key={s}>
              <SquareCheck size={16} strokeWidth={1.75} aria-hidden="true" />
              {s}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}

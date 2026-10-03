import { ScanSearch, MousePointer2, ShieldCheck, RefreshCw } from "lucide-react";
import Reveal from "@/components/motion/Reveal";
import PickerMock from "./a/PickerMock";
import "@/styles/sections-a.css";

const TICKS = [
  { Icon: ScanSearch, text: "Scan page: badges, counters, titles, aria counts — grouped and ranked" },
  { Icon: MousePointer2, text: "Pick in Safari: live outline, arrow keys walk the DOM, ⏎ confirms" },
  { Icon: ShieldCheck, text: "Confirm: a live read of the value before the watcher is saved" },
  { Icon: RefreshCw, text: "Self-healing: relocates the element after a redesign, tells you if it can’t" },
];

export default function Picker() {
  return (
    <section id="picker" className="picker" aria-labelledby="picker-title">
      <div className="container picker__grid">
        <Reveal>
          <PickerMock />
        </Reveal>
        <Reveal className="picker__copy" delay={0.1}>
          <p className="eyebrow">The guided picker</p>
          <h2 id="picker-title" className="picker__h">It reads the page so you don’t have to.</h2>
          <p className="picker__p">
            Page → Element → Confirm. WebWatcher scans the open tab, groups what looks watchable,
            ranks the likely badge, and shows you what it will track before you save. If the page
            changes its markup later, the assistant re-locates the element instead of going quiet.
          </p>
          <ul className="ticks">
            {TICKS.map(({ Icon, text }) => (
              <li key={text}><Icon size={18} aria-hidden="true" />{text}</li>
            ))}
          </ul>
        </Reveal>
      </div>
    </section>
  );
}

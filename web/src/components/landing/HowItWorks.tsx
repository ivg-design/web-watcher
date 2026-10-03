import StepsDemo from "./steps/StepsDemo";
import "@/styles/steps.css";

export default function HowItWorks() {
  const lede = (
    <>
      You never type a selector. <span className="nw">WebWatcher</span> reads the page that is already open in Safari and
      walks you to the element.
    </>
  );
  return (
    <section id="how-it-works" className="section hw-section" aria-labelledby="how-title">
      <div className="container">
        <div className="hw-head">
          <h2 id="how-title" className="h2-v3">Three steps. No DevTools.</h2>
          {/* Under 1100 the lede follows the title; from 1100 it sits under the running clock (StepsDemo). */}
          <p className="hw-lede hw-lede--head">{lede}</p>
        </div>
        <StepsDemo lede={<p className="hw-lede hw-lede--aside">{lede}</p>} />
      </div>
    </section>
  );
}

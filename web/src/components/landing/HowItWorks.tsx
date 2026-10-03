import StepsDemo from "./steps/StepsDemo";
import "@/styles/steps.css";

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="section hw-section" aria-labelledby="how-title">
      <div className="container">
        <h2 id="how-title" className="h2-v3">Three steps. No DevTools.</h2>
        <p className="hw-lede">
          You never type a selector. WebWatcher reads the page that is already open in Safari and
          walks you to the element.
        </p>
        <StepsDemo />
      </div>
    </section>
  );
}

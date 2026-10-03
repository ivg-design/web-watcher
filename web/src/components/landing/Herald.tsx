import "@/styles/sections-b.css";
import "@/styles/herald.css";
import { HERALD_URL, asset } from "@/lib/config";
import HeraldDemo from "./herald/HeraldDemo";

export default function Herald() {
  return (
    <section id="herald" className="herald">
      <div className="container herald__grid">
        <div>
          <img className="herald__logo" src={asset("/images/herald-logo.png")} alt="Herald" width={88} height={88} />
          <p className="eyebrow"><span className="eyebrow__n">05</span>Pairs with Herald · Free</p>
          <h2 className="herald__h">Make it talk back.</h2>
          <p className="herald__p">
            Herald turns WebWatcher’s alerts into banners that stay until you deal with them, read themselves aloud, and
            carry the buttons that matter — Archive, Mark as read, Open — right on the banner. One switch in Settings; no
            Herald, no change.
          </p>
          <a className="btn btn--herald" href={HERALD_URL} target="_blank" rel="noopener noreferrer">
            <img src={asset("/images/herald-icon.png")} alt="" width={24} height={24} />
            Get Herald — it’s free
          </a>
        </div>
        <HeraldDemo />
      </div>
    </section>
  );
}

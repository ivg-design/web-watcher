import PickerDemo from "./picker/PickerDemo";

export default function Picker() {
  return (
    <section id="picker" className="picker" aria-labelledby="picker-title">
      <div className="container">
        <div className="picker__head">
          <p className="eyebrow">The guided picker</p>
          <h2 id="picker-title" className="picker__h">It reads the page so you don’t have to.</h2>
          <p className="picker__p">
            This is the real flow, on a sketch of a community page. Scan the page, select a candidate to see exactly what
            WebWatcher would track, or point at the element yourself the way Pick in Safari does.
          </p>
        </div>
        <div className="picker__demo">
          <PickerDemo />
          <p className="picker__note">
            Simulation on a sample page. In the app the same steps run on the tab you have open in Safari.
          </p>
        </div>
      </div>
    </section>
  );
}

"use client";

import { PlayCircle } from "lucide-react";

export default function DemoLink() {
  return (
    <button
      type="button"
      className="hero__demo-link"
      onClick={() => window.dispatchEvent(new CustomEvent("ww:open-demo"))}
    >
      <PlayCircle size={20} aria-hidden="true" />
      Watch the 40-second demo
    </button>
  );
}

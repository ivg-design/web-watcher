"use client";

import { useEffect, useRef, useState } from "react";
import { SAMPLES, fmt, barLevel, type Key } from "./samples";

const LABEL_H = 22;
const MIN_GAP = 4;

type Props = { sample: Key; playing: boolean; getAudio: () => HTMLAudioElement | null };

// The voice ruler: one 1 px tick per 40 ms of the sample, height from the real peak. Lit up to the playhead while it plays.
export default function Ruler({ sample, playing, getAudio }: Props) {
  const wrap = useRef<HTMLDivElement>(null);
  const cv = useRef<HTMLCanvasElement>(null);
  const tRef = useRef(0);
  const [tenths, setTenths] = useState(0);
  const dur = SAMPLES[sample].dur;

  useEffect(() => {
    const w = wrap.current;
    const c = cv.current;
    if (!w || !c) return;
    const { peaks } = SAMPLES[sample];
    const root = document.documentElement;
    const css = getComputedStyle(root);
    const unlit = css.getPropertyValue("--n-line-2").trim() || "#666";
    const lit = css.getPropertyValue("--n-ink").trim() || "#eee";
    const muted = css.getPropertyValue("--n-muted").trim() || "#999";
    const family = getComputedStyle(c).fontFamily;
    let W = 0;
    let H = 0;
    let rafId = 0;
    let lastLit = -1;

    const draw = (t: number) => {
      const dpr = window.devicePixelRatio || 1;
      const ctx = c.getContext("2d");
      if (!ctx || !W) return;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, W, H);
      const rh = H - LABEL_H;
      const group = Math.max(1, Math.ceil(peaks.length / Math.max(1, Math.floor(W / MIN_GAP))));
      const m = Math.ceil(peaks.length / group);
      const span = SAMPLES[sample].dur;
      const nLit = t > 0 ? Math.min(m, Math.floor((t / span) * m) + 1) : 0;
      // baseline
      ctx.fillStyle = unlit;
      ctx.fillRect(0, rh, W, 1);
      for (let i = 0; i < m; i++) {
        let pk = 0;
        for (let j = i * group; j < Math.min(peaks.length, (i + 1) * group); j++) pk = Math.max(pk, peaks[j]);
        const h = Math.round(6 + pk * (rh - 6));
        const x = Math.round((i / m) * (W - 1));
        ctx.fillStyle = i < nLit ? lit : unlit;
        ctx.fillRect(x, rh - h, 1, h);
      }
      // seconds
      ctx.font = `500 ${W < 700 ? 11 : 12}px ${family}`;
      ctx.textBaseline = "top";
      const step = W < 700 ? 2 : 1;
      for (let s = 0; s <= span; s += step) {
        const x = Math.round((s / span) * (W - 1));
        ctx.fillStyle = unlit;
        ctx.fillRect(x, rh, 1, 5);
        ctx.fillStyle = muted;
        const label = `${s} s`;
        const tw = ctx.measureText(label).width;
        ctx.fillText(label, Math.min(Math.max(0, x - (s === 0 ? 0 : tw / 2)), W - tw), rh + 8);
      }
      if (t > 0) {
        ctx.fillStyle = lit;
        ctx.fillRect(Math.min(W - 1, Math.round((t / span) * (W - 1))), 0, 1, rh);
      }
      if (nLit !== lastLit) {
        lastLit = nLit;
        w.dataset.lit = String(nLit);
      }
    };

    const size = () => {
      const r = w.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      W = Math.round(r.width);
      H = Math.round(r.height);
      c.width = Math.round(W * dpr);
      c.height = Math.round(H * dpr);
      draw(tRef.current);
    };
    size();
    const ro = new ResizeObserver(size);
    ro.observe(w);

    const scope = w.closest("section");
    const loop = () => {
      const a = getAudio();
      const t = a ? Math.min(a.currentTime, SAMPLES[sample].dur) : 0;
      tRef.current = t;
      draw(t);
      const tn = Math.floor(t * 10);
      setTenths((p) => (p === tn ? p : tn));
      scope?.querySelectorAll<HTMLElement>(".hx__meter i").forEach((el, i) => {
        el.style.setProperty("--l", barLevel(sample, t, i % 5, 5).toFixed(2));
      });
      rafId = requestAnimationFrame(loop);
    };
    if (playing) rafId = requestAnimationFrame(loop);
    else {
      tRef.current = 0;
      lastLit = -1;
      draw(0);
    }
    return () => {
      cancelAnimationFrame(rafId);
      ro.disconnect();
    };
  }, [sample, playing, getAudio]);

  return (
    <div className="vr">
      <div className="vr__ruler" ref={wrap} data-testid="hv-ruler" data-lit="0" data-sample={sample}>
        <canvas ref={cv} role="img" aria-label="Waveform of the spoken banner" />
      </div>
      <div className="vr__row">
        <p className="vr__cap t-label">Herald can read a banner aloud. Press the speaker on a banner. This is the real sample.</p>
        <span className="vr__time t-label t-num" data-testid="hv-time">
          {fmt(playing ? tenths / 10 : 0)} / {fmt(dur)}
        </span>
      </div>
    </div>
  );
}

/**
 * Rive renderer for the mark. Contract: view model `Mark` (lookX, lookY, badge, hover, reduced, tick, sand, turn),
 * state machine `Mark`. The sand is not a timeline: the page writes the progress of the current check (0..1) into `sand`,
 * so the glass drains over the real interval. `tick` flips the glass with the eye's pop (a check); `turn` flips it
 * without the pop (the idle loop at intervals above a minute).
 */
import { useEffect, useRef } from "react";
import {
  RuntimeLoader,
  useRive,
  useViewModelInstanceBoolean,
  useViewModelInstanceNumber,
  useViewModelInstanceTrigger,
} from "@rive-app/react-canvas-lite";
import { asset } from "@/lib/config";

// Self-hosted runtime: no request ever leaves for unpkg/jsdelivr (this module loads before the first Rive instance).
RuntimeLoader.setWasmUrl(asset("/rive/rive.wasm"));
RuntimeLoader.setWasmFallbackUrl(asset("/rive/rive_fallback.wasm"));

export interface RiveProps {
  sinkRef: React.MutableRefObject<((x: number, y: number) => void) | null>;
  unseen: number;
  hover: boolean;
  reduced: boolean;
  tickSignal: number;
  /** The check interval in seconds and the time (Date.now) of the last check. */
  interval: number;
  lastCheck: number;
  onReady: () => void;
  onError: () => void;
}

const FLIP_MS = 500;
const IDLE_MS = 6500;

export default function WatchMarkRive({ sinkRef, unseen, hover, reduced, tickSignal, interval, lastCheck, onReady, onError }: RiveProps) {
  const { rive, RiveComponent, canvas } = useRive({
    src: asset("/rive/watcher-mark.riv"),
    stateMachines: "Mark",
    autoplay: true,
    autoBind: true,
    onLoad: onReady,
    onLoadError: onError,
  });
  const vmi = rive?.viewModelInstance ?? null;
  const lookX = useViewModelInstanceNumber("lookX", vmi);
  const lookY = useViewModelInstanceNumber("lookY", vmi);
  const badge = useViewModelInstanceNumber("badge", vmi);
  const hov = useViewModelInstanceBoolean("hover", vmi);
  const red = useViewModelInstanceBoolean("reduced", vmi);
  const tick = useViewModelInstanceTrigger("tick", vmi);
  const sand = useViewModelInstanceNumber("sand", vmi);
  const turn = useViewModelInstanceTrigger("turn", vmi);

  const refs = useRef({ lookX, lookY });
  useEffect(() => {
    refs.current = { lookX, lookY };
  });
  useEffect(() => {
    sinkRef.current = (x, y) => { refs.current.lookX.setValue?.(x); refs.current.lookY.setValue?.(y); };
    return () => { sinkRef.current = null; };
  }, [sinkRef]);

  useEffect(() => { badge.setValue?.(unseen); }, [badge, unseen]);
  useEffect(() => { hov.setValue?.(hover); }, [hov, hover]);
  useEffect(() => { red.setValue?.(reduced); }, [red, reduced]);
  const last = useRef(tickSignal);
  useEffect(() => {
    if (tickSignal !== last.current) { last.current = tickSignal; tick.trigger?.(); }
  }, [tick, tickSignal]);

  // Sand = time. At 60 s or less the glass drains over the interval itself; above that it keeps a 6.5 s idle loop
  // (the popover carries the real countdown). Ten writes a second is far below a pixel of sand per write.
  const sandRef = useRef({ sand, turn });
  useEffect(() => { sandRef.current = { sand, turn }; });
  // Changing the interval re-arms the page's timer, so the glass starts over from that moment.
  const armed = useRef(0);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) { first.current = false; return; }
    armed.current = Date.now();
  }, [interval]);
  useEffect(() => {
    if (!vmi) return;
    if (reduced) { sandRef.current.sand.setValue?.(0.46); return; }
    const real = interval <= 60;
    const span = real ? interval * 1000 : IDLE_MS;
    let lap = 0;
    const write = () => {
      if (document.hidden) return;
      const since = Date.now() - Math.max(lastCheck, armed.current);
      let t = since;
      if (!real) {
        const n = Math.floor(since / IDLE_MS);
        if (n !== lap) { lap = n; sandRef.current.turn.trigger?.(); }
        t = since - n * IDLE_MS;
      }
      const v = Math.max(0, Math.min(1, (t - FLIP_MS) / (span - FLIP_MS)));
      sandRef.current.sand.setValue?.(v);
      canvas?.setAttribute("data-sand", v.toFixed(3));
    };
    write();
    const id = window.setInterval(write, 100);
    return () => window.clearInterval(id);
  }, [vmi, canvas, interval, lastCheck, reduced]);

  return <RiveComponent className="ww-mark__rive" aria-hidden />;
}

/** Rive renderer for the mark. Contract: view model `Mark` (lookX, lookY, badge, hover, reduced, tick), state machine `Mark`. */
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
  onReady: () => void;
  onError: () => void;
}

export default function WatchMarkRive({ sinkRef, unseen, hover, reduced, tickSignal, onReady, onError }: RiveProps) {
  const { rive, RiveComponent } = useRive({
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

  return <RiveComponent className="ww-mark__rive" aria-hidden />;
}

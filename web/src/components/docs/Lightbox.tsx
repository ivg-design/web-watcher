"use client";

import { useEffect, useRef, useState } from "react";
import { X } from "lucide-react";

interface Open { src: string; alt: string; caption: string; w?: number; h?: number }

/** Enlarge view for docs figures: any `.shot__zoom` button opens its image in a modal dialog (Esc or Close returns focus). */
export default function Lightbox() {
  const ref = useRef<HTMLDialogElement>(null);
  const opener = useRef<HTMLElement | null>(null);
  const [open, setOpen] = useState<Open | null>(null);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      const btn = (e.target as HTMLElement).closest<HTMLButtonElement>(".shot__zoom");
      if (!btn) return;
      const img = btn.querySelector("img");
      const cap = btn.closest("figure")?.querySelector("figcaption");
      opener.current = btn;
      setOpen({
        src: btn.dataset.full || img?.currentSrc || "",
        alt: img?.alt || "",
        caption: cap?.textContent || "",
        w: Number(btn.dataset.w) || undefined,
        h: Number(btn.dataset.h) || undefined,
      });
    };
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  }, []);

  useEffect(() => {
    const d = ref.current;
    if (open && d && !d.open) d.showModal();
  }, [open]);

  const close = () => ref.current?.close();
  const onClose = () => { setOpen(null); opener.current?.focus(); };

  return (
    <dialog ref={ref} className="lightbox" aria-label="Enlarged image" onClose={onClose} onClick={(e) => { if (e.target === ref.current) close(); }}>
      {open && (
        <figure className="lightbox__fig">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={open.src} alt={open.alt} width={open.w} height={open.h} />
          <figcaption>
            <span>{open.caption}</span>
            <button type="button" className="lightbox__x" onClick={close} autoFocus><X size={16} aria-hidden /> Close</button>
          </figcaption>
        </figure>
      )}
    </dialog>
  );
}

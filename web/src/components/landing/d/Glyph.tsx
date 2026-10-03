"use client";

import { motion, useAnimationControls } from "framer-motion";
import { useEffect, useRef } from "react";

/** Menu-bar hourglass glyph. The eye fades in at the end of the hero sequence; hover 3s to make it blink. */
export default function Glyph({ animate, eyeDelay }: { animate: boolean; eyeDelay: number }) {
  const blink = useAnimationControls();
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);

  const enter = () => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      void blink.start({ scaleY: [1, 0.08, 1], transition: { duration: 0.3, ease: [0.25, 1, 0.5, 1] } });
    }, 3000);
  };
  const leave = () => { if (timer.current) clearTimeout(timer.current); };

  return (
    <span className="demo__glyph" onPointerEnter={enter} onPointerLeave={leave}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M5 3h14M5 21h14" />
        <path d="M6.5 3v3.2c0 1.6 1 2.9 2.5 3.9l3 1.9-3 1.9c-1.5 1-2.5 2.3-2.5 3.9V21M17.5 3v3.2c0 1.6-1 2.9-2.5 3.9L12 12l3 1.9c1.5 1 2.5 2.3 2.5 3.9V21" />
        <motion.g
          initial={animate ? { opacity: 0, scale: 0.5 } : false}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: eyeDelay, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
        >
          <motion.g animate={blink} style={{ originX: "12px", originY: "12px" }}>
            <ellipse cx="12" cy="12" rx="4.2" ry="3" fill="#e9ebf3" strokeWidth="1.4" />
            <circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none" />
          </motion.g>
        </motion.g>
      </svg>
    </span>
  );
}

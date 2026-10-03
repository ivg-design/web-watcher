"use client";

import { motion } from "framer-motion";

/** Digit counter that rolls 0 -> n with a translateY stack (transform only). */
export default function Roll({
  to,
  delay,
  duration,
  animate,
}: {
  to: number;
  delay: number;
  duration: number;
  animate: boolean;
}) {
  const digits = Array.from({ length: to + 1 }, (_, i) => i);
  const end = `${-(100 / digits.length) * to}%`;
  return (
    <motion.span
      className="demo__roll"
      aria-hidden
      initial={animate ? { y: "0%" } : false}
      animate={{ y: end }}
      transition={{ delay, duration, ease: [0.22, 1, 0.36, 1] }}
      style={animate ? undefined : { y: end }}
    >
      {digits.map((d) => (
        <span key={d}>{d}</span>
      ))}
    </motion.span>
  );
}

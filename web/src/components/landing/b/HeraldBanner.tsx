"use client";

import { motion, useReducedMotion } from "framer-motion";
import { asset } from "@/lib/config";

function Inner() {
  return (
    <>
      <div className="banner__top">
        <img src={asset("/images/herald-icon.png")} alt="" width={26} height={26} />
        <div>
          <div className="banner__app">Herald · WebWatcher · Email</div>
          <div className="banner__title">3 new from Rive team</div>
        </div>
        <span className="banner__count">3</span>
      </div>
      <div className="banner__body">Scripting update · Office hours · Release notes</div>
      <div className="banner__btns">
        <button type="button" className="bbtn bbtn--open">Open</button>
        <button type="button" className="bbtn">Mark as Read</button>
        <button type="button" className="bbtn">Archive</button>
        <button type="button" className="bbtn" aria-describedby="snooze-tip">
          Snooze
          <span className="tip" id="snooze-tip" role="tooltip">returns at 9:00</span>
        </button>
      </div>
    </>
  );
}

/** Enters once from the top-right like a real banner. */
export default function HeraldBanner() {
  const reduce = useReducedMotion();
  if (reduce) return <div className="banner"><Inner /></div>;
  return (
    <motion.div
      className="banner"
      initial={{ opacity: 0, x: 40, y: -24 }}
      whileInView={{ opacity: 1, x: 0, y: 0 }}
      viewport={{ once: true, margin: "0px 0px -15% 0px" }}
      transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
    >
      <Inner />
    </motion.div>
  );
}

/**
 * Formerly a scroll-in animation. Scroll reveals explain no state change, so this is now a plain
 * wrapper; the delay/y props are accepted and ignored so call sites stay valid.
 */
export default function Reveal({
  children,
  className,
  as = "div",
}: {
  children: React.ReactNode;
  delay?: number;
  y?: number;
  className?: string;
  as?: "div" | "li" | "section" | "article";
}) {
  const Tag = as;
  return <Tag className={className}>{children}</Tag>;
}

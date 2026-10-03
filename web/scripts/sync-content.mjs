// Copies README.md and CHANGELOG.md from the repo root into web/content so the site can be
// built from web/ alone (e.g. on a host that only sees this folder). Skipped when the root files are absent.
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");
const dest = join(here, "..", "content");
mkdirSync(dest, { recursive: true });
for (const f of ["CHANGELOG.md", "README.md"]) {
  const src = join(root, f);
  if (existsSync(src)) copyFileSync(src, join(dest, f));
}

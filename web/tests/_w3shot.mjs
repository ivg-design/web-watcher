import { open, sleep } from "/Users/ivg/github/web-watcher/web/tests/_h.mjs";
for (const [w,h] of [[1440,900],[390,844]]) {
  const { browser, page } = await open(); await page.setViewport({width:w,height:h});
  await page.goto("http://localhost:3101/",{waitUntil:"networkidle2"});
  await page.$eval("#interval",e=>e.scrollIntoView({block:"center"})); await sleep(1500);
  const el = await page.$("#interval"); await el.screenshot({path:"/private/tmp/claude-501/-Users-ivg-github-web-watcher/1b5c3420-5ad4-4c49-88f4-04aad1e374ed/scratchpad/W3/"+w+".png"}); await browser.close();
}

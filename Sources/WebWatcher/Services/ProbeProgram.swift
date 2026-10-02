import Foundation

/// The injected program that runs inside the user's own Safari tab via
/// AppleScript `do JavaScript` (see Services/ProbeScript.swift, which builds the
/// `__CFG__` object and substitutes it in before injection).
///
/// Behavior is specified in the design spec §3.5/§4: check/diagnose/suggest stay
/// byte-for-byte identical to the pre-assistant program except for the additions
/// documented inline below (tab-liveness guard, `autoBadge` strategy, `scan`,
/// and the `pick*`/`highlight` interactive modes). Kept as one raw string so the
/// JS reads normally; the whole IIFE is wrapped in try/catch and always returns
/// a JSON string — see the top-level `try` at the bottom of the program.
enum ProbeProgram {
    static let source: String = #"""
(function () {
  var CFG = __CFG__;
  var steps = [];
  function st(label, ok, note) { if (CFG.diag) steps.push({ label: label, ok: ok, note: note || null }); }
  function fin(o) {
    o.title = document.title;
    o.href = location.href;
    o.tabState = /^(https?|file):/.test(location.href) ? 'live' : 'blank';
    o.visible = (document.visibilityState === 'visible');
    if (CFG.diag) o.steps = steps;
    return JSON.stringify(o);
  }
  function miss(code, detail) { return fin({ status: 'MISS', code: code, detail: detail || null }); }
  function errOut(code, detail) { return fin({ status: 'ERR', code: code, detail: detail || null }); }
  function okOut(v) { return fin({ status: 'OK', value: String(v) }); }
  function zeroOut() { return fin({ status: 'ZERO' }); }

  function shadowRoots() {
    var roots = [], stack = [document], guard = 0;
    while (stack.length && guard < 400) {
      guard++;
      var root = stack.shift(), all;
      try { all = root.querySelectorAll('*'); } catch (e) { continue; }
      for (var i = 0; i < all.length; i++) {
        var sr = all[i].shadowRoot;
        if (sr) { roots.push(sr); stack.push(sr); }
      }
    }
    return roots;
  }

  function dq(sel) {
    if (!sel) return null;
    var el = null;
    try { el = document.querySelector(sel); } catch (e) { throw { ww: 'BAD_SELECTOR', m: String(e.message || e) }; }
    if (el || !CFG.pierce) return el;
    var roots = shadowRoots();
    for (var i = 0; i < roots.length; i++) {
      try { var f = roots[i].querySelector(sel); if (f) return f; } catch (e) { }
    }
    return null;
  }

  function dqAll(sel) {
    var res = [];
    try { res = [].slice.call(document.querySelectorAll(sel)); } catch (e) { throw { ww: 'BAD_SELECTOR', m: String(e.message || e) }; }
    if (!CFG.pierce) return res;
    var roots = shadowRoots();
    for (var i = 0; i < roots.length; i++) {
      try { res = res.concat([].slice.call(roots[i].querySelectorAll(sel))); } catch (e) { }
    }
    return res;
  }

  function xpath(sel, all) {
    try {
      if (all) {
        var r = document.evaluate(sel, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
        return r.snapshotLength;
      }
      return document.evaluate(sel, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
    } catch (e) { throw { ww: 'BAD_SELECTOR', m: String(e.message || e) }; }
  }

  // Odometer-style components (e.g. number-flow) keep every digit 0-9 in the DOM and
  // select the visible one with a CSS custom property, so text scraping returns garbage.
  function readOdometer(el) {
    var root = el.shadowRoot || el;
    var digits;
    try { digits = root.querySelectorAll('[part~="digit"]'); } catch (e) { return null; }
    if (!digits || !digits.length) return null;
    var s = '';
    for (var i = 0; i < digits.length; i++) {
      var v = digits[i].style ? digits[i].style.getPropertyValue('--current') : '';
      if (v === '' || v === null) return null;
      var n = parseInt(v, 10);
      if (isNaN(n)) return null;
      s += String(n);
    }
    return s;
  }

  function readValue(el, attr) {
    if (attr) {
      var a = el.getAttribute(attr);
      return a === null ? '' : String(a);
    }
    var odo = readOdometer(el);
    if (odo !== null) return odo;
    var t = (el.innerText || el.textContent || '');
    if (!t && el.shadowRoot) t = (el.shadowRoot.textContent || '');
    t = t.trim();
    // A blob this large is never a badge; treat it as unreadable rather than parsing junk.
    if (t.length > 40) return '';
    return t;
  }

  function firstNumber(s) {
    var m = String(s).match(/([0-9][0-9.,\s ]*)(\+)?/);
    if (!m) return null;
    return m[0].replace(/[\s ]+$/, '');
  }

  // --- Selector ladder (describe/scan/pick) -----------------------------------
  var ID_BAD_RE = /\d{3,}|^[a-f0-9]{8,}$|^(ember|react|radix|headlessui|mui|rc-|:r|__)/i;
  var UNSTABLE_CLASS_RES = [
    /[:\/\[\]!]/,
    /^(css|sc|jss|styled|emotion|chakra|_|svelte|ng)[-_]/,
    /^(w|h|p|m|px|py|pt|pb|pl|pr|mx|my|mt|mb|ml|mr|gap|text|bg|border|flex|grid|rounded|shadow|top|left|right|bottom|z|opacity|min|max|size|leading|tracking|font|space|inset|translate|scale|rotate|duration|transition|hover|focus|active|group|peer|sm|md|lg|xl)-/,
    /\d/
  ];

  function isHashClass(c) {
    if (c.length < 5 || c.length > 12) return false;
    if (/[-_]/.test(c)) return false;
    if (!/^[A-Za-z0-9]+$/.test(c)) return false;
    var transitions = 0;
    for (var i = 1; i < c.length; i++) {
      var a = c.charAt(i - 1), b = c.charAt(i);
      var aUp = a >= 'A' && a <= 'Z', aLo = a >= 'a' && a <= 'z';
      var bUp = b >= 'A' && b <= 'Z', bLo = b >= 'a' && b <= 'z';
      if ((aUp && bLo) || (aLo && bUp)) transitions++;
    }
    return transitions >= 2;
  }

  function classStable(raw) {
    var c = raw.charAt(0) === '!' ? raw.slice(1) : raw;
    if (!c) return false;
    for (var i = 0; i < UNSTABLE_CLASS_RES.length; i++) if (UNSTABLE_CLASS_RES[i].test(c)) return false;
    if (isHashClass(c)) return false;
    return true;
  }

  function uniqueIn(root, sel) {
    try { return root.querySelectorAll(sel).length === 1; } catch (e) { return false; }
  }

  function escAttr(v) { return String(v).replace(/(["\\])/g, '\\$1'); }
  function escClass(c) { return c.replace(/([^\w-])/g, '\\$1'); }

  function selectorForSelf(el, root) {
    var tag = el.tagName.toLowerCase();
    var testAttrs = ['data-testid', 'data-test', 'data-cy', 'data-id', 'data-qa', 'data-e2e'];
    for (var i = 0; i < testAttrs.length; i++) {
      var v = el.getAttribute(testAttrs[i]);
      if (v) {
        var s = tag + '[' + testAttrs[i] + '="' + escAttr(v) + '"]';
        if (uniqueIn(root, s)) return { sel: s, tier: 1 };
      }
    }
    var id = el.getAttribute('id');
    if (id && !ID_BAD_RE.test(id) && /^[A-Za-z][\w-]*$/.test(id)) {
      var s2 = '#' + escClass(id);
      if (uniqueIn(root, s2)) return { sel: s2, tier: 2 };
    }
    var al = el.getAttribute('aria-label');
    if (al && al.length <= 60) {
      var s3 = tag + '[aria-label="' + escAttr(al) + '"]';
      if (uniqueIn(root, s3)) return { sel: s3, tier: 2 };
    }
    var nm = el.getAttribute('name');
    if (nm) {
      var s4 = tag + '[name="' + escAttr(nm) + '"]';
      if (uniqueIn(root, s4)) return { sel: s4, tier: 2 };
    }
    var ti = el.getAttribute('title');
    if (ti) {
      var s5 = tag + '[title="' + escAttr(ti) + '"]';
      if (uniqueIn(root, s5)) return { sel: s5, tier: 2 };
    }
    var href = el.getAttribute('href');
    if (href) {
      var path = href.replace(/^https?:\/\/[^\/]*/, '').split('?')[0];
      if (path && path.length <= 50) {
        var s6 = tag + '[href*="' + escAttr(path) + '"]';
        if (uniqueIn(root, s6)) return { sel: s6, tier: 3 };
      }
    }
    var clsAttr = el.getAttribute('class') || '';
    var cls = clsAttr.split(/\s+/).filter(function (c) { return c && classStable(c); });
    if (cls.length) {
      var pick = cls.slice(0, 2);
      var s7 = tag + pick.map(function (c) { return '.' + escClass(c); }).join('');
      if (uniqueIn(root, s7)) return { sel: s7, tier: 4 };
    }
    return null;
  }

  function nthOfType(el) {
    var idx = 1;
    for (var p = el.previousElementSibling; p; p = p.previousElementSibling) if (p.tagName === el.tagName) idx++;
    return idx;
  }

  function selectorFor(el, root, depth) {
    depth = depth || 0;
    var own = selectorForSelf(el, root);
    if (own) return own;
    if (depth >= 4 || !el.parentElement) {
      return { sel: el.tagName.toLowerCase() + ':nth-of-type(' + nthOfType(el) + ')', tier: 5 };
    }
    var parentSel = selectorFor(el.parentElement, root, depth + 1);
    var combined = parentSel.sel + ' > ' + el.tagName.toLowerCase();
    if (uniqueIn(root, combined)) return { sel: combined, tier: 5 };
    var withNth = parentSel.sel + ' > ' + el.tagName.toLowerCase() + ':nth-of-type(' + nthOfType(el) + ')';
    return { sel: withNth, tier: 5 };
  }

  // --- Anchor ------------------------------------------------------------------
  var ANCHOR_TAG_SEL = 'a,button,[role="button"],[role="link"],[role="menuitem"],li,nav,header,[data-testid]';

  function anchorFor(el, allowSelf) {
    function tryNode(node) {
      if (!node || node.nodeType !== 1) return null;
      if (node === el && !allowSelf) return null;
      var ok = false;
      try { ok = node.matches(ANCHOR_TAG_SEL); } catch (e) { ok = false; }
      if (!ok) return null;
      var root = node.getRootNode ? node.getRootNode() : document;
      var s = selectorFor(node, root);
      if (s && s.tier <= 3) return s.sel;
      return null;
    }
    // F3: a badge's own value container often carries a [data-testid] too (it is
    // itself an "anchor-shaped" node) but disappears along with the badge at zero,
    // so it is not a usable anchor. Its sibling — the always-present bell/button —
    // is. Check siblings before the cursor itself at every depth so that sibling
    // wins whenever both would otherwise match.
    var cursor = el, depth = 0;
    while (cursor && depth <= 8) {
      var r = tryNode(cursor.previousElementSibling);
      if (r) return r;
      r = tryNode(cursor.nextElementSibling);
      if (r) return r;
      r = tryNode(cursor);
      if (r) return r;
      cursor = cursor.parentElement;
      depth++;
    }
    return null;
  }

  function anchorName(anchorSel, fallbackEl) {
    var node = null;
    if (anchorSel) { try { node = dq(anchorSel); } catch (e) { node = null; } }
    if (!node) node = fallbackEl;
    if (!node) return 'the page';
    var al = node.getAttribute && node.getAttribute('aria-label');
    if (al) return al;
    var tid = node.getAttribute && node.getAttribute('data-testid');
    if (tid) {
      var words = tid.split(/[-_]/).filter(function (w) { return w && !/^(button|popover|menu|link|icon)$/i.test(w); });
      if (words.length) return words.map(function (w) { return w.charAt(0).toUpperCase() + w.slice(1).toLowerCase(); }).join(' ');
    }
    var txt = (node.textContent || '').trim();
    if (txt && txt.length <= 24) return txt;
    // §9.2: a bare tag name ("div", "span") reads like a bug in the assistant's
    // copy; "this element" is honest about not having a better name to offer.
    return 'this element';
  }

  // --- describe() ----------------------------------------------------------
  var ARIA_COUNT_RE = /([0-9][0-9,.]*)\s*\+?\s*(new|unread|notification|message)/i;
  var SHORT_NUM_RE = /^\d{1,5}\+?$/;
  var ATTR_NUM_RE = /count|badge|unread|number|value|total/i;

  function shortNumFromText(t) {
    var stripped = String(t).replace(/[,.\s\u00a0]/g, '');
    return SHORT_NUM_RE.test(stripped) ? stripped : null;
  }

  function isClickableTag(el) {
    try { return el.matches('a,button,[role="button"],[role="link"],[role="menuitem"]'); } catch (e) { return false; }
  }

  function findNumberDescendant(root, exclude) {
    var els;
    try { els = root.querySelectorAll('*'); } catch (e) { return null; }
    for (var i = 0; i < els.length; i++) {
      var d = els[i];
      if (d === exclude) continue;
      if (!d.children || d.children.length === 0) {
        var n = shortNumFromText((d.textContent || '').trim());
        if (n) return d;
        var odo = readOdometer(d);
        if (odo !== null && shortNumFromText(odo)) return d;
      }
      var attrs = d.attributes;
      for (var a = 0; a < attrs.length; a++) {
        if (ATTR_NUM_RE.test(attrs[a].name)) {
          var v = shortNumFromText(attrs[a].value || '');
          if (v) return d;
        }
      }
    }
    return null;
  }

  function shapeAndPlace(el, rect) {
    var shape = 'number';
    try {
      var cs = getComputedStyle(el);
      var br = parseFloat(cs.borderRadius) || 0;
      var minSide = Math.min(rect.w || 0, rect.h || 0);
      if (minSide > 0 && br >= minSide * 0.35) {
        shape = (rect.w <= 22 && rect.h <= 22) ? 'small circle' : 'pill';
      }
    } catch (e) { }
    var place = 'in the page';
    try {
      if (el.closest && el.closest('header,[role="banner"]')) place = 'in the page header';
      else if (el.closest && el.closest('nav,[role="navigation"]')) place = 'in the navigation';
      else if (el.closest && el.closest('aside')) place = 'in the sidebar';
    } catch (e) { }
    return shape + ' ' + place;
  }

  function scoreFor(el, strategy, tier, rect, anchorNameStr) {
    var s = 0;
    var hay = (((el.getAttribute && el.getAttribute('data-testid')) || '') + ' ' + (el.className || '') + ' ' +
      ((el.getAttribute && el.getAttribute('aria-label')) || '')).toLowerCase();
    if (/badge|unread|notif|indicator|counter/i.test(hay)) s += 4;
    var txt = (el.textContent || '').trim().replace(/[,.\s\u00a0]/g, '');
    if (/^\d{1,3}\+?$/.test(txt)) s += 3;
    var isNotifKeyword = /notif|message|inbox|chat|mail|alert|activity|dm|bell/i.test(anchorNameStr || '');
    if (isNotifKeyword) s += 3;
    if ((rect.y || 0) < 160) s += 2;
    try { if (el.closest && el.closest('header,nav,[role="banner"],[role="navigation"],aside')) s += 2; } catch (e) { }
    try {
      var cs = getComputedStyle(el);
      var br = parseFloat(cs.borderRadius) || 0;
      var minSide = Math.min(rect.w || 0, rect.h || 0);
      var pill = minSide > 0 && br >= minSide * 0.4;
      var bg = cs.backgroundColor || '';
      var nonTransparent = bg && bg.indexOf('rgba(0, 0, 0, 0)') === -1 && bg !== 'transparent';
      if (pill || nonTransparent) s += 2;
    } catch (e) { }
    if (strategy === 'ariaCount') s += 2;
    if (el.tagName === 'SUP') s += 1;
    try { var fz = parseFloat(getComputedStyle(el).fontSize); if (fz && fz <= 12) s += 1; } catch (e) { }
    if (txt.length >= 4) s -= 3;
    try { if (el.closest && el.closest('article,main p,table,td')) s -= 5; } catch (e) { }
    if (tier >= 5) s -= 2;
    if (strategy === 'autoBadge' && isNotifKeyword) s += 3;
    return s;
  }

  function describe(el, opts) {
    var explicit = !!(opts && opts.explicit);
    var root = el.getRootNode ? el.getRootNode() : document;
    var inShadow = !!(root && root.host);
    var rectRaw;
    try { rectRaw = el.getBoundingClientRect(); } catch (e) { rectRaw = { left: 0, top: 0, width: 0, height: 0 }; }
    var rect = { x: rectRaw.left || 0, y: rectRaw.top || 0, w: rectRaw.width || 0, h: rectRaw.height || 0 };

    var baseSel = selectorFor(el, root);
    var describedEl = el, describedSel = baseSel;
    var strategy, value = null, attr = null, allowSelf = false;

    var al = el.getAttribute('aria-label') || '';
    var am = al.match(ARIA_COUNT_RE);
    if (am) {
      strategy = 'ariaCount'; value = am[1]; allowSelf = true;
    } else {
      var odo = readOdometer(el);
      if (odo !== null && shortNumFromText(odo)) {
        strategy = 'badgeText'; value = odo;
      } else if ((!el.children || el.children.length === 0) && shortNumFromText((el.textContent || '').trim())) {
        strategy = 'badgeText'; value = shortNumFromText((el.textContent || '').trim());
      } else {
        var attrs = el.attributes, hitAttr = null, hitVal = null;
        for (var i = 0; i < attrs.length; i++) {
          if (ATTR_NUM_RE.test(attrs[i].name)) {
            var v = shortNumFromText(attrs[i].value || '');
            if (v) { hitAttr = attrs[i].name; hitVal = v; break; }
          }
        }
        if (hitAttr) {
          strategy = 'badgeAttr'; attr = hitAttr; value = hitVal;
        } else {
          var clickable = isClickableTag(el);
          var searchRoot = clickable ? (el.parentElement || el) : el;
          var leaf = explicit ? null : findNumberDescendant(searchRoot, el);
          if (leaf) return describe(leaf);
          if (clickable) {
            strategy = 'autoBadge'; value = '0'; allowSelf = true;
          } else {
            var txt2 = (el.textContent || '').trim();
            if (txt2 && txt2.length <= 80) { strategy = 'text'; value = txt2; }
            else { strategy = 'exists'; value = 'true'; }
          }
        }
      }
    }

    // Value-preserving promotion (numeric leaves only).
    if (strategy === 'badgeText' || strategy === 'badgeAttr') {
      var text = (describedEl.textContent || '').trim();
      var anc = describedEl.parentElement, steps = 0, bestSel = describedSel, bestEl = describedEl;
      while (anc && steps < 3) {
        var ancText = (anc.textContent || '').trim();
        if (ancText === text) {
          var ownSel = selectorForSelf(anc, root);
          if (ownSel && bestSel && ownSel.tier < bestSel.tier) { bestSel = ownSel; bestEl = anc; }
        }
        anc = anc.parentElement; steps++;
      }
      describedEl = bestEl; describedSel = bestSel;
    }

    var anchorSel = anchorFor(el, allowSelf);
    var name = anchorName(anchorSel, el);

    var selfIsAnchor = (strategy === 'ariaCount' || strategy === 'autoBadge');
    var selector = describedSel ? describedSel.sel : (baseSel ? baseSel.sel : '');
    var finalAnchor = selfIsAnchor ? (anchorSel || selector) : anchorSel;

    var label;
    if (strategy === 'autoBadge') label = 'Number next to ' + name;
    // §9.2: an "exists" candidate's value is always the literal string 'true' —
    // showing "true · inside X" reads like debug output, not a description.
    else if (strategy === 'exists') label = name;
    else label = value + ' \u00b7 inside ' + name;

    var tierWord = describedSel && describedSel.tier === 1 ? 'unique name'
      : describedSel && describedSel.tier === 2 ? 'accessibility label'
      : describedSel && describedSel.tier === 3 ? 'link'
      : describedSel && describedSel.tier === 4 ? 'stable class'
      : 'position \u2014 may break when the page changes';
    var detail = shapeAndPlace(describedEl, rect) + ', found by its ' + tierWord;
    if (detail.length > 90) detail = detail.substring(0, 87) + '...';

    var technical = (attr ? ('attr=' + attr + ' \u00b7 ') : '') +
      Math.round(rect.w) + '\u00d7' + Math.round(rect.h) + ' \u00b7 top ' + Math.round(rect.y) + 'px';

    var tier = describedSel ? describedSel.tier : 5;
    var score = scoreFor(describedEl, strategy, tier, rect, name);

    return {
      selector: selector,
      anchor: finalAnchor || null,
      strategy: strategy,
      attr: attr,
      value: value,
      label: label,
      detail: detail,
      technical: technical,
      tier: tier,
      score: score,
      inShadow: inShadow,
      rect: rect
    };
  }

  // --- scan() ----------------------------------------------------------------
  var POOL_KEYWORD_RE = /badge|count|unread|notif|message|inbox|chat|mail|alert|activity|dm|bell|indicator|counter|bubble|pill|dot/i;
  var AD_PATTERN_RE = /[$\u20ac\u00a3\u00a5]|:\d\d|\d\/\d|\bago\b|\b(min|hr|hrs|h|d|w|y)\b|\b(19|20)\d\d\b|%/;
  var EXCLUDE_KEYWORD_RE = /like|vote|upvote|comment|share|follower|following|reply|repl|view|karma|member|online|subscriber|highlight|point|score|rating|star|cart|price|qty|quantity|page|step/i;
  var OWN_OVERRIDE_RE = /badge|unread|notif/i;

  function inPool(el) {
    if (!el.children || el.children.length === 0) {
      if (shortNumFromText((el.textContent || '').trim())) return true;
    }
    var hay = ((el.getAttribute('data-testid') || '') + ' ' + (el.getAttribute('id') || '') + ' ' +
      (el.getAttribute('class') || '') + ' ' + (el.getAttribute('aria-label') || ''));
    if (POOL_KEYWORD_RE.test(hay)) return true;
    if (el.tagName === 'SUP') return true;
    var al = el.getAttribute('aria-label');
    if (al && /\d/.test(al)) return true;
    return false;
  }

  function isHidden(el) {
    try {
      var cs = getComputedStyle(el);
      if (cs.display === 'none' || cs.visibility === 'hidden' || parseFloat(cs.opacity) === 0) return true;
    } catch (e) { }
    var r;
    try { r = el.getBoundingClientRect(); } catch (e) { return true; }
    if (r.width === 0 && r.height === 0) {
      var anc = el.parentElement, levels = 0, allZero = true;
      while (anc && levels < 2) {
        var ar;
        try { ar = anc.getBoundingClientRect(); } catch (e) { ar = { width: 0, height: 0 }; }
        if (ar.width > 0 || ar.height > 0) { allZero = false; break; }
        anc = anc.parentElement; levels++;
      }
      if (allZero) return true;
    }
    return false;
  }

  function inExcludedTag(el) {
    try { return !!el.closest('script,style,svg,noscript,template,time,[datetime]'); } catch (e) { return false; }
  }

  function surroundingTextExcluded(el) {
    var p = el.parentElement;
    var txt = p ? (p.textContent || '') : '';
    return AD_PATTERN_RE.test(txt);
  }

  function ownHayOf(node) {
    if (!node || !node.getAttribute) return '';
    return (node.tagName || '') + ' ' + (node.getAttribute('class') || '') + ' ' +
      (node.getAttribute('id') || '') + ' ' + (node.getAttribute('data-testid') || '') + ' ' +
      (node.getAttribute('aria-label') || '');
  }

  function ancestorChainExcluded(el) {
    if (OWN_OVERRIDE_RE.test(ownHayOf(el))) return false;
    var node = el, levels = 0;
    while (node && levels <= 6) {
      if (EXCLUDE_KEYWORD_RE.test(ownHayOf(node))) return true;
      node = node.parentElement;
      levels++;
    }
    return false;
  }

  function repeatedListExcluded(el) {
    if (OWN_OVERRIDE_RE.test(ownHayOf(el))) return false;
    var anc = el.parentElement, levels = 0;
    while (anc && levels < 3) {
      var firstClass = (anc.getAttribute('class') || '').split(/\s+/)[0] || '';
      var siblings = anc.parentElement ? anc.parentElement.children : [];
      var count = 0;
      for (var i = 0; i < siblings.length; i++) {
        var sib = siblings[i];
        if (sib.tagName === anc.tagName && ((sib.getAttribute('class') || '').split(/\s+/)[0] || '') === firstClass) count++;
      }
      if (count >= 3) return true;
      anc = anc.parentElement; levels++;
    }
    return false;
  }

  function scan() {
    var pool = [], seen = [];
    function consider(el) {
      if (seen.indexOf(el) !== -1) return;
      seen.push(el);
      if (inPool(el)) pool.push(el);
    }
    var all;
    try { all = document.querySelectorAll('*'); } catch (e) { all = []; }
    for (var i = 0; i < all.length; i++) consider(all[i]);
    if (CFG.pierce) {
      var roots = shadowRoots();
      for (var r = 0; r < roots.length; r++) {
        var inner;
        try { inner = roots[r].querySelectorAll('*'); } catch (e) { inner = []; }
        for (var j = 0; j < inner.length; j++) consider(inner[j]);
      }
    }

    var out = [], bySelector = {};
    for (var p = 0; p < pool.length; p++) {
      var el = pool[p];
      if (isHidden(el)) continue;
      if (inExcludedTag(el)) continue;
      if (surroundingTextExcluded(el)) continue;
      if (ancestorChainExcluded(el)) continue;
      if (repeatedListExcluded(el)) continue;
      var cand;
      try { cand = describe(el); } catch (e) { continue; }
      if (!cand || !cand.selector) continue;
      // describe() can redirect a container (pooled via a keyword substring match
      // on its own class, e.g. "counts" matching /count/i) to a numeric descendant
      // that scan()'s exclusion filters never saw directly. Re-run them against
      // whatever element the candidate's selector actually resolves to.
      var leafEl = null;
      try { leafEl = dq(cand.selector); } catch (e) { leafEl = null; }
      if (leafEl && leafEl !== el) {
        if (isHidden(leafEl) || inExcludedTag(leafEl) || surroundingTextExcluded(leafEl) ||
            ancestorChainExcluded(leafEl) || repeatedListExcluded(leafEl)) continue;
      }
      if ((cand.strategy === 'badgeText' || cand.strategy === 'badgeAttr' || cand.strategy === 'ariaCount') && cand.value != null) {
        var numOnly = parseInt(String(cand.value).replace(/[^\d]/g, ''), 10);
        if (!isNaN(numOnly) && numOnly >= 100000) continue;
      }
      if (bySelector[cand.selector]) continue;
      bySelector[cand.selector] = true;
      out.push(cand);
    }

    var titleMatch = document.title.match(/^\s*\((\d+)\+?\)/);
    if (titleMatch) {
      out.push({
        selector: 'title', anchor: null, strategy: 'title', attr: null, value: titleMatch[1],
        label: '(' + titleMatch[1] + ') in the tab title', detail: 'Count shown in the browser tab title',
        technical: 'document.title', tier: 2, score: 3, inShadow: false, rect: { x: 0, y: 0, w: 0, h: 0 }
      });
    }

    out.sort(function (a, b) { if (b.score !== a.score) return b.score - a.score; return a.tier - b.tier; });
    if (out.length > 12) out = out.slice(0, 12);

    return fin({ status: 'OK', candidates: out });
  }

  // --- Suggest anchors (legacy) -----------------------------------------------
  function suggestSelectorFor(el) {
    var tag = el.tagName.toLowerCase();
    var tid = el.getAttribute('data-testid');
    if (tid) return { sel: tag + '[data-testid="' + tid + '"]', tier: 1, label: 'test id: ' + tid };
    var al = el.getAttribute('aria-label');
    if (al && al.length < 60) return { sel: tag + '[aria-label="' + al + '"]', tier: 2, label: 'label: ' + al };
    var href = el.getAttribute('href');
    if (href) {
      var path = href.replace(/^https?:\/\/[^\/]+/, '');
      if (path && path.length < 50) return { sel: tag + '[href*="' + path + '"]', tier: 3, label: 'links to ' + path };
    }
    var id = el.getAttribute('id');
    if (id && !/[0-9]{4,}/.test(id)) return { sel: '#' + id, tier: 4, label: 'id: ' + id };
    return null;
  }

  function suggest() {
    var out = [], seen = {};
    var cands = [];
    try { cands = [].slice.call(document.querySelectorAll('a,button,[role="button"],[role="link"]')); } catch (e) { }
    if (CFG.pierce) {
      var roots = shadowRoots();
      for (var i = 0; i < roots.length; i++) {
        try { cands = cands.concat([].slice.call(roots[i].querySelectorAll('a,button,[role="button"],[role="link"]'))); } catch (e) { }
      }
    }
    for (var i = 0; i < cands.length; i++) {
      var el = cands[i];
      var hay = ((el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('href') || '') + ' ' +
                 (el.getAttribute('data-testid') || '') + ' ' + (el.getAttribute('id') || '') + ' ' +
                 (el.textContent || '')).toLowerCase();
      if (!/notif|message|inbox|chat|mail|alert|activity/.test(hay)) continue;
      var r;
      try { r = el.getBoundingClientRect(); } catch (e) { continue; }
      if (r.top > 400) continue;
      var s = suggestSelectorFor(el);
      if (!s || seen[s.sel]) continue;
      seen[s.sel] = 1;
      var sample = (el.getAttribute('aria-label') || (el.textContent || '').trim().substring(0, 30) || null);
      out.push({ selector: s.sel, label: s.label, tier: s.tier, sample: sample });
      if (out.length >= 12) break;
    }
    out.sort(function (a, b) { return a.tier - b.tier; });
    return fin({ status: 'MISS', code: 'NO_MATCH', detail: 'suggest-only', anchors: out });
  }

  // --- Pick session ------------------------------------------------------------
  function elementUnderPoint(x, y) {
    var el = document.elementFromPoint(x, y);
    var guard = 0;
    while (el && el.shadowRoot && guard < 10) {
      var inner = el.shadowRoot.elementFromPoint(x, y);
      if (!inner || inner === el) break;
      el = inner;
      guard++;
    }
    return el;
  }

  function teardownPick(keepObj) {
    var w = window.__ww;
    if (w) {
      if (w.listeners) {
        for (var i = 0; i < w.listeners.length; i++) {
          var l = w.listeners[i];
          try { l.target.removeEventListener(l.type, l.fn, l.opts); } catch (e) { }
        }
        w.listeners = [];
      }
      try { if (w.overlay && w.overlay.parentNode) w.overlay.parentNode.removeChild(w.overlay); } catch (e) { }
      try { if (w.tip && w.tip.parentNode) w.tip.parentNode.removeChild(w.tip); } catch (e) { }
      try { if (w.toolbar && w.toolbar.parentNode) w.toolbar.parentNode.removeChild(w.toolbar); } catch (e) { }
      try { if (document.body) document.body.style.cursor = w.prevCursor || ''; } catch (e) { }
    }
    if (!keepObj) { try { window.__ww = undefined; delete window.__ww; } catch (e) { } }
  }

  // Pick session v2 (§3.5/§9.2): a click no longer commits the pick — it moves
  // the session into 'selected' with a locked highlight and a toolbar the user
  // can refine from (parent/child/siblings) before confirming with Enter, the
  // toolbar's own button, or the app-side pickConfirm (the CSP-proof path that
  // must always work even when the page's own JS blocks synthetic keys/clicks).
  function lockHighlight(el) {
    var w = window.__ww;
    if (!w) return;
    try {
      var r = el.getBoundingClientRect();
      w.overlay.style.display = 'block';
      w.overlay.style.outline = '2px solid #22c55e';
      w.overlay.style.background = 'rgba(34,197,94,.25)';
      w.overlay.style.left = r.left + 'px'; w.overlay.style.top = r.top + 'px';
      w.overlay.style.width = r.width + 'px'; w.overlay.style.height = r.height + 'px';
    } catch (e) { }
    try { w.tip.style.display = 'none'; } catch (e) { }
  }

  function selectElement(el) {
    var w = window.__ww;
    if (!w || !el) return;
    w.current = el;
    w.state = 'selected';
    lockHighlight(el);
    try { if (w.toolbar) w.toolbar.style.display = 'flex'; } catch (e) { }
  }

  // Shared by the Enter key, the toolbar's "Use this element" button, and the
  // pickConfirm mode — one place that turns 'selected' into 'picked'.
  function doConfirm() {
    var w = window.__ww;
    if (!w || w.state !== 'selected' || !w.current) return null;
    var d;
    try { d = describe(w.current, { explicit: true }); } catch (e) { d = null; }
    if (!d) return null;
    w.pick = d;
    w.state = 'picked';
    teardownPick(true);
    return d;
  }

  function pickStart() {
    teardownPick(false);
    var overlay = document.createElement('div');
    overlay.id = '__ww_overlay';
    overlay.style.cssText = 'position:fixed;pointer-events:none;outline:2px solid #3B74F6;background:rgba(59,116,246,.15);z-index:2147483647;display:none;';
    var tip = document.createElement('div');
    tip.id = '__ww_tip';
    tip.style.cssText = 'position:fixed;pointer-events:none;background:#1e1f27;color:#fff;font-size:12px;padding:4px 8px;border-radius:12px;z-index:2147483647;display:none;max-width:300px;';
    var toolbar = document.createElement('div');
    toolbar.id = '__ww_toolbar';
    toolbar.style.cssText = 'position:fixed;left:50%;bottom:24px;transform:translateX(-50%);background:#1e1f27;color:#fff;font-size:12px;padding:8px 12px;border-radius:20px;z-index:2147483647;display:none;align-items:center;gap:10px;box-shadow:0 2px 12px rgba(0,0,0,.35);pointer-events:auto;';
    var toolbarLabel = document.createElement('span');
    toolbarLabel.textContent = '\u2190 \u2192 siblings \u00b7 \u2191 parent \u00b7 \u2193 child \u00b7 \u23ce use \u00b7 \u238b cancel';
    var useBtn = document.createElement('button');
    useBtn.type = 'button';
    useBtn.textContent = 'Use this element';
    useBtn.setAttribute('data-ww-action', 'use');
    useBtn.style.cssText = 'background:#3B74F6;color:#fff;border:none;border-radius:12px;padding:4px 10px;font-size:12px;cursor:pointer;';
    var cancelBtn = document.createElement('button');
    cancelBtn.type = 'button';
    cancelBtn.textContent = 'Cancel';
    cancelBtn.setAttribute('data-ww-action', 'cancel');
    cancelBtn.style.cssText = 'background:transparent;color:#fff;border:1px solid rgba(255,255,255,.4);border-radius:12px;padding:4px 10px;font-size:12px;cursor:pointer;';
    toolbar.appendChild(toolbarLabel);
    toolbar.appendChild(useBtn);
    toolbar.appendChild(cancelBtn);
    (document.body || document.documentElement).appendChild(overlay);
    (document.body || document.documentElement).appendChild(tip);
    (document.body || document.documentElement).appendChild(toolbar);

    var state = {
      state: 'waiting', pick: null, current: null, note: null,
      overlay: overlay, tip: tip, toolbar: toolbar, listeners: [],
      prevCursor: document.body ? document.body.style.cursor : ''
    };
    window.__ww = state;

    function addL(target, type, fn, opts) {
      target.addEventListener(type, fn, opts);
      state.listeners.push({ target: target, type: type, fn: fn, opts: opts });
    }

    function onMove(e) {
      // Hover preview only runs before anything is selected; once locked, the
      // highlight tracks `current` (via click/keyboard) and ignores the mouse.
      if (state.state !== 'waiting') return;
      var target = elementUnderPoint(e.clientX, e.clientY);
      if (!target || target === overlay || target === tip || target === toolbar) { overlay.style.display = 'none'; tip.style.display = 'none'; return; }
      var r;
      try { r = target.getBoundingClientRect(); } catch (err) { return; }
      overlay.style.display = 'block';
      overlay.style.left = r.left + 'px'; overlay.style.top = r.top + 'px';
      overlay.style.width = r.width + 'px'; overlay.style.height = r.height + 'px';
      tip.style.display = 'block';
      tip.style.left = Math.max(0, Math.min(r.left, (window.innerWidth || 1000) - 260)) + 'px';
      tip.style.top = Math.max(0, r.top - 28) + 'px';
      if (target.tagName === 'IFRAME') {
        tip.textContent = "inside an embedded frame \u2014 can't pick here";
      } else {
        var d;
        try { d = describe(target); } catch (err) { d = null; }
        tip.textContent = d ? d.label : target.tagName.toLowerCase();
      }
    }
    addL(document, 'mousemove', onMove, true);

    function onBlock(e) { e.preventDefault(); e.stopImmediatePropagation(); }
    addL(document, 'click', function (e) {
      onBlock(e);
      var target = (e.composedPath && e.composedPath()[0]) || e.target;
      if (!target) return;
      if (toolbar.contains(target)) {
        var actionEl = target.closest ? target.closest('[data-ww-action]') : null;
        var action = actionEl ? actionEl.getAttribute('data-ww-action') : null;
        if (action === 'use') { doConfirm(); }
        else if (action === 'cancel') { state.state = 'cancelled'; teardownPick(true); }
        return;
      }
      if (target.tagName === 'IFRAME') { state.note = 'iframe'; return; }
      selectElement(target);
    }, true);
    addL(document, 'mousedown', onBlock, true);
    addL(document, 'mouseup', onBlock, true);
    addL(document, 'pointerdown', onBlock, true);

    // §9.2: Enter/ArrowUp/ArrowDown/ArrowLeft/ArrowRight/Escape are claimed with
    // preventDefault+stopPropagation whenever a session is active, so the host
    // page never sees them (no accidental submit/scroll/navigation underneath).
    addL(window, 'keydown', function (e) {
      var w = window.__ww;
      if (!w) return;
      var k = e.key;
      var isEscape = (k === 'Escape' || e.keyCode === 27);
      var isNav = isEscape || k === 'Enter' || k === 'ArrowUp' || k === 'ArrowDown' || k === 'ArrowLeft' || k === 'ArrowRight';
      if (!isNav) return;
      e.preventDefault();
      e.stopPropagation();
      if (isEscape) { w.state = 'cancelled'; teardownPick(true); return; }
      if (w.state !== 'selected' || !w.current) return;
      if (k === 'Enter') { doConfirm(); return; }
      // Parent stops at <body>; going further up is never useful for a watch area.
      if (k === 'ArrowUp') {
        if (w.current !== document.body && w.current.parentElement) selectElement(w.current.parentElement);
        return;
      }
      if (k === 'ArrowDown') {
        if (w.current.firstElementChild) selectElement(w.current.firstElementChild);
        return;
      }
      if (k === 'ArrowLeft') {
        if (w.current.previousElementSibling) selectElement(w.current.previousElementSibling);
        return;
      }
      if (k === 'ArrowRight') {
        if (w.current.nextElementSibling) selectElement(w.current.nextElementSibling);
        return;
      }
    }, true);

    try { if (document.body) document.body.style.cursor = 'crosshair'; } catch (e) { }

    return fin({ status: 'OK', pickState: 'waiting' });
  }

  function pickPoll() {
    var w = window.__ww;
    if (!w) return fin({ status: 'OK', pickState: 'absent' });
    var out = { status: 'OK', pickState: w.state };
    if (w.state === 'selected' && w.current) {
      var d;
      try { d = describe(w.current, { explicit: true }); } catch (e) { d = null; }
      if (d) out.pick = d;
    } else if (w.pick) {
      out.pick = w.pick;
    }
    if (w.note) out.note = w.note;
    return fin(out);
  }

  function pickStop() {
    teardownPick(false);
    return fin({ status: 'OK', pickState: 'cancelled' });
  }

  // §9.2: guarded exactly like pickPoll — no active session is reported the
  // same way whether the caller asks "what's the state?" (pickPoll) or "commit
  // it" (pickConfirm), rather than as a distinct error the app has to special-case.
  function pickConfirm() {
    var w = window.__ww;
    if (!w) return fin({ status: 'OK', pickState: 'absent' });
    var d = doConfirm();
    if (d) return fin({ status: 'OK', pickState: 'picked', pick: d });
    var out = { status: 'OK', pickState: w.state };
    if (w.pick) out.pick = w.pick;
    if (w.note) out.note = w.note;
    return fin(out);
  }

  function doHighlight() {
    var sel = CFG.hl;
    if (!sel) return fin({ status: 'OK', value: '0' });
    var el;
    try { el = dq(sel); } catch (e) { el = null; }
    if (!el) return fin({ status: 'OK', value: '0' });
    try { el.scrollIntoView({ block: 'center' }); } catch (e) { }
    var r;
    try { r = el.getBoundingClientRect(); } catch (e) { r = { left: 0, top: 0, width: 0, height: 0 }; }
    var ov = document.createElement('div');
    ov.style.cssText = 'position:fixed;pointer-events:none;outline:3px solid #3B74F6;background:rgba(59,116,246,.2);z-index:2147483647;left:' +
      r.left + 'px;top:' + r.top + 'px;width:' + r.width + 'px;height:' + r.height + 'px;';
    (document.body || document.documentElement).appendChild(ov);
    setTimeout(function () { try { if (ov.parentNode) ov.parentNode.removeChild(ov); } catch (e) { } }, 1500);
    return fin({ status: 'OK', value: '1' });
  }

  // --- autoBadge scope search (check/diagnose) --------------------------------
  function isStopScope(node) {
    if (!node) return true;
    var tag = node.tagName;
    if (tag === 'HEADER' || tag === 'NAV' || tag === 'LI') return true;
    var role = node.getAttribute && node.getAttribute('role');
    if (role === 'banner' || role === 'navigation') return true;
    return false;
  }

  function autoBadgeCheck(anchorEl) {
    var scopes = [anchorEl];
    var cur = anchorEl.parentElement;
    // A landmark boundary (header/nav/li/[role=banner]/[role=navigation]) reached
    // as the anchor's own immediate parent is searched, not skipped — the common
    // `<li><button/><span class="badge"/></li>` pattern puts the badge exactly
    // there, as the anchor's sibling. But a landmark reached further up (the
    // ordinary 3rd-level grandparent stop, e.g. a `<header>` that also wraps an
    // unrelated nav with its own counts) is never entered at all: "never climb
    // above" a landmark means the search stops just short of it in that case.
    var atImmediateParent = true;
    while (scopes.length < 3 && cur) {
      var stop = isStopScope(cur);
      if (stop && !atImmediateParent) break;
      scopes.push(cur);
      if (stop) break;
      cur = cur.parentElement;
      atImmediateParent = false;
    }
    var NUM_RE = /^\d{1,5}\+?$/;
    var COUNTLIKE_ATTR_RE = /count|badge|unread|number|total/i;
    var found = null;
    for (var si = 0; si < scopes.length && found === null; si++) {
      var scope = scopes[si];
      var descEls;
      try { descEls = scope.querySelectorAll('*'); } catch (e) { continue; }
      if (descEls.length > 60) continue;
      for (var di = 0; di < descEls.length; di++) {
        var d = descEls[di];
        if (d === anchorEl) continue;
        if (!d.children || d.children.length === 0) {
          var dt = (d.textContent || '').trim().replace(/[,.\s\u00a0]/g, '');
          if (NUM_RE.test(dt)) { found = dt; break; }
          var odo = readOdometer(d);
          if (odo !== null && NUM_RE.test(odo)) { found = odo; break; }
        }
        var attrs = d.attributes, hit = null;
        for (var ai = 0; ai < attrs.length; ai++) {
          if (COUNTLIKE_ATTR_RE.test(attrs[ai].name)) {
            var av = (attrs[ai].value || '').replace(/[,.\s\u00a0]/g, '');
            if (NUM_RE.test(av)) { hit = av; break; }
          }
        }
        if (hit !== null) { found = hit; break; }
      }
    }
    st('Number near anchor', found !== null, null);
    if (found !== null) return okOut(firstNumber(found));
    return zeroOut();
  }

  // --- Subtree fingerprint ("Anything changes inside", G2/§3.5/§9.2) ---------
  // FNV-1a 32-bit over a bounded, order-stable signature of the watched area's
  // descendants: tag/data-testid/aria-label/role/href-path/alt only — NOT
  // class/style/id/aria-expanded/aria-hidden/tabindex/data-state, which churn
  // on every render (open/closed states, generated ids, focus tracking) without
  // the visible content actually changing. Relative-time substrings ("3 hours
  // ago") are stripped from the trailing text pass so a fingerprint doesn't
  // drift on its own every minute; `time`/`[datetime]`/`script`/`style`/`svg`
  // subtrees are skipped entirely (icon internals, hidden metadata). `n` is the
  // real, uncapped descendant count (so the UI can warn on a busy container);
  // hashing itself is capped at the first 400 descendants in document order.
  // DEVIATION from §9.2's literal regex, additive only (nothing removed/reordered):
  // added "hours?" alongside the spec's own "h|hr|hrs". The spec text already
  // spells out the day unit both ways ("d|days?") but only abbreviates hours —
  // against the live fixture (Sources: scratchpad/fixture/badge-fixture.html,
  // "Posted 2 hours ago") the un-amended pattern leaves the digit in the hashed
  // text, so "2 hours ago" → "3 hours ago" changes the fingerprint, which is
  // exactly the false-positive §7's live check exists to rule out. Verified in
  // Node against every literal-spec case (5s/3 sec/10 secs/2m/4 min/9 mins/
  // 1h/2 hr/3 hrs/2d/3 days/1 day/2w/3mo/1y ago) with no change in behavior.
  var REL_TIME_NUM_RE = /\b\d+\s*(s|sec|secs|m|min|mins|h|hr|hrs|hours?|d|days?|w|mo|y)\b\.?\s*(ago)?/gi;
  var REL_TIME_WORD_RE = /\b(just now|yesterday|today)\b/gi;
  var SKIP_SUBTREE_SEL = 'time,[datetime],script,style,svg';

  function subtreeFingerprint(el) {
    var all;
    try { all = el.querySelectorAll('*'); } catch (e) { all = []; }
    var n = all.length;
    var cap = Math.min(n, 400);

    var hash = 0x811c9dc5;
    function fnv(str) {
      for (var i = 0; i < str.length; i++) {
        hash = Math.imul(hash ^ str.charCodeAt(i), 0x01000193) >>> 0;
      }
    }

    for (var i = 0; i < cap; i++) {
      var d = all[i];
      var skip = null;
      try { skip = d.closest(SKIP_SUBTREE_SEL); } catch (e) { skip = null; }
      if (skip && el.contains(skip)) continue;
      var href = (d.getAttribute && d.getAttribute('href')) || '';
      var hrefPath = href.replace(/^https?:\/\/[^\/]+/, '');
      var sig = d.tagName + '|' + (d.getAttribute('data-testid') || '') + '|' +
        (d.getAttribute('aria-label') || '') + '|' + (d.getAttribute('role') || '') + '|' +
        hrefPath + '|' + (d.getAttribute('alt') || '') + '\n';
      fnv(sig);
    }

    var text = (el.innerText || el.textContent || '');
    text = text.replace(REL_TIME_NUM_RE, '').replace(REL_TIME_WORD_RE, '');
    text = text.replace(/\s+/g, ' ').trim();
    if (text.length > 3000) text = text.substring(0, 3000);
    fnv(text);

    return { n: n, hex: hash.toString(16) };
  }

  // --- Main ------------------------------------------------------------------
  try {
    // F1: Safari can unload a tab to about:blank while its AppleScript `URL of tab`
    // still reports the real address — probing it must fail loudly (TAB_BLANK)
    // rather than silently reading nothing. `file:` is accepted alongside
    // `http(s):` only so the local verification fixture (opened as a file:// URL)
    // is not mistaken for a suspended tab; a monitored watcher always targets a
    // real http(s) site, so this never widens what production traffic accepts.
    if (!/^(https?|file):/.test(location.href)) return miss('TAB_BLANK', location.href);

    if (CFG.mode === 'pickPoll') return pickPoll();
    if (CFG.mode === 'pickStop') return pickStop();
    // §9.2: locate/pickConfirm run before the loaded-page gate too — locate's
    // whole purpose is reporting whether the page is STILL loading, and
    // pickConfirm must be able to say "nothing selected yet" during that window.
    if (CFG.mode === 'locate') return fin({ status: 'OK', value: '', loading: document.readyState !== 'complete' });
    if (CFG.mode === 'pickConfirm') return pickConfirm();

    if (document.readyState !== 'complete') {
      st('Page loaded', false, document.readyState);
      return miss('NOT_LOADED', document.readyState);
    }
    st('Page loaded', true, null);

    if (CFG.mode === 'suggest' || CFG.suggest) return suggest();
    if (CFG.mode === 'scan') return scan();
    if (CFG.mode === 'pickStart') return pickStart();
    if (CFG.mode === 'highlight') return doHighlight();

    var strategy = CFG.strategy;
    var anchorSel = CFG.anchor;
    var anchorEl = null;

    if (anchorSel) {
      anchorEl = dq(anchorSel);
      st('Anchor found', !!anchorEl, anchorSel);
      if (!anchorEl) {
        // Only consult signed-out / challenge markers when the anchor is missing.
        // Checking them first produces false positives on healthy pages: a stale
        // js_challenge query string can persist on a fully working Reddit tab.
        if (CFG.signedOut) {
          var so = null;
          try { so = document.querySelector(CFG.signedOut); } catch (e) { }
          if (so) { st('Signed in', false, 'sign-in link present'); return miss('SIGNED_OUT', null); }
        }
        if (/\/checkpoint\/|cdn-cgi\/challenge/.test(location.href) ||
            document.querySelector('#challenge-form,#cf-challenge-running')) {
          return miss('CHALLENGE', null);
        }
        return miss('ANCHOR_MISSING', anchorSel);
      }
    }

    if (strategy === 'documentTitle') {
      var m = document.title.match(/^\s*\((\d+)\+?\)/);
      st('Title count', !!m, document.title.substring(0, 40));
      if (m) return okOut(m[1]);
      return zeroOut();
    }

    if (strategy === 'ariaCount') {
      if (!anchorEl) return miss('ANCHOR_MISSING', anchorSel);
      var label = anchorEl.getAttribute('aria-label') || '';
      var mm = label.match(/([0-9][0-9,.]*)\s*(\+)?\s*new/i);
      st('Count in label', !!mm, label.substring(0, 50));
      if (mm) return okOut(mm[1] + (mm[2] || ''));
      var any = firstNumber(label);
      if (any !== null) return okOut(any);
      return miss('NO_MATCH', label ? label.substring(0, 40) : 'no aria-label');
    }

    if (strategy === 'anchoredBadge') {
      if (!CFG.badge) return miss('NO_MATCH', 'no badge selector');
      var badgeEl = dq(CFG.badge);
      st('Badge present', !!badgeEl, CFG.badge);
      if (!badgeEl) return zeroOut();   // anchor present + badge absent = confirmed zero
      var raw = readValue(badgeEl, CFG.attr);
      if (!raw) return zeroOut();
      var num = firstNumber(raw);
      if (num === null) return miss('NO_MATCH', raw.substring(0, 30));
      return okOut(num);
    }

    if (strategy === 'autoBadge') {
      if (!anchorEl) return miss('ANCHOR_MISSING', anchorSel);
      return autoBadgeCheck(anchorEl);
    }

    // --- Manual watcher (arbitrary user-authored site) ---
    var wt = CFG.watchType;
    var isXPath = CFG.selectorType === 'xpath';

    if (wt === 'count') {
      var n = isXPath ? xpath(CFG.selector, true) : dqAll(CFG.selector).length;
      st('Elements matched', true, String(n));
      return okOut(n);
    }

    var el = isXPath ? xpath(CFG.selector, false) : dq(CFG.selector);
    st('Element found', !!el, CFG.selector);

    if (wt === 'exists' || wt === 'disappears') {
      return okOut(el ? 'true' : 'false');
    }

    if (!el) {
      // The old behaviour returned '0' here, which is the entire product defect:
      // a dead selector became a confident "nothing new" forever.
      if (anchorEl) return zeroOut();
      return miss('NO_MATCH', CFG.selector);
    }

    if (wt === 'text') {
      var txt = (el.innerText || el.textContent || '').trim();
      return okOut(txt);
    }

    if (wt === 'subtree') {
      var fp = subtreeFingerprint(el);
      st('Fingerprint', true, fp.n + ' elements');
      return okOut(fp.n + ':' + fp.hex);
    }

    var rawVal = readValue(el, CFG.attr);
    if (!rawVal) return anchorEl ? zeroOut() : miss('NO_MATCH', 'element empty');
    var parsed = firstNumber(rawVal);
    if (parsed === null) return miss('NO_MATCH', rawVal.substring(0, 30));
    return okOut(parsed);

  } catch (e) {
    if (e && e.ww === 'BAD_SELECTOR') return errOut('BAD_SELECTOR', e.m);
    return errOut('JS_EXCEPTION', String((e && e.message) || e));
  }
})()
"""#
}

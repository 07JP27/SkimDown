(function () {
  let markdownIt = null;
  let searchMatches = [];
  let currentSearchIndex = -1;
  let tableResizeObserver = null;
  let tableResizeHandler = null;
  let mermaidResizeObserver = null;
  let mermaidResizeHandler = null;
  let activeHeadingIntersectionObserver = null;
  let activeHeadingResizeHandler = null;
  let activeHeadingScrollHandler = null;
  let activeHeadingUpdateHandler = null;
  let activeHeadingFrameRequest = null;
  let activeHeadingUserInteractionHandler = null;
  let programmaticActiveHeadingID = null;
  let programmaticActiveHeadingWasVisible = false;
  let activeHeadingRenderID = null;
  let lastActiveHeadingID = null;
  let activeMermaidModal = null;
  let mermaidModalSequence = 0;
  const IMAGE_READY_TIMEOUT_MS = 3000;
  const CODE_COPY_FEEDBACK_RESET_MS = 1500;
  // Matches standalone #RGB, #RGBA, #RRGGBB, and #RRGGBBAA color codes.
  const COLOR_CODE_PATTERN_SOURCE = "(^|[^\\w-])(#(?:[0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{3}))(?![\\w-])";
  const COLOR_CODE_DETECTION_PATTERN = new RegExp(COLOR_CODE_PATTERN_SOURCE);

  function renderer() {
    if (!markdownIt) {
      markdownIt = window.markdownit({
        html: true,
        linkify: true,
        typographer: false,
        highlight: function (code, language) {
          if (language && language.toLowerCase() === "math") {
            return escapeHtml(code);
          }
          if (language && window.hljs && window.hljs.getLanguage(language)) {
            try {
              return window.hljs.highlight(code, { language: language }).value;
            } catch (_) {}
          }
          if (window.hljs) {
            try {
              return window.hljs.highlightAuto(code).value;
            } catch (_) {}
          }
          return escapeHtml(code);
        }
      });

      if (window.markdownitFootnote) {
        markdownIt.use(window.markdownitFootnote);
      }

      if (window.markdownitImsize || window["markdown-it-imsize.js"]) {
        markdownIt.use(window.markdownitImsize || window["markdown-it-imsize.js"]);
      }

      // Single-tilde strikethrough (~text~) — GitHub extension not in GFM spec.
      markdownIt.inline.ruler.after("strikethrough", "single_tilde_strikethrough", function (state, silent) {
        var src = state.src;
        var pos = state.pos;
        var max = state.posMax;
        if (src.charCodeAt(pos) !== 0x7E) { return false; }
        // Must be single ~, not ~~
        if (pos + 1 <= max && src.charCodeAt(pos + 1) === 0x7E) { return false; }
        // Find closing ~ within the inline boundary
        var end = pos + 1;
        while (end <= max) {
          var idx = src.indexOf("~", end);
          if (idx < 0 || idx > max) { return false; }
          end = idx;
          break;
        }
        if (end <= pos + 1) { return false; }
        // Closing ~ must also be single (not adjacent to another ~)
        if (end + 1 <= max && src.charCodeAt(end + 1) === 0x7E) { return false; }
        if (end > 0 && src.charCodeAt(end - 1) === 0x7E) { return false; }
        // No empty content, no newlines
        var inner = src.slice(pos + 1, end);
        if (!inner.trim() || inner.indexOf("\n") >= 0) { return false; }
        if (!silent) {
          var token = state.push("s_open", "s", 1);
          token.markup = "~";
          var tokenInner = state.push("text", "", 0);
          tokenInner.content = inner;
          var tokenClose = state.push("s_close", "s", -1);
          tokenClose.markup = "~";
        }
        state.pos = end + 1;
        return true;
      });

      if (window.markdownitEmoji) {
        markdownIt.use(window.markdownitEmoji, { shortcuts: {} });
      }
    }
    return markdownIt;
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function render(payload) {
    const restoreScrollY = Number(payload.restoreScrollY) || 0;
    if (restoreScrollY > 0) {
      document.body.classList.add("skimdown-restoring");
    }
    document.documentElement.dataset.theme = payload.theme || "system";
    document.documentElement.style.setProperty("--skimdown-font-size", String(payload.fontSize || 16) + "px");
    closeActiveMermaidModal();

    const content = document.getElementById("content");
    const dirtyHtml = renderer().render(payload.markdown || "");
    content.innerHTML = window.DOMPurify.sanitize(dirtyHtml, {
      FORBID_TAGS: ["script", "iframe", "object", "embed", "style"],
      ALLOW_DATA_ATTR: false
    });

    assignHeadingAnchorIDs(content);
    convertAlerts(content);
    normalizeTaskLists(content);
    normalizeLinksAndImages(content, payload);
    wrapTables(content);
    initializeTableScrollCues(content);
    const mermaidTasks = renderMermaidBlocks(content, payload);
    convertMathBlocks(content);
    convertBacktickMath(content);
    decorateCodeBlocks(content);
    renderMath(content);
    decorateColorCodes(content);
    clearSearch();

    notifyWhenRenderSettled(content, payload.renderID, mermaidTasks, restoreScrollY);
    installUserInteractionWatcher(payload.renderID);
    installScrollPositionListener(payload.renderID);
    installActiveHeadingTracker(content, payload.renderID);
  }

  function installScrollPositionListener(renderID) {
    let pending = false;
    let lastPosted = null;
    function flush() {
      pending = false;
      if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.scrollPosition) {
        return;
      }
      const value = window.scrollY;
      if (value === lastPosted) {
        return;
      }
      lastPosted = value;
      window.webkit.messageHandlers.scrollPosition.postMessage({ renderID: renderID, scrollY: value });
    }
    function onScroll() {
      if (pending) {
        return;
      }
      pending = true;
      window.requestAnimationFrame(flush);
    }
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  function installUserInteractionWatcher(renderID) {
    function onInteract() {
      window.removeEventListener("wheel", onInteract, { capture: true });
      window.removeEventListener("touchstart", onInteract, { capture: true });
      window.removeEventListener("keydown", onInteract, { capture: true });
      window.removeEventListener("mousedown", onInteract, { capture: true });
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.userInteracted) {
        window.webkit.messageHandlers.userInteracted.postMessage({ renderID: renderID });
      }
    }
    window.addEventListener("wheel", onInteract, { capture: true, once: true, passive: true });
    window.addEventListener("touchstart", onInteract, { capture: true, once: true, passive: true });
    window.addEventListener("keydown", onInteract, { capture: true, once: true });
    window.addEventListener("mousedown", onInteract, { capture: true, once: true });
  }

  function tableOfContents() {
    const content = document.getElementById("content");
    if (!content) {
      return [];
    }

    return headingElements(content).map(function (heading) {
      return {
        level: Number(heading.tagName.slice(1)),
        title: (heading.textContent || "").trim(),
        id: heading.id
      };
    }).filter(function (entry) {
      return entry.title && entry.id;
    });
  }

  function headingElements(content) {
    return Array.from(content.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function (heading) {
      return Boolean(heading.id);
    });
  }

  function installActiveHeadingTracker(content, renderID) {
    teardownActiveHeadingTracker();
    activeHeadingRenderID = renderID;
    lastActiveHeadingID = null;

    const headings = headingElements(content);
    if (headings.length === 0) {
      postActiveHeading(renderID, "");
      return;
    }

    let positions = [];
    let shouldRecalculate = false;

    function recalculatePositions() {
      positions = headings.map(function (heading) {
        return {
          id: heading.id,
          top: heading.getBoundingClientRect().top + window.scrollY
        };
      });
    }

    function scheduleUpdate(recalculate) {
      shouldRecalculate = shouldRecalculate || recalculate;
      if (activeHeadingFrameRequest !== null) {
        return;
      }

      activeHeadingFrameRequest = window.requestAnimationFrame(function () {
        activeHeadingFrameRequest = null;
        if (shouldRecalculate) {
          recalculatePositions();
          shouldRecalculate = false;
        }
        updateActiveHeading(renderID, positions);
      });
    }

    activeHeadingScrollHandler = function () {
      scheduleUpdate(false);
    };
    activeHeadingUpdateHandler = function () {
      recalculatePositions();
      updateActiveHeading(renderID, positions);
    };
    activeHeadingResizeHandler = function () {
      scheduleUpdate(true);
    };
    activeHeadingUserInteractionHandler = function () {
      clearProgrammaticActiveHeadingAndUpdate();
    };

    window.addEventListener("scroll", activeHeadingScrollHandler, { passive: true });
    window.addEventListener("resize", activeHeadingResizeHandler);
    window.addEventListener("wheel", activeHeadingUserInteractionHandler, { capture: true, passive: true });
    window.addEventListener("touchstart", activeHeadingUserInteractionHandler, { capture: true, passive: true });
    window.addEventListener("keydown", activeHeadingUserInteractionHandler, { capture: true });
    window.addEventListener("mousedown", activeHeadingUserInteractionHandler, { capture: true });

    if ("IntersectionObserver" in window) {
      activeHeadingIntersectionObserver = new IntersectionObserver(function () {
        scheduleUpdate(true);
      }, {
        root: null,
        rootMargin: "-20% 0px -70% 0px",
        threshold: [0, 1]
      });
      headings.forEach(function (heading) {
        activeHeadingIntersectionObserver.observe(heading);
      });
    }

    recalculatePositions();
    updateActiveHeading(renderID, positions);
  }

  function teardownActiveHeadingTracker() {
    if (activeHeadingIntersectionObserver) {
      activeHeadingIntersectionObserver.disconnect();
      activeHeadingIntersectionObserver = null;
    }
    if (activeHeadingScrollHandler) {
      window.removeEventListener("scroll", activeHeadingScrollHandler);
      activeHeadingScrollHandler = null;
    }
    activeHeadingUpdateHandler = null;
    if (activeHeadingResizeHandler) {
      window.removeEventListener("resize", activeHeadingResizeHandler);
      activeHeadingResizeHandler = null;
    }
    if (activeHeadingUserInteractionHandler) {
      window.removeEventListener("wheel", activeHeadingUserInteractionHandler, { capture: true });
      window.removeEventListener("touchstart", activeHeadingUserInteractionHandler, { capture: true });
      window.removeEventListener("keydown", activeHeadingUserInteractionHandler, { capture: true });
      window.removeEventListener("mousedown", activeHeadingUserInteractionHandler, { capture: true });
      activeHeadingUserInteractionHandler = null;
    }
    if (activeHeadingFrameRequest !== null) {
      window.cancelAnimationFrame(activeHeadingFrameRequest);
      activeHeadingFrameRequest = null;
    }
    clearProgrammaticActiveHeading();
    activeHeadingRenderID = null;
  }

  function updateActiveHeading(renderID, positions) {
    if (!positions || positions.length === 0) {
      postActiveHeading(renderID, "");
      return;
    }

    if (postProgrammaticActiveHeadingIfNeeded(renderID)) {
      return;
    }

    const anchorY = window.scrollY + Math.min(window.innerHeight * 0.25, 160);
    let low = 0;
    let high = positions.length - 1;
    let bestIndex = 0;
    while (low <= high) {
      const middle = Math.floor((low + high) / 2);
      if (positions[middle].top <= anchorY) {
        bestIndex = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    postActiveHeading(renderID, positions[bestIndex].id);
  }

  function setProgrammaticActiveHeading(renderID, headingID) {
    if (renderID === null || renderID === undefined) {
      clearProgrammaticActiveHeading();
      return;
    }
    const target = document.getElementById(headingID || "");
    if (!target) {
      clearProgrammaticActiveHeading();
      return;
    }
    programmaticActiveHeadingID = headingID;
    programmaticActiveHeadingWasVisible = isElementInViewport(target);
    postActiveHeading(renderID, headingID);
  }

  function clearProgrammaticActiveHeading() {
    programmaticActiveHeadingID = null;
    programmaticActiveHeadingWasVisible = false;
  }

  function clearProgrammaticActiveHeadingAndUpdate() {
    const hadOverride = programmaticActiveHeadingID !== null;
    clearProgrammaticActiveHeading();
    if (hadOverride && activeHeadingUpdateHandler) {
      activeHeadingUpdateHandler();
    }
  }

  function postProgrammaticActiveHeadingIfNeeded(renderID) {
    if (!programmaticActiveHeadingID) {
      return false;
    }

    const target = document.getElementById(programmaticActiveHeadingID);
    if (!target) {
      clearProgrammaticActiveHeading();
      return false;
    }

    const isVisible = isElementInViewport(target);
    if (isVisible) {
      programmaticActiveHeadingWasVisible = true;
    } else if (programmaticActiveHeadingWasVisible) {
      clearProgrammaticActiveHeading();
      return false;
    }

    postActiveHeading(renderID, programmaticActiveHeadingID);
    return true;
  }

  function isElementInViewport(element) {
    const rect = element.getBoundingClientRect();
    return rect.bottom > 0 && rect.top < window.innerHeight;
  }

  function postActiveHeading(renderID, headingID) {
    const normalizedID = headingID || "";
    if (normalizedID === lastActiveHeadingID) {
      return;
    }
    lastActiveHeadingID = normalizedID;
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.activeHeading) {
      window.webkit.messageHandlers.activeHeading.postMessage({ renderID: renderID, headingID: normalizedID });
    }
  }

  var ALERT_TYPES = {
    NOTE:      { icon: "ℹ", label: "Note" },
    TIP:       { icon: "💡", label: "Tip" },
    IMPORTANT: { icon: "❗", label: "Important" },
    WARNING:   { icon: "⚠️", label: "Warning" },
    CAUTION:   { icon: "🔴", label: "Caution" }
  };

  function convertAlerts(content) {
    content.querySelectorAll("blockquote").forEach(function (bq) {
      var firstP = bq.firstElementChild;
      if (!firstP || firstP.tagName !== "P") {
        return;
      }
      var firstNode = firstP.firstChild;
      if (!firstNode || firstNode.nodeType !== Node.TEXT_NODE) {
        return;
      }
      var text = firstNode.nodeValue;

      var match = text.match(/^\[!(\w+)\]\s*/);
      if (!match) {
        return;
      }
      var typeKey = match[1].toUpperCase();
      var alertDef = ALERT_TYPES[typeKey];
      if (!alertDef) {
        return;
      }

      // Remove the marker text from the first text node
      firstNode.nodeValue = text.slice(match[0].length);
      // If the text node is now empty, remove it
      if (firstNode.nodeValue === "") {
        firstP.removeChild(firstNode);
      }
      // If the <p> is now empty, remove it entirely
      if (firstP.childNodes.length === 0) {
        bq.removeChild(firstP);
      }

      // Build the alert title element
      var title = document.createElement("p");
      title.className = "skimdown-alert-title";
      title.textContent = alertDef.icon + " " + alertDef.label;
      bq.insertBefore(title, bq.firstChild);

      bq.classList.add("skimdown-alert", "skimdown-alert-" + typeKey.toLowerCase());
    });
  }

  function normalizeTaskLists(content) {
    content.querySelectorAll("li").forEach(function (item) {
      const first = item.firstChild;
      if (!first || first.nodeType !== Node.TEXT_NODE) {
        return;
      }

      const match = first.nodeValue.match(/^\s*\[( |x|X)\]\s+/);
      if (!match) {
        return;
      }

      first.nodeValue = first.nodeValue.slice(match[0].length);
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.disabled = true;
      checkbox.checked = match[1].toLowerCase() === "x";
      item.classList.add("task-list-item");
      item.insertBefore(checkbox, item.firstChild);
    });
  }

  function assignHeadingAnchorIDs(content) {
    const usedIDs = new Set();
    const idScope = content.ownerDocument || document;
    idScope.querySelectorAll("[id]").forEach(function (element) {
      const id = element.getAttribute("id");
      if (id) {
        usedIDs.add(id);
      }
    });

    content.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function (heading) {
      if (heading.getAttribute("id")) {
        return;
      }

      const baseID = slugifyHeadingText(heading.textContent || "") || "section";
      const id = uniqueHeadingID(baseID, usedIDs);
      heading.setAttribute("id", id);
      usedIDs.add(id);
    });
  }

  function slugifyHeadingText(text) {
    return String(text)
      .trim()
      .toLowerCase()
      .replace(/[^\p{Letter}\p{Mark}\p{Number}\s_-]+/gu, "")
      .replace(/\s+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-+|-+$/g, "");
  }

  function uniqueHeadingID(baseID, usedIDs) {
    let id = baseID;
    let suffix = 1;
    while (usedIDs.has(id)) {
      id = baseID + "-" + suffix;
      suffix += 1;
    }
    return id;
  }

  function normalizeLinksAndImages(content, payload) {
    const baseURL = payload.baseURL || document.baseURI;
    const rootURL = payload.rootURL || "";
    const localFileScheme = payload.localFileScheme || "skimdown-local";

    content.querySelectorAll("a[href]").forEach(function (link) {
      const href = link.getAttribute("href");
      if (!href || href.trim() === "") {
        link.removeAttribute("href");
        return;
      }
      link.addEventListener("click", function (event) {
        event.preventDefault();
        window.webkit.messageHandlers.linkClick.postMessage(href);
      });
    });

    content.querySelectorAll("img[src]").forEach(function (image) {
      const src = image.getAttribute("src");
      if (!src) {
        return;
      }
      try {
        const resolved = new URL(src, baseURL);
        if (resolved.protocol === "file:") {
          if (rootURL && !resolved.href.startsWith(rootURL)) {
            image.removeAttribute("src");
          } else {
            const rewrittenURL = new URL(localFileScheme + "://" + resolved.pathname + resolved.search);
            rewrittenURL.searchParams.set("__skimdown_render", String(payload.renderID || 0));
            const rewrittenSrc = rewrittenURL.href;
            image.setAttribute("src", rewrittenSrc);
          }
        }
      } catch (_) {
        image.removeAttribute("src");
      }
    });
  }

  function wrapTables(content) {
    content.querySelectorAll("table").forEach(function (table) {
      if (isWrappedTable(table)) {
        return;
      }
      const wrapper = document.createElement("div");
      wrapper.className = "table-scroll";
      const viewport = document.createElement("div");
      viewport.className = "table-scroll-viewport";
      table.parentNode.insertBefore(wrapper, table);
      wrapper.appendChild(viewport);
      viewport.appendChild(table);
    });
  }

  function isWrappedTable(table) {
    const viewport = table.parentElement;
    return viewport &&
      viewport.classList.contains("table-scroll-viewport") &&
      viewport.parentElement &&
      viewport.parentElement.classList.contains("table-scroll");
  }

  function initializeTableScrollCues(content) {
    if (tableResizeObserver) {
      tableResizeObserver.disconnect();
      tableResizeObserver = null;
    }
    if (tableResizeHandler) {
      window.removeEventListener("resize", tableResizeHandler);
      tableResizeHandler = null;
    }

    const wrappers = Array.from(content.querySelectorAll(".table-scroll"));
    if (wrappers.length === 0) {
      return;
    }

    wrappers.forEach(function (wrapper) {
      const viewport = tableScrollViewport(wrapper);
      updateTableScrollCue(wrapper);
      viewport.addEventListener("scroll", function () {
        updateTableScrollCue(wrapper);
      }, { passive: true });
    });

    if ("ResizeObserver" in window) {
      tableResizeObserver = new ResizeObserver(function (entries) {
        const wrappersToUpdate = new Set();
        entries.forEach(function (entry) {
          if (entry.target.classList && entry.target.classList.contains("table-scroll")) {
            wrappersToUpdate.add(entry.target);
            return;
          }
          if (entry.target.closest) {
            const wrapper = entry.target.closest(".table-scroll");
            if (wrapper) {
              wrappersToUpdate.add(wrapper);
            }
          }
        });
        wrappersToUpdate.forEach(updateTableScrollCue);
      });

      wrappers.forEach(function (wrapper) {
        tableResizeObserver.observe(wrapper);
        const viewport = tableScrollViewport(wrapper);
        tableResizeObserver.observe(viewport);
        const table = wrapper.querySelector("table");
        if (table) {
          tableResizeObserver.observe(table);
        }
      });
    } else {
      tableResizeHandler = function () {
        wrappers.forEach(updateTableScrollCue);
      };
      window.addEventListener("resize", tableResizeHandler);
    }

    window.requestAnimationFrame(function () {
      wrappers.forEach(updateTableScrollCue);
    });
  }

  function updateTableScrollCue(wrapper) {
    const viewport = tableScrollViewport(wrapper);
    const tolerance = 1;
    const maxScrollLeft = viewport.scrollWidth - viewport.clientWidth;
    const isOverflowing = maxScrollLeft > tolerance;
    const scrollLeft = Math.max(0, viewport.scrollLeft);

    wrapper.classList.toggle("can-scroll-left", isOverflowing && scrollLeft > tolerance);
    wrapper.classList.toggle("can-scroll-right", isOverflowing && scrollLeft < maxScrollLeft - tolerance);
  }

  function tableScrollViewport(wrapper) {
    const viewport = wrapper.firstElementChild;
    return viewport && viewport.classList.contains("table-scroll-viewport") ? viewport : wrapper;
  }

  function renderMermaidBlocks(content, payload) {
    // Tear down any observers/listeners from the previous render so they don't
    // accumulate across renders or keep detached nodes alive.
    teardownMermaidOverflowWatchers();

    if (!window.mermaid) {
      // Mermaid is unavailable: leave the original code blocks untouched and bail out.
      return [];
    }

    // Detect Mermaid code blocks up front so non-Mermaid documents skip the
    // matchMedia / getComputedStyle / mermaid.initialize work entirely.
    const codeBlocks = [];
    content.querySelectorAll("pre > code").forEach(function (code) {
      const language = code.className.match(/language-([A-Za-z0-9_-]+)/);
      if (language && language[1].toLowerCase() === "mermaid") {
        codeBlocks.push(code);
      }
    });
    if (codeBlocks.length === 0) {
      return [];
    }

    const isDark = typeof payload.themeIsDark === "boolean"
      ? payload.themeIsDark
      : (payload.theme === "dark" || (payload.theme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches));
    // Match Mermaid's font-family and font-size to the body so diagram labels appear
    // the same size as the surrounding prose.
    const bodyStyle = window.getComputedStyle(document.body);
    const rootStyle = window.getComputedStyle(document.documentElement);
    const cssVar = function (name) {
      const value = rootStyle.getPropertyValue(name);
      return value ? value.trim() : "";
    };
    const mermaidVars = {
      fontFamily: bodyStyle.fontFamily,
      fontSize: bodyStyle.fontSize
    };
    // Feed the theme's CSS variables into Mermaid so its diagram colors match
    // the surrounding page. Empty values fall back to Mermaid's built-in palette.
    const bg = cssVar("--skimdown-bg");
    const fg = cssVar("--skimdown-fg");
    const subtle = cssVar("--skimdown-subtle");
    const diagramLine = cssVar("--skimdown-diagram-line");
    const border = cssVar("--skimdown-border");
    if (bg) { mermaidVars.background = bg; }
    if (subtle) { mermaidVars.primaryColor = subtle; }
    if (fg) {
      mermaidVars.primaryTextColor = fg;
      mermaidVars.secondaryTextColor = fg;
      mermaidVars.tertiaryTextColor = fg;
    }
    if (border) { mermaidVars.primaryBorderColor = border; }
    if (diagramLine) { mermaidVars.lineColor = diagramLine; }
    window.mermaid.initialize({
      startOnLoad: false,
      theme: isDark ? "dark" : "default",
      securityLevel: "strict",
      fontFamily: bodyStyle.fontFamily,
      themeVariables: mermaidVars
    });

    const entries = [];
    codeBlocks.forEach(function (code) {
      const source = code.textContent;
      const fallback = code.parentElement.cloneNode(true);
      const wrapper = document.createElement("div");
      wrapper.className = "mermaid-container";
      // Make the container focusable so keyboard users can trigger :focus-within and reveal the toolbar.
      wrapper.tabIndex = 0;
      // Provide an accessible name so screen readers announce the focused container as a Mermaid diagram.
      wrapper.setAttribute("role", "group");
      wrapper.setAttribute("aria-label", "Mermaid diagram");
      const viewport = document.createElement("div");
      viewport.className = "mermaid-viewport";
      const diagram = document.createElement("div");
      diagram.className = "mermaid";
      diagram.textContent = source;
      viewport.appendChild(diagram);
      wrapper.appendChild(viewport);
      wrapper.appendChild(buildMermaidToolbar(wrapper, viewport));
      code.parentElement.replaceWith(wrapper);

      initMermaidZoomPan(wrapper, viewport);

      entries.push({ diagram: diagram, wrapper: wrapper, fallback: fallback });
    });

    // Run all diagrams in a single mermaid.run() call to avoid interleaving Mermaid's
    // internal state across parallel runs. Errors are suppressed here and handled per
    // diagram below by checking whether an SVG was actually produced.
    const allDiagrams = entries.map(function (entry) { return entry.diagram; });
    const task = window.mermaid
      .run({ nodes: allDiagrams, suppressErrors: true })
      .catch(function () { /* handled by the per-diagram fallback below */ })
      .then(function () {
        entries.forEach(function (entry) {
          const svg = entry.diagram.querySelector("svg");
          if (!svg) {
            entry.wrapper.replaceWith(entry.fallback);
            // mermaid runs after decorateCodeBlocks(content), so the cloned fallback
            // misses the language label / Copy button. Decorate it now.
            const fallbackCode = entry.fallback.querySelector("code");
            if (fallbackCode) {
              decorateCodeBlock(fallbackCode);
            }
            return;
          }
          // Intentionally leave Mermaid's width/height attributes on the SVG so the
          // diagram renders at its intrinsic (1:1) size where in-diagram text matches
          // body font-size. The card uses overflow: hidden, and drag-to-pan handles
          // diagrams that overflow the card (see initMermaidOverflowWatcher).
          initMermaidOverflowWatcher(entry.wrapper, svg);
          enableMermaidExpandButton(entry.wrapper);
        });
      });
    return [task];
  }

  // Watch the rendered SVG and toggle .mermaid-overflowing on the wrapper when the
  // SVG's intrinsic size exceeds the wrapper's content area. The class is used to
  // show the grab cursor and to enable drag-to-pan even when zoom is 1.
  //
  // Observers and resize handlers are kept at module scope so they can be torn down
  // at the start of each render (see teardownMermaidOverflowWatchers) — otherwise
  // they would leak across renders and keep detached wrappers alive.
  function initMermaidOverflowWatcher(wrapper, svg) {
    const update = function () {
      const svgRect = svg.getBoundingClientRect();
      const overflows = svgRect.width > wrapper.clientWidth + 1 ||
        svgRect.height > wrapper.clientHeight + 1;
      wrapper.classList.toggle("mermaid-overflowing", overflows);
    };
    update();
    if ("ResizeObserver" in window) {
      if (!mermaidResizeObserver) {
        mermaidResizeObserver = new ResizeObserver(function (entries) {
          // The observer is shared across all Mermaid wrappers; rerun the check for
          // each affected wrapper rather than tracking per-target callbacks.
          const wrappers = new Set();
          entries.forEach(function (entry) {
            const w = entry.target.classList && entry.target.classList.contains("mermaid-container")
              ? entry.target
              : entry.target.closest && entry.target.closest(".mermaid-container");
            if (w) { wrappers.add(w); }
          });
          wrappers.forEach(function (w) {
            const s = w.querySelector("svg");
            if (!s) { return; }
            const r = s.getBoundingClientRect();
            w.classList.toggle("mermaid-overflowing",
              r.width > w.clientWidth + 1 || r.height > w.clientHeight + 1);
          });
        });
      }
      mermaidResizeObserver.observe(wrapper);
      mermaidResizeObserver.observe(svg);
    } else if (!mermaidResizeHandler) {
      mermaidResizeHandler = function () {
        document.querySelectorAll(".mermaid-container").forEach(function (w) {
          const s = w.querySelector("svg");
          if (!s) { return; }
          const r = s.getBoundingClientRect();
          w.classList.toggle("mermaid-overflowing",
            r.width > w.clientWidth + 1 || r.height > w.clientHeight + 1);
        });
      };
      window.addEventListener("resize", mermaidResizeHandler);
    }
  }

  function teardownMermaidOverflowWatchers() {
    if (mermaidResizeObserver) {
      mermaidResizeObserver.disconnect();
      mermaidResizeObserver = null;
    }
    if (mermaidResizeHandler) {
      window.removeEventListener("resize", mermaidResizeHandler);
      mermaidResizeHandler = null;
    }
  }

  function buildMermaidToolbar(container, viewport) {
    var toolbar = document.createElement("div");
    toolbar.className = "mermaid-toolbar";

    var zoomIn = document.createElement("button");
    zoomIn.type = "button";
    zoomIn.className = "mermaid-zoom-btn";
    zoomIn.textContent = "+";
    zoomIn.setAttribute("aria-label", "Zoom in");

    var zoomOut = document.createElement("button");
    zoomOut.type = "button";
    zoomOut.className = "mermaid-zoom-btn";
    zoomOut.textContent = "\u2212";
    zoomOut.setAttribute("aria-label", "Zoom out");

    var zoomReset = document.createElement("button");
    zoomReset.type = "button";
    zoomReset.className = "mermaid-zoom-btn mermaid-zoom-reset";
    zoomReset.textContent = "Reset";
    zoomReset.setAttribute("aria-label", "Reset zoom");

    var expand = document.createElement("button");
    expand.type = "button";
    expand.className = "mermaid-zoom-btn mermaid-expand";
    expand.textContent = "Expand";
    expand.setAttribute("aria-label", "Open Mermaid diagram in expanded pane");
    expand.disabled = true;

    zoomIn.addEventListener("click", function () {
      applyMermaidZoom(container, viewport, 0.25);
    });
    zoomOut.addEventListener("click", function () {
      applyMermaidZoom(container, viewport, -0.25);
    });
    zoomReset.addEventListener("click", function () {
      resetMermaidZoom(container, viewport);
    });
    expand.addEventListener("click", function () {
      openMermaidModal(container, expand);
    });

    toolbar.appendChild(zoomOut);
    toolbar.appendChild(zoomReset);
    toolbar.appendChild(zoomIn);
    toolbar.appendChild(expand);
    return toolbar;
  }

  function enableMermaidExpandButton(container) {
    var button = container.querySelector(".mermaid-expand");
    if (button) {
      button.disabled = false;
    }
  }

  function openMermaidModal(container, openerElement) {
    var sourceSVG = container.querySelector("svg");
    if (!sourceSVG) {
      return;
    }

    closeActiveMermaidModal();

    var activeElement = document.activeElement;
    var opener = openerElement && openerElement.focus
      ? openerElement
      : activeElement && activeElement !== document.body && activeElement.focus
      ? activeElement
      : container;
    var modalID = "skimdown-mermaid-modal-" + (++mermaidModalSequence);
    var modal = document.createElement("div");
    modal.className = "mermaid-modal";
    modal.tabIndex = -1;
    modal.setAttribute("role", "dialog");
    modal.setAttribute("aria-modal", "true");
    modal.setAttribute("aria-labelledby", modalID + "-title");

    var panel = document.createElement("div");
    panel.className = "mermaid-modal-panel";

    var header = document.createElement("div");
    header.className = "mermaid-modal-header";

    var title = document.createElement("div");
    title.id = modalID + "-title";
    title.className = "mermaid-modal-title";
    title.textContent = "Mermaid diagram";

    var controls = document.createElement("div");
    controls.className = "mermaid-modal-controls";

    var zoomOut = buildMermaidModalButton("\u2212", "Zoom out", "mermaid-modal-zoom-out");
    var zoomReset = buildMermaidModalButton("Reset", "Reset zoom", "mermaid-modal-zoom-reset");
    var zoomIn = buildMermaidModalButton("+", "Zoom in", "mermaid-modal-zoom-in");
    var closeButton = buildMermaidModalButton("Close", "Close expanded Mermaid diagram", "mermaid-modal-close");

    var frame = document.createElement("div");
    frame.className = "mermaid-modal-frame";

    var viewport = document.createElement("div");
    viewport.className = "mermaid-modal-viewport";
    var modalSVG = cloneMermaidSVGForModal(sourceSVG);
    viewport.dataset.baseWidth = String(modalSVG.width);
    viewport.dataset.baseHeight = String(modalSVG.height);
    viewport.appendChild(modalSVG.svg);
    frame.appendChild(viewport);

    zoomOut.addEventListener("click", function () {
      applyMermaidZoom(modal, viewport, -0.25);
      resizeHandler();
    });
    zoomReset.addEventListener("click", function () {
      refreshMermaidModalBaseline(frame, viewport);
      resetMermaidZoom(modal, viewport);
      resizeHandler();
    });
    zoomIn.addEventListener("click", function () {
      applyMermaidZoom(modal, viewport, 0.25);
      resizeHandler();
    });
    closeButton.addEventListener("click", closeModal);

    controls.appendChild(zoomOut);
    controls.appendChild(zoomReset);
    controls.appendChild(zoomIn);
    controls.appendChild(closeButton);
    header.appendChild(title);
    header.appendChild(controls);
    panel.appendChild(header);
    panel.appendChild(frame);
    modal.appendChild(panel);

    var resizeHandler = function () {
      updateMermaidModalOverflow(modal, frame, viewport);
    };
    var backdropMouseDown = false;

    function closeModal() {
      if (!activeMermaidModal || activeMermaidModal.element !== modal) {
        return;
      }
      endMermaidDrag();
      window.removeEventListener("resize", resizeHandler);
      modal.remove();
      document.documentElement.classList.remove("skimdown-mermaid-modal-open");
      document.body.classList.remove("skimdown-mermaid-modal-open");
      activeMermaidModal = null;
      restoreMermaidModalFocus(opener, container);
    }

    modal.addEventListener("mousedown", function (event) {
      backdropMouseDown = event.target === modal;
    });
    modal.addEventListener("click", function (event) {
      if (event.target === modal && backdropMouseDown) {
        closeModal();
      }
      backdropMouseDown = false;
    });
    modal.addEventListener("keydown", function (event) {
      handleMermaidModalKeydown(event, modal, closeModal);
    });

    activeMermaidModal = { element: modal, close: closeModal };
    document.documentElement.classList.add("skimdown-mermaid-modal-open");
    document.body.classList.add("skimdown-mermaid-modal-open");
    document.body.appendChild(modal);

    initMermaidZoomPan(modal, viewport, {
      wheelTarget: frame,
      preventPlainWheel: true,
      alwaysAllowPan: true,
      overflowClass: "mermaid-modal-overflowing"
    });
    window.addEventListener("resize", resizeHandler);
    initializeMermaidModalZoom(modal, frame, viewport);
    updateMermaidModalOverflow(modal, frame, viewport);
    window.requestAnimationFrame(function () {
      if (!activeMermaidModal || activeMermaidModal.element !== modal) {
        return;
      }
      updateMermaidModalOverflow(modal, frame, viewport);
      closeButton.focus();
    });
  }

  function closeActiveMermaidModal() {
    if (activeMermaidModal) {
      activeMermaidModal.close();
    }
  }

  function restoreMermaidModalFocus(opener, container) {
    if (isRestorableMermaidFocusTarget(opener)) {
      opener.focus();
      if (document.activeElement === opener) {
        return;
      }
    }
    if (isRestorableMermaidFocusTarget(container)) {
      container.focus();
    }
  }

  function isRestorableMermaidFocusTarget(element) {
    if (!element || typeof element.focus !== "function" || !document.contains(element)) {
      return false;
    }
    if (element.disabled || element.getAttribute("aria-disabled") === "true") {
      return false;
    }
    var style = window.getComputedStyle(element);
    if (!style || style.display === "none" || style.visibility === "hidden") {
      return false;
    }
    return element.getClientRects().length > 0;
  }

  function buildMermaidModalButton(text, ariaLabel, className) {
    var button = document.createElement("button");
    button.type = "button";
    button.className = "mermaid-modal-button " + className;
    button.textContent = text;
    button.setAttribute("aria-label", ariaLabel);
    return button;
  }

  function handleMermaidModalKeydown(event, modal, closeModal) {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      closeModal();
      return;
    }

    if (event.key !== "Tab") {
      return;
    }

    var focusable = mermaidModalFocusableElements(modal);
    if (focusable.length === 0) {
      event.preventDefault();
      modal.focus();
      return;
    }

    var first = focusable[0];
    var last = focusable[focusable.length - 1];
    if (document.activeElement === modal) {
      event.preventDefault();
      (event.shiftKey ? last : first).focus();
    } else if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  function mermaidModalFocusableElements(modal) {
    return Array.from(modal.querySelectorAll([
      "button:not([disabled])",
      "[href]",
      "input:not([disabled])",
      "select:not([disabled])",
      "textarea:not([disabled])",
      "[tabindex]:not([tabindex='-1'])"
    ].join(","))).filter(function (element) {
      return element.getAttribute("aria-hidden") !== "true";
    });
  }

  function cloneMermaidSVGForModal(sourceSVG) {
    var clone = sourceSVG.cloneNode(true);
    var baseSize = mermaidSVGBaseSize(sourceSVG);
    var suffix = "skimdown-modal-svg-" + (++mermaidModalSequence);
    var elements = [clone].concat(Array.from(clone.querySelectorAll("*")));
    var idMap = new Map();

    elements.forEach(function (element) {
      var id = element.getAttribute("id");
      if (!id) {
        return;
      }
      var newID = id + "-" + suffix;
      idMap.set(id, newID);
      element.setAttribute("id", newID);
    });

    if (idMap.size > 0) {
      elements.forEach(function (element) {
        Array.from(element.attributes || []).forEach(function (attribute) {
          var remapped = remapMermaidSVGAttributeValue(attribute.name, attribute.value, idMap);
          if (remapped !== attribute.value) {
            element.setAttribute(attribute.name, remapped);
          }
        });
        if (element.tagName && element.tagName.toLowerCase() === "style") {
          element.textContent = remapMermaidSVGReferences(element.textContent || "", idMap);
        }
      });
    }

    clone.classList.add("mermaid-modal-svg");
    normalizeMermaidModalSVG(clone, baseSize);
    return { svg: clone, width: baseSize.width, height: baseSize.height };
  }

  function mermaidSVGBaseSize(svg) {
    var viewBoxSize = mermaidSVGViewBoxSize(svg);
    if (viewBoxSize) {
      return viewBoxSize;
    }

    var attrWidth = parseSVGLength(svg.getAttribute("width"));
    var attrHeight = parseSVGLength(svg.getAttribute("height"));
    if (attrWidth && attrHeight) {
      return { width: attrWidth, height: attrHeight };
    }

    try {
      var bbox = svg.getBBox();
      if (bbox && bbox.width > 0 && bbox.height > 0) {
        return { width: bbox.width, height: bbox.height };
      }
    } catch (_) {}

    var rect = svg.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) {
      return { width: rect.width, height: rect.height };
    }

    return { width: 300, height: 150 };
  }

  function mermaidSVGViewBoxSize(svg) {
    var viewBox = svg.getAttribute("viewBox");
    if (!viewBox) {
      return null;
    }
    var values = viewBox.trim().split(/[\s,]+/).map(Number);
    if (values.length !== 4 || values.some(function (value) { return !Number.isFinite(value); })) {
      return null;
    }
    var width = values[2];
    var height = values[3];
    if (width <= 0 || height <= 0) {
      return null;
    }
    return { width: width, height: height };
  }

  function parseSVGLength(value) {
    if (!value) {
      return null;
    }
    var trimmed = String(value).trim();
    if (trimmed.endsWith("%")) {
      return null;
    }
    var number = parseFloat(trimmed);
    return Number.isFinite(number) && number > 0 ? number : null;
  }

  function normalizeMermaidModalSVG(svg, baseSize) {
    var width = Math.max(1, Math.round(baseSize.width * 100) / 100);
    var height = Math.max(1, Math.round(baseSize.height * 100) / 100);

    svg.setAttribute("width", String(width));
    svg.setAttribute("height", String(height));
    svg.style.width = width + "px";
    svg.style.height = height + "px";
    svg.style.maxWidth = "none";
    svg.style.maxHeight = "none";
  }

  function remapMermaidSVGAttributeValue(name, value, idMap) {
    if (name === "aria-labelledby" || name === "aria-describedby") {
      return String(value).split(/\s+/).map(function (id) {
        return idMap.get(id) || id;
      }).join(" ");
    }
    return remapMermaidSVGReferences(value, idMap);
  }

  function remapMermaidSVGReferences(value, idMap) {
    var next = value;
    idMap.forEach(function (newID, oldID) {
      var escapedID = escapeRegExp(oldID);
      next = next.replace(new RegExp("url\\(\\s*#" + escapedID + "\\s*\\)", "g"), "url(#" + newID + ")");
      next = next.replace(new RegExp("#" + escapedID + "(?![A-Za-z0-9_-])", "g"), "#" + newID);
    });
    return next;
  }

  function updateMermaidModalOverflow(modal, frame, viewport) {
    var svg = viewport.querySelector("svg");
    if (!svg) {
      modal.classList.remove("mermaid-modal-overflowing");
      return;
    }
    var svgRect = svg.getBoundingClientRect();
    var frameRect = frame.getBoundingClientRect();
    modal.classList.toggle(
      "mermaid-modal-overflowing",
      svgRect.width > frameRect.width + 1 || svgRect.height > frameRect.height + 1
    );
  }

  function initializeMermaidModalZoom(modal, frame, viewport) {
    refreshMermaidModalBaseline(frame, viewport);
    resetMermaidZoom(modal, viewport);
  }

  function refreshMermaidModalBaseline(frame, viewport) {
    var baseline = mermaidModalInitialZoom(frame, viewport);
    viewport.dataset.zoomBaseline = String(baseline);
    return baseline;
  }

  function mermaidModalInitialZoom(frame, viewport) {
    var baseWidth = parseFloat(viewport.dataset.baseWidth) || 0;
    var baseHeight = parseFloat(viewport.dataset.baseHeight) || 0;
    if (baseWidth <= 0 || baseHeight <= 0) {
      return 1;
    }

    var available = mermaidModalAvailableSize(frame);
    if (available.width <= 0 || available.height <= 0) {
      return 1;
    }

    var contain = Math.min(available.width / baseWidth, available.height / baseHeight);
    if (!Number.isFinite(contain) || contain <= 0) {
      return 1;
    }
    return Math.max(0.01, Math.floor(Math.min(contain, 3) * 100) / 100);
  }

  function mermaidModalAvailableSize(frame) {
    var style = window.getComputedStyle(frame);
    var horizontalPadding = parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
    var verticalPadding = parseFloat(style.paddingTop) + parseFloat(style.paddingBottom);
    return {
      width: Math.max(0, frame.clientWidth - (Number.isFinite(horizontalPadding) ? horizontalPadding : 0)),
      height: Math.max(0, frame.clientHeight - (Number.isFinite(verticalPadding) ? verticalPadding : 0))
    };
  }

  function updateViewportTransform(viewport, zoom, px, py) {
    viewport.style.transform = "translate(" + px + "px, " + py + "px) scale(" + zoom + ")";
  }

  function applyMermaidZoom(container, viewport, delta) {
    var current = parseFloat(viewport.dataset.zoom) || 1;
    var baseline = parseFloat(viewport.dataset.zoomBaseline) || 1;
    var minZoom = Math.min(0.25, baseline);
    var next = Math.round(Math.min(Math.max(current + delta, minZoom), 4) * 100) / 100;
    if (Math.abs(next - baseline) < 0.05) { next = baseline; }
    if (next === baseline) {
      resetMermaidZoom(container, viewport);
      return;
    }
    viewport.dataset.zoom = String(next);
    updateViewportTransform(viewport, next, parseFloat(viewport.dataset.panX) || 0, parseFloat(viewport.dataset.panY) || 0);
    if (container) {
      container.classList.toggle("mermaid-zoomed", next > baseline);
    }
  }

  function resetMermaidZoom(container, viewport) {
    var baseline = parseFloat(viewport.dataset.zoomBaseline) || 1;
    viewport.dataset.zoom = String(baseline);
    viewport.dataset.panX = "0";
    viewport.dataset.panY = "0";
    if (baseline === 1) {
      viewport.style.transform = "";
    } else {
      updateViewportTransform(viewport, baseline, 0, 0);
    }
    if (container) {
      container.classList.remove("mermaid-zoomed");
    }
  }

  var activeDragViewport = null;
  var dragStartX = 0;
  var dragStartY = 0;
  var dragBasePanX = 0;
  var dragBasePanY = 0;

  document.addEventListener("mousemove", function (e) {
    if (!activeDragViewport) { return; }
    var zoom = parseFloat(activeDragViewport.dataset.zoom) || 1;
    var dx = (e.clientX - dragStartX);
    var dy = (e.clientY - dragStartY);
    activeDragViewport.dataset.panX = String(dragBasePanX + dx);
    activeDragViewport.dataset.panY = String(dragBasePanY + dy);
    updateViewportTransform(activeDragViewport, zoom, dragBasePanX + dx, dragBasePanY + dy);
  });

  function endMermaidDrag() {
    if (!activeDragViewport) { return; }
    activeDragViewport.classList.remove("mermaid-dragging");
    activeDragViewport.style.cursor = "";
    activeDragViewport = null;
  }

  // Also end the drag on blur and mouseleave so the dragging state cannot get stuck
  // when mouseup is missed (mouse released outside the window or focus is lost).
  document.addEventListener("mouseup", endMermaidDrag);
  document.addEventListener("mouseleave", endMermaidDrag);
  window.addEventListener("blur", endMermaidDrag);

  function initMermaidZoomPan(container, viewport, options) {
    options = options || {};
    var wheelTarget = options.wheelTarget || container;
    var overflowClass = options.overflowClass || "mermaid-overflowing";
    var preventPlainWheel = options.preventPlainWheel === true;
    var alwaysAllowPan = options.alwaysAllowPan === true;

    wheelTarget.addEventListener("wheel", function (e) {
      if (!e.ctrlKey && !e.metaKey) {
        if (preventPlainWheel) {
          e.preventDefault();
          e.stopPropagation();
        }
        return;
      }
      e.preventDefault();
      if (preventPlainWheel) {
        e.stopPropagation();
      }
      var delta = e.deltaY > 0 ? -0.1 : 0.1;
      applyMermaidZoom(container, viewport, delta);
    }, { passive: false });

    viewport.addEventListener("mousedown", function (e) {
      if (e.button !== 0) { return; }
      var zoom = parseFloat(viewport.dataset.zoom) || 1;
      // Allow drag-to-pan when zoomed in OR when the diagram overflows the card.
      if (!alwaysAllowPan && zoom <= 1 && !container.classList.contains(overflowClass)) { return; }
      e.preventDefault();
      activeDragViewport = viewport;
      viewport.classList.add("mermaid-dragging");
      dragStartX = e.clientX;
      dragStartY = e.clientY;
      dragBasePanX = parseFloat(viewport.dataset.panX) || 0;
      dragBasePanY = parseFloat(viewport.dataset.panY) || 0;
      viewport.style.cursor = "grabbing";
    });
  }

  function decorateCodeBlocks(content) {
    content.querySelectorAll("pre > code").forEach(decorateCodeBlock);
  }

  function resetCodeCopyButton(button) {
    button.textContent = "Copy";
    button.setAttribute("aria-label", "Copy code");
    button.classList.remove("code-copy-copied");
  }

  function decorateCodeBlock(code) {
    const pre = code.parentElement;
    if (!pre || pre.querySelector(".code-toolbar")) {
      return;
    }

    const languageMatch = code.className.match(/language-([A-Za-z0-9_-]+)/);
    const toolbar = document.createElement("div");
    toolbar.className = "code-toolbar";

    if (languageMatch) {
      const label = document.createElement("span");
      label.className = "code-language";
      label.textContent = languageMatch[1];
      toolbar.appendChild(label);
    }

    const button = document.createElement("button");
    button.className = "code-copy";
    button.type = "button";
    resetCodeCopyButton(button);
    let feedbackResetTimer = null;
    button.addEventListener("click", function () {
      window.webkit.messageHandlers.copyCode.postMessage(code.textContent || "");
      button.textContent = "Copied";
      button.setAttribute("aria-label", "Copied code");
      button.classList.add("code-copy-copied");
      if (feedbackResetTimer !== null) {
        window.clearTimeout(feedbackResetTimer);
      }
      const resetTimer = window.setTimeout(function () {
        if (feedbackResetTimer !== resetTimer) {
          return;
        }
        feedbackResetTimer = null;
        resetCodeCopyButton(button);
      }, CODE_COPY_FEEDBACK_RESET_MS);
      feedbackResetTimer = resetTimer;
    });
    toolbar.appendChild(button);
    pre.appendChild(toolbar);
  }

  function decorateColorCodes(content) {
    const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        if (!node.nodeValue || !COLOR_CODE_DETECTION_PATTERN.test(node.nodeValue)) {
          return NodeFilter.FILTER_REJECT;
        }
        const parent = node.parentElement;
        if (!parent || parent.closest("a, code, kbd, pre, script, style, .katex, .skimdown-color-code, .mermaid, .mermaid-container")) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    });

    const nodes = [];
    while (walker.nextNode()) {
      nodes.push(walker.currentNode);
    }

    const replacementPattern = new RegExp(COLOR_CODE_PATTERN_SOURCE, "g");
    nodes.forEach(function (node) {
      const fragment = document.createDocumentFragment();
      const value = node.nodeValue;
      let lastIndex = 0;
      let match;
      replacementPattern.lastIndex = 0;
      while ((match = replacementPattern.exec(value)) !== null) {
        const color = match[2];
        const colorIndex = match.index + match[1].length;
        fragment.appendChild(document.createTextNode(value.slice(lastIndex, colorIndex)));
        fragment.appendChild(colorCodePreview(color));
        lastIndex = colorIndex + color.length;
      }
      fragment.appendChild(document.createTextNode(value.slice(lastIndex)));
      node.replaceWith(fragment);
    });
  }

  function colorCodePreview(color) {
    const wrapper = document.createElement("span");
    wrapper.className = "skimdown-color-code";
    wrapper.textContent = color;

    const swatch = document.createElement("span");
    swatch.className = "skimdown-color-swatch";
    swatch.style.backgroundColor = color;
    swatch.title = color;
    swatch.setAttribute("role", "img");
    swatch.setAttribute("aria-label", "Color preview " + color);
    wrapper.appendChild(swatch);

    return wrapper;
  }

  function convertMathBlocks(content) {
    content.querySelectorAll("pre > code.language-math").forEach(function (code) {
      var pre = code.parentElement;
      var mathDiv = document.createElement("div");
      mathDiv.className = "skimdown-math-block";
      mathDiv.textContent = "$$" + code.textContent + "$$";
      pre.replaceWith(mathDiv);
    });
  }

  // Convert GitHub's $`…`$ backtick-math to inline math in the DOM.
  // markdown-it renders $`…`$ as: text"$" + <code>…</code> + text"$".
  // We find <code> elements preceded by "$" and followed by "$" and
  // directly render them as KaTeX inline math.
  function convertBacktickMath(content) {
    if (!window.katex) { return; }
    // Collect matches first to avoid mutating during iteration
    var matches = [];
    content.querySelectorAll("code").forEach(function (code) {
      if (code.closest("pre")) { return; }
      var prev = code.previousSibling;
      var next = code.nextSibling;
      if (!prev || prev.nodeType !== Node.TEXT_NODE) { return; }
      if (!next || next.nodeType !== Node.TEXT_NODE) { return; }
      if (!prev.nodeValue.endsWith("$")) { return; }
      if (!next.nodeValue.startsWith("$")) { return; }
      matches.push({ code: code, prev: prev, next: next });
    });
    matches.forEach(function (m) {
      var latex = m.code.textContent;
      try {
        var span = document.createElement("span");
        window.katex.render(latex, span, { throwOnError: false, displayMode: false });
        m.prev.nodeValue = m.prev.nodeValue.slice(0, -1);
        m.next.nodeValue = m.next.nodeValue.slice(1);
        if (m.prev.nodeValue === "") { m.prev.remove(); }
        if (m.next.nodeValue === "") { m.next.remove(); }
        m.code.replaceWith(span);
      } catch (_) {
        // On failure, leave the DOM unchanged
      }
    });
  }

  function renderMath(content) {
    if (!window.renderMathInElement) {
      return;
    }

    try {
      window.renderMathInElement(content, {
        throwOnError: false,
        delimiters: [
          { left: "$$", right: "$$", display: true },
          { left: "\\[", right: "\\]", display: true },
          { left: "$", right: "$", display: false },
          { left: "\\(", right: "\\)", display: false }
        ]
      });
    } catch (_) {}
  }

  function clearSearch() {
    searchMatches = [];
    currentSearchIndex = -1;
    document.querySelectorAll(".skimdown-search-match").forEach(function (mark) {
      const text = document.createTextNode(mark.textContent);
      mark.replaceWith(text);
    });
    var content = document.getElementById("content");
    if (content) {
      content.normalize();
    }
  }

  function performSearch(query, caseSensitive, scrollToMatch) {
    clearSearch();
    if (!query) {
      return searchState();
    }

    const content = document.getElementById("content");
    const flags = caseSensitive ? "g" : "gi";
    const pattern = new RegExp(escapeRegExp(query), flags);
    const segments = collectSearchTextSegments(content);
    const searchableText = segments.map(function (segment) { return segment.text; }).join("");
    const replacements = new Map();
    Array.from(searchableText.matchAll(pattern)).forEach(function (match) {
      const group = [];
      const matchStart = match.index;
      const matchEnd = matchStart + match[0].length;
      let overlapIndex = firstOverlappingSegmentIndex(segments, matchStart);
      let hasOverlap = false;
      while (overlapIndex < segments.length && segments[overlapIndex].start < matchEnd) {
        const segment = segments[overlapIndex];
        if (!segment.node) { overlapIndex++; continue; }
        const start = Math.max(matchStart, segment.start) - segment.start;
        const end = Math.min(matchEnd, segment.end) - segment.start;
        if (!replacements.has(segment.node)) {
          replacements.set(segment.node, []);
        }
        replacements.get(segment.node).push({ start: start, end: end, group: group });
        hasOverlap = true;
        overlapIndex++;
      }
      if (hasOverlap) {
        searchMatches.push(group);
      }
    });

    segments.forEach(function (segment) {
      const ranges = replacements.get(segment.node);
      if (!ranges || ranges.length === 0) {
        return;
      }
      applySearchReplacements(segment, ranges);
    });

    if (searchMatches.length > 0) {
      if (scrollToMatch === false) {
        currentSearchIndex = nearestSearchIndexToViewport();
      } else {
        currentSearchIndex = 0;
      }
      updateCurrentSearchMatch(scrollToMatch !== false);
    }
    return searchState();
  }

  function firstOverlappingSegmentIndex(segments, offset) {
    let low = 0;
    let high = segments.length;
    while (low < high) {
      const mid = Math.floor((low + high) / 2);
      if (segments[mid].end <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  function applySearchReplacements(segment, ranges) {
    const fragment = document.createDocumentFragment();
    let lastIndex = 0;
    ranges.forEach(function (range) {
      fragment.appendChild(document.createTextNode(segment.text.slice(lastIndex, range.start)));
      const mark = document.createElement("mark");
      mark.className = "skimdown-search-match";
      mark.textContent = segment.text.slice(range.start, range.end);
      fragment.appendChild(mark);
      range.group.push(mark);
      lastIndex = range.end;
    });
    fragment.appendChild(document.createTextNode(segment.text.slice(lastIndex)));
    segment.node.replaceWith(fragment);
  }

  var SEARCH_BLOCK_TAGS = new Set([
    "ADDRESS", "ARTICLE", "ASIDE", "BLOCKQUOTE", "DD", "DETAILS", "DIALOG",
    "DIV", "DL", "DT", "FIELDSET", "FIGCAPTION", "FIGURE", "FOOTER",
    "FORM", "H1", "H2", "H3", "H4", "H5", "H6", "HEADER", "HGROUP", "HR",
    "LI", "MAIN", "NAV", "OL", "P", "PRE", "SECTION", "SUMMARY", "TABLE",
    "TBODY", "TD", "TFOOT", "TH", "THEAD", "TR", "UL"
  ]);

  function closestBlockAncestor(node, root) {
    var el = node.parentElement;
    while (el && el !== root) {
      if (SEARCH_BLOCK_TAGS.has(el.tagName)) { return el; }
      el = el.parentElement;
    }
    return root;
  }

  function collectSearchTextSegments(content) {
    const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        if (!node.nodeValue) {
          return NodeFilter.FILTER_REJECT;
        }
        const parent = node.parentElement;
        if (!parent || ["SCRIPT", "STYLE"].includes(parent.tagName)) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    });

    const segments = [];
    let offset = 0;
    let prevBlock = null;
    while (walker.nextNode()) {
      const node = walker.currentNode;
      const text = node.nodeValue;
      const block = closestBlockAncestor(node, content);
      if (prevBlock !== null && block !== prevBlock) {
        segments.push({ node: null, text: "\n", start: offset, end: offset + 1 });
        offset += 1;
      }
      segments.push({ node: node, text: text, start: offset, end: offset + text.length });
      offset += text.length;
      prevBlock = block;
    }
    return segments;
  }

  function nearestSearchIndexToViewport() {
    if (searchMatches.length === 0) {
      return -1;
    }
    const anchor = window.scrollY + window.innerHeight / 2;
    let bestIndex = 0;
    let bestDistance = Infinity;
    for (let i = 0; i < searchMatches.length; i++) {
      const target = searchMatches[i][0];
      const rect = target.getBoundingClientRect();
      const center = window.scrollY + rect.top + rect.height / 2;
      const distance = Math.abs(center - anchor);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  function nextSearch() {
    if (searchMatches.length === 0) {
      return searchState();
    }
    currentSearchIndex = (currentSearchIndex + 1) % searchMatches.length;
    scrollToCurrentSearchMatch();
    return searchState();
  }

  function previousSearch() {
    if (searchMatches.length === 0) {
      return searchState();
    }
    currentSearchIndex = (currentSearchIndex - 1 + searchMatches.length) % searchMatches.length;
    scrollToCurrentSearchMatch();
    return searchState();
  }

  function scrollToCurrentSearchMatch() {
    updateCurrentSearchMatch(true);
  }

  function updateCurrentSearchMatch(scrollToMatch) {
    searchMatches.forEach(function (matchGroup) {
      matchGroup.forEach(function (match) {
        match.classList.remove("skimdown-search-current");
      });
    });
    const current = searchMatches[currentSearchIndex];
    if (current) {
      current.forEach(function (match) {
        match.classList.add("skimdown-search-current");
      });
      if (scrollToMatch) {
        clearProgrammaticActiveHeadingAndUpdate();
        current[0].scrollIntoView({ block: "center" });
      }
    }
  }

  function searchState() {
    return { count: searchMatches.length, index: currentSearchIndex >= 0 ? currentSearchIndex + 1 : 0 };
  }

  function escapeRegExp(value) {
    return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  function scrollToAnchor(anchor) {
    clearProgrammaticActiveHeadingAndUpdate();
    if (!anchor) {
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }

    const decoded = decodeAnchor(anchor);
    const slug = slugifyHeadingText(decoded);
    const target = document.getElementById(decoded) ||
      (slug && slug !== decoded ? document.getElementById(slug) : null) ||
      namedAnchorTarget(decoded);
    if (target) {
      target.scrollIntoView({ block: "start", behavior: "smooth" });
    }
  }

  function scrollToElementID(elementID) {
    const target = document.getElementById(elementID || "");
    if (target) {
      setProgrammaticActiveHeading(activeHeadingRenderID, target.id);
      target.scrollIntoView({ block: "start", behavior: "smooth" });
    } else {
      clearProgrammaticActiveHeadingAndUpdate();
    }
  }

  function decodeAnchor(anchor) {
    try {
      return decodeURIComponent(anchor);
    } catch (_) {
      return anchor;
    }
  }

  function namedAnchorTarget(anchor) {
    if (!window.CSS || !CSS.escape) {
      return null;
    }
    return document.querySelector("[name='" + CSS.escape(anchor) + "']");
  }

  function waitForImages(content) {
    const images = Array.from(content.querySelectorAll("img"));
    if (images.length === 0) {
      return Promise.resolve();
    }

    return Promise.all(images.map(waitForImage));
  }

  function waitForImage(image) {
    return new Promise(function (resolve) {
      if (image.complete) {
        resolve();
        return;
      }

      let didResolve = false;
      const timeoutID = window.setTimeout(finish, IMAGE_READY_TIMEOUT_MS);

      function finish() {
        if (didResolve) {
          return;
        }
        didResolve = true;
        window.clearTimeout(timeoutID);
        image.removeEventListener("load", finish);
        image.removeEventListener("error", finish);
        resolve();
      }

      image.addEventListener("load", finish, { once: true });
      image.addEventListener("error", finish, { once: true });
      if (image.complete) {
        finish();
      }
    });
  }

  function notifyWhenRenderSettled(content, renderID, mermaidTasks, restoreScrollY) {
    const awaitFullSettle = restoreScrollY > 0;
    waitForRenderSettled(content, mermaidTasks, awaitFullSettle).then(function () {
      applyRestoreAndUnveil(restoreScrollY);
      postRenderReady(renderID);
    }, function () {
      applyRestoreAndUnveil(restoreScrollY);
      postRenderReady(renderID);
    });
  }

  function applyRestoreAndUnveil(restoreScrollY) {
    if (restoreScrollY > 0) {
      window.scrollTo(0, restoreScrollY);
      // Force a synchronous layout/scroll commit so the unveil paint shows the restored position.
      void window.scrollY;
    }
    document.body.classList.remove("skimdown-restoring");
  }

  function waitForRenderSettled(content, mermaidTasks, awaitFullSettle) {
    const mermaid = Promise.all(mermaidTasks);
    if (!awaitFullSettle) {
      return mermaid.then(waitForSingleLayoutFrame);
    }
    return mermaid
      .then(function () {
        return waitForImages(content);
      })
      .then(waitForFonts)
      .then(waitForLayoutFrame);
  }

  function waitForSingleLayoutFrame() {
    return new Promise(function (resolve) {
      window.requestAnimationFrame(resolve);
    });
  }

  function waitForFonts() {
    if (document.fonts && document.fonts.ready) {
      return document.fonts.ready;
    }
    return Promise.resolve();
  }

  function waitForLayoutFrame() {
    return new Promise(function (resolve) {
      window.requestAnimationFrame(function () {
        window.requestAnimationFrame(resolve);
      });
    });
  }

  function postRenderReady(renderID) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.renderReady) {
      window.webkit.messageHandlers.renderReady.postMessage({ renderID: renderID });
    }
  }

  window.skimdown = {
    render: render,
    performSearch: performSearch,
    nextSearch: nextSearch,
    previousSearch: previousSearch,
    scrollToAnchor: scrollToAnchor,
    scrollToElementID: scrollToElementID,
    tableOfContents: tableOfContents
  };
})();

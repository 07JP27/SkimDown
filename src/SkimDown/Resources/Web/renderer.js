(function () {
  let markdownIt = null;
  let searchMatches = [];
  let currentSearchIndex = -1;
  let tableResizeObserver = null;
  let tableResizeHandler = null;
  let mermaidResizeObserver = null;
  let mermaidResizeHandler = null;
  const IMAGE_READY_TIMEOUT_MS = 3000;

  function renderer() {
    if (!markdownIt) {
      markdownIt = window.markdownit({
        html: true,
        linkify: true,
        typographer: false,
        highlight: function (code, language) {
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

    const content = document.getElementById("content");
    const dirtyHtml = renderer().render(payload.markdown || "");
    content.innerHTML = window.DOMPurify.sanitize(dirtyHtml, {
      FORBID_TAGS: ["script", "iframe", "object", "embed", "style"],
      ALLOW_DATA_ATTR: false
    });

    normalizeTaskLists(content);
    normalizeLinksAndImages(content, payload);
    wrapTables(content);
    initializeTableScrollCues(content);
    const mermaidTasks = renderMermaidBlocks(content, payload);
    decorateCodeBlocks(content);
    renderMath(content);
    clearSearch();

    notifyWhenRenderSettled(content, payload.renderID, mermaidTasks, restoreScrollY);
    installUserInteractionWatcher(payload.renderID);
    installScrollPositionListener(payload.renderID);
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

  function normalizeLinksAndImages(content, payload) {
    const baseURL = payload.baseURL || document.baseURI;
    const rootURL = payload.rootURL || "";

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
        if (resolved.protocol === "file:" && rootURL && !resolved.href.startsWith(rootURL)) {
          image.removeAttribute("src");
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

    const isDark = payload.theme === "dark" || (payload.theme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);
    // Match Mermaid's font-family and font-size to the body so diagram labels appear
    // the same size as the surrounding prose.
    const bodyStyle = window.getComputedStyle(document.body);
    window.mermaid.initialize({
      startOnLoad: false,
      theme: isDark ? "dark" : "default",
      securityLevel: "strict",
      fontFamily: bodyStyle.fontFamily,
      themeVariables: {
        fontFamily: bodyStyle.fontFamily,
        fontSize: bodyStyle.fontSize
      }
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
      wrapper.appendChild(buildMermaidToolbar(viewport));
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

  function buildMermaidToolbar(viewport) {
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

    zoomIn.addEventListener("click", function () {
      applyMermaidZoom(viewport, 0.25);
    });
    zoomOut.addEventListener("click", function () {
      applyMermaidZoom(viewport, -0.25);
    });
    zoomReset.addEventListener("click", function () {
      resetMermaidZoom(viewport);
    });

    toolbar.appendChild(zoomOut);
    toolbar.appendChild(zoomReset);
    toolbar.appendChild(zoomIn);
    return toolbar;
  }

  function updateViewportTransform(viewport, zoom, px, py) {
    viewport.style.transform = "translate(" + px + "px, " + py + "px) scale(" + zoom + ")";
  }

  function applyMermaidZoom(viewport, delta) {
    var current = parseFloat(viewport.dataset.zoom) || 1;
    var next = Math.round(Math.min(Math.max(current + delta, 0.25), 4) * 100) / 100;
    if (Math.abs(next - 1) < 0.05) { next = 1; }
    if (next === 1) {
      resetMermaidZoom(viewport);
      return;
    }
    viewport.dataset.zoom = String(next);
    updateViewportTransform(viewport, next, parseFloat(viewport.dataset.panX) || 0, parseFloat(viewport.dataset.panY) || 0);
    // Only flag as "zoomed" when above 1x — drag-to-pan is gated on zoom > 1, so the
    // grab cursor should not appear for zoom-out states (0.25x–0.95x) where panning
    // is intentionally disabled.
    viewport.closest(".mermaid-container").classList.toggle("mermaid-zoomed", next > 1);
  }

  function resetMermaidZoom(viewport) {
    viewport.dataset.zoom = "1";
    viewport.dataset.panX = "0";
    viewport.dataset.panY = "0";
    viewport.style.transform = "";
    viewport.closest(".mermaid-container").classList.remove("mermaid-zoomed");
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

  function initMermaidZoomPan(container, viewport) {
    container.addEventListener("wheel", function (e) {
      if (!e.ctrlKey && !e.metaKey) { return; }
      e.preventDefault();
      var delta = e.deltaY > 0 ? -0.1 : 0.1;
      applyMermaidZoom(viewport, delta);
    }, { passive: false });

    viewport.addEventListener("mousedown", function (e) {
      if (e.button !== 0) { return; }
      var zoom = parseFloat(viewport.dataset.zoom) || 1;
      // Allow drag-to-pan when zoomed in OR when the diagram overflows the card.
      if (zoom <= 1 && !container.classList.contains("mermaid-overflowing")) { return; }
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
    button.textContent = "Copy";
    button.addEventListener("click", function () {
      window.webkit.messageHandlers.copyCode.postMessage(code.textContent || "");
    });
    toolbar.appendChild(button);
    pre.appendChild(toolbar);
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
    const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        if (!node.nodeValue || !pattern.test(node.nodeValue)) {
          return NodeFilter.FILTER_REJECT;
        }
        pattern.lastIndex = 0;
        const parent = node.parentElement;
        if (!parent || ["SCRIPT", "STYLE"].includes(parent.tagName)) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    });

    const nodes = [];
    while (walker.nextNode()) {
      nodes.push(walker.currentNode);
    }

    nodes.forEach(function (node) {
      const fragment = document.createDocumentFragment();
      const value = node.nodeValue;
      let lastIndex = 0;
      pattern.lastIndex = 0;
      let match;
      while ((match = pattern.exec(value)) !== null) {
        fragment.appendChild(document.createTextNode(value.slice(lastIndex, match.index)));
        const mark = document.createElement("mark");
        mark.className = "skimdown-search-match";
        mark.textContent = match[0];
        fragment.appendChild(mark);
        searchMatches.push(mark);
        lastIndex = match.index + match[0].length;
      }
      fragment.appendChild(document.createTextNode(value.slice(lastIndex)));
      node.replaceWith(fragment);
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

  function nearestSearchIndexToViewport() {
    if (searchMatches.length === 0) {
      return -1;
    }
    const anchor = window.scrollY + window.innerHeight / 2;
    let bestIndex = 0;
    let bestDistance = Infinity;
    for (let i = 0; i < searchMatches.length; i++) {
      const rect = searchMatches[i].getBoundingClientRect();
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
    searchMatches.forEach(function (match) {
      match.classList.remove("skimdown-search-current");
    });
    const current = searchMatches[currentSearchIndex];
    if (current) {
      current.classList.add("skimdown-search-current");
      if (scrollToMatch) {
        current.scrollIntoView({ block: "center" });
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
    if (!anchor) {
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }

    const decoded = decodeURIComponent(anchor);
    const target = document.getElementById(decoded) || document.querySelector("[name='" + CSS.escape(decoded) + "']");
    if (target) {
      target.scrollIntoView({ block: "start", behavior: "smooth" });
    }
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
    scrollToAnchor: scrollToAnchor
  };
})();

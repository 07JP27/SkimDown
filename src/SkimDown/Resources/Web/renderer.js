(function () {
  let markdownIt = null;
  let searchMatches = [];
  let currentSearchIndex = -1;
  let tableResizeObserver = null;
  let tableResizeHandler = null;

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
    renderMermaidBlocks(content, payload);
    decorateCodeBlocks(content);
    renderMath(content);
    clearSearch();
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
      if (table.closest(".table-scroll")) {
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

    wrapper.classList.toggle("is-overflowing", isOverflowing);
    wrapper.classList.toggle("can-scroll-left", isOverflowing && scrollLeft > tolerance);
    wrapper.classList.toggle("can-scroll-right", isOverflowing && scrollLeft < maxScrollLeft - tolerance);
  }

  function tableScrollViewport(wrapper) {
    return wrapper.querySelector(".table-scroll-viewport") || wrapper;
  }

  function renderMermaidBlocks(content, payload) {
    const isDark = payload.theme === "dark" || (payload.theme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);
    if (window.mermaid) {
      window.mermaid.initialize({ startOnLoad: false, theme: isDark ? "dark" : "default", securityLevel: "strict" });
    }

    content.querySelectorAll("pre > code").forEach(function (code) {
      const language = code.className.match(/language-([A-Za-z0-9_-]+)/);
      if (!language || language[1].toLowerCase() !== "mermaid") {
        return;
      }

      const source = code.textContent;
      const fallback = code.parentElement.cloneNode(true);
      const wrapper = document.createElement("div");
      wrapper.className = "mermaid-container";
      const diagram = document.createElement("div");
      diagram.className = "mermaid";
      diagram.textContent = source;
      wrapper.appendChild(diagram);
      code.parentElement.replaceWith(wrapper);

      if (window.mermaid) {
        window.mermaid.run({ nodes: [diagram] }).catch(function () {
          wrapper.replaceWith(fallback);
        });
      }
    });
  }

  function decorateCodeBlocks(content) {
    content.querySelectorAll("pre > code").forEach(function (code) {
      const pre = code.parentElement;
      if (pre.querySelector(".code-toolbar")) {
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

  function performSearch(query, caseSensitive) {
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
      currentSearchIndex = 0;
      scrollToCurrentSearchMatch();
    }
    return searchState();
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
    searchMatches.forEach(function (match) {
      match.classList.remove("skimdown-search-current");
    });
    const current = searchMatches[currentSearchIndex];
    if (current) {
      current.classList.add("skimdown-search-current");
      current.scrollIntoView({ block: "center" });
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

  window.skimdown = {
    render: render,
    performSearch: performSearch,
    nextSearch: nextSearch,
    previousSearch: previousSearch,
    scrollToAnchor: scrollToAnchor
  };
})();

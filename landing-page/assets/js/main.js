/* حروف — Landing page script. بلا اعتمادات خارجية. */
(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var $ = function (sel, root) { return (root || document).querySelector(sel); };
  var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };
  var rand = function (min, max) { return Math.random() * (max - min) + min; };

  /* ─────────────── Navigation ─────────────── */
  var nav = $("#nav");
  var toggle = $(".nav__toggle");
  function onScroll() { nav.classList.toggle("is-scrolled", window.scrollY > 12); }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
  if (toggle) {
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", String(open));
    });
    $$(".nav__links a").forEach(function (a) {
      a.addEventListener("click", function () {
        nav.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  /* ─────────────── Sky: stars + floating letters ─────────────── */
  var stars = $(".stars");
  if (stars) {
    var frag = document.createDocumentFragment();
    for (var i = 0; i < 70; i++) {
      var s = document.createElement("i");
      s.style.left = rand(0, 100) + "%";
      s.style.top = rand(0, 70) + "%";
      var size = rand(1, 2.6);
      s.style.width = s.style.height = size + "px";
      s.style.animationDelay = rand(-4, 0) + "s";
      s.style.animationDuration = rand(2.5, 6) + "s";
      frag.appendChild(s);
    }
    stars.appendChild(frag);
  }

  var floating = $(".floating-letters");
  if (floating && !reduceMotion) {
    var letters = "ابتثجحخدذرزسشصضطظعغفقكلمنهوي".split("");
    for (var j = 0; j < 18; j++) {
      var l = document.createElement("span");
      l.textContent = letters[Math.floor(Math.random() * letters.length)];
      l.style.left = rand(2, 98) + "%";
      l.style.top = rand(35, 100) + "%";
      l.style.fontSize = rand(16, 42) + "px";
      l.style.animationDuration = rand(10, 20) + "s";
      l.style.animationDelay = rand(-20, 0) + "s";
      l.style.setProperty("--o", rand(0.25, 0.6).toFixed(2));
      l.style.setProperty("--r", rand(-40, 40).toFixed(0) + "deg");
      floating.appendChild(l);
    }
  }

  /* ─────────────── Reveal on scroll ─────────────── */
  var reveals = $$(".reveal");
  if ("IntersectionObserver" in window && !reduceMotion) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          e.target.classList.add("is-visible");
          io.unobserve(e.target);
        }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add("is-visible"); });
  }

  /* ─────────────── Count-up stats ─────────────── */
  function countUp(el) {
    var target = parseInt(el.getAttribute("data-count"), 10);
    var prefix = el.getAttribute("data-prefix") || "";
    if (reduceMotion) { el.textContent = prefix + target.toLocaleString("en-US"); return; }
    var start = null;
    var dur = 1400;
    function step(ts) {
      if (!start) start = ts;
      var p = Math.min((ts - start) / dur, 1);
      var eased = 1 - Math.pow(1 - p, 3);
      el.textContent = prefix + Math.round(target * eased).toLocaleString("en-US");
      if (p < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }
  var nums = $$("[data-count]");
  if ("IntersectionObserver" in window) {
    var io2 = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { countUp(e.target); io2.unobserve(e.target); }
      });
    }, { threshold: 0.5 });
    nums.forEach(function (n) { io2.observe(n); });
  }

  /* ─────────────── Proverb tiles ─────────────── */
  var proverb = $("#proverb");
  if (proverb) {
    var ptiles = $$(".proverb__tiles span", proverb);
    var pTimer = null;
    var runProverb = function () {
      ptiles.forEach(function (t) { t.classList.remove("is-filled"); });
      ptiles.forEach(function (t, k) {
        setTimeout(function () { t.classList.add("is-filled"); }, 500 + k * 170);
      });
    };
    if (reduceMotion || !("IntersectionObserver" in window)) {
      ptiles.forEach(function (t) { t.classList.add("is-filled"); });
    } else {
      new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting && !pTimer) {
            runProverb();
            pTimer = setInterval(runProverb, 4600);
          } else if (!e.isIntersecting && pTimer) {
            clearInterval(pTimer);
            pTimer = null;
          }
        });
      }, { threshold: 0.4 }).observe(proverb);
    }
  }

  /* ─────────────── Year ─────────────── */
  var year = $("#year");
  if (year) year.textContent = String(new Date().getFullYear());

  /* ═══════════════ Live demo: letter wheel ═══════════════ */
  var demo = $("#demo");
  if (!demo) return;

  var wheel = $("#demo-wheel");
  var lines = $("#demo-lines");
  var preview = $("#demo-preview");
  var meaning = $("#demo-meaning");
  var coinsEl = $("#demo-coins");
  var hintText = $("#demo-hint");
  var win = $("#demo-win");
  var buttons = $$(".demo__letter", wheel);
  var words = $$(".demo__word", demo);
  var SVGNS = "http://www.w3.org/2000/svg";
  var RADIUS = 33; // نصف قطر توزيع الحروف (٪ من العجلة)
  var HIT = 15; // نصف قطر زرّ الحرف (٪)

  var slots = []; // موضع كل زرّ: {x, y} بالنسبة المئوية
  var path = []; // فهارس الأزرار المختارة بالترتيب
  var dragging = false;
  var moved = false;
  var pointer = null;
  var coins = 120;
  var interacted = false;
  var hintTimer = null;

  // كل تباديل م ل ح كلمة عربية صحيحة: الثلاث خارج اللوح «كلمات إضافية»
  // كما في جرّة اللعبة — لا يجوز أن تُعلَّم خطأ أمام قارئ عربي
  var bonus = {};
  (demo.getAttribute("data-bonus") || "").split("|").forEach(function (pair) {
    var at = pair.indexOf(":");
    if (at > 0) bonus[pair.slice(0, at)] = pair.slice(at + 1);
  });
  var bonusLabel = demo.getAttribute("data-bonus-label") || "";
  var bonusFound = {};

  function layout(order) {
    var n = buttons.length;
    order.forEach(function (btnIndex, slot) {
      var angle = -Math.PI / 2 + (slot * 2 * Math.PI) / n;
      slots[btnIndex] = { x: 50 + RADIUS * Math.cos(angle), y: 50 + RADIUS * Math.sin(angle) };
      buttons[btnIndex].style.left = slots[btnIndex].x + "%";
      buttons[btnIndex].style.top = slots[btnIndex].y + "%";
    });
  }
  var order = buttons.map(function (_, k) { return k; });
  layout(order);

  function letterAt(px, py) {
    for (var k = 0; k < slots.length; k++) {
      var dx = slots[k].x - px;
      var dy = slots[k].y - py;
      if (dx * dx + dy * dy <= HIT * HIT) return k;
    }
    return -1;
  }

  function toPercent(e) {
    var r = wheel.getBoundingClientRect();
    return { x: ((e.clientX - r.left) / r.width) * 100, y: ((e.clientY - r.top) / r.height) * 100 };
  }

  function currentWord() {
    return path.map(function (k) { return buttons[k].getAttribute("data-letter"); }).join("");
  }

  function draw(extraClass, pts) {
    lines.innerHTML = "";
    var points = pts || path.map(function (k) { return slots[k]; });
    if (!pts && dragging && pointer && path.length) points = points.concat([pointer]);
    if (points.length < 2) return;
    var pl = document.createElementNS(SVGNS, "polyline");
    pl.setAttribute("points", points.map(function (p) { return p.x.toFixed(2) + "," + p.y.toFixed(2); }).join(" "));
    if (extraClass) pl.setAttribute("class", extraClass);
    lines.appendChild(pl);
  }

  function renderSelection() {
    buttons.forEach(function (b, k) { b.classList.toggle("is-active", path.indexOf(k) !== -1); });
    preview.classList.remove("is-wrong");
    preview.innerHTML = "";
    path.forEach(function (k) {
      var chip = document.createElement("span");
      chip.textContent = buttons[k].getAttribute("data-letter");
      preview.appendChild(chip);
    });
    draw();
  }

  function clearSelection() {
    path = [];
    dragging = false;
    moved = false;
    pointer = null;
    renderSelection();
  }

  function addLetter(k) {
    if (k < 0) return;
    var at = path.indexOf(k);
    if (at === -1) {
      path.push(k);
      return true;
    }
    // الرجوع إلى الحرف قبل الأخير يلغي الأخير — كما في اللعبة
    if (dragging && at === path.length - 2) {
      path.pop();
      return true;
    }
    return false;
  }

  function sparkleAt(el) {
    if (reduceMotion) return;
    var host = demo.getBoundingClientRect();
    var r = el.getBoundingClientRect();
    var cx = r.left - host.left + r.width / 2;
    var cy = r.top - host.top + r.height / 2;
    for (var k = 0; k < 7; k++) {
      var sp = document.createElement("span");
      sp.className = "sparkle";
      sp.style.left = cx + "px";
      sp.style.top = cy + "px";
      sp.style.background = k % 3 === 0 ? "#fff" : "#F4C430";
      sp.style.setProperty("--dx", rand(-50, 50).toFixed(0) + "px");
      sp.style.setProperty("--dy", rand(-55, 20).toFixed(0) + "px");
      demo.appendChild(sp);
      setTimeout(function (node) { node.remove(); }, 950, sp);
    }
  }

  function showMeaning(label, text) {
    meaning.innerHTML = "";
    var b = document.createElement("b");
    b.textContent = label;
    meaning.appendChild(b);
    meaning.appendChild(document.createTextNode(" " + text));
  }

  function addCoins(n) {
    coins += n;
    coinsEl.textContent = String(coins);
    coinsEl.parentNode.classList.add("bump");
    setTimeout(function () { coinsEl.parentNode.classList.remove("bump"); }, 300);
  }

  function submit() {
    var word = currentWord();
    dragging = false;
    pointer = null;
    if (word.length < 2) { clearSelection(); return; }

    var row = words.filter(function (w) { return w.getAttribute("data-word") === word; })[0];
    if (!row && bonus[word]) {
      showMeaning(bonusLabel + " · " + word + ":", bonus[word]);
      if (!bonusFound[word]) { bonusFound[word] = true; addCoins(5); }
      preview.classList.add("is-bonus");
      lines.innerHTML = "";
      buttons.forEach(function (bt) { bt.classList.remove("is-active"); });
      path = [];
      setTimeout(function () { if (!path.length) { preview.innerHTML = ""; preview.classList.remove("is-bonus"); } }, 700);
      return;
    }
    if (row && !row.classList.contains("is-solved")) {
      row.classList.add("is-solved");
      var tiles = $$(".demo__tile", row);
      word.split("").forEach(function (ch, k) {
        setTimeout(function () {
          tiles[k].textContent = ch;
          tiles[k].classList.add("is-filled");
          sparkleAt(tiles[k]);
        }, k * 110);
      });
      showMeaning(word + ":", row.getAttribute("data-meaning"));
      addCoins(10);
      clearSelection();
      if (words.every(function (w) { return w.classList.contains("is-solved"); })) {
        setTimeout(function () {
          win.classList.add("is-open");
          var replay = $("#demo-replay");
          if (replay) replay.focus({ preventScroll: true });
        }, 900);
      }
    } else if (row) {
      row.classList.remove("is-repeat");
      void row.offsetWidth;
      row.classList.add("is-repeat");
      clearSelection();
    } else {
      preview.classList.add("is-wrong");
      lines.innerHTML = "";
      buttons.forEach(function (bt) { bt.classList.remove("is-active"); });
      path = [];
      setTimeout(function () { if (!path.length) { preview.innerHTML = ""; preview.classList.remove("is-wrong"); } }, 450);
    }
  }

  function firstInteraction() {
    if (interacted) return;
    interacted = true;
    stopHint();
    if (hintText) hintText.style.opacity = "0.55";
  }

  wheel.addEventListener("pointerdown", function (e) {
    var p = toPercent(e);
    var k = letterAt(p.x, p.y);
    if (k < 0) return;
    e.preventDefault();
    firstInteraction();
    dragging = true;
    moved = false;
    pointer = p;
    addLetter(k);
    try { wheel.setPointerCapture(e.pointerId); } catch (err) { /* لا بأس */ }
    renderSelection();
  });

  wheel.addEventListener("pointermove", function (e) {
    if (!dragging) return;
    pointer = toPercent(e);
    var k = letterAt(pointer.x, pointer.y);
    if (k >= 0 && addLetter(k)) {
      moved = true;
      renderSelection();
    } else {
      draw();
    }
  });

  function endDrag() {
    if (!dragging) return;
    dragging = false;
    pointer = null;
    // نقرة بلا سحب: نمط النقر — يبقى الاختيار مفتوحا حتى تكتمل الحروف
    if (moved || path.length === buttons.length) submit();
    else renderSelection();
  }
  wheel.addEventListener("pointerup", endDrag);
  wheel.addEventListener("pointercancel", function () { clearSelection(); });

  // لوحة المفاتيح: Enter/Space على زرّ الحرف (نقرة detail = 0)
  buttons.forEach(function (b, k) {
    b.addEventListener("click", function (e) {
      if (e.detail !== 0) return;
      firstInteraction();
      if (path.indexOf(k) === -1) path.push(k);
      renderSelection();
      if (path.length === buttons.length) submit();
    });
  });

  $("#demo-shuffle").addEventListener("click", function () {
    firstInteraction();
    clearSelection();
    var next;
    do {
      next = order.slice().sort(function () { return Math.random() - 0.5; });
    } while (next.join() === order.join());
    order = next;
    layout(order);
  });

  $("#demo-replay").addEventListener("click", function () {
    win.classList.remove("is-open");
    words.forEach(function (w) {
      w.classList.remove("is-solved", "is-repeat");
      $$(".demo__tile", w).forEach(function (t) { t.textContent = ""; t.classList.remove("is-filled"); });
    });
    meaning.textContent = "";
    bonusFound = {};
    coins = 120;
    coinsEl.textContent = "120";
    clearSelection();
    var first = buttons[0];
    if (first) first.focus({ preventScroll: true });
  });

  /* تلميح متحرّك قبل أول لمسة: نبض الحروف بترتيب أول كلمة ناقصة */
  function runHint() {
    var row = words.filter(function (w) { return !w.classList.contains("is-solved"); })[0];
    if (!row) return;
    var target = row.getAttribute("data-word").split("");
    var seq = target.map(function (ch) {
      return buttons.findIndex(function (b) { return b.getAttribute("data-letter") === ch; });
    });
    seq.forEach(function (k, step) {
      setTimeout(function () {
        if (interacted) return;
        buttons[k].classList.remove("is-hint");
        void buttons[k].offsetWidth;
        buttons[k].classList.add("is-hint");
        draw("hint-line", seq.slice(0, step + 1).map(function (q) { return slots[q]; }));
      }, step * 650);
    });
    setTimeout(function () { if (!interacted) lines.innerHTML = ""; }, seq.length * 650 + 700);
  }
  function stopHint() {
    if (hintTimer) clearInterval(hintTimer);
    hintTimer = null;
    lines.innerHTML = "";
    buttons.forEach(function (b) { b.classList.remove("is-hint"); });
  }
  if (!reduceMotion) {
    setTimeout(function () {
      if (interacted) return;
      runHint();
      hintTimer = setInterval(function () { if (!interacted) runHint(); }, 4200);
    }, 1800);
  }
})();

/* حروف — تفاعلات صفحة الهبوط (خفيفة، بلا أي مكتبة خارجية) */
(function () {
  'use strict';

  // 1) ظهور تدريجي للأقسام عند التمرير — يُتخطّى لمن يفضّل تقليل الحركة
  var reduceMotion = window.matchMedia(
    '(prefers-reduced-motion: reduce)'
  ).matches;
  var targets = document.querySelectorAll('.reveal');

  function revealAll() {
    targets.forEach(function (el) {
      el.classList.add('visible');
    });
  }

  if (reduceMotion || !('IntersectionObserver' in window)) {
    revealAll();
  } else {
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: '0px 0px -60px 0px' }
    );
    targets.forEach(function (el) {
      io.observe(el);
    });

    // شبكة أمان: لو لم يُطلق المراقب لأي سبب (تبويب خلفي عند التحميل،
    // سلوك متصفح غير متوقع) نُظهر كل شيء بدل ترك الصفحة فارغة
    window.setTimeout(revealAll, 2500);
  }

  // 2) توزيع حروف العجلة في المحاكاة على دائرة — نفس حساب LetterWheel
  //    في التطبيق: الزاوية تبدأ من الأعلى وتتوزع بالتساوي
  document.querySelectorAll('.mock-wheel').forEach(function (wheel) {
    var letters = wheel.querySelectorAll('.mock-letter');
    var radius = 66;
    letters.forEach(function (el, i) {
      var angle = -Math.PI / 2 + (2 * Math.PI * i) / letters.length;
      el.style.setProperty('--x', Math.cos(angle) * radius + 'px');
      el.style.setProperty('--y', Math.sin(angle) * radius + 'px');
    });
  });

  // 3) عدّاد تصاعدي لأرقام الإحصاءات عند أول ظهور
  var stats = document.querySelectorAll('.stat b[data-count]');
  if (stats.length && !reduceMotion && 'IntersectionObserver' in window) {
    var counter = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          counter.unobserve(entry.target);
          var el = entry.target;
          var target = parseInt(el.dataset.count, 10);
          var suffix = el.dataset.suffix || '';
          var start = performance.now();
          var duration = 1100;
          (function tick(now) {
            var t = Math.min((now - start) / duration, 1);
            var eased = 1 - Math.pow(1 - t, 3);
            el.textContent = Math.round(target * eased) + suffix;
            if (t < 1) requestAnimationFrame(tick);
          })(start);
        });
      },
      { threshold: 0.5 }
    );
    stats.forEach(function (el) {
      counter.observe(el);
    });
  }
})();

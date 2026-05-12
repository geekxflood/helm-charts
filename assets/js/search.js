/* Client-side chart search.
   Filters [data-name][data-keywords][data-description] cards on the index page.
   No external deps. Matches every whitespace-separated query term against the
   concatenated haystack (substring match — fast and predictable for a list
   of ~50 charts). */
(function () {
  'use strict';

  var input = document.getElementById('chart-search');
  if (!input) return;
  var countEl = document.getElementById('search-count');
  var emptyEl = document.getElementById('search-empty');

  var cards = Array.prototype.slice.call(document.querySelectorAll('.chart-card'));
  var groups = Array.prototype.slice.call(document.querySelectorAll('.chart-group'));
  var totalCount = cards.length;

  var haystacks = cards.map(function (card) {
    return [
      card.getAttribute('data-name') || '',
      card.getAttribute('data-keywords') || '',
      card.getAttribute('data-description') || ''
    ].join(' ').toLowerCase();
  });

  function applyFilter(q) {
    q = (q || '').trim().toLowerCase();
    var terms = q ? q.split(/\s+/) : [];

    var visible = 0;
    cards.forEach(function (card, i) {
      var hay = haystacks[i];
      var match = terms.every(function (t) { return hay.indexOf(t) !== -1; });
      card.hidden = !match;
      if (match) visible++;
    });

    // Hide categories that now contain zero visible cards
    groups.forEach(function (group) {
      var hasVisible = group.querySelectorAll('.chart-card:not([hidden])').length > 0;
      group.hidden = !hasVisible;
    });

    if (emptyEl) emptyEl.hidden = visible !== 0;

    if (countEl) {
      if (terms.length === 0) {
        countEl.textContent = totalCount + ' charts';
      } else {
        countEl.textContent = visible + ' / ' + totalCount;
      }
    }
  }

  var t = 0;
  input.addEventListener('input', function () {
    clearTimeout(t);
    var v = input.value;
    t = setTimeout(function () { applyFilter(v); }, 60);
  });

  // Allow ESC to clear
  input.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      input.value = '';
      applyFilter('');
    }
  });

  // Focus shortcut: "/" anywhere
  document.addEventListener('keydown', function (e) {
    if (e.key === '/' && document.activeElement !== input && !e.metaKey && !e.ctrlKey) {
      e.preventDefault();
      input.focus();
      input.select();
    }
  });
})();

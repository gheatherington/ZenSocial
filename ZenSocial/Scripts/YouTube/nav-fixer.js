// ZenSocial YouTube nav fixer
// Forces dark backgrounds on fixed/sticky nav bars by targeting computed styles.
// Runs at atDocumentEnd; re-runs on SPA mutations via MutationObserver.
// D-11: Does not touch navigator.serviceWorker, Notification, or PushManager.
(function () {
    'use strict';

    var NAV_BG = '#000000';

    function applyNavTheme() {
        var all = document.querySelectorAll('body *');
        for (var i = 0; i < all.length; i++) {
            var el = all[i];
            var pos = window.getComputedStyle(el).position;
            if (pos === 'fixed' || pos === 'sticky') {
                el.style.setProperty('background-color', NAV_BG, 'important');
                el.style.setProperty('background', NAV_BG, 'important');
            }
        }
    }

    applyNavTheme();
    setTimeout(applyNavTheme, 500);
    setTimeout(applyNavTheme, 2000);

    var timer = null;
    new MutationObserver(function () {
        if (timer) return;
        timer = setTimeout(function () {
            applyNavTheme();
            timer = null;
        }, 300);
    }).observe(document.documentElement, { childList: true, subtree: true });
})();

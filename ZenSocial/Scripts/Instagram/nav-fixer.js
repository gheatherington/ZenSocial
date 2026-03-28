// ZenSocial Instagram nav fixer
// Forces dark backgrounds on fixed/sticky nav bars by targeting computed styles.
// Runs at atDocumentEnd; re-runs on SPA mutations via MutationObserver and pushState interception.
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

    // SPA navigation interception — Instagram uses pushState for page switches.
    // Fires theme fixers immediately on route change, before DOM mutations accumulate.
    function onSPANavigate() {
        applyNavTheme();
        // Follow-up for late-painting components
        setTimeout(applyNavTheme, 150);
    }

    var _pushState = history.pushState.bind(history);
    var _replaceState = history.replaceState.bind(history);
    history.pushState = function() { _pushState.apply(history, arguments); onSPANavigate(); };
    history.replaceState = function() { _replaceState.apply(history, arguments); onSPANavigate(); };
    window.addEventListener('popstate', onSPANavigate);

    applyNavTheme();
    setTimeout(applyNavTheme, 500);
    setTimeout(applyNavTheme, 2000);

    var timer = null;
    new MutationObserver(function () {
        if (timer) return;
        timer = setTimeout(function () {
            applyNavTheme();
            timer = null;
        }, 0);
    }).observe(document.documentElement, { childList: true, subtree: true });
})();

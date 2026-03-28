// ZenSocial YouTube nav fixer
// Forces dark backgrounds on fixed/sticky nav bars by targeting computed styles.
// Also forces black on the "You're not signed in" account page (YouTube's JS
// can override CSS !important by setting inline styles; el.style.setProperty
// with 'important' priority beats inline styles).
// Runs at atDocumentEnd; re-runs on SPA mutations via MutationObserver.
// D-11: Does not touch navigator.serviceWorker, Notification, or PushManager.
(function () {
    'use strict';

    var NAV_BG = '#000000';

    // Tags to never touch (D-02: preserve media elements)
    var SKIP_TAGS = { IMG: 1, VIDEO: 1, CANVAS: 1, SVG: 1, PICTURE: 1 };

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

    // Force pure black on the "You're not signed in" page.
    // CSS !important can be beaten by YouTube's JS setting inline styles.
    // el.style.setProperty(..., 'important') wins over everything.
    function fixAccountPage() {
        var roots = document.querySelectorAll(
            'ytm-account-controller, ytm-browse, ytm-page-manager, ytm-app'
        );
        for (var i = 0; i < roots.length; i++) {
            var root = roots[i];
            if (SKIP_TAGS[root.tagName]) continue;
            root.style.setProperty('background-color', NAV_BG, 'important');
            root.style.setProperty('background', 'none', 'important');
            var children = root.querySelectorAll('*');
            for (var j = 0; j < children.length; j++) {
                var child = children[j];
                if (SKIP_TAGS[child.tagName]) continue;
                var bg = window.getComputedStyle(child).backgroundColor;
                // Only override non-transparent, non-black computed backgrounds
                if (bg && bg !== 'transparent' && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'rgb(0, 0, 0)') {
                    child.style.setProperty('background-color', NAV_BG, 'important');
                    child.style.setProperty('background', 'none', 'important');
                }
            }
        }
    }

    applyNavTheme();
    fixAccountPage();
    setTimeout(applyNavTheme, 500);
    setTimeout(fixAccountPage, 500);
    setTimeout(applyNavTheme, 2000);
    setTimeout(fixAccountPage, 2000);

    var timer = null;
    new MutationObserver(function () {
        if (timer) return;
        timer = setTimeout(function () {
            applyNavTheme();
            fixAccountPage();
            timer = null;
        }, 300);
    }).observe(document.documentElement, { childList: true, subtree: true });
})();

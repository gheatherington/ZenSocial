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
    var CTA_BLUE = '#4DA6FF';
    var CTA_TEXT = '#FFFFFF';
    var CTA_MARKER = 'data-zen-signed-out-cta';

    // Tags to never touch (D-02: preserve media elements)
    var SKIP_TAGS = { IMG: 1, VIDEO: 1, CANVAS: 1, SVG: 1, PICTURE: 1 };

    function normalizeText(value) {
        return (value || '').replace(/\s+/g, ' ').trim();
    }

    function isSignedOutAccountPage() {
        var text = normalizeText(document.body && document.body.innerText);
        return text.indexOf("You're not signed in") !== -1 || text.indexOf('You’re not signed in') !== -1;
    }

    function closestClickableInContainer(el, container) {
        var current = el;
        while (current && current !== container) {
            if (
                current.matches &&
                current.matches('a, button, [role="button"], ytm-button-renderer, yt-button-renderer, yt-button-shape, [tabindex], [jsaction], [jsname]')
            ) {
                return current;
            }
            current = current.parentElement;
        }
        return el;
    }

    function styleSignedOutCTA(target) {
        if (!target || !target.style) return;
        target.setAttribute(CTA_MARKER, '1');
        target.style.setProperty('display', 'inline-flex', 'important');
        target.style.setProperty('align-items', 'center', 'important');
        target.style.setProperty('justify-content', 'center', 'important');
        target.style.setProperty('box-sizing', 'border-box', 'important');
        target.style.setProperty('min-width', '96px', 'important');
        target.style.setProperty('padding', '10px 18px', 'important');
        target.style.setProperty('border-radius', '999px', 'important');
        target.style.setProperty('background', CTA_BLUE, 'important');
        target.style.setProperty('background-color', CTA_BLUE, 'important');
        target.style.setProperty('border', '1px solid ' + CTA_BLUE, 'important');
        target.style.setProperty('border-color', CTA_BLUE, 'important');
        target.style.setProperty('color', CTA_TEXT, 'important');
        target.style.setProperty('text-align', 'center', 'important');
        target.style.setProperty('text-decoration', 'none', 'important');
    }

    function getSignInURL() {
        if (window.ytcfg && typeof window.ytcfg.get === 'function') {
            var cfgUrl = window.ytcfg.get('SIGNIN_URL');
            if (cfgUrl) return cfgUrl;
        }

        var links = document.querySelectorAll('a[href*="ServiceLogin"], a[href*="signin"]');
        for (var i = 0; i < links.length; i++) {
            if (links[i].href) return links[i].href;
        }

        return 'https://accounts.google.com/ServiceLogin?service=youtube';
    }

    function collectSignInOrigins(container) {
        var origins = [];
        var seen = [];
        var walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT, null);
        var node;

        while ((node = walker.nextNode())) {
            if (normalizeText(node.nodeValue) !== 'Sign in') continue;
            if (!node.parentElement) continue;
            if (seen.indexOf(node.parentElement) !== -1) continue;
            seen.push(node.parentElement);
            origins.push(node.parentElement);
        }

        var labeled = container.querySelectorAll('[aria-label*="Sign in"], [title*="Sign in"]');
        for (var i = 0; i < labeled.length; i++) {
            if (seen.indexOf(labeled[i]) !== -1) continue;
            seen.push(labeled[i]);
            origins.push(labeled[i]);
        }

        return origins;
    }

    function ensureOverlayCTA(container) {
        var overlay = document.createElement('a');
        overlay.setAttribute(CTA_MARKER, 'overlay');
        overlay.href = getSignInURL();
        overlay.textContent = 'Sign in';
        styleSignedOutCTA(overlay);
        overlay.style.setProperty('font-size', '16px', 'important');
        overlay.style.setProperty('font-weight', '500', 'important');
        overlay.style.setProperty('line-height', '20px', 'important');
        overlay.style.setProperty('pointer-events', 'auto', 'important');

        overlay.addEventListener('click', function (event) {
            event.preventDefault();
            window.location.href = overlay.href;
        });

        return overlay;
    }

    function ensureFixedOverlayCTA() {
        if (!document.body) return;

        var overlay = document.querySelector('[' + CTA_MARKER + '="fixed-overlay"]');
        if (!overlay) {
            overlay = ensureOverlayCTA(document.body);
            overlay.setAttribute(CTA_MARKER, 'fixed-overlay');
            document.body.appendChild(overlay);
        }

        overlay.href = getSignInURL();
        overlay.style.setProperty('position', 'fixed', 'important');
        overlay.style.setProperty('left', '50%', 'important');
        overlay.style.setProperty('top', Math.round(window.innerHeight * 0.56) + 'px', 'important');
        overlay.style.setProperty('transform', 'translate(-50%, -50%)', 'important');
        overlay.style.setProperty('z-index', '2147483647', 'important');
        overlay.style.setProperty('box-shadow', '0 10px 24px rgba(0, 0, 0, 0.35)', 'important');
    }

    function removeFixedOverlayCTA() {
        var overlay = document.querySelector('[' + CTA_MARKER + '="fixed-overlay"]');
        if (overlay && overlay.parentNode) {
            overlay.parentNode.removeChild(overlay);
        }
    }

    function hideCenteredNativeSignInLabel() {
        if (!document.body) return;

        var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
        var node;
        while ((node = walker.nextNode())) {
            if (normalizeText(node.nodeValue) !== 'Sign in') continue;
            if (!node.parentElement || !node.parentElement.style) continue;
            if (node.parentElement.closest && node.parentElement.closest('[' + CTA_MARKER + ']')) continue;

            var rect = node.parentElement.getBoundingClientRect();
            var midX = rect.left + rect.width / 2;
            var midY = rect.top + rect.height / 2;

            if (midX < window.innerWidth * 0.25 || midX > window.innerWidth * 0.75) continue;
            if (midY < window.innerHeight * 0.45 || midY > window.innerHeight * 0.70) continue;

            node.parentElement.style.setProperty('color', 'transparent', 'important');
            node.parentElement.style.setProperty('text-shadow', 'none', 'important');
        }
    }

    function restoreSignedOutCTA() {
        if (!isSignedOutAccountPage()) {
            removeFixedOverlayCTA();
            return;
        }

        var containers = document.querySelectorAll(
            'ytm-inline-message-renderer, yt-upsell-dialog-renderer, ytm-upsell-dialog-renderer, ytm-account-controller'
        );
        var totalStyledCount = 0;

        for (var i = 0; i < containers.length; i++) {
            var container = containers[i];
            var origins = collectSignInOrigins(container);
            var styledCount = 0;

            for (var j = 0; j < origins.length; j++) {
                var origin = origins[j];
                var rect = origin.getBoundingClientRect ? origin.getBoundingClientRect() : null;
                if (rect && rect.top < window.innerHeight * 0.25) continue;

                var target = closestClickableInContainer(origin, container);
                styleSignedOutCTA(target);
                styledCount++;
                totalStyledCount++;

                var descendants = target.querySelectorAll ? target.querySelectorAll('*') : [];
                for (var k = 0; k < descendants.length; k++) {
                    var child = descendants[k];
                    child.setAttribute(CTA_MARKER, '1');
                    if (child.style) {
                        child.style.setProperty('color', CTA_TEXT, 'important');
                        child.style.setProperty('fill', CTA_TEXT, 'important');
                        child.style.setProperty('stroke', CTA_TEXT, 'important');
                    }
                }
            }
        }

        if (!totalStyledCount) {
            ensureFixedOverlayCTA();
            hideCenteredNativeSignInLabel();
        } else {
            removeFixedOverlayCTA();
        }
    }

    function applyNavTheme() {
        var all = document.querySelectorAll('body *');
        for (var i = 0; i < all.length; i++) {
            var el = all[i];
            if (el.getAttribute && el.getAttribute(CTA_MARKER)) continue;
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
                if (child.closest && child.closest('[' + CTA_MARKER + '="1"]')) continue;
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
    restoreSignedOutCTA();
    setTimeout(applyNavTheme, 500);
    setTimeout(fixAccountPage, 500);
    setTimeout(restoreSignedOutCTA, 500);
    setTimeout(applyNavTheme, 2000);
    setTimeout(fixAccountPage, 2000);
    setTimeout(restoreSignedOutCTA, 2000);

    var timer = null;
    new MutationObserver(function () {
        if (timer) return;
        timer = setTimeout(function () {
            applyNavTheme();
            fixAccountPage();
            restoreSignedOutCTA();
            timer = null;
        }, 300);
    }).observe(document.documentElement, { childList: true, subtree: true });
})();

(function() {
    'use strict';

    var POLL_INTERVAL_MS = 30000;
    var lastKnownBadge = false;
    var observer = null;

    function sendToNative(payload) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.zenNotification) {
            window.webkit.messageHandlers.zenNotification.postMessage(payload);
        }
    }

    function findNotificationBadge() {
        // Strategy 1: Look for the notification/activity icon in Instagram's nav with a badge indicator.
        // Instagram uses svg-based nav icons with badge dots rendered as sibling spans/divs.
        var navLinks = document.querySelectorAll('[role="navigation"] a, nav a, [aria-label*="notification" i], [aria-label*="activity" i]');
        for (var i = 0; i < navLinks.length; i++) {
            var item = navLinks[i];
            var href = item.getAttribute('href') || '';
            if (href.indexOf('/accounts/activity') !== -1 || href.indexOf('/notifications') !== -1) {
                // Check for a badge indicator as a sibling or child
                var badge = item.querySelector('[class*="badge" i], [class*="dot" i], [class*="unread" i]');
                if (badge) return { hasNew: true };
                // Check aria-label for "new" indicator
                var label = item.getAttribute('aria-label') || '';
                if (label.toLowerCase().indexOf('new') !== -1 || label.toLowerCase().indexOf('unread') !== -1) {
                    return { hasNew: true };
                }
            }
        }

        // Strategy 2: Red dot indicators in nav (Instagram's badge is typically a red/coral circle)
        // Checking for elements with background-color matching Instagram's notification red
        var allNavElements = document.querySelectorAll('nav *, [role="navigation"] *');
        for (var j = 0; j < allNavElements.length; j++) {
            var el = allNavElements[j];
            var style = window.getComputedStyle(el);
            var bg = style.backgroundColor;
            // Instagram notification badge red: approximately rgb(255, 48, 64) or similar
            if (bg && (bg.indexOf('rgb(255, 48') !== -1 || bg.indexOf('rgb(255, 0') !== -1 || bg.indexOf('rgb(254, 44') !== -1)) {
                var bounds = el.getBoundingClientRect();
                // Badge dots are small — typically under 20px diameter
                if (bounds.width < 25 && bounds.height < 25 && bounds.width > 0) {
                    return { hasNew: true };
                }
            }
        }

        // Strategy 3: Look for notification count indicators with non-zero text
        var countElements = document.querySelectorAll('[aria-label*="notification" i] span, [class*="notification" i] span, [class*="badge" i]');
        for (var k = 0; k < countElements.length; k++) {
            var text = countElements[k].textContent.trim();
            var num = parseInt(text, 10);
            if (!isNaN(num) && num > 0) {
                return { hasNew: true, count: num };
            }
        }

        return { hasNew: false };
    }

    function checkAndNotify() {
        var result = findNotificationBadge();
        if (result.hasNew && !lastKnownBadge) {
            sendToNative({
                type: 'badge_change',
                hasNew: true,
                count: result.count || 0,
                timestamp: Date.now()
            });
        }
        lastKnownBadge = result.hasNew;
    }

    // Poll periodically while page is visible
    setInterval(function() {
        if (!document.hidden) {
            checkAndNotify();
        }
    }, POLL_INTERVAL_MS);

    // MutationObserver on the nav area for real-time detection
    function setupObserver() {
        var nav = document.querySelector('nav, [role="navigation"]');
        if (!nav) {
            // Nav not yet in DOM -- retry until it appears
            setTimeout(setupObserver, 2000);
            return;
        }
        if (observer) {
            observer.disconnect();
        }
        observer = new MutationObserver(function() {
            checkAndNotify();
        });
        observer.observe(nav, { childList: true, subtree: true, attributes: true, attributeFilter: ['aria-label', 'class', 'style'] });
    }

    // Initial check after page has settled
    setTimeout(function() {
        checkAndNotify();
        setupObserver();
    }, 3000);

})();

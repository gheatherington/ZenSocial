(function() {
    'use strict';

    var POLL_INTERVAL_MS = 15000;
    var lastKnownActivityBadge = false;
    var lastKnownDMBadge = false;
    var observer = null;

    function sendToNative(payload) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.zenNotification) {
            window.webkit.messageHandlers.zenNotification.postMessage(payload);
        }
    }

    // Returns true if an element has a visible badge dot child
    function elementHasBadge(el) {
        // Class-based badge dots
        var badge = el.querySelector('[class*="badge" i], [class*="dot" i], [class*="unread" i], [class*="indicator" i]');
        if (badge) {
            var bounds = badge.getBoundingClientRect();
            if (bounds.width > 0 && bounds.height > 0) return true;
        }
        // Red/coral color badge dot (Instagram's notification red)
        var children = el.querySelectorAll('*');
        for (var i = 0; i < children.length; i++) {
            var style = window.getComputedStyle(children[i]);
            var bg = style.backgroundColor;
            if (bg && (
                bg.indexOf('rgb(255, 48') !== -1 ||
                bg.indexOf('rgb(255, 0,') !== -1 ||
                bg.indexOf('rgb(254, 44') !== -1 ||
                bg.indexOf('rgb(255, 55') !== -1
            )) {
                var b = children[i].getBoundingClientRect();
                if (b.width > 0 && b.width < 25 && b.height > 0 && b.height < 25) return true;
            }
        }
        // Numeric badge text
        var spans = el.querySelectorAll('span');
        for (var j = 0; j < spans.length; j++) {
            var num = parseInt(spans[j].textContent.trim(), 10);
            if (!isNaN(num) && num > 0) return true;
        }
        // aria-label on the link itself signals new content
        var label = (el.getAttribute('aria-label') || '').toLowerCase();
        if (label.indexOf('new') !== -1 || label.indexOf('unread') !== -1 || label.indexOf('notification') !== -1) {
            // Make sure it's not just the icon label without a badge
            if (label.indexOf('0') === -1) return true;
        }
        return false;
    }

    function findBadges() {
        var hasActivity = false;
        var hasDM = false;

        // Scan all nav links
        var navLinks = document.querySelectorAll(
            '[role="navigation"] a, nav a, header a, [role="tablist"] a'
        );

        for (var i = 0; i < navLinks.length; i++) {
            var link = navLinks[i];
            var href = link.getAttribute('href') || '';

            // Activity / notifications bell
            if (href.indexOf('/accounts/activity') !== -1 ||
                href.indexOf('/notifications') !== -1) {
                if (elementHasBadge(link)) hasActivity = true;
            }

            // Direct messages (paper airplane icon)
            if (href.indexOf('/direct/inbox') !== -1 ||
                href.indexOf('/direct/') !== -1) {
                if (elementHasBadge(link)) hasDM = true;
            }
        }

        // Fallback: look for DM icon by aria-label if href-based scan missed it
        if (!hasDM) {
            var dmCandidates = document.querySelectorAll(
                '[aria-label*="message" i], [aria-label*="direct" i], [aria-label*="inbox" i]'
            );
            for (var k = 0; k < dmCandidates.length; k++) {
                if (elementHasBadge(dmCandidates[k])) {
                    hasDM = true;
                    break;
                }
            }
        }

        return { hasActivity: hasActivity, hasDM: hasDM };
    }

    function checkAndNotify() {
        var result = findBadges();

        // Activity badge: new notification
        if (result.hasActivity && !lastKnownActivityBadge) {
            sendToNative({
                type: 'badge_change',
                badgeType: 'activity',
                hasNew: true,
                timestamp: Date.now()
            });
        }
        lastKnownActivityBadge = result.hasActivity;

        // DM badge: new direct message
        if (result.hasDM && !lastKnownDMBadge) {
            sendToNative({
                type: 'badge_change',
                badgeType: 'dm',
                hasNew: true,
                timestamp: Date.now()
            });
        }
        lastKnownDMBadge = result.hasDM;
    }

    // Poll every 15s while page is visible
    setInterval(function() {
        if (!document.hidden) {
            checkAndNotify();
        }
    }, POLL_INTERVAL_MS);

    // MutationObserver on the full document for real-time badge changes
    function setupObserver() {
        var root = document.querySelector('nav, [role="navigation"], header, body');
        if (!root) {
            setTimeout(setupObserver, 2000);
            return;
        }
        if (observer) observer.disconnect();
        observer = new MutationObserver(function() {
            checkAndNotify();
        });
        observer.observe(root, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['aria-label', 'class', 'style']
        });
    }

    // Initial check after page has settled
    setTimeout(function() {
        checkAndNotify();
        setupObserver();
    }, 3000);

})();

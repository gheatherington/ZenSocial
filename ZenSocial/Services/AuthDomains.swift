enum AuthDomains {
    static let allowlist: Set<String> = [
        "accounts.google.com",
        "accounts.youtube.com",
        "myaccount.google.com",
        "www.facebook.com",
        "m.facebook.com",
        "web.facebook.com",
        "login.instagram.com",
        "appleid.apple.com",
    ]

    static func isAuthDomain(_ host: String) -> Bool {
        allowlist.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}

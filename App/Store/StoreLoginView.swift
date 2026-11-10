import SwiftUI
import WebKit
import NoblesKit

/// A sheet that signs the user into the Nobles school-store pages through the genuine Veracross
/// login, then hands back the resulting session (cookie + signed-in person) for the app to save.
///
/// The app never sees or stores the password: the user types their own credentials into the real
/// Veracross page loaded in `WKWebView`. Once that page lands back on a signed-in
/// `nobilis.nobles.edu/SchoolStoreNew/…` page, the view reads only the session cookie and the people
/// linked on it. Nothing else is captured or kept.
///
/// The school-store pages themselves are covered by a "Connecting" panel (sign-in pages show), so
/// a reconnect that needs no typing goes straight to "Connected" instead of flashing the spending
/// page on its way to closing.
struct StoreLoginView: View {
    /// Called with the captured session once sign-in completes. The caller saves and verifies it.
    let onCapture: (StoreSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var stage = Stage.connecting
    /// Set once a capture has failed: from then on every page shows, so the user can find their way.
    @State private var showsEveryPage = false
    @State private var isLoading = true
    /// A capture awaiting a choice of person, when the account can see more than one.
    @State private var pendingCapture: Capture?
    @State private var problem: String?

    /// What the sheet shows the user.
    fileprivate enum Stage: Equatable {
        /// Working with the school store: the page underneath isn't for the user.
        case connecting
        /// A sign-in page, which the user fills in.
        case signingIn
        /// Connected as the named person; the sheet closes in a moment.
        case connected(String?)
    }

    /// A captured cookie plus the people the signed-in page linked to.
    private struct Capture {
        let cookie: String
        let people: [StorePerson]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StoreLoginWebView(
                    onLoadingChange: { isLoading = $0 },
                    onNeedsUser: showPage,
                    onCapture: handleCapture
                )
                .ignoresSafeArea(.container, edges: .bottom)

                if stage != .signingIn {
                    StoreLoginStatus(stage: stage)
                        .transition(.opacity)
                } else if isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: stage)
            .navigationTitle("Connect Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Choose an Account",
                isPresented: pickerIsPresented,
                titleVisibility: .visible,
                presenting: pendingCapture
            ) { capture in
                ForEach(capture.people) { person in
                    Button(person.displayName) { finish(cookie: capture.cookie, person: person) }
                }
                // Without a person there's nothing to connect, and the page underneath is covered.
                Button("Cancel", role: .cancel) { dismiss() }
            } message: { _ in
                Text("This account can see more than one person. Pick whose spending to show.")
            }
            .alert("Couldn't Sign In", isPresented: problemIsPresented, presenting: problem) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
        // A downward drag on the web page shouldn't throw away a half-finished sign-in; Cancel does.
        .interactiveDismissDisabled()
    }

    /// Shows the web page when it's one the user acts on (a sign-in page), and covers it while the
    /// school store works. Once connected, the cover stays.
    private func showPage(_ needsUser: Bool) {
        if case .connected = stage { return }
        stage = needsUser || showsEveryPage ? .signingIn : .connecting
    }

    /// Shows the page with `message`, after a capture that didn't work out.
    private func fail(_ message: String) {
        showsEveryPage = true
        stage = .signingIn
        problem = message
    }

    /// Decides what to do with a freshly captured cookie and the people found on the page.
    private func handleCapture(cookie: String, people: [StorePerson]) {
        guard !cookie.isEmpty else {
            fail("You signed in, but the app couldn't read the session. Try again.")
            return
        }
        switch people.count {
        case 0:
            fail("You signed in, but no account was on the page. Open your spending page, then try again.")
        case 1:
            finish(cookie: cookie, person: people[0])
        default:
            pendingCapture = Capture(cookie: cookie, people: people)
        }
    }

    /// Builds the session for `person` and hands it back, shows "Connected" for a moment, then
    /// closes the sheet.
    private func finish(cookie: String, person: StorePerson) {
        onCapture(StoreSession(cookie: cookie, personID: person.id, personName: person.name))
        stage = .connected(person.name)
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            dismiss()
        }
    }

    private var pickerIsPresented: Binding<Bool> {
        Binding(get: { pendingCapture != nil }, set: { if !$0 { pendingCapture = nil } })
    }

    private var problemIsPresented: Binding<Bool> {
        Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })
    }
}

/// The panel over the web view while the school store works, then the "Connected" check.
private struct StoreLoginStatus: View {
    let stage: StoreLoginView.Stage

    var body: some View {
        VStack(spacing: 12) {
            if case .connected(let name) = stage {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: stage)
                Text("Connected")
                    .font(.title3.weight(.semibold))
                if let name {
                    Text(name)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
                    .controlSize(.large)
                Text("Connecting to Nobles…")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .combine)
    }
}

/// One person an account can view, extracted from the signed-in school-store page.
struct StorePerson: Identifiable, Hashable {
    /// The `person_id`/`child_id` that keys the charges endpoint.
    let id: String
    /// The person's name as shown on the page, or `nil` when it couldn't be read.
    let name: String?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return "Account \(id)"
    }

    /// Parses the `[{id, name}]` array the people-extraction script returns, dropping duplicates.
    static func list(from jsResult: Any?) -> [StorePerson] {
        guard let rows = jsResult as? [[String: Any]] else { return [] }
        var seen = Set<String>()
        var people: [StorePerson] = []
        for row in rows {
            guard let id = string(row["id"]), !id.isEmpty, seen.insert(id).inserted else { continue }
            let name = string(row["name"])?.trimmingCharacters(in: .whitespacesAndNewlines)
            people.append(StorePerson(id: id, name: (name?.isEmpty == false) ? name : nil))
        }
        return people
    }

    /// A string from a bridged JS value, whether it arrived as a string or a number.
    private static func string(_ value: Any?) -> String? {
        (value as? String) ?? (value as? NSNumber)?.stringValue
    }
}

/// Hosts the sign-in `WKWebView` and reports when a signed-in school-store page is reached.
private struct StoreLoginWebView: UIViewRepresentable {
    /// Reports page-load progress, to drive a spinner.
    let onLoadingChange: (Bool) -> Void
    /// Reports whether the page is one for the user rather than a school-store page.
    let onNeedsUser: (Bool) -> Void
    /// Reports the captured cookie header and the people on the page, once sign-in completes.
    let onCapture: (_ cookie: String, _ people: [StorePerson]) -> Void

    /// The school-store page to open; `nobilis` redirects to Veracross to sign in, then back here.
    private static let startURL = URL(string: "https://nobilis.nobles.edu/SchoolStoreNew/parent_limits.php")!

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadingChange: onLoadingChange, onNeedsUser: onNeedsUser, onCapture: onCapture)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // The default, persistent data store, so a cookie from a previous sign-in reconnects at once.
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: Self.startURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// The web view's navigation and UI delegate. WebKit calls it on the main actor, so it's
    /// isolated there, which lets it touch the web view and the SwiftUI callbacks directly.
    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let onLoadingChange: (Bool) -> Void
        private let onNeedsUser: (Bool) -> Void
        private let onCapture: (_ cookie: String, _ people: [StorePerson]) -> Void
        /// Set once the signed-in page has been captured, so a later `didFinish` doesn't re-capture.
        private var hasCaptured = false

        init(
            onLoadingChange: @escaping (Bool) -> Void,
            onNeedsUser: @escaping (Bool) -> Void,
            onCapture: @escaping (_ cookie: String, _ people: [StorePerson]) -> Void
        ) {
            self.onLoadingChange = onLoadingChange
            self.onNeedsUser = onNeedsUser
            self.onCapture = onCapture
        }

        /// Covers the page before a school-store page starts to draw.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            if navigationAction.targetFrame?.isMainFrame == true, Self.isSignedInStorePage(navigationAction.request.url) {
                onNeedsUser(false)
            }
            return .allow
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onLoadingChange(true)
        }

        /// Covers a school-store page reached by a server redirect, which asks no navigation policy.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            if Self.isSignedInStorePage(webView.url) {
                onNeedsUser(false)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadingChange(false)
            // Only school-store pages are covered, and each starts a capture, so any other page
            // (a sign-in step, or a portal page the sign-in returned to) shows.
            onNeedsUser(!Self.isSignedInStorePage(webView.url))
            guard !hasCaptured, Self.isSignedInStorePage(webView.url) else { return }
            hasCaptured = true
            Task { await captureSession(from: webView) }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoadingChange(false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onLoadingChange(false)
        }

        /// Sign-in pages can open their identity provider in a new window; there's only one window
        /// here, so load it in place instead of ignoring the tap.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            webView.load(navigationAction.request)
            return nil
        }

        /// Whether `url` is a Nobles school-store page (`nobilis…/SchoolStoreNew/`), not a sign-in page.
        private static func isSignedInStorePage(_ url: URL?) -> Bool {
            guard let url, url.host == "nobilis.nobles.edu" else { return false }
            return url.path.contains("SchoolStoreNew")
        }

        /// Reads the people and the session cookie from the signed-in page, then reports them.
        private func captureSession(from webView: WKWebView) async {
            var people = await Self.people(on: webView)
            if people.isEmpty {
                // The sign-in can return through a school-store page that forwards itself on; give
                // it a moment and look again before deciding there's no account here.
                try? await Task.sleep(for: .seconds(1.5))
                people = await Self.people(on: webView)
            }
            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            let cookie = cookies
                .filter { $0.domain.contains("nobles.edu") }
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            // Nothing usable yet: let a later page try again rather than latching on this one.
            if cookie.isEmpty || people.isEmpty { hasCaptured = false }
            onCapture(cookie, people)
        }

        /// The people the loaded page links to, or none if it can't be read.
        private static func people(on webView: WKWebView) async -> [StorePerson] {
            StorePerson.list(from: try? await webView.evaluateJavaScript(peopleScript))
        }

        /// Collects `[{id, name}]` for every person the page links to by `person_id`. Falls back to
        /// any `person_id`/`child_id` found in the page's markup when no such links exist.
        private static let peopleScript = """
        (function() {
          function clean(s) { return (s || '').replace(/\\s+/g, ' ').trim(); }
          var byId = {};
          var links = document.querySelectorAll('a[href*="person_id="]');
          for (var i = 0; i < links.length; i++) {
            var m = links[i].href.match(/person_id=(\\d+)/);
            if (m && !(m[1] in byId)) { byId[m[1]] = clean(links[i].textContent); }
          }
          if (Object.keys(byId).length === 0) {
            var html = document.documentElement ? document.documentElement.outerHTML : '';
            var re = /(?:person_id|child_id)=(\\d+)/g, found;
            while ((found = re.exec(html)) !== null) {
              if (!(found[1] in byId)) { byId[found[1]] = ''; }
            }
          }
          return Object.keys(byId).map(function(id) { return { id: id, name: byId[id] }; });
        })();
        """
    }
}

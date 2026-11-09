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
struct StoreLoginView: View {
    /// Called with the captured session once sign-in completes. The caller saves and verifies it.
    let onCapture: (StoreSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    /// A capture awaiting a choice of person, when the account can see more than one.
    @State private var pendingCapture: Capture?
    @State private var problem: String?

    /// A captured cookie plus the people the signed-in page linked to.
    private struct Capture: Identifiable {
        let id = UUID()
        let cookie: String
        let people: [StorePerson]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StoreLoginWebView(
                    onLoadingChange: { isLoading = $0 },
                    onCapture: handleCapture
                )
                .ignoresSafeArea(.container, edges: .bottom)

                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
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
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This account can see more than one person. Pick whose spending to show.")
            }
            .alert("Couldn't Sign In", isPresented: problemIsPresented, presenting: problem) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    /// Decides what to do with a freshly captured cookie and the people found on the page.
    private func handleCapture(cookie: String, people: [StorePerson]) {
        guard !cookie.isEmpty else {
            problem = "Signed in, but no session could be read. Please try again."
            return
        }
        switch people.count {
        case 0:
            problem = "Signed in, but no account was found on the page. Open your spending page, then try again."
        case 1:
            finish(cookie: cookie, person: people[0])
        default:
            pendingCapture = Capture(cookie: cookie, people: people)
        }
    }

    /// Builds the session for `person` and hands it back, then closes the sheet.
    private func finish(cookie: String, person: StorePerson) {
        onCapture(StoreSession(cookie: cookie, personID: person.id, personName: person.name))
        dismiss()
    }

    private var pickerIsPresented: Binding<Bool> {
        Binding(get: { pendingCapture != nil }, set: { if !$0 { pendingCapture = nil } })
    }

    private var problemIsPresented: Binding<Bool> {
        Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })
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
    /// Reports the captured cookie header and the people on the page, once sign-in completes.
    let onCapture: (_ cookie: String, _ people: [StorePerson]) -> Void

    /// The school-store page to open; `nobilis` redirects to Veracross to sign in, then back here.
    private static let startURL = URL(string: "https://nobilis.nobles.edu/SchoolStoreNew/parent_limits.php")!

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadingChange: onLoadingChange, onCapture: onCapture)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // The default, persistent data store, so a cookie from a previous sign-in reconnects at once.
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: Self.startURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// The web view's navigation delegate. Lives on the main actor in practice (WebKit calls its
    /// delegate there), so each callback hops onto it explicitly before touching the web view.
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onLoadingChange: (Bool) -> Void
        private let onCapture: (_ cookie: String, _ people: [StorePerson]) -> Void
        /// Set once the signed-in page has been captured, so a later `didFinish` doesn't re-capture.
        private var hasCaptured = false

        init(
            onLoadingChange: @escaping (Bool) -> Void,
            onCapture: @escaping (_ cookie: String, _ people: [StorePerson]) -> Void
        ) {
            self.onLoadingChange = onLoadingChange
            self.onCapture = onCapture
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            MainActor.assumeIsolated { onLoadingChange(true) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated {
                onLoadingChange(false)
                guard !hasCaptured, Self.isSignedInStorePage(webView.url) else { return }
                hasCaptured = true
                Task { @MainActor in await captureSession(from: webView) }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            MainActor.assumeIsolated { onLoadingChange(false) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            MainActor.assumeIsolated { onLoadingChange(false) }
        }

        /// Whether `url` is a signed-in Nobles school-store page, not the Veracross login host.
        private static func isSignedInStorePage(_ url: URL?) -> Bool {
            guard let url, let host = url.host else { return false }
            return host == "nobilis.nobles.edu" && url.path.contains("SchoolStoreNew")
        }

        /// Reads the people and the session cookie from the signed-in page, then reports them.
        @MainActor
        private func captureSession(from webView: WKWebView) async {
            let people = StorePerson.list(from: try? await webView.evaluateJavaScript(Self.peopleScript))
            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            let cookie = cookies
                .filter { $0.domain.contains("nobles.edu") }
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            // No cookie means the page wasn't really signed in; let a later navigation try again.
            if cookie.isEmpty { hasCaptured = false }
            onCapture(cookie, people)
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

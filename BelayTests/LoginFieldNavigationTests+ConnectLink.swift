import XCTest
@testable import Belay

/// Sign-in codes (`belay://connect`), scanned or tapped: what they fill
/// in, and what they refuse.
extension LoginFieldNavigationTests {
    func testConnectLinkReadsTheAddressUsernameAndPassword() throws {
        let url = try XCTUnwrap(URL(string: "belay://connect?url=https%3A%2F%2Fmac.tailnet.ts.net&username=%20eric%20&password=p%40ss%20word%2B1"))
        let link = try XCTUnwrap(DashboardConnectLink(url: url))
        XCTAssertEqual(link.address, "https://mac.tailnet.ts.net")
        XCTAssertEqual(link.username, "eric")
        // The password is used exactly as given, a literal "+" included.
        XCTAssertEqual(link.password, "p@ss word+1")
    }

    func testConnectLinkNeedsOnlyTheAddress() throws {
        let bare = try XCTUnwrap(DashboardConnectLink(url: XCTUnwrap(URL(string: "BELAY://Connect/?url=192.168.1.28:9119"))))
        XCTAssertEqual(bare.address, "192.168.1.28:9119")
        XCTAssertNil(bare.username)
        XCTAssertNil(bare.password)

        let blanks = try XCTUnwrap(DashboardConnectLink(url: XCTUnwrap(URL(string: "belay://connect?url=hermes.example&username=&password="))))
        XCTAssertNil(blanks.username)
        XCTAssertNil(blanks.password)
    }

    func testConnectLinkRefusesOtherShapes() throws {
        for raw in [
            "belay://connect",
            "belay://connect?url=%20",
            "belay://connect?username=eric&password=p",
            "belay://connect?url=a.example&url=b.example",
            "belay://connect?url=a.example&password=one&password=two",
            "belay://connect/extra?url=a.example",
            "belay://session/abc?url=a.example",
            "https://connect?url=a.example",
        ] {
            XCTAssertNil(DashboardConnectLink(url: try XCTUnwrap(URL(string: raw))), raw)
        }
    }

    func testConnectLinkDescriptionLeavesOutThePassword() throws {
        let link = try XCTUnwrap(DashboardConnectLink(url: XCTUnwrap(URL(string: "belay://connect?url=hermes.example&username=eric&password=hunter2"))))
        XCTAssertFalse(String(describing: link).contains("hunter2"))
        XCTAssertFalse(String(reflecting: link).contains("hunter2"))
    }

    func testScanTellsCodesAddressesAndEverythingElseApart() {
        guard case .link(let link) = DashboardConnectLink.scan(" belay://connect?url=mac.tailnet.ts.net:9119&username=eric ") else {
            return XCTFail("A sign-in code must read as a link")
        }
        XCTAssertEqual(link.address, "mac.tailnet.ts.net:9119")
        guard case .address(let address) = DashboardConnectLink.scan("mac.tailnet.ts.net:9119") else {
            return XCTFail("A bare dashboard address must read as an address")
        }
        XCTAssertEqual(address, "mac.tailnet.ts.net:9119")
        for text in ["", "hello world", "ftp://hermes.example", "belay://session/abc", "belay://connect?username=eric", "http://203.0.113.10:9119"] {
            guard case .unreadable = DashboardConnectLink.scan(text) else {
                return XCTFail("\(text) must not read as a dashboard")
            }
        }
    }

    func testOnlyLoopbackAddressesAreRefusedAsHermesOwn() {
        XCTAssertTrue(LoginAddress.isOnlyOnHermesComputer("localhost:9119"))
        XCTAssertTrue(LoginAddress.isOnlyOnHermesComputer("http://127.0.0.1:9119"))
        XCTAssertTrue(LoginAddress.isOnlyOnHermesComputer("127.0.1.1:9119"))
        XCTAssertFalse(LoginAddress.isOnlyOnHermesComputer("mac.tailnet.ts.net:9119"))
        XCTAssertFalse(LoginAddress.isOnlyOnHermesComputer("192.168.1.28:9119"))
        XCTAssertFalse(LoginAddress.isOnlyOnHermesComputer("https://hermes.example"))
    }

    func testSignInCodePromptDescribesTheLink() {
        let prompt = ConnectionSetupPrompt.signInCode.text
        XCTAssertTrue(prompt.contains("belay://connect?url="), prompt)
        XCTAssertTrue(prompt.contains("localhost"), "The prompt must steer Hermes away from localhost: \(prompt)")
    }
}

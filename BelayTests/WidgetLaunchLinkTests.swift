import XCTest
@testable import Belay

final class WidgetLaunchLinkTests: XCTestCase {
    private let workspace = WidgetWorkspaceID(dashboardID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, profile: "家庭/Work & café")
    private let reference = WidgetConversationReference(kind: .bot, scopeProfile: "研究者", botName: "研究者", botLabel: "Private Label", sessionID: "session-1", isUnverified: true)

    func testWidgetLinkRoundTripAndStrictNamespace() throws {
        let link = try XCTUnwrap(WidgetLaunchLink(action: .resume, workspace: workspace, reference: reference))
        XCTAssertEqual(WidgetLaunchLink(url: link.url), link)
        XCTAssertNil(WidgetLaunchLink(url: try XCTUnwrap(URL(string: "belay://session/session-1"))))
        let setup = try XCTUnwrap(WidgetLaunchLink(action: .open, workspace: nil, reference: nil))
        XCTAssertEqual(WidgetLaunchLink(url: setup.url), setup)
        XCTAssertFalse(link.url.absoluteString.contains("Private"))
        XCTAssertFalse(link.url.absoluteString.contains("label"))
    }

    func testMalformedShapesAndForeignURLsAreRejected() throws {
        for raw in [
            "https://widget/v1/open",
            "belay://session/abc",
            "belay://widget/v2/open",
            "belay://widget/v1/unknown",
            "belay://widget/v1//open",
            "belay://widget/v1/open/",
            "belay://widget/v1/resume?profile=x",
            "belay://widget/v1/newChat",
            "belay://widget/v1/talk",
            "belay://widget/v1/resume?dashboard=00000000-0000-0000-0000-000000000001",
            "belay://widget/v1/open?dashboard=00000000-0000-0000-0000-000000000001&profile=p&profile=q",
            "belay://widget/v1/open?dashboard=00000000-0000-0000-0000-000000000001&profile=p&extra=x",
            "belay://widget/v1/resume?dashboard=00000000-0000-0000-0000-000000000001&profile=p",
            "belay://widget/v1/newChat?dashboard=00000000-0000-0000-0000-000000000001&profile=p&kind=dashboard&scope=p&session=s",
            "belay://widget/v1/talk?dashboard=00000000-0000-0000-0000-000000000001&profile=p&kind=dashboard&scope=p&session=s",
            "belay://widget/v1/resume?dashboard=00000000-0000-0000-0000-000000000001&profile=p&kind=bot&scope=b&bot=b&session=s&unverified=perhaps"
        ] {
            XCTAssertNil(WidgetLaunchLink(url: try XCTUnwrap(URL(string: raw), raw)), raw)
        }
    }

    func testAllActionsHaveStrictIdentityShapes() throws {
        let open = try XCTUnwrap(WidgetLaunchLink(action: .open, workspace: workspace, reference: nil))
        let fresh = try XCTUnwrap(WidgetLaunchLink(action: .newChat, workspace: workspace, reference: nil))
        let talk = try XCTUnwrap(WidgetLaunchLink(action: .talk, workspace: workspace, reference: nil))
        XCTAssertEqual(WidgetLaunchLink(url: open.url), open)
        XCTAssertEqual(WidgetLaunchLink(url: fresh.url), fresh)
        XCTAssertEqual(WidgetLaunchLink(url: talk.url), talk)
        XCTAssertNil(WidgetLaunchLink(url: URL(string: "belay://widget/v1/resume")!))
        XCTAssertNil(WidgetLaunchLink(action: .resume, workspace: workspace, reference: nil))
        XCTAssertNil(WidgetLaunchLink(action: .resume, workspace: nil, reference: reference))
        XCTAssertNil(WidgetLaunchLink(action: .newChat, workspace: nil, reference: nil))
        XCTAssertNil(WidgetLaunchLink(action: .talk, workspace: nil, reference: nil))
        XCTAssertNil(WidgetLaunchLink(action: .newChat, workspace: workspace, reference: reference))
        XCTAssertNil(WidgetLaunchLink(action: .talk, workspace: workspace, reference: reference))
        XCTAssertNil(WidgetLaunchLink(action: .open, workspace: workspace, reference: reference))
        let mismatchedBot = WidgetConversationReference(kind: .bot, scopeProfile: "owner", botName: "other", botLabel: nil, sessionID: "s", isUnverified: false)
        XCTAssertNil(WidgetLaunchLink(action: .resume, workspace: workspace, reference: mismatchedBot))
        let mismatchedDashboard = WidgetConversationReference(kind: .dashboard, scopeProfile: "another-profile", botName: nil, botLabel: nil, sessionID: "s", isUnverified: false)
        XCTAssertNil(WidgetLaunchLink(action: .resume, workspace: workspace, reference: mismatchedDashboard))
    }
}

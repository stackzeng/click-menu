import XCTest

final class PathFormatterTests: XCTestCase {

    private let pdf = URL(fileURLWithPath: "/Users/bin/Desktop/报告 2026.pdf")
    private let folder = URL(fileURLWithPath: "/Users/bin/Desktop/设计稿/", isDirectory: true)

    func testCopyName() {
        XCTAssertEqual(PathFormatter.text(for: .copyName, urls: [pdf]), "报告 2026.pdf")
        XCTAssertEqual(PathFormatter.text(for: .copyName, urls: [pdf, folder]), "报告 2026.pdf\n设计稿")
    }

    func testCopyPath() {
        XCTAssertEqual(PathFormatter.text(for: .copyPath, urls: [pdf]), "/Users/bin/Desktop/报告 2026.pdf")
        // 文件夹路径不带末尾斜杠
        XCTAssertEqual(PathFormatter.text(for: .copyPath, urls: [folder]), "/Users/bin/Desktop/设计稿")
    }

    func testDirectoryForTerminal() {
        XCTAssertEqual(PathFormatter.path(PathFormatter.directory(for: pdf)), "/Users/bin/Desktop")
        XCTAssertEqual(PathFormatter.path(PathFormatter.directory(for: folder)), "/Users/bin/Desktop/设计稿")
    }

    func testRealDirectoryOnDisk() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cm-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        // 不带末尾斜杠的文件夹 URL 也能通过元数据识别
        let noSlash = URL(fileURLWithPath: tmp.path)
        XCTAssertTrue(PathFormatter.isDirectory(noSlash))
    }

    func testNonCopyActionsReturnNil() {
        XCTAssertNil(PathFormatter.text(for: .openTerminal, urls: [pdf]))
        XCTAssertNil(PathFormatter.text(for: .copyName, urls: []))
    }

    func testCopiedTitle() {
        XCTAssertEqual(MenuAction.copyName.copiedTitle(count: 1, isContainer: false), "已复制文件名")
        XCTAssertEqual(MenuAction.copyName.copiedTitle(count: 3, isContainer: false), "已复制 3 个文件名")
        XCTAssertEqual(MenuAction.copyPath.copiedTitle(count: 2, isContainer: false), "已复制 2 个路径")
        XCTAssertEqual(MenuAction.copyPath.copiedTitle(count: 1, isContainer: true), "已复制当前目录路径")
    }

    func testMenuTitles() {
        // 空白处右键时没有「复制文件名」
        XCTAssertNil(MenuAction.copyName.containerTitle)
        XCTAssertEqual(MenuAction.copyPath.containerTitle, "复制当前目录路径")
        XCTAssertEqual(MenuAction.allCases.map(\.rawValue), [1, 2, 3])
    }
}

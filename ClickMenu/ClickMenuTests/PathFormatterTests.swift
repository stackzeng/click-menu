import XCTest

final class PathFormatterTests: XCTestCase {

    private let home = "/Users/bin"
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

    func testBaseName() {
        XCTAssertEqual(PathFormatter.baseName(pdf), "报告 2026")
        XCTAssertEqual(PathFormatter.baseName(URL(fileURLWithPath: "/tmp/archive.tar.gz")), "archive.tar")
        XCTAssertEqual(PathFormatter.baseName(URL(fileURLWithPath: "/Users/bin/.zshrc")), ".zshrc")
        XCTAssertEqual(PathFormatter.baseName(URL(fileURLWithPath: "/Users/bin/Makefile")), "Makefile")
        XCTAssertEqual(PathFormatter.baseName(folder), "设计稿")
    }

    func testEscaped() {
        XCTAssertEqual(PathFormatter.escaped("/Users/bin/报告 2026.pdf"), "/Users/bin/报告\\ 2026.pdf")
        XCTAssertEqual(PathFormatter.escaped("/a/b (1)/c&d's"), "/a/b\\ \\(1\\)/c\\&d\\'s")
        XCTAssertEqual(PathFormatter.escaped("/plain/path"), "/plain/path")
    }

    func testTilde() {
        XCTAssertEqual(PathFormatter.tilde("/Users/bin/Desktop/a.txt", home: home), "~/Desktop/a.txt")
        XCTAssertEqual(PathFormatter.tilde("/Users/bin", home: home), "~")
        XCTAssertEqual(PathFormatter.tilde("/Users/binary/a", home: home), "/Users/binary/a")
        XCTAssertEqual(PathFormatter.tilde("/Volumes/USB/a", home: home), "/Volumes/USB/a")
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
        XCTAssertEqual(MenuAction.copyPath.copiedTitle(count: 1, isContainer: true), "已复制当前目录路径")
    }
}

import CoreGraphics
import Foundation

/// Supplies bundled card images so the recognition flow can be exercised
/// without a camera (simulator) or deterministically (UI tests).
///
/// `Fixtures` is a folder reference in the app bundle, so it is enumerated with
/// `FileManager` rather than `Bundle.urls(forResourcesWithExtension:)`, which
/// does not descend into folder references.
struct FixtureProvider: Sendable {
    let names: [String]

    static func directory() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Fixtures", isDirectory: true)
    }

    static func bundled() -> FixtureProvider? {
        guard let directory = directory(),
              let contents = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: nil
              ) else { return nil }
        let names = contents
            .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
        return names.isEmpty ? nil : FixtureProvider(names: names)
    }

    func image(named name: String) -> CGImage? {
        guard let directory = Self.directory() else { return nil }
        for ext in ["jpg", "jpeg", "png"] {
            let url = directory.appendingPathComponent("\(name).\(ext)")
            if let data = try? Data(contentsOf: url), let image = ImageCoding.cgImage(from: data) {
                return image
            }
        }
        return nil
    }

    /// Cycles through the bundle so repeated captures in a test are distinct.
    func image(at index: Int) -> (name: String, image: CGImage)? {
        guard !names.isEmpty else { return nil }
        let name = names[index % names.count]
        guard let image = image(named: name) else { return nil }
        return (name, image)
    }
}

import UniformTypeIdentifiers

struct UTTypeWrapper: Hashable {
    let type: UTType
    static let pdf = UTTypeWrapper(type: .pdf)
    static let image = UTTypeWrapper(type: .image)
    static let plainText = UTTypeWrapper(type: .plainText)
}

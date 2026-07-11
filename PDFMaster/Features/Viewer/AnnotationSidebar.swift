import PDFKit
import SwiftUI

struct AnnotationSidebar: View {
    @ObservedObject var viewModel: PDFEditorViewModel
    @State private var searchQuery = ""
    @State private var selectedFilter: AnnotationFilter = .all
    @State private var sortOrder: AnnotationSort = .page

    enum AnnotationFilter: String, CaseIterable {
        case all      = "All"
        case markup   = "Markup"
        case text     = "Text"
        case shape    = "Shape"
        case stamp    = "Stamp"
        case ink      = "Drawing"
    }

    enum AnnotationSort: String, CaseIterable {
        case page     = "Page"
        case type     = "Type"
        case date     = "Date"
        case author   = "Author"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(AnnotationFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search annotations...", text: $searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)

                Picker("Sort", selection: $sortOrder) {
                    ForEach(AnnotationSort.allCases, id: \.self) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                .padding(.vertical, 4)

                if filteredAnnotations.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Annotations",
                        systemImage: "note.text",
                        description: Text(searchQuery.isEmpty ? "Tap an annotation tool to add one" : "No matching annotations")
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(Array(filteredAnnotations.enumerated()), id: \.offset) { _, item in
                            annotationRow(item)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Annotations (\(filteredAnnotations.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { viewModel.showSidebar = false }
            }
        }
    }

    private var allItems: [(PDFAnnotation, Int)] {
        viewModel.allAnnotations()
    }

    private var filteredAnnotations: [(PDFAnnotation, Int)] {
        var items = allItems

        switch selectedFilter {
        case .markup:
            items = items.filter { ann, _ in
                ann.type == PDFAnnotationSubtype.highlight.rawValue ||
                ann.type == PDFAnnotationSubtype.underline.rawValue ||
                ann.type == PDFAnnotationSubtype.strikeOut.rawValue
            }
        case .text:
            items = items.filter { ann, _ in
                ann.type == PDFAnnotationSubtype.text.rawValue ||
                ann.type == PDFAnnotationSubtype.freeText.rawValue
            }
        case .shape:
            items = items.filter { ann, _ in
                ann.type == PDFAnnotationSubtype.square.rawValue ||
                ann.type == PDFAnnotationSubtype.circle.rawValue ||
                ann.type == PDFAnnotationSubtype.line.rawValue
            }
        case .stamp:
            items = items.filter { ann, _ in
                ann.type == PDFAnnotationSubtype.stamp.rawValue
            }
        case .ink:
            items = items.filter { ann, _ in
                ann.type == PDFAnnotationSubtype.ink.rawValue
            }
        case .all:
            break
        }

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            items = items.filter { ann, _ in
                (ann.contents ?? "").lowercased().contains(q) ||
                (ann.userName ?? "").lowercased().contains(q)
            }
        }

        switch sortOrder {
        case .page:  items.sort { $0.1 < $1.1 }
        case .type:  items.sort { ($0.0.type ?? "") < ($1.0.type ?? "") }
        case .date:  items.sort { ($0.0.modificationDate ?? .distantPast) > ($1.0.modificationDate ?? .distantPast) }
        case .author: items.sort { ($0.0.userName ?? "") < ($1.0.userName ?? "") }
        }

        return items
    }

    @ViewBuilder
    private func annotationRow(_ item: (PDFAnnotation, Int)) -> some View {
        let (annotation, pageIndex) = item
        Button {
            viewModel.selectionManager.select(annotation)
            viewModel.selectionManager.jumpToAnnotation(annotation)
            viewModel.showSidebar = false
        } label: {
            HStack(spacing: 12) {
                iconForType(annotation.type)
                    .font(.title3)
                    .foregroundStyle(Color(annotation.color))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(annotation.contents?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text("Page \(pageIndex + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let author = annotation.userName, !author.isEmpty {
                            Text(author)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let date = annotation.modificationDate {
                            Text(date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                if let page = annotation.page {
                    viewModel.removeAnnotation(annotation, from: page)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func iconForType(_ type: String?) -> Image {
        guard let type else { return Image(systemName: "note.text") }
        switch type {
        case PDFAnnotationSubtype.highlight.rawValue:  return Image(systemName: "highlighter")
        case PDFAnnotationSubtype.underline.rawValue:  return Image(systemName: "underline")
        case PDFAnnotationSubtype.strikeOut.rawValue:  return Image(systemName: "strikethrough")
        case PDFAnnotationSubtype.text.rawValue:       return Image(systemName: "note.text")
        case PDFAnnotationSubtype.freeText.rawValue:   return Image(systemName: "character.textbox")
        case PDFAnnotationSubtype.square.rawValue:     return Image(systemName: "rectangle")
        case PDFAnnotationSubtype.circle.rawValue:     return Image(systemName: "circle")
        case PDFAnnotationSubtype.line.rawValue:       return Image(systemName: "line.diagonal")
        case PDFAnnotationSubtype.stamp.rawValue:      return Image(systemName: "seal")
        case PDFAnnotationSubtype.ink.rawValue:        return Image(systemName: "pencil.tip")
        default:                                       return Image(systemName: "note.text")
        }
    }
}

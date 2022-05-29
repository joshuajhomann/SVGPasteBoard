//
//  ContentView.swift
//  SVGPasteBoard
//
//  Created by Joshua Homann on 5/28/22.
//

import SwiftUI

final class SVG: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    var cgPath: CGPath? {
        didParse ? path : nil
    }
    private let path = CGMutablePath()
    private var didParse = false
    init(data: Data) {
        parser = XMLParser(data: data)
        super.init()
        parser.delegate = self
        didParse = parser.parse()
    }
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String]
    ) {
        if elementName == "path", let pathString = attributeDict["d"] {
            print(pathString)
            makePath(from: pathString)
        } else if elementName == "polygon", let polygonString = attributeDict["points"] {
            print(polygonString)
            makePolygon(from: polygonString)
        } else {
            print("Unhandled element :\(elementName)")
        }
    }

    private func makePath(from pathString: String) { }
    private func makePolygon(from polygonString: String) {
        let scanner = Scanner(string: polygonString)
        scanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ","))
        var points = sequence(state: scanner) { scanner -> CGPoint? in
            scanner.scanPoint()
        }
        if let point = points.next() {
            path.move(to: point)
            points.forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }
    }
}

extension Scanner {
    func scanPoint() -> CGPoint? {
        guard let x = scanDouble(), let y = scanDouble() else { return nil }
        return .init(x: x, y: y)
    }
}

extension CGPath {
    func transformToFit(maxDimension: Double) -> CGAffineTransform {
        let maximumDimension = max(boundingBoxOfPath.width, boundingBoxOfPath.height)
        let scale = maximumDimension == 0 ? 1 : 1/maximumDimension
        return CGAffineTransform.identity
            .scaledBy(x: scale * maxDimension, y: scale * maxDimension)
            .translatedBy(x: -boundingBoxOfPath.minX, y: -boundingBoxOfPath.minY)
    }
}

final class ViewModel: ObservableObject {
    @Published private(set) var availablePasteboardTypes = ""
    @Published private(set) var pastedText = ""
    @Published private(set) var path: CGPath?
    func paste() {
        let data = UIPasteboard.general.items.first?["com.adobe.svg"].flatMap { $0 as? Data } ??
            UIPasteboard.general.items.first?["public.utf8-plain-text"].flatMap { ($0 as? String)?.data(using: .utf8) }
        guard let data = data else { return path = nil }
        availablePasteboardTypes = UIPasteboard.general.types.joined(separator: "\n")
        pastedText = String(data: data, encoding: .utf8) ?? ""
        path = SVG(data: data).cgPath
    }
}


struct ContentView: View {
    @StateObject private var viewModel = ViewModel()
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.availablePasteboardTypes).font(.body)
                    Text(viewModel.pastedText).font(.body.monospaced())
                }
            }
                .padding()
                .navigationTitle("Pasted text")
                .toolbar { Button("Paste", action: viewModel.paste) }
            ZStack(alignment: .center) {
                if let path = viewModel.path {
                    Path(path)
                        .strokedPath(.init(lineWidth: 1, lineCap: .round))
                        .transform(path.transformToFit(maxDimension: 400))
                        .frame(width: 400, height: 400)
                } else {
                    Text(viewModel.pastedText.isEmpty ? "Paste an SVG": "Can not parse as SVG")
                }
            }
        }
    }
}



import Foundation
import UIKit
import PDFKit

// PDF Export Service for PosterScan objects
class PDFExportService {
    
    // Main function to generate a PDF from a PosterScan
    static func generatePDF(from scan: PosterScan) -> Data? {
        // Create a PDF document
        let pdfMetaData = [
            kCGPDFContextCreator: "PosterLens",
            kCGPDFContextAuthor: "PosterLens App",
            kCGPDFContextTitle: scan.title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // Use A4 size for the PDF
        let pageWidth = 8.27 * 72.0
        let pageHeight = 11.69 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        // Generate PDF data
        let data = renderer.pdfData { (context) in
            context.beginPage()
            
            // Get the context for drawing
            let drawContext = context.cgContext
            
            // Set up fonts and colors
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 14, weight: .medium)
            let headingFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let textColor = UIColor.black
            
            // Set up margins and positions
            let margin: CGFloat = 50
            var yPosition: CGFloat = margin
            
            // Draw title
            yPosition = drawText(scan.title, font: titleFont, textColor: textColor, rect: pageRect, yPosition: yPosition, margin: margin)
            yPosition += 10
            
            // Draw date
            yPosition = drawText("Date: \(scan.dateFormatted)", font: subtitleFont, textColor: textColor, rect: pageRect, yPosition: yPosition, margin: margin)
            yPosition += 20
            
            // Draw image if available
            if let image = scan.image {
                let imageMaxHeight: CGFloat = 250
                let imageWidth = pageWidth - (margin * 2)
                let aspectRatio = image.size.width / image.size.height
                let imageHeight = min(imageMaxHeight, imageWidth / aspectRatio)
                
                let imageRect = CGRect(x: margin, y: yPosition, width: imageWidth, height: imageHeight)
                
                // Draw a border around the image
                drawContext.setStrokeColor(UIColor.lightGray.cgColor)
                drawContext.setLineWidth(1.0)
                drawContext.stroke(imageRect)
                
                // Draw the image
                image.draw(in: imageRect)
                
                yPosition += imageHeight + 20
            }
            
            // Pagination helpers: start a new page when content won't fit, measuring
            // each piece of text first so nothing overlaps at the page bottom.
            let headingWidth = pageWidth - margin * 2
            let bulletWidth = pageWidth - (margin + 10) * 2

            func ensureSpace(_ needed: CGFloat) {
                if yPosition + needed > pageHeight - margin {
                    context.beginPage()
                    yPosition = margin
                }
            }
            func drawHeading(_ text: String) {
                let h = textHeight(text, font: headingFont, width: headingWidth)
                ensureSpace(h + 30) // keep the heading with at least one line below it
                yPosition = drawText(text, font: headingFont, textColor: textColor, rect: pageRect, yPosition: yPosition, margin: margin)
                yPosition += 10
            }
            func drawBullet(_ text: String) {
                let h = textHeight(text, font: bodyFont, width: bulletWidth)
                ensureSpace(h)
                yPosition = drawText(text, font: bodyFont, textColor: textColor, rect: pageRect, yPosition: yPosition, margin: margin + 10)
            }

            // Draw summary points
            drawHeading("Summary")
            for (index, point) in scan.summaryPoints.enumerated() {
                drawBullet("• \(point)")
                if index < scan.summaryPoints.count - 1 { yPosition += 5 }
            }
            yPosition += 20

            // Draw author questions if available
            if let questions = scan.authorQuestions, !questions.isEmpty {
                drawHeading("Questions for the Author")
                for (index, question) in questions.enumerated() {
                    drawBullet("• \(question)")
                    if index < questions.count - 1 { yPosition += 5 }
                }
                yPosition += 20
            }

            // Draw research categories if available
            if let categories = scan.categories, !categories.isEmpty {
                drawHeading("Research Categories")
                for category in categories {
                    drawBullet("• \(category.name) — \(category.type.rawValue)")
                    yPosition += 5
                }
                yPosition += 20
            }

            // Draw research directions if available
            if let directions = scan.researchContext?.futureDirections, !directions.isEmpty {
                drawHeading("Research Directions")
                for (index, direction) in directions.enumerated() {
                    drawBullet("• \(direction)")
                    if index < directions.count - 1 { yPosition += 5 }
                }
                yPosition += 20
            }

            // Draw related research if available
            if let papers = scan.researchContext?.literatureContext, !papers.isEmpty {
                drawHeading("Related Research")
                for (index, paper) in papers.enumerated() {
                    drawBullet("• \(paper.formattedCitation)")
                    if index < papers.count - 1 { yPosition += 5 }
                }
                yPosition += 20
            }

            // Draw footer
            let footerText = "Generated by PosterLens App"
            let footerFont = UIFont.systemFont(ofSize: 10, weight: .light)
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.gray
            ]
            
            let footerSize = footerText.size(withAttributes: footerAttributes)
            let footerX = (pageWidth - footerSize.width) / 2
            let footerY = pageHeight - margin / 2
            
            footerText.draw(at: CGPoint(x: footerX, y: footerY), withAttributes: footerAttributes)
        }
        
        return data
    }
    
    // Measure the height a string will occupy when wrapped to the given width
    private static func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(boundingRect.height)
    }

    // Helper function to draw text with proper wrapping
    private static func drawText(_ text: String, font: UIFont, textColor: UIColor, rect: CGRect, yPosition: CGFloat, margin: CGFloat) -> CGFloat {
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        let textRect = CGRect(
            x: margin,
            y: yPosition,
            width: rect.width - (margin * 2),
            height: rect.height - yPosition - margin
        )
        
        let textToRender = NSAttributedString(string: text, attributes: textAttributes)
        let framesetter = CTFramesetterCreateWithAttributedString(textToRender)
        
        let path = CGMutablePath()
        path.addRect(textRect)
        
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, textToRender.length), path, nil)
        
        // Get the context for drawing
        let context = UIGraphicsGetCurrentContext()!
        
        // Flip the coordinate system
        context.translateBy(x: 0, y: textRect.origin.y * 2 + textRect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the text
        CTFrameDraw(frame, context)
        
        // Restore the coordinate system
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0, y: -(textRect.origin.y * 2 + textRect.size.height))
        
        // Calculate the height of the rendered text
        let frameLines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: frameLines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, frameLines.count), &origins)
        
        if frameLines.isEmpty {
            return yPosition + font.lineHeight
        }
        
        // Calculate the new Y position based on the text height
        let lastLineOriginY = origins.last!.y
        let lastLineHeight = font.lineHeight
        let textHeight = textRect.height - lastLineOriginY + lastLineHeight
        
        return yPosition + textHeight + 5
    }
}

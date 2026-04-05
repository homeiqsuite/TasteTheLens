import UIKit

struct PDFExporter {
    static func generatePDF(for recipe: Recipe) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size
        let margin: CGFloat = 50
        let contentWidth = pageRect.width - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            var y: CGFloat = 0

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageRect.height - margin {
                    context.beginPage()
                    y = margin
                }
            }

            func drawText(_ text: String, font: UIFont, color: UIColor = .darkText, maxWidth: CGFloat = contentWidth) -> CGFloat {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 4
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraphStyle
                ]
                let attrString = NSAttributedString(string: text, attributes: attrs)
                let rect = attrString.boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                attrString.draw(in: CGRect(x: margin, y: y, width: maxWidth, height: rect.height))
                return rect.height
            }

            // Page 1
            context.beginPage()
            y = margin

            // Dish name
            let titleFont = UIFont(name: "Georgia-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
            let titleHeight = drawText(recipe.dishName, font: titleFont, color: Theme.goldUI)
            y += titleHeight + 12

            // Description
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let descHeight = drawText(recipe.recipeDescription, font: bodyFont, color: .darkGray)
            y += descHeight + 16

            // Dish image
            if let imageData = recipe.generatedDishImageData, let image = UIImage(data: imageData) {
                let imageHeight: CGFloat = 200
                ensureSpace(imageHeight + 20)
                let imageRect = CGRect(x: margin, y: y, width: contentWidth, height: imageHeight)
                let path = UIBezierPath(roundedRect: imageRect, cornerRadius: 8)
                path.addClip()
                // Scale to fill
                let scale = max(contentWidth / image.size.width, imageHeight / image.size.height)
                let scaledW = image.size.width * scale
                let scaledH = image.size.height * scale
                let drawRect = CGRect(
                    x: imageRect.midX - scaledW / 2,
                    y: imageRect.midY - scaledH / 2,
                    width: scaledW,
                    height: scaledH
                )
                image.draw(in: drawRect)
                // Reset clipping
                context.cgContext.resetClip()
                y += imageHeight + 20
            }

            // Color palette dots
            if !recipe.colorPalette.isEmpty {
                ensureSpace(30)
                let dotSize: CGFloat = 16
                let dotSpacing: CGFloat = 8
                var dotX = margin
                for hex in recipe.colorPalette {
                    let color = UIColor(hex: hex)
                    color.setFill()
                    UIBezierPath(ovalIn: CGRect(x: dotX, y: y, width: dotSize, height: dotSize)).fill()
                    dotX += dotSize + dotSpacing
                }
                y += dotSize + 20
            }

            // Servings
            let servingsFont = UIFont.systemFont(ofSize: 11, weight: .medium)
            let servingsHeight = drawText("Serves \(recipe.baseServings)", font: servingsFont, color: .gray)
            y += servingsHeight + 20

            // Section helper
            func drawSection(_ title: String) {
                ensureSpace(30)
                let sectionFont = UIFont.systemFont(ofSize: 14, weight: .bold)
                let h = drawText(title.uppercased(), font: sectionFont, color: Theme.goldUI)
                y += h + 4
                // Underline
                Theme.goldUI30.setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: y))
                line.addLine(to: CGPoint(x: margin + contentWidth, y: y))
                line.lineWidth = 0.5
                line.stroke()
                y += 12
            }

            // Translation Matrix
            if !recipe.translationMatrix.isEmpty {
                drawSection("Translation Matrix")
                let smallFont = UIFont.systemFont(ofSize: 11)
                for item in recipe.translationMatrix {
                    ensureSpace(30)
                    let h = drawText("\(item.visual)  →  \(item.culinary)", font: smallFont)
                    y += h + 6
                }
                y += 10
            }

            // Components
            drawSection("Components")
            let ingredientFont = UIFont.systemFont(ofSize: 11)
            let methodFont = UIFont.italicSystemFont(ofSize: 11)
            let componentNameFont = UIFont.systemFont(ofSize: 12, weight: .semibold)

            for component in recipe.components {
                ensureSpace(40)
                let nameH = drawText(component.name, font: componentNameFont)
                y += nameH + 4

                for ingredient in component.ingredients {
                    ensureSpace(20)
                    let h = drawText("• \(ingredient)", font: ingredientFont)
                    y += h + 2
                }
                y += 4

                ensureSpace(30)
                let methodH = drawText(component.method, font: methodFont, color: .darkGray)
                y += methodH + 12
            }

            // Cooking Steps
            let steps = recipe.effectiveCookingSteps
            if !steps.isEmpty {
                drawSection("Cooking Steps")
                for (i, step) in steps.enumerated() {
                    ensureSpace(30)
                    var stepText = "\(i + 1). \(step.instruction)"
                    if !step.ingredientsUsed.isEmpty {
                        stepText += " [Uses: \(step.ingredientsUsed.joined(separator: ", "))]"
                    }
                    let h = drawText(stepText, font: bodyFont)
                    y += h + 6
                }
                y += 10
            }

            // Plating
            if !recipe.platingSteps.isEmpty {
                drawSection("Plating")
                for (i, step) in recipe.platingSteps.enumerated() {
                    ensureSpace(30)
                    let h = drawText("\(i + 1). \(step)", font: bodyFont)
                    y += h + 6
                }
                y += 10
            }

            // Pairings
            drawSection("Pairings")
            ensureSpace(60)
            let pairingFont = UIFont.systemFont(ofSize: 11)
            var h = drawText("Wine: \(recipe.sommelierPairing.wine)", font: pairingFont)
            y += h + 4
            h = drawText("Cocktail: \(recipe.sommelierPairing.cocktail)", font: pairingFont)
            y += h + 4
            h = drawText("Non-Alcoholic: \(recipe.sommelierPairing.nonalcoholic)", font: pairingFont)
            y += h + 20

            // Footer
            ensureSpace(30)
            let footerFont = UIFont.systemFont(ofSize: 9, weight: .light)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let footerText = "Created with Taste The Lens • \(dateFormatter.string(from: recipe.createdAt))"
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.lightGray
            ]
            let footerStr = NSAttributedString(string: footerText, attributes: footerAttrs)
            footerStr.draw(at: CGPoint(x: margin, y: pageRect.height - margin + 10))
        }
    }

    static func generateMenuPDF(theme: String, courses: [(courseType: String, recipe: Recipe)]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 50
        let contentWidth = pageRect.width - margin * 2
        let goldColor = Theme.goldUI

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            // Cover page
            context.beginPage()
            let coverTitleFont = UIFont(name: "Georgia-Bold", size: 32) ?? UIFont.boldSystemFont(ofSize: 32)
            let coverSubFont = UIFont.systemFont(ofSize: 14, weight: .medium)

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: coverTitleFont, .foregroundColor: goldColor]
            let titleStr = NSAttributedString(string: theme, attributes: titleAttrs)
            let titleRect = titleStr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
            titleStr.draw(in: CGRect(x: margin, y: pageRect.midY - titleRect.height - 20, width: contentWidth, height: titleRect.height))

            let subAttrs: [NSAttributedString.Key: Any] = [.font: coverSubFont, .foregroundColor: UIColor.gray]
            let subStr = NSAttributedString(string: "A \(courses.count)-Course Tasting Menu", attributes: subAttrs)
            subStr.draw(at: CGPoint(x: margin, y: pageRect.midY + 10))

            let footerFont = UIFont.systemFont(ofSize: 9, weight: .light)
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.lightGray]
            let footerStr = NSAttributedString(string: "Created with Taste The Lens", attributes: footerAttrs)
            footerStr.draw(at: CGPoint(x: margin, y: pageRect.height - margin + 10))

            // Course pages
            let courseTypeFont = UIFont.systemFont(ofSize: 11, weight: .bold)
            let dishNameFont = UIFont(name: "Georgia-Bold", size: 22) ?? UIFont.boldSystemFont(ofSize: 22)
            let bodyFont = UIFont.systemFont(ofSize: 12)

            for (courseType, recipe) in courses {
                context.beginPage()
                var y: CGFloat = margin

                // Course type
                let typeAttrs: [NSAttributedString.Key: Any] = [.font: courseTypeFont, .foregroundColor: goldColor]
                NSAttributedString(string: courseType.uppercased(), attributes: typeAttrs).draw(at: CGPoint(x: margin, y: y))
                y += 24

                // Dish name
                let nameAttrs: [NSAttributedString.Key: Any] = [.font: dishNameFont, .foregroundColor: UIColor.darkText]
                let nameStr = NSAttributedString(string: recipe.dishName, attributes: nameAttrs)
                let nameRect = nameStr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
                nameStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: nameRect.height))
                y += nameRect.height + 12

                // Description
                let descAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]
                let descStr = NSAttributedString(string: recipe.recipeDescription, attributes: descAttrs)
                let descRect = descStr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
                descStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: descRect.height))
                y += descRect.height + 20

                // Dish image
                if let imageData = recipe.generatedDishImageData, let image = UIImage(data: imageData) {
                    let imageHeight: CGFloat = 200
                    let imageRect = CGRect(x: margin, y: y, width: contentWidth, height: imageHeight)
                    let path = UIBezierPath(roundedRect: imageRect, cornerRadius: 8)
                    context.cgContext.saveGState()
                    path.addClip()
                    let scale = max(contentWidth / image.size.width, imageHeight / image.size.height)
                    let scaledW = image.size.width * scale
                    let scaledH = image.size.height * scale
                    image.draw(in: CGRect(x: imageRect.midX - scaledW / 2, y: imageRect.midY - scaledH / 2, width: scaledW, height: scaledH))
                    context.cgContext.restoreGState()
                    y += imageHeight + 20
                }

                // All components and their ingredients (#8)
                if !recipe.components.isEmpty {
                    let sectionAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: goldColor]
                    NSAttributedString(string: "INGREDIENTS", attributes: sectionAttrs).draw(at: CGPoint(x: margin, y: y))
                    y += 20

                    let componentNameFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
                    let ingredientFont = UIFont.systemFont(ofSize: 11)

                    for component in recipe.components {
                        if recipe.components.count > 1 {
                            let nameAttrs: [NSAttributedString.Key: Any] = [.font: componentNameFont, .foregroundColor: UIColor.darkText]
                            NSAttributedString(string: component.name, attributes: nameAttrs).draw(at: CGPoint(x: margin, y: y))
                            y += 16
                        }
                        for ingredient in component.ingredients {
                            let attrs: [NSAttributedString.Key: Any] = [.font: ingredientFont, .foregroundColor: UIColor.darkText]
                            let indentX = recipe.components.count > 1 ? margin + 12 : margin
                            NSAttributedString(string: "• \(ingredient)", attributes: attrs).draw(at: CGPoint(x: indentX, y: y))
                            y += 16
                        }
                        y += 4
                    }
                }
            }
        }
    }
}

// UIColor hex helper for PDF rendering
private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: CGFloat
        switch hex.count {
        case 6:
            r = CGFloat((int >> 16) & 0xFF) / 255
            g = CGFloat((int >> 8) & 0xFF) / 255
            b = CGFloat(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

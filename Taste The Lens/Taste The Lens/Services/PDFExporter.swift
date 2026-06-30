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

    // MARK: - Meal Plan / Meal PDFs

    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter
    private static let pdfMargin: CGFloat = 50

    /// Single planned meal as a one-or-more page PDF.
    static func generateMealPDF(for meal: PlannedMeal) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            var y = drawMeal(meal, in: context, startY: pdfMargin, showImage: true)
            drawFooter(at: &y)
        }
    }

    /// Whole weekly plan: cover + grocery list + each meal.
    static func generateMealPlanPDF(for plan: MealPlan) -> Data {
        let margin = pdfMargin
        let contentWidth = pageRect.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            // Cover page
            context.beginPage()
            let coverTitleFont = UIFont(name: "Georgia-Bold", size: 30) ?? UIFont.boldSystemFont(ofSize: 30)
            let titleStr = NSAttributedString(string: plan.title, attributes: [.font: coverTitleFont, .foregroundColor: Theme.goldUI])
            let titleRect = titleStr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
            titleStr.draw(in: CGRect(x: margin, y: pageRect.midY - titleRect.height - 16, width: contentWidth, height: titleRect.height))

            let chefName = ChefPersonality(rawValue: plan.chefPersonality ?? "")?.displayName ?? "Taste The Lens"
            let subStr = NSAttributedString(
                string: "\(chefName)  •  \(plan.daysCount) days · \(plan.totalMealCount) meals",
                attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: UIColor.gray]
            )
            subStr.draw(at: CGPoint(x: margin, y: pageRect.midY + 6))

            let footerStr = NSAttributedString(string: "Created with Taste The Lens", attributes: [.font: UIFont.systemFont(ofSize: 9, weight: .light), .foregroundColor: UIColor.lightGray])
            footerStr.draw(at: CGPoint(x: margin, y: pageRect.height - margin + 10))

            // Grocery list page
            if !plan.groceryList.isEmpty {
                context.beginPage()
                var y = margin
                drawSectionHeader("Grocery List", in: context, y: &y)
                let grouped = Dictionary(grouping: plan.groceryList, by: { $0.aisle })
                for aisle in grouped.keys.sorted() {
                    ensurePageSpace(40, in: context, y: &y)
                    let aisleStr = NSAttributedString(string: aisle, attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: UIColor.darkText])
                    aisleStr.draw(at: CGPoint(x: margin, y: y)); y += 18
                    for item in grouped[aisle]!.sorted(by: { $0.name < $1.name }) {
                        ensurePageSpace(18, in: context, y: &y)
                        let line = "• \(item.name) — \(item.quantity)"
                        NSAttributedString(string: line, attributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkText]).draw(at: CGPoint(x: margin + 12, y: y))
                        y += 15
                    }
                    y += 8
                }
            }

            // Each meal (one page each)
            for group in plan.mealsByDay {
                for meal in group.meals {
                    context.beginPage()
                    var y = margin
                    let dayStr = NSAttributedString(string: "DAY \(group.day)", attributes: [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: Theme.goldUI])
                    dayStr.draw(at: CGPoint(x: margin, y: y)); y += 18
                    y = drawMeal(meal, in: context, startY: y, showImage: true)
                }
            }
        }
    }

    // MARK: - Shared meal drawing

    private static func drawMeal(_ meal: PlannedMeal, in context: UIGraphicsPDFRendererContext, startY: CGFloat, showImage: Bool) -> CGFloat {
        let margin = pdfMargin
        let contentWidth = pageRect.width - margin * 2
        var y = startY

        func ensure(_ needed: CGFloat) { ensurePageSpace(needed, in: context, y: &y) }
        func draw(_ text: String, font: UIFont, color: UIColor = .darkText) -> CGFloat {
            let ps = NSMutableParagraphStyle(); ps.lineSpacing = 4
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: ps]
            let s = NSAttributedString(string: text, attributes: attrs)
            let r = s.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            s.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: r.height))
            return r.height
        }

        // Meal type label
        y += draw(meal.mealType.uppercased(), font: .systemFont(ofSize: 11, weight: .bold), color: Theme.goldUI) + 4
        // Dish name
        y += draw(meal.dishName, font: UIFont(name: "Georgia-Bold", size: 22) ?? .boldSystemFont(ofSize: 22)) + 8
        // Description
        if !meal.mealDescription.isEmpty { y += draw(meal.mealDescription, font: .systemFont(ofSize: 12), color: .darkGray) + 12 }

        // Image
        if showImage, let data = meal.generatedImageData, let image = UIImage(data: data) {
            let imageHeight: CGFloat = 200
            ensure(imageHeight + 16)
            let rect = CGRect(x: margin, y: y, width: contentWidth, height: imageHeight)
            context.cgContext.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: 8).addClip()
            let scale = max(contentWidth / image.size.width, imageHeight / image.size.height)
            let sw = image.size.width * scale, sh = image.size.height * scale
            image.draw(in: CGRect(x: rect.midX - sw / 2, y: rect.midY - sh / 2, width: sw, height: sh))
            context.cgContext.restoreGState()
            y += imageHeight + 16
        }

        // Meta line (times / difficulty / calories)
        var meta: [String] = []
        if let p = meal.prepTime { meta.append("Prep \(p)") }
        if let c = meal.cookTime { meta.append("Cook \(c)") }
        if let d = meal.difficulty { meta.append(d) }
        if let n = meal.nutrition { meta.append("\(n.calories) cal · \(n.protein)g protein · \(n.carbs)g carbs · \(n.fat)g fat") }
        if !meta.isEmpty { y += draw(meta.joined(separator: "  ·  "), font: .systemFont(ofSize: 11, weight: .medium), color: .gray) + 12 }

        // Research notes
        if !meal.researchNotes.isEmpty {
            ensure(30)
            y += draw("Why this meal: \(meal.researchNotes)", font: .italicSystemFont(ofSize: 11), color: .darkGray) + 14
        }

        // Ingredients
        drawSectionHeader("Ingredients", in: context, y: &y)
        for component in meal.components {
            ensure(30)
            if meal.components.count > 1 { y += draw(component.name, font: .systemFont(ofSize: 12, weight: .semibold)) + 4 }
            for ingredient in component.ingredients {
                ensure(18)
                y += draw("• \(ingredient)", font: .systemFont(ofSize: 11)) + 2
            }
            y += 6
        }

        // Cooking steps
        if !meal.cookingSteps.isEmpty {
            drawSectionHeader("Cooking Steps", in: context, y: &y)
            for (i, step) in meal.cookingSteps.enumerated() {
                ensure(30)
                y += draw("\(i + 1). \(step.instruction)", font: .systemFont(ofSize: 12)) + 4
                if let tip = step.tip, !tip.isEmpty {
                    ensure(18)
                    y += draw("Tip: \(tip)", font: .italicSystemFont(ofSize: 10), color: .gray) + 6
                } else { y += 4 }
            }
        }
        return y
    }

    private static func ensurePageSpace(_ needed: CGFloat, in context: UIGraphicsPDFRendererContext, y: inout CGFloat) {
        if y + needed > pageRect.height - pdfMargin {
            context.beginPage()
            y = pdfMargin
        }
    }

    private static func drawSectionHeader(_ title: String, in context: UIGraphicsPDFRendererContext, y: inout CGFloat) {
        let margin = pdfMargin
        let contentWidth = pageRect.width - margin * 2
        ensurePageSpace(40, in: context, y: &y)
        let s = NSAttributedString(string: title.uppercased(), attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: Theme.goldUI])
        s.draw(at: CGPoint(x: margin, y: y)); y += 20
        Theme.goldUI30.setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y)); line.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        line.lineWidth = 0.5; line.stroke()
        y += 12
    }

    private static func drawFooter(at y: inout CGFloat) {
        let footerStr = NSAttributedString(string: "Created with Taste The Lens", attributes: [.font: UIFont.systemFont(ofSize: 9, weight: .light), .foregroundColor: UIColor.lightGray])
        footerStr.draw(at: CGPoint(x: pdfMargin, y: pageRect.height - pdfMargin + 10))
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

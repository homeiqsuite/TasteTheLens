import SwiftUI

struct KitchenPassProcessingView: View {
    let capturedImage: UIImage
    @Bindable var pipeline: ImageAnalysisPipeline
    var onCancel: (() -> Void)?

    @State private var ticketLines: [TicketLine] = []
    @State private var currentTypewriterText = ""
    @State private var typewriterTarget = ""
    @State private var ticketAppeared = false

    private struct TicketLine: Identifiable {
        let id = UUID()
        let text: String
        let isHighlight: Bool
        let timestamp: String?
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dark background
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Cancel button
                    HStack {
                        ProcessingCancelButton(onCancel: onCancel)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                        Spacer()

                        // 86 Order button (kitchen slang for cancel)
                        Button {
                            onCancel?()
                        } label: {
                            Text("86 ORDER")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.culinary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.culinary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }

                    // Reference photo — pinned like a ticket on a pass
                    Color.clear
                        .frame(height: geo.size.height * 0.38)
                        .overlay {
                            Image(uiImage: capturedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .rotationEffect(.degrees(-1.5))
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    Spacer(minLength: 0)

                    // Ticket — centered vertically in remaining space
                    ticketView
                        .padding(.horizontal, 24)
                        .offset(y: ticketAppeared ? 0 : 40)
                        .opacity(ticketAppeared ? 1 : 0)

                    Spacer(minLength: 0)

                    // Timeout warning
                    if let startTime = pipeline.startTime {
                        TimeoutWarningView(startTime: startTime, onCancel: onCancel)
                            .padding(.bottom, 60)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                // Complete overlay
                if pipeline.state == .complete {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: pipeline.state)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                ticketAppeared = true
            }
        }
        .onChange(of: pipeline.state) { _, newState in
            updateTicket(for: newState)
        }
    }

    // MARK: - Ticket View

    private var ticketView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ticket header
            HStack {
                Text("TASTE THE LENS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.culinary)
                Spacer()
                Text(Date(), format: .dateTime.hour().minute())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.5, green: 0.48, blue: 0.44))
            }
            .padding(.bottom, 8)

            // Dashed separator
            dashedLine

            // Ticket content lines
            ForEach(ticketLines) { line in
                ticketLineView(line)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Current typewriter line
            if !currentTypewriterText.isEmpty {
                TypewriterText(
                    fullText: typewriterTarget,
                    displayedText: currentTypewriterText
                )
                .padding(.vertical, 6)
            }

            dashedLine
                .padding(.top, 4)

            // Status indicator
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(pipeline.processingStatus)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.5, green: 0.48, blue: 0.44))
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(ticketBackground)
        .overlay(
            // Left accent bar
            HStack {
                Rectangle()
                    .fill(Theme.culinary)
                    .frame(width: 3)
                Spacer()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var ticketBackground: some View {
        ZStack {
            Color(red: 0.96, green: 0.94, blue: 0.90)
            // Subtle noise texture
            Canvas { context, size in
                for _ in 0..<80 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.black.opacity(0.03))
                    )
                }
            }
        }
    }

    private var dashedLine: some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: 1000, y: 0))
        }
        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        .foregroundStyle(Color(red: 0.8, green: 0.78, blue: 0.74))
        .frame(height: 1)
    }

    private func ticketLineView(_ line: TicketLine) -> some View {
        HStack {
            Text(line.text)
                .font(.system(size: line.isHighlight ? 18 : 14, weight: line.isHighlight ? .bold : .medium, design: .monospaced))
                .foregroundStyle(line.isHighlight ? Color(red: 0.78, green: 0.42, blue: 0.31) : Color(red: 0.2, green: 0.18, blue: 0.16))
            Spacer()
            if let ts = line.timestamp {
                Text(ts)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.6, green: 0.58, blue: 0.54))
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch pipeline.state {
        case .screeningImage: Theme.visual
        case .analyzingImage: Theme.gold
        case .generatingImage: Theme.culinary
        case .complete: .green
        default: Theme.darkTextHint
        }
    }

    // MARK: - Ticket Updates

    private func updateTicket(for state: PipelineState) {
        let timeString = Date().formatted(.dateTime.hour(.twoDigits(amPM: .abbreviated)).minute(.twoDigits))

        switch state {
        case .screeningImage:
            startTypewriter("ORDER IN", onComplete: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    ticketLines.append(TicketLine(text: "ORDER IN", isHighlight: false, timestamp: timeString))
                    currentTypewriterText = ""
                    typewriterTarget = ""
                }
            })

        case .analyzingImage:
            startTypewriter("PREP: analyzing...", onComplete: {
                // Will be updated when dish name arrives
            })

        case .generatingImage:
            let dishName = pipeline.partialDishName ?? "Special"
            withAnimation(.easeInOut(duration: 0.3)) {
                ticketLines.append(TicketLine(text: "PREP: \(dishName)", isHighlight: false, timestamp: timeString))
                currentTypewriterText = ""
                typewriterTarget = ""
            }
            startTypewriter("PLATING...", onComplete: nil)

        case .complete:
            withAnimation(.easeInOut(duration: 0.3)) {
                ticketLines.append(TicketLine(text: "PLATING...", isHighlight: false, timestamp: timeString))
                currentTypewriterText = ""
                typewriterTarget = ""
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    ticketLines.append(TicketLine(text: "FIRE!", isHighlight: true, timestamp: timeString))
                }
            }

        default:
            break
        }
    }

    private func startTypewriter(_ text: String, onComplete: (() -> Void)?) {
        typewriterTarget = text
        currentTypewriterText = ""
        var charIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if charIndex < text.count {
                charIndex += 1
                currentTypewriterText = String(text.prefix(charIndex))
            } else {
                timer.invalidate()
                onComplete?()
            }
        }
    }
}

// MARK: - Typewriter Text

private struct TypewriterText: View {
    let fullText: String
    let displayedText: String

    var body: some View {
        HStack(spacing: 0) {
            Text(displayedText)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 0.2, green: 0.18, blue: 0.16))

            // Blinking cursor
            Rectangle()
                .fill(Color(red: 0.2, green: 0.18, blue: 0.16))
                .frame(width: 8, height: 16)
                .opacity(displayedText.count < fullText.count ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: displayedText.count)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
        return renderer.image { ctx in
            UIColor.systemBrown.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 80, y: 120, width: 240, height: 360))
        }
    }()

    let pipeline: ImageAnalysisPipeline = {
        let p = ImageAnalysisPipeline()
        p.state = .analyzingImage
        p.processingStatus = "Extracting palette..."
        p.startTime = Date()
        return p
    }()

    KitchenPassProcessingView(capturedImage: sampleImage, pipeline: pipeline, onCancel: {})
}

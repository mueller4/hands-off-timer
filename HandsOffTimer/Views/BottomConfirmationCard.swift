import SwiftUI

/// Bottom confirmation used for Home delete and Run stop.
/// One card at every width: capped near 400pt and centered on the bottom edge.
/// The dimmed background is not a popover and has no arrow.
struct BottomConfirmationCard: View {
    var title: String
    var message: String
    var destructiveTitle: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        ViewThatFits(in: .vertical) {
            cardColumn
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                cardColumn
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .onAppear {
            titleFocused = true
        }
    }

    private var cardColumn: some View {
        VStack(spacing: 8) {
            actionCard
            cancelCard
        }
        .frame(maxWidth: 400)
        .padding(.horizontal, 8)
        .safeAreaPadding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, onCancel)
    }

    private var actionCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($titleFocused)

            Divider()

            Button(role: .destructive, action: onConfirm) {
                Text(destructiveTitle)
                    .font(.body)
                    .foregroundStyle(.red)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(ConfirmationRowStyle())
            .accessibilityLabel(destructiveTitle)
        }
        .background(Self.cardFill, in: Self.cardShape)
        .clipShape(Self.cardShape)
    }

    private var cancelCard: some View {
        Button(role: .cancel, action: onCancel) {
            Text("Cancel")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
        }
        .buttonStyle(ConfirmationRowStyle())
        .background(Self.cardFill, in: Self.cardShape)
        .clipShape(Self.cardShape)
    }

    private static let cardFill = Color(.secondarySystemGroupedBackground)
    private static let cardShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
}

private struct ConfirmationRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear)
    }
}

extension View {
    /// Dims this view and shows a `BottomConfirmationCard` along the bottom edge.
    func bottomConfirmation(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        destructiveTitle: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            BottomConfirmationModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                destructiveTitle: destructiveTitle,
                onConfirm: onConfirm
            )
        )
    }
}

private struct BottomConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var destructiveTitle: String
    var onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            ZStack(alignment: .bottom) {
                if isPresented {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { cancel() }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
                if isPresented {
                    BottomConfirmationCard(
                        title: title,
                        message: message,
                        destructiveTitle: destructiveTitle,
                        onConfirm: confirm,
                        onCancel: cancel
                    )
                    .transition(cardTransition)
                }
            }
            .animation(cardAnimation, value: isPresented)
            .allowsHitTesting(isPresented)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(isPresented ? AccessibilityTraits.isModal : AccessibilityTraits())
            .accessibilityHidden(!isPresented)
            .accessibilityAction(.escape) {
                if isPresented {
                    cancel()
                }
            }
        }
    }

    private var cardTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    private var cardAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.25)
    }

    private func confirm() {
        onConfirm()
        if isPresented {
            isPresented = false
        }
    }

    private func cancel() {
        isPresented = false
    }
}

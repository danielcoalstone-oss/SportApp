import SwiftUI

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(AuthorizationUX.permissionDeniedMessage)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct PermissionDeniedAlert: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
            Text(AuthorizationUX.permissionDeniedMessage)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85), in: Capsule())
        .padding(.top, 8)
        .padding(.horizontal)
    }
}

private struct PermissionDeniedAlertModifier: ViewModifier {
    @Binding var message: String?
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isVisible {
                    PermissionDeniedAlert()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: message) { newValue in
                guard newValue == AuthorizationUX.permissionDeniedMessage else {
                    return
                }

                message = nil
                withAnimation {
                    isVisible = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
    }
}

extension View {
    func permissionDeniedAlert(message: Binding<String?>) -> some View {
        modifier(PermissionDeniedAlertModifier(message: message))
    }
}

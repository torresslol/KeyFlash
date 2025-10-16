import SwiftUI
import AppKit

struct ThemeSegmentControl: View {
    @ObservedObject private var settingsManager = AppSettingsManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var segments = ["theme_light", "theme_dark"]
    
    // Get current theme index
    private var currentThemeIndex: Int {
        switch settingsManager.currentTheme {
        case .light: return 0
        case .dark: return 1
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settingsManager.setTheme(index == 0 ? .light : .dark)
                    }
                } label: {
                    Text(segments[index].localized)
                        .font(.system(size: 12, design: .rounded))
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SegmentButtonStyle(isSelected: index == currentThemeIndex))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(themeManager.accentTertiaryColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct SegmentButtonStyle: ButtonStyle {
    let isSelected: Bool
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isSelected 
                              ? themeManager.selectedTextColor
                              : themeManager.textSecondaryColor)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(themeManager.accentColor)
                            .padding(1)
                    }
                }
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

#Preview {
    VStack {
        ThemeSegmentControl()
            .frame(width: 90, height: 28)
            .padding()
    }
    .frame(width: 200, height: 100)
    .background(Color(.windowBackgroundColor))
} 

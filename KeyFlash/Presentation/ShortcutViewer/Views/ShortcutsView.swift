import SwiftUI
import Combine

/// ShortcutsView - A modern, elegant view for displaying application shortcuts
struct ShortcutsView: View {
    // MARK: - Properties
    
    @State private var searchText = ""
    @State private var selectedCategory = "shortcuts_category_all".localized
    @EnvironmentObject private var appDelegate: AppDelegate
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Application entity
    private let application: ApplicationEntity
    
    // App icon
    @State private var applicationIcon: NSImage?
    @State private var isCached = false
    
    // Animation states
    @State private var isAppearing = false
    @State private var headerOpacity = 0.0
    @State private var searchOpacity = 0.0
    @State private var categoriesOpacity = 0.0
    @State private var listOpacity = 0.0
    
    // MARK: - Initialization
    
    init(application: ApplicationEntity) {
        self.application = application
    }
    
    // MARK: - Computed Properties
    
    private var filteredShortcuts: [MenuItemEntity] {
        // First filter to show only items with shortcuts
        let shortcutsOnly = application.menuItems.filter { item in
            !item.shortcutDescription.isNilOrEmpty
        }
        
        // Then apply search filtering
        let searchFiltered = shortcutsOnly.filter { item in
            searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText)
        }
        
        // Filter by category if needed
        if selectedCategory == "shortcuts_category_all".localized {
            return searchFiltered
        } else {
            return searchFiltered.filter { $0.menuGroup == selectedCategory }
        }
    }
    
    
    /// Available categories from menu items
    private var categories: [String] {
        var menuGroups = Set<String>()
        for item in application.menuItems where !item.shortcutDescription.isNilOrEmpty {
            if !item.menuGroup.isEmpty {
                menuGroups.insert(item.menuGroup)
            }
        }
        return ["shortcuts_category_all".localized] + menuGroups.sorted()
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient based on theme
            backgroundGradient
            
            VStack(spacing: 0) {
                // New top bar with search on left, app icon on right
                topBarView
                    .padding(16) // Add horizontal padding separately for topBarView
                    .opacity(headerOpacity)
                
                Divider()
                    .background(themeManager.textPrimaryColor.opacity(0.1))
                
                // Categories (horizontal scroll) with more subtle background
                categoriesView
                    .opacity(categoriesOpacity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                
                // Shortcuts list (vertical scroll)
                shortcutsListView
                    .opacity(listOpacity)
                    .padding(.horizontal, 16)
                
                Divider()
                    .background(themeManager.textPrimaryColor.opacity(0.1))
                
                // Footer bar
                footBarView
                    .opacity(headerOpacity)
                    .padding(.horizontal, 16)
            }
            .cornerRadius(12)

        }
        .onAppear {
            loadApplicationIcon()
            checkIfCached()
            animateViewAppearance()
        }
    }
    
    // MARK: - Background Views
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(
                colors: [
                    themeManager.backgroundColor,
                    themeManager.backgroundSecondaryColor
                ]
            ),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .edgesIgnoringSafeArea(.all)
    }
    
    // MARK: - Component Views
    
    /// Top bar with search and app icon
    private var topBarView: some View {
        HStack(spacing: 16) {
            // Left: Search bar
            searchBarView
                .frame(maxWidth: .infinity)
            
            // Right: App icon
            appIconView
        }
        .padding(.vertical, 4)
    }
    
    /// App icon with app name
    private var appIconView: some View {
        HStack(alignment: .center, spacing: 6) {
            if let icon = applicationIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .shadow(color: themeManager.textPrimaryColor.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(themeManager.accentColor.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "app.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(themeManager.accentColor)
                }
            }
            
            Text(application.name.isEmpty ? "App" : application.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.textPrimaryColor.opacity(0.8))
                .lineLimit(1)
        }
    }
    
    /// Minimal search bar for filtering shortcuts - extremely simplified
    private var searchBarView: some View {
        HStack(spacing: 8) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.searchIconColor)
                .font(.system(size: 14, weight: .medium))
            
            // Text field with no background and custom placeholder
            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("shortcuts_search_placeholder".localized)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(themeManager.searchPlaceholderColor)
                }
                
                TextField("", text: $searchText)
                    .font(.system(size: 15, design: .rounded))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(themeManager.searchTextColor)
                    .accentColor(themeManager.accentColor)
                    .focusable(true)
            }
            
            // Clear button
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.searchIconColor)
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 2)
    }
    
    /// Horizontal scrolling categories view with more subtle background
    private var categoriesView: some View {
        
        DraggableScrollView(axes: .horizontal, showsIndicators: false) {
            
            HStack(spacing: 12) {
                
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(.system(size: 13, weight: selectedCategory == category ? .bold : .regular, design: .rounded))
                            .foregroundColor(selectedCategory == category
                                             ? themeManager.selectedTextColor
                                             : themeManager.textSecondaryColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category
                                          ? themeManager.accentColor
                                          : themeManager.backgroundTertiaryColor)
                                    .shadow(color: selectedCategory == category
                                            ? themeManager.accentColor.opacity(0.2)
                                            : Color.clear,
                                            radius: 2, x: 0, y: 1)
                            )
                    }
                    .buttonStyle(SpringyButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(height: 46)
        .background(
            themeManager.backgroundColor.opacity(0.1)
        )
    }
    
    /// Vertical scrolling shortcuts list
    private var shortcutsListView: some View {
        Group {
            if filteredShortcuts.isEmpty {
                emptyStateView
            } else {
                DraggableScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if selectedCategory != "shortcuts_category_all".localized {
                            // When a specific category is selected, show all shortcuts without section headers
                            ForEach(filteredShortcuts, id: \.id) { shortcut in
                                shortcutItemView(shortcut)
                                    .id(shortcut.id)
                            }
                        } else {
                            // Group shortcuts by menu group and create sections
                            let groups = Dictionary(grouping: filteredShortcuts) { $0.menuGroup }
                            let sortedKeys = groups.keys.sorted()
                            
                            ForEach(Array(sortedKeys.enumerated()), id: \.element) { index, group in
                                if let items = groups[group], !items.isEmpty {
                                    Section(
                                        header: sectionHeaderView(title: group),
                                        footer: Rectangle()
                                            .fill(.clear)
                                            .frame(height: 20)
                                    ) {
                                        ForEach(items, id: \.id) { shortcut in
                                            shortcutItemView(shortcut)
                                                .id(shortcut.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func shortcutItemView(_ shortcut: MenuItemEntity) -> some View {
        Group {
            if !shortcut.isSubmenuTitle && !shortcut.isSeparator {
                
                HStack(spacing: 16) {
                    
                    Text(shortcut.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1) // Disallow line wrapping
                        .truncationMode(.tail) // Use ellipsis for overflow
                        .foregroundColor(themeManager.textPrimaryColor)
                        .fixedSize(horizontal: true, vertical: false) // Allow horizontal expansion, fix vertical height
                        .frame(maxWidth: .infinity, alignment: .leading) // Limit width
                        .layoutPriority(0) // Lower priority, allow compression
                    
                    Spacer(minLength: 20) // Minimum spacing 20
                    
                    if let shortcutDesc = shortcut.shortcutDescription {
                        Text(formatShortcutText(shortcutDesc))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(themeManager.accentSecondaryColor)
                            )
                            .foregroundColor(themeManager.textPrimaryColor)
                            .lineLimit(1) // Limit to one line
                            .layoutPriority(1) // Higher priority, prefer showing full text
                            .frame(maxWidth: .infinity, alignment: .trailing) // Right align
                    }
                }
                .padding(.vertical, 8)
                .padding(.leading, 16)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.clear)
                )
                .cornerRadius(10)
                
            } else if shortcut.isSubmenuTitle {
                Text(shortcut.title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(themeManager.accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                
            } else if shortcut.isSeparator {
                Divider()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
            }
        }
    }
    
    private var footBarView: some View {
        HStack(spacing: 16) {
            // Left: Shortcut count
            HStack(spacing: 6) {
                Text(String(format: "shortcuts_total_count".localized, filteredShortcuts.count))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(themeManager.textSecondaryColor)
            }
            
            Spacer()
            
            // Center-Right: Theme Segment Control
            ThemeSegmentControl()
                .frame(width: 90, height: 28)
                .padding(.trailing, 8)
            
            // Right: Coffee Cup button - opens Buy Me a Coffee page
            Button {
                // Open Buy Me a Coffee page
                if let url = URL(string: "https://buymeacoffee.com/torreslol") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.textPrimaryColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(themeManager.accentTertiaryColor)
                    )
            }
            .buttonStyle(SpringyButtonStyle())
            .help("buy_me_coffee".localized)
        }
        .padding(.vertical, 12)
        .background(
            themeManager.backgroundColor.opacity(0.1)
        )
    }
    
    /// Empty state view shown when no shortcuts match the filter
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "keyboard")
                .font(.system(size: 42))
                .foregroundColor(themeManager.textPrimaryColor.opacity(0.3))
            
            Text("shortcuts_no_results".localized)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(themeManager.textSecondaryColor)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Text("shortcuts_clear_search".localized)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(themeManager.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.accentColor, lineWidth: 1)
                        )
                }
                .buttonStyle(SpringyButtonStyle())
            }
            
            Spacer()
        }
    }
    
    /// Section header view for shortcut groups with more subtle styling
    private func sectionHeaderView(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.accentColor)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)  // Keep title vertically centered
        .background(
            themeManager.backgroundColor.opacity(0.4)
        )
    }
    
    // MARK: - Methods
    
    /// Animate the appearance of all elements in sequence
    private func animateViewAppearance() {
        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
            headerOpacity = 1
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            searchOpacity = 1
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            categoriesOpacity = 1
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
            listOpacity = 1
        }
    }
    
    /// Load the application icon
    private func loadApplicationIcon() {
        let bundleID = application.bundleIdentifier
        if !bundleID.isEmpty {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                applicationIcon = NSWorkspace.shared.icon(forFile: appURL.path)
            } else {
                applicationIcon = application.icon
            }
        } else {
            applicationIcon = application.icon
        }
    }
    
    /// Check if shortcuts are cached
    private func checkIfCached() {
        isCached = application.lastRefreshTime.timeIntervalSince1970 > 0
    }
    
    /// Refresh shortcuts
    private func refreshShortcuts() {
        appDelegate.extractCurrentAppShortcuts()
    }
    
    /// Format shortcut text to add more spacing between keys
    private func formatShortcutText(_ text: String) -> String {
        var result = ""
        var skipNextChar = false
        
        for (index, char) in text.enumerated() {
            if skipNextChar {
                skipNextChar = false
                continue
            }
            
            result.append(char)
            
            if index < text.count - 1 {
                let nextChar = text[text.index(text.startIndex, offsetBy: index + 1)]
                if char == "F" && nextChar.isNumber {
                    result.append(nextChar)
                    skipNextChar = true
                } else {
                    result.append(" ")
                }
            }
        }
        
        return result
    }
}


// MARK: - Helper Views and Extensions

/// BlurView for creating frosted glass effect
struct BlurView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

/// Custom button style with spring effect
struct SpringyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}


// Add extension to check if a string is nil or empty
extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

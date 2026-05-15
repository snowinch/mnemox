# SwiftUI macOS Reference — Complete Guide for AI Agents

> **MANDATORY**: All AI agents working on Mnemox UI MUST follow these patterns.
> DO NOT deviate from these examples unless explicitly authorized.
> Last updated: May 2026
> 
> **Official Documentation**: https://developer.apple.com/documentation/swiftui

---

## Table of Contents

1. [Text Input](#text-input)
2. [Layout Containers](#layout-containers)
3. [Controls](#controls)
4. [Lists and Collections](#lists-and-collections)
5. [Navigation](#navigation)
6. [Modifiers](#modifiers)
7. [State Management](#state-management)
8. [Colors and Styling](#colors-and-styling)
9. [File Pickers](#file-pickers)
10. [Keyboard Shortcuts](#keyboard-shortcuts)

---

## Text Input

### TextEditor

**Documentation**: https://developer.apple.com/documentation/swiftui/texteditor

Multi-line editable text view. ALWAYS use this for long-form text input.

#### Basic Pattern (ALWAYS use as starting point)

```swift
struct WorkingTextEditorExample: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 14))
            .frame(minHeight: 100)
            .focused($isFocused)
            .scrollContentBackground(.hidden)  // removes white background
            .background(Color(NSColor.textBackgroundColor))
            .onAppear {
                // CRITICAL: Small delay fixes focus issues on macOS
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
    }
}
```

#### TextEditor with Placeholder

```swift
struct TextEditorWithPlaceholder: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 15))
            .frame(minHeight: 200)
            .focused($isFocused)
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("What do you want to build?")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)  // CRITICAL: allows click-through
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
    }
}
```

#### TextEditor with Character Limit

```swift
extension View {
    func characterLimit(_ text: Binding<String>, to limit: Int) -> some View {
        onChange(of: text.wrappedValue) {
            text.wrappedValue = String(text.wrappedValue.prefix(limit))
        }
    }
}

struct TextEditorWithLimit: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool
    let characterLimit = 200
    
    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Float(text.count), total: Float(characterLimit))
                .progressViewStyle(.linear)
            
            TextEditor(text: $text)
                .font(.system(size: 15))
                .frame(minHeight: 150)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .characterLimit($text, to: characterLimit)
            
            HStack {
                Spacer()
                Text("\(text.count) / \(characterLimit)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}
```

### TextField

**Documentation**: https://developer.apple.com/documentation/swiftui/textfield

Single-line text input.

```swift
@State private var username = ""

TextField("Username", text: $username)
    .textFieldStyle(.roundedBorder)
    .frame(width: 200)
```

### SecureField

**Documentation**: https://developer.apple.com/documentation/swiftui/securefield

Password input field.

```swift
@State private var password = ""

SecureField("Password", text: $password)
    .textFieldStyle(.roundedBorder)
    .frame(width: 200)
```

---

## Layout Containers

### VStack

**Documentation**: https://developer.apple.com/documentation/swiftui/vstack

Vertical stack of views.

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("Title")
    Text("Subtitle")
}
```

### HStack

**Documentation**: https://developer.apple.com/documentation/swiftui/hstack

Horizontal stack of views.

```swift
HStack(alignment: .center, spacing: 12) {
    Image(systemName: "person")
    Text("Username")
}
```

### ZStack

**Documentation**: https://developer.apple.com/documentation/swiftui/zstack

Overlapping stack of views.

```swift
ZStack(alignment: .bottomTrailing) {
    Color.blue
    Text("Overlay")
        .padding()
}
```

### Group

**Documentation**: https://developer.apple.com/documentation/swiftui/group

Transparent container for conditional views.

```swift
Group {
    if condition {
        ViewA()
    } else {
        ViewB()
    }
}
.font(.headline)  // applies to all views in group
```

### ScrollView

**Documentation**: https://developer.apple.com/documentation/swiftui/scrollview

Scrollable content container.

```swift
ScrollView {
    VStack(spacing: 20) {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
    .padding()
}
```

### GeometryReader

**Documentation**: https://developer.apple.com/documentation/swiftui/geometryreader

Access parent size and coordinates.

```swift
GeometryReader { geometry in
    Text("Width: \(geometry.size.width)")
        .frame(width: geometry.size.width * 0.5)
}
```

---

## Controls

### Button

**Documentation**: https://developer.apple.com/documentation/swiftui/button

Interactive button.

```swift
// Primary button
Button("Send") {
    action()
}
.buttonStyle(.borderedProminent)
.controlSize(.large)

// Secondary button
Button("Cancel") {
    action()
}
.buttonStyle(.bordered)

// Destructive button
Button("Delete", role: .destructive) {
    action()
}
.buttonStyle(.bordered)

// Plain button (no styling)
Button(action: action) {
    Label("New Agent", systemImage: "bolt.fill")
}
.buttonStyle(.plain)
```

### Toggle

**Documentation**: https://developer.apple.com/documentation/swiftui/toggle

On/off switch.

```swift
@State private var isEnabled = false

Toggle("Enable feature", isOn: $isEnabled)
    .toggleStyle(.switch)
```

### Picker

**Documentation**: https://developer.apple.com/documentation/swiftui/picker

Selection from multiple options.

```swift
@State private var selected = "Option 1"
let options = ["Option 1", "Option 2", "Option 3"]

// Menu style (dropdown)
Picker("Select", selection: $selected) {
    ForEach(options, id: \.self) { option in
        Text(option).tag(option)
    }
}
.pickerStyle(.menu)

// Segmented style
Picker("Select", selection: $selected) {
    ForEach(options, id: \.self) { option in
        Text(option).tag(option)
    }
}
.pickerStyle(.segmented)
```

### Slider

**Documentation**: https://developer.apple.com/documentation/swiftui/slider

Value selection from a range.

```swift
@State private var value: Double = 50

Slider(value: $value, in: 0...100, step: 1) {
    Text("Volume")
} minimumValueLabel: {
    Text("0")
} maximumValueLabel: {
    Text("100")
}
```

### Stepper

**Documentation**: https://developer.apple.com/documentation/swiftui/stepper

Increment/decrement control.

```swift
@State private var count = 0

Stepper("Count: \(count)", value: $count, in: 0...10)
```

### ProgressView

**Documentation**: https://developer.apple.com/documentation/swiftui/progressview

Progress indicator.

```swift
// Indeterminate
ProgressView()

// Determinate
ProgressView(value: 0.6)

// With label
ProgressView("Loading...", value: 0.4, total: 1.0)
```

---

## Lists and Collections

### List

**Documentation**: https://developer.apple.com/documentation/swiftui/list

Scrollable list of rows.

```swift
struct Item: Identifiable {
    let id = UUID()
    let name: String
}

@State private var items: [Item] = []
@State private var selected: Item?

List(items, selection: $selected) { item in
    Text(item.name)
}
.listStyle(.sidebar)  // macOS sidebar style
```

### List with Sections

```swift
List {
    Section("Pinned") {
        ForEach(pinnedItems) { item in
            ItemRow(item: item)
        }
    }
    
    Section("Recent") {
        ForEach(recentItems) { item in
            ItemRow(item: item)
        }
    }
}
.listStyle(.sidebar)
```

### ForEach

**Documentation**: https://developer.apple.com/documentation/swiftui/foreach

Loop over collection.

```swift
ForEach(items) { item in
    Text(item.name)
}

// With index
ForEach(Array(items.enumerated()), id: \.1.id) { index, item in
    HStack {
        Text("\(index + 1)")
        Text(item.name)
    }
}
```

### LazyVStack / LazyHStack

**Documentation**: https://developer.apple.com/documentation/swiftui/lazyvstack

Lazy-loading stacks (only render visible items).

```swift
ScrollView {
    LazyVStack(spacing: 8) {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}
```

---

## Navigation

### NavigationSplitView

**Documentation**: https://developer.apple.com/documentation/swiftui/navigationsplitview

Two or three column navigation (perfect for macOS apps like Mnemox).

```swift
struct ContentView: View {
    @State private var selectedProject: LocalProject?
    @State private var selectedAgent: AgentSession?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar (260pt fixed)
            ProjectSidebar(selected: $selectedAgent)
                .frame(minWidth: 260, idealWidth: 260, maxWidth: 260)
        } content: {
            // Center panel (flexible)
            if let agent = selectedAgent {
                ConversationPanel(agent: agent)
            } else {
                EmptyStateView()
            }
        } detail: {
            // Right panel (420pt fixed, optional)
            if hasChangesToShow {
                DiffView()
                    .frame(minWidth: 420, idealWidth: 420, maxWidth: 420)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### NavigationStack

**Documentation**: https://developer.apple.com/documentation/swiftui/navigationstack

Stack-based navigation.

```swift
@State private var path: [Destination] = []

NavigationStack(path: $path) {
    RootView()
        .navigationDestination(for: Destination.self) { destination in
            DetailView(destination: destination)
        }
}
```

### NavigationLink

**Documentation**: https://developer.apple.com/documentation/swiftui/navigationlink

Link to navigate to another view.

```swift
NavigationLink(destination: DetailView()) {
    Text("Go to Detail")
}
```

---

## Modifiers

### Frame

**Documentation**: https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:)

Set view size.

```swift
Text("Hello")
    .frame(width: 200, height: 100)
    .frame(maxWidth: .infinity)  // expand to fill available width
    .frame(minHeight: 50, maxHeight: 200)
```

### Padding

**Documentation**: https://developer.apple.com/documentation/swiftui/view/padding(_:_:)

Add spacing around view.

```swift
Text("Padded")
    .padding()  // 16pt all sides
    .padding(.horizontal, 24)
    .padding(.top, 8)
```

### Background

**Documentation**: https://developer.apple.com/documentation/swiftui/view/background(alignment:content:)

Set background.

```swift
Text("Hello")
    .background(Color.blue)
    .background(Color(NSColor.textBackgroundColor))
```

### Foreground Style

**Documentation**: https://developer.apple.com/documentation/swiftui/view/foregroundstyle(_:)

Set text/icon color.

```swift
Text("Hello")
    .foregroundStyle(.primary)
    .foregroundStyle(.secondary)
    .foregroundStyle(Color.blue)
```

### Corner Radius

**Documentation**: https://developer.apple.com/documentation/swiftui/view/cornerradius(_:antialiased:)

Round corners.

```swift
Rectangle()
    .fill(Color.blue)
    .cornerRadius(8)
```

### Overlay

**Documentation**: https://developer.apple.com/documentation/swiftui/view/overlay(alignment:content:)

Layer view on top.

```swift
Rectangle()
    .fill(Color.blue)
    .overlay(
        Text("Overlay")
    )
    .overlay(alignment: .topTrailing) {
        Image(systemName: "xmark")
            .padding(8)
    }
```

### Shadow

**Documentation**: https://developer.apple.com/documentation/swiftui/view/shadow(color:radius:x:y:)

Add drop shadow.

```swift
Text("Shadow")
    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
```

### Disabled

**Documentation**: https://developer.apple.com/documentation/swiftui/view/disabled(_:)

Disable interaction.

```swift
Button("Submit") {
    submit()
}
.disabled(text.isEmpty)
```

---

## State Management

### @State

**Documentation**: https://developer.apple.com/documentation/swiftui/state

View-local state.

```swift
@State private var count = 0

Button("Increment") {
    count += 1
}
```

### @Binding

**Documentation**: https://developer.apple.com/documentation/swiftui/binding

Two-way binding to parent state.

```swift
struct ChildView: View {
    @Binding var text: String
    
    var body: some View {
        TextField("Enter text", text: $text)
    }
}

struct ParentView: View {
    @State private var text = ""
    
    var body: some View {
        ChildView(text: $text)
    }
}
```

### @Observable

**Documentation**: https://developer.apple.com/documentation/observation/observable

Observable reference type (Swift 5.9+). ALWAYS use instead of ObservableObject.

```swift
import Observation

@Observable
class SidebarViewModel {
    var projects: [LocalProject] = []
    var selectedAgent: AgentSession?
    var isLoading: Bool = false
    
    func loadProjects() async {
        isLoading = true
        // async work
        isLoading = false
    }
}

// In view:
struct SidebarView: View {
    @State private var viewModel = SidebarViewModel()  // NOT @StateObject
    
    var body: some View {
        List(viewModel.projects) { project in
            Text(project.name)
        }
    }
}
```

### @FocusState

**Documentation**: https://developer.apple.com/documentation/swiftui/focusstate

Manage focus state.

```swift
@FocusState private var isFocused: Bool

TextField("Name", text: $name)
    .focused($isFocused)
    .onAppear {
        isFocused = true
    }
```

### @Environment

**Documentation**: https://developer.apple.com/documentation/swiftui/environment

Access environment values.

```swift
@Environment(\.dismiss) var dismiss
@Environment(\.colorScheme) var colorScheme

Button("Close") {
    dismiss()
}
```

---

## Colors and Styling

### Semantic Colors (macOS)

**Documentation**: https://developer.apple.com/documentation/appkit/nscolor

ALWAYS use semantic colors. NEVER hardcode hex values.

```swift
// Background colors
Color(NSColor.windowBackgroundColor)      // window background
Color(NSColor.controlBackgroundColor)     // control backgrounds
Color(NSColor.textBackgroundColor)        // text field backgrounds
Color(NSColor.separatorColor)             // divider lines

// Text colors
Color(NSColor.labelColor)                 // primary text
Color(NSColor.secondaryLabelColor)        // secondary text
Color(NSColor.tertiaryLabelColor)         // muted text

// System colors
Color.accentColor                          // user's accent color
Color.primary                              // adapts to light/dark mode
Color.secondary                            // muted version of primary
```

### Font

**Documentation**: https://developer.apple.com/documentation/swiftui/font

Text styling.

```swift
Text("Hello")
    .font(.largeTitle)
    .font(.headline)
    .font(.body)
    .font(.caption)
    .font(.system(size: 14))
    .font(.system(size: 16, weight: .bold, design: .monospaced))
```

### Button Styles

**Documentation**: https://developer.apple.com/documentation/swiftui/buttonstyle

```swift
.buttonStyle(.automatic)        // default
.buttonStyle(.bordered)         // bordered button
.buttonStyle(.borderedProminent) // primary action
.buttonStyle(.plain)            // no styling
.buttonStyle(.link)             // link appearance
```

---

## File Pickers

### NSOpenPanel (Folder Picker)

**Documentation**: https://developer.apple.com/documentation/appkit/nsopenpanel

Open folder/file picker.

```swift
func openFolderPicker() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    panel.message = "Select your project repository"
    
    panel.begin { response in
        if response == .OK, let url = panel.url {
            handleSelectedFolder(url)
        }
    }
}
```

---

## Keyboard Shortcuts

**Documentation**: https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:)

Add keyboard shortcuts.

```swift
Button("New Agent") {
    action()
}
.keyboardShortcut("n", modifiers: .command)  // ⌘N

Button("Send") {
    send()
}
.keyboardShortcut(.return, modifiers: .command)  // ⌘↵

// Common shortcuts
.keyboardShortcut("w", modifiers: .command)      // ⌘W
.keyboardShortcut(",", modifiers: .command)      // ⌘,
.keyboardShortcut(.escape)                        // Esc
```

---

## CRITICAL RULES

### ✅ ALWAYS DO THIS

1. **Use @FocusState for TextEditor** — Required for reliable keyboard input on macOS
2. **Delay focus by 0.1s in onAppear** — `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)`
3. **Use semantic colors** — `Color(NSColor.windowBackgroundColor)`, never hex
4. **Set explicit frames** — TextEditor and many views need `.frame()` to render
5. **Use @Observable for view models** — Not ObservableObject (Swift 5.9+)
6. **Hide TextEditor scroll background** — `.scrollContentBackground(.hidden)`

### ❌ NEVER DO THIS

1. **NEVER use NSViewRepresentable** — Unless absolutely necessary
2. **NEVER skip @FocusState on TextEditor** — It won't accept input
3. **NEVER hardcode colors** — Use semantic colors from NSColor
4. **NEVER bind TextEditor to .constant()** — Makes it read-only but keyboard still shows
5. **NEVER use ObservableObject** — Use @Observable instead (Swift 5.9+)

---

## Common macOS-Specific Issues

### Issue: TextEditor not accepting keyboard input
**Solution**: Use @FocusState with delayed focus assignment.

### Issue: White background in dark mode
**Solution**: `.scrollContentBackground(.hidden)` + `.background(Color(NSColor.textBackgroundColor))`

### Issue: Placeholder blocks input
**Solution**: Add `.allowsHitTesting(false)` to overlay.

### Issue: View doesn't appear
**Solution**: Set explicit `.frame(minHeight: 100)` or fixed size.

---

## Testing Checklist

Before submitting UI code:

- [ ] TextEditor accepts keyboard input when clicked
- [ ] Focus works on window activation
- [ ] Dark mode looks correct (no white backgrounds)
- [ ] Keyboard shortcuts work
- [ ] Placeholder doesn't block input
- [ ] Layout doesn't break on resize
- [ ] `swift build` completes with zero errors
- [ ] All backend tests still pass

---

## Additional Resources

- **SwiftUI Documentation**: https://developer.apple.com/documentation/swiftui
- **SwiftUI Tutorials**: https://developer.apple.com/tutorials/swiftui
- **WWDC Videos**: https://developer.apple.com/videos/swiftui
- **Hacking with Swift**: https://www.hackingwithswift.com/quick-start/swiftui

---

*This file is the source of truth for Mnemox UI development.*
*All AI agents must read and follow these patterns.*
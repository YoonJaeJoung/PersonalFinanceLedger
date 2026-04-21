import SwiftUI

// MARK: - Focused value for Import/Export
struct ImportExportActions {
    var importCSV: () -> Void
    var exportCSV: () -> Void
    var exportCategories: () -> Void
    var importCategories: () -> Void
}

// MARK: - Focused value for Maintenance actions
struct MaintenanceActions {
    var clearAndRestoreDefaults: () -> Void
}

private struct ImportExportActionsKey: FocusedValueKey {
    typealias Value = ImportExportActions
}

private struct MaintenanceActionsKey: FocusedValueKey {
    typealias Value = MaintenanceActions
}

extension FocusedValues {
    var importExportActions: ImportExportActions? {
        get { self[ImportExportActionsKey.self] }
        set { self[ImportExportActionsKey.self] = newValue }
    }
    var maintenanceActions: MaintenanceActions? {
        get { self[MaintenanceActionsKey.self] }
        set { self[MaintenanceActionsKey.self] = newValue }
    }
}

// MARK: - Environment keys for sheet toggles
private struct ShowAddCategoryBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}
private struct ShowEditCategoriesBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}
private struct ShowAddAccountBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}
private struct ShowEditAccountsBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

extension EnvironmentValues {
    var showAddCategoryBinding: Binding<Bool>? {
        get { self[ShowAddCategoryBindingKey.self] }
        set { self[ShowAddCategoryBindingKey.self] = newValue }
    }
    var showEditCategoriesBinding: Binding<Bool>? {
        get { self[ShowEditCategoriesBindingKey.self] }
        set { self[ShowEditCategoriesBindingKey.self] = newValue }
    }
    var showAddAccountBinding: Binding<Bool>? {
        get { self[ShowAddAccountBindingKey.self] }
        set { self[ShowAddAccountBindingKey.self] = newValue }
    }
    var showEditAccountsBinding: Binding<Bool>? {
        get { self[ShowEditAccountsBindingKey.self] }
        set { self[ShowEditAccountsBindingKey.self] = newValue }
    }
}

#if os(macOS)
// MARK: - App menu commands
struct AppMenuCommands: Commands {
    @FocusedValue(\.importExportActions) private var importExportActions
    @FocusedValue(\.maintenanceActions) private var maintenanceActions

    @Environment(\.showAddCategoryBinding) private var showAddCategoryBinding
    @Environment(\.showEditCategoriesBinding) private var showEditCategoriesBinding
    @Environment(\.showAddAccountBinding) private var showAddAccountBinding
    @Environment(\.showEditAccountsBinding) private var showEditAccountsBinding

    var body: some Commands {
        // File > Import/Export
        CommandGroup(replacing: .importExport) {
            Button("Import CSV Files…") {
                importExportActions?.importCSV()
            }
            .keyboardShortcut("i", modifiers: [.command])
            .disabled(importExportActions == nil)

            Button("Export CSV Files…") {
                importExportActions?.exportCSV()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(importExportActions == nil)
            
            Button("Export Categories as CSV…") {
                importExportActions?.exportCategories()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .disabled(importExportActions == nil)
            
            Button("Import Categories from CSV…") {
                importExportActions?.importCategories()
            }
            .disabled(importExportActions == nil)
        }

        // Edit > Category / Account submenus
        CommandGroup(after: .pasteboard) {
            Menu("Category") {
                Button("Add Category…") {
                    showAddCategoryBinding?.wrappedValue = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Edit Category…") {
                    showEditCategoriesBinding?.wrappedValue = true
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }

            Menu("Account") {
                Button("Add Account…") {
                    showAddAccountBinding?.wrappedValue = true
                }
                Button("Edit Accounts…") {
                    showEditAccountsBinding?.wrappedValue = true
                }
            }
        }

        CommandGroup(after: .appInfo) {
            Button("Clear Data and Restore Defaults…") {
                maintenanceActions?.clearAndRestoreDefaults()
            }
            .keyboardShortcut(.init("r"), modifiers: [.command, .option, .shift])
            .disabled(maintenanceActions == nil)
        }
    }
}
#endif

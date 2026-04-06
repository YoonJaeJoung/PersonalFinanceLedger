import Foundation
import SwiftData

// MARK: - Schema V1 (Original release — Transaction only)
// This matches the on-disk store created by the original app which used:
//   .modelContainer(for: Transaction.self)

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Transaction.self]
    }
}

// MARK: - Schema V2 (Added CategoryItem & AccountItem)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Transaction.self, CategoryItem.self, AccountItem.self]
    }
}

// MARK: - Migration Plan

/// Tells SwiftData how to migrate between schema versions.
/// Without this, SwiftData's default behavior on schema mismatch is to
/// delete and recreate the store — causing complete data loss.
enum LedgerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // Lightweight migration: only adds new tables (CategoryItem, AccountItem).
    // No data transformation needed — SwiftData creates the tables automatically.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}

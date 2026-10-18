//
//  Controller.swift
//  Toolbox
//
//  Created by Christian Nagel on 04.03.23.
//

import Foundation
import CoreData
import os

class SBDataController: ObservableObject {
    /// The one controller the app uses.
    static let shared = SBDataController()

    /// One container for the whole app: every NSPersistentContainer loads its own copy of the store,
    /// so all controllers (including ones created with `SBDataController()`) share this one.
    private static let sharedContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ScannedBarcodes")
        container.loadPersistentStores { _, error in
            if let error = error {
                SBDataController.logger.error("Failed to load the scanned barcodes store: \(error.localizedDescription, privacy: .public)")
            }
        }
        return container
    }()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Toolbox", category: "ScannedBarcodes")

    // Responsible for preparing a model
    var container: NSPersistentContainer { Self.sharedContainer }

    init() {}

    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Don't crash the app: log the error and drop the changes that could not be saved.
            Self.logger.error("Failed to save scanned barcodes: \(error.localizedDescription, privacy: .public)")
            context.rollback()
        }
    }

    func addBarcode(content: String, type: String, context: NSManagedObjectContext) {
        let barcode = ScannedBarcode(context: context)
        barcode.id = UUID()
        barcode.date = Date()
        barcode.content = content
        barcode.type = type

        save(context: context)
    }

    func resetBarcodes(context: NSManagedObjectContext) {
        // Create a fetch request for the entity you want to delete
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ScannedBarcode")

        // Create a batch delete request that reports the IDs of the deleted objects
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs

        do {
            // The batch delete works directly on the store, bypassing the context,
            // so tell the contexts which objects are gone; otherwise @FetchRequest keeps showing them.
            let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
            let deletedIDs = result?.result as? [NSManagedObjectID] ?? []
            var contexts = [context]
            if container.viewContext !== context {
                contexts.append(container.viewContext)
            }
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: deletedIDs], into: contexts)
        } catch {
            Self.logger.error("Failed to delete scanned barcodes: \(error.localizedDescription, privacy: .public)")
        }
    }
}

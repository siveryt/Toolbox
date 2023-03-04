//
//  Controller.swift
//  Toolbox
//
//  Created by Christian Nagel on 04.03.23.
//

import Foundation
import CoreData

class SBDataController: ObservableObject {
    // Responsible for preparing a model
    let container = NSPersistentContainer(name: "ScannedBarcodes")
    
    init() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Failed to load data in DataController \(error.localizedDescription)")
            }
        }
    }
    
    func save(context: NSManagedObjectContext) {
        do {
            try context.save()
            print("Data saved successfully. WUHU!!!")
        } catch {
            // Handle errors in our database
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            
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

        // Create a batch delete request for the fetch request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        // Execute the batch delete request
        do {
            try context.execute(batchDeleteRequest)
            try context.save() // save the context to commit the changes
        } catch let error {
            print("Error deleting data: \(error)")
        }
    }
    
}

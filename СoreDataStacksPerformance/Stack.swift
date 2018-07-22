//
//  Stack.swift
//  СoreDataStacksPerformance
//
//  Created by Dmitrii on 21/07/2018.
//  Copyright © 2018 DI. All rights reserved.
//

import Foundation
import CoreData


protocol CoreDataStackProtocol {
    func construct(completion: @escaping () -> ())
    func mainContext() -> NSManagedObjectContext
    func workerContext() -> NSManagedObjectContext
    func saveContext(context: NSManagedObjectContext)
    func asyncWorkerContext(block: @escaping (NSManagedObjectContext?)->())
}


extension CoreDataStackProtocol {

    func construct(completion: @escaping () -> ()) {
        completion()
    }

    func saveContext(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    func createPSC() -> NSPersistentStoreCoordinator {
        let docDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first!
        let urlString = (docDir as NSString).appendingPathComponent("SessionsDB.sqlite")
        let storeURL = URL(fileURLWithPath: urlString)
        let bundles = [Bundle(for: Session.self)]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles) else {
            fatalError("model not found")
        }
        let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
        try! psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        return psc
    }

    func asyncWorkerContext(block: @escaping (NSManagedObjectContext?)->()) {
        block(workerContext())
    }
}


// ----------------------------------------------------------------------------
// MARK: - Nested (PSC -> Main -> Worker)
// ----------------------------------------------------------------------------
class Simple: CoreDataStackProtocol {

    private var mContext: NSManagedObjectContext!

    init() {
        let psc = createPSC()
        mContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mContext.persistentStoreCoordinator = psc
    }

    func mainContext() -> NSManagedObjectContext {
        return mContext
    }

    func workerContext() -> NSManagedObjectContext {
        return mContext
    }

    func saveContext(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}


// ----------------------------------------------------------------------------
// MARK: - Persistent Container
// ----------------------------------------------------------------------------
class PersistentContainer: CoreDataStackProtocol {

    private let container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CoreDataStacks")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    func mainContext() -> NSManagedObjectContext {
        return container.viewContext
    }

    func workerContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
}


// ----------------------------------------------------------------------------
// MARK: - Persistent Container with Merging
// ----------------------------------------------------------------------------
class PersistentContainerMerging: CoreDataStackProtocol {

    private let container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CoreDataStacks")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            container.viewContext.automaticallyMergesChangesFromParent = true
        })
        return container
    }()

    func mainContext() -> NSManagedObjectContext {
        return container.viewContext
    }

    func workerContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        return context
    }
}


// ----------------------------------------------------------------------------
// MARK: - Nested (PSC -> Private -> Main -> Worker)
// ----------------------------------------------------------------------------
class NestedStack: CoreDataStackProtocol {

    private var mContext: NSManagedObjectContext!
    private var pContext: NSManagedObjectContext!

    init() {
        let psc = createPSC()
        pContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        pContext.persistentStoreCoordinator = psc
        mContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mContext.parent = pContext
    }

    func mainContext() -> NSManagedObjectContext {
        return mContext
    }

    func workerContext() -> NSManagedObjectContext {
        let newWorker = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        newWorker.parent = mContext
        return newWorker
    }
}


// ----------------------------------------------------------------------------
// MARK: - Nested with Propagation (PSC -> Private -> Main -> Worker)
// ----------------------------------------------------------------------------
class NestedStackProp: CoreDataStackProtocol {

    private var mContext: NSManagedObjectContext!
    private var pContext: NSManagedObjectContext!

    init() {
        let psc = createPSC()
        pContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        pContext.persistentStoreCoordinator = psc
        mContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mContext.parent = pContext
    }

    func mainContext() -> NSManagedObjectContext {
        return mContext
    }

    func workerContext() -> NSManagedObjectContext {
        let newWorker = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        newWorker.parent = mContext
        return newWorker
    }

    func saveContext(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
                if let parent = context.parent {
                    parent.perform {
                        self.saveContext(context: parent)
                    }
                }
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}


// ----------------------------------------------------------------------------
// MARK: - Shared PSC
// ----------------------------------------------------------------------------
class SharedPSC: CoreDataStackProtocol {

    private var mContext: NSManagedObjectContext!
    private var wContext: NSManagedObjectContext!

    init() {
        let psc = createPSC()
        mContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mContext.persistentStoreCoordinator = psc
        wContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        wContext.persistentStoreCoordinator = psc
    }

    func mainContext() -> NSManagedObjectContext {
        return mContext
    }

    func workerContext() -> NSManagedObjectContext {
        return wContext
    }
}


// ----------------------------------------------------------------------------
// MARK: - Shared PSC With Merging
// ----------------------------------------------------------------------------
class SharedPSCMerging: CoreDataStackProtocol {

    private var mContext: NSManagedObjectContext!
    private var wContext: NSManagedObjectContext!

    init() {
        let psc = createPSC()
        mContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mContext.persistentStoreCoordinator = psc
        wContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        wContext.persistentStoreCoordinator = psc

        subscribeToNotifications()
    }

    func mainContext() -> NSManagedObjectContext {
        return mContext
    }

    func workerContext() -> NSManagedObjectContext {
        return wContext
    }

    private func subscribeToNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainContextDidSave(_:)),
            name: Notification.Name.NSManagedObjectContextDidSave,
            object: mContext
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(workerContextDidSave(_:)),
            name: Notification.Name.NSManagedObjectContextDidSave,
            object: wContext
        )
    }

    @objc private func mainContextDidSave(_ notification: Notification) {
        wContext.performMergeChangesFromContextDidSaveNotification(notification: notification)
    }

    @objc private func workerContextDidSave(_ notification: Notification) {
        mContext.performMergeChangesFromContextDidSaveNotification(notification: notification)
    }
}


// ----------------------------------------------------------------------------
// MARK: - Shared Store
// ----------------------------------------------------------------------------
class SharedStore: CoreDataStackProtocol {

    private var mContext: NSManagedObjectContext!
    private var wContext: NSManagedObjectContext!

    init() {
        let pscMain = createPSC()
        let pscWorker = createPSC()
        mContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mContext.persistentStoreCoordinator = pscMain
        wContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        wContext.persistentStoreCoordinator = pscWorker
    }

    func mainContext() -> NSManagedObjectContext {
        return mContext
    }

    func workerContext() -> NSManagedObjectContext {
        return wContext
    }
}


extension NSManagedObjectContext {
    public func performMergeChangesFromContextDidSaveNotification(notification: Notification) {
        perform {
            self.mergeChanges(fromContextDidSave: notification)
        }
    }
}

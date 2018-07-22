//
//  ViewController.swift
//  СoreDataStacksPerformance
//
//  Created by Dmitrii on 21/07/2018.
//  Copyright © 2018 DI. All rights reserved.
//

import UIKit
import CoreData


class ViewController: UIViewController {

    // MARK: Properties
    var stack: CoreDataStackProtocol?

    // MARK: Actions

    @IBAction func buttonFetchPressed() {
        fetch()
    }

    @IBAction func buttonFetchWithPopulationPressed() {
        populateDB(startIndex: 10000, amount: 10000)
        fetch()
    }

    @IBAction func buttonPopulatePressed() {
        populateDB(startIndex: 0, amount: 10000)
    }


    // MARK: Private

    private func populateDB(startIndex: Int, amount: Int) {
        guard let stack = stack else { return }

        let endIndex = startIndex + amount

        stack.asyncWorkerContext { (context) in
            guard let workerContext = context else { return }
            workerContext.perform {
                for i in startIndex..<endIndex {
                    let start = Date(timeIntervalSinceNow: TimeInterval(i * 10))
                    let end = Date(timeInterval: 10.0, since: start)
                    let even: Bool = i % 2 == 0
                    let valid = even ? true : false
                    let session =  Session(context: workerContext)
                    session.setValuesForKeys([
                        "start" : start,
                        "end" : end,
                        "valid" : valid,
                        "number" : Int32(i)
                        ]
                    )
                    stack.saveContext(context: workerContext)
                }
                //NSLog("Population finished")
            }
        }
    }

    private func fetch() {
        guard let stack = stack else { return }

        let context = stack.mainContext()

        let counter = 0
        let batchSize = 1
        //let amount = 10000

        fetchSessions(context: context, startIndex: counter, amount: batchSize)
        //fetchSessionsIterative(context: context, startIndex: counter, amount: amount)
    }

    private func fetchSessions(context: NSManagedObjectContext, startIndex: Int, amount: Int)  {
        DispatchQueue.main.async {
            var sessions = [Session]()
            context.performAndWait {
                let request: NSFetchRequest<NSFetchRequestResult> = Session.fetchRequest()
                let descriptor = NSSortDescriptor(key: "number", ascending: true)
                let predicate = NSPredicate(format: "number >= %d AND number <%d", startIndex, startIndex + amount)
                request.sortDescriptors = [descriptor]
                request.predicate = predicate
                guard let result = try? context.fetch(request) as? [Session] else { return }
                if result != nil {
                    sessions = result!
                }
            }
            //NSLog("count: \(sessions.count) firts: \(sessions.first?.number)")
            if !sessions.isEmpty && startIndex < 10000 {
                self.fetchSessions(context: context, startIndex: startIndex+amount, amount: amount)
            }
        }
    }
/*
    private func fetchSessionsIterative(context: NSManagedObjectContext, startIndex: Int, amount: Int) {
        let batch = 1
        var start = startIndex
        let endIndex = startIndex + amount
        var result = [Session]()
        repeat {
            result = fetchOneBatchIterative(context: context, startIndex: start, amount: batch)
            start += batch
        } while (start < endIndex) && !result.isEmpty
    }

    private func fetchOneBatchIterative(context: NSManagedObjectContext, startIndex: Int, amount: Int) -> [Session] {
        var sessions = [Session]()
        context.performAndWait {
            let request: NSFetchRequest<NSFetchRequestResult> = Session.fetchRequest()
            let descriptor = NSSortDescriptor(key: "number", ascending: true)
            let predicate = NSPredicate(format: "number >= %d AND number <%d", startIndex, startIndex + amount)
            request.sortDescriptors = [descriptor]
            request.predicate = predicate
            guard let result = try? context.fetch(request) as? [Session] else { return }
            if result != nil {
                sessions = result!
            }
        }
        //NSLog("count: \(sessions.count) firts: \(sessions.first?.number)")
        return sessions
    }
 */
}


//
//  EntryController.swift
//  JournalCoreData
//
//  Created by Nelson Gonzalez on 2/11/19.
//  Copyright © 2019 Nelson Gonzalez. All rights reserved.
//

import Foundation
import CoreData

class EntryController {
    
    
   private let baseURL = URL(string: "https://nelson-ios-journal.firebaseio.com/")!
  //  https://journal-coredata-b5a96.firebaseio.com/
  
    // let baseURL = URL(string: "https://journal-coredata-b5a96.firebaseio.com/")!
    init() {
        fetchEntriesFromServer()
    }
    
//    func saveToPersistentStore(){
//        //Save changes to disk
//        let moc = CoreDataStack.shared.mainContext
//        do {
//            try moc.save()//Save the task to the persistent store
//        } catch {
//            print("Error saving MOC (managed object context): \(error)")
//        }
//    }
    

    
    func create(title: String, body: String, mood: Mood) {
        
        let newEntry = Entry(title: title, bodyText: body, mood: mood)

     //   saveToPersistentStore()
        do {
            try CoreDataStack.shared.save()
        } catch {
            print("Error creating task: \(error)")
        }

        self.put(entry: newEntry)
    }
    
    func update(title: String, body: String, entry: Entry, mood: String){

        entry.title = title
        entry.bodyText = body
        entry.timestamp = Date()
        entry.mood = mood
    
        do {
            try CoreDataStack.shared.save()
        } catch {
            NSLog("Error creating task: \(error)")
        }
        
        
        //entry from above
        self.put(entry: entry)
       //saveToPersistentStore()
       
    }
    
    func delete(entry: Entry){
        let moc = CoreDataStack.shared.mainContext
        
            moc.delete(entry)//Remore from moc but not persistent store.
        
        self.deleteEntryFromServer(entry: entry)

        // saveToPersistentStore()
        do {
            try CoreDataStack.shared.save()
        } catch {
            NSLog("Error creating task: \(error)")
        }
    }
    
    // Give this completion closure a default value of an empty closure. (e.g. { _ in } ). This will allow you to use the completion closure if you want to do something when completion is called or just not worry about doing anything after knowing the data task has completed.
    func put(entry: Entry, completion: @escaping(Error?)-> Void = { _ in }) {
        guard let identifier = entry.identifier else {return}
        let url = baseURL.appendingPathComponent(identifier).appendingPathExtension("json")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        
        let encoder = JSONEncoder()
        
        do {
           let jsonData = try encoder.encode(entry)
            urlRequest.httpBody = jsonData
        } catch {
            print("error encoding entry: \(error)")
            completion(error)
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { (data, _, error) in
            if let error = error {
                print("Error with request: \(error)")
                completion(error)
                return
            }
        }.resume()
        
    }
    
    
    func deleteEntryFromServer(entry: Entry, completion: @escaping(Error?) -> Void = { _ in }) {
        guard let identifier = entry.identifier else {return}
        let url = baseURL.appendingPathComponent(identifier).appendingPathExtension("json")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: urlRequest) { (_, _, error) in
            if let error = error {
                print("Error deleting entry: \(error)")
                completion(error)
                return
            }
            completion(nil)
        }.resume()
    }
    
    func update(entry: Entry, entryRepresentation: EntryRepresentation){
        
        // Check to make sure there is a context
       guard let context = entry.managedObjectContext else { return }
        
       context.perform {
            guard entry.identifier == entryRepresentation.identifier else {
                fatalError("Updating the wrong task!")
            }
            
            entry.title = entryRepresentation.title
            entry.bodyText = entryRepresentation.bodyText
            entry.timestamp = entryRepresentation.timestamp
            entry.identifier = entryRepresentation.identifier
            entry.mood = entryRepresentation.mood
            
       }
    
        
    }
    
    func fetchSingleEntryFromPersistentStore(identifier: String, context: NSManagedObjectContext) -> Entry? {
        let fetchedRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchedRequest.predicate = NSPredicate(format: "identifier == %@", identifier)
        
         var entry: Entry?
        
      //  let moc = CoreDataStack.shared.mainContext
         context.performAndWait {
        do {
         entry = try context.fetch(fetchedRequest).first
        } catch {
            NSLog("Error fetching task with \(identifier): \(error)")
        }
       // return (try? moc.fetch(fetchedRequest))?.first
        }
        return entry
    }
    
    func fetchEntriesFromServer(completion: @escaping(Error?) -> Void = { _ in }) {
        let url = baseURL.appendingPathExtension("json")

        URLSession.shared.dataTask(with: url) { (data, _, error) in
            if let error = error {
                print("Error fetching data: \(error)")
                completion(error)
                return
            }

            guard let data = data else {
                print("Error getting data")
                completion(NSError())
                return
            }

            var entryRepresentation: [EntryRepresentation] = []

            // Use container to get a new background context
            let backgroundMoc = CoreDataStack.shared.container.newBackgroundContext()


            backgroundMoc.performAndWait {
                do {
                    entryRepresentation = try JSONDecoder().decode([String: EntryRepresentation].self, from: data).map({$0.value})
                    
                    
                    
                    // entryRepresentation = decodedDict
                    for eachEntry in entryRepresentation {
                        if let entry = self.fetchSingleEntryFromPersistentStore(identifier: eachEntry.identifier, context: backgroundMoc) {
                            self.update(entry: entry, entryRepresentation: eachEntry)
                        } else {
                            
                            _ = Entry(er: eachEntry, context: backgroundMoc)
                        }
                    }
                    
                     try CoreDataStack.shared.save(context: backgroundMoc)
                 //   self.saveToPersistentStore()
                    
                    completion(nil)
                } catch {
                    print("Error decoding or importing tasks: \(error)")
                    completion(error)
                }
            }
          

          
        }.resume()
    }
    
}

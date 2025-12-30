//
//  SoundProvider.swift
//  kaamelott
//
//  Created by Tony Ducrocq on 06/04/2017.
//  Copyright © 2017 hubmobile. All rights reserved.
//

import Foundation
import CoreData
import Alamofire
import UIKit

typealias SoundsResponseHandler = (_ response : [SoundMO]?, _ error:Error?) -> ()
typealias SoundsProgressHandler = (_ fileName: String, _ downloaded : Int, _ count : Int) -> ()

/// Fournisseur de données pour les sons de Kaamelott.
class SoundProvider {
    
    static var baseApiUrl : String = "https://raw.githubusercontent.com/2ec0b4/kaamelott-soundboard/master/sounds"
    
    typealias fetchDataCompletionHandler = (_ sounds: [SoundMO]?, _ error:Error?) -> Void
    
    /// Récupère les sons depuis Core Data.
    /// - Parameters:
    ///   - sortKey: Clé de tri pour les résultats
    ///   - context: Contexte Core Data
    ///   - completion: Closure appelée avec les sons ou une erreur
    static func fetchData(sortKey : String = "titleClean", context: NSManagedObjectContext, completion: @escaping fetchDataCompletionHandler) {
        DispatchQueue.global(qos: .background).async {
            let fetchRequest: NSFetchRequest<SoundMO> = SoundMO.fetchRequest()
            let sortDescriptor = NSSortDescriptor(key: sortKey, ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]
            
            let fetchResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
            do {
                try fetchResultController.performFetch()
                if let fetchedObjects = fetchResultController.fetchedObjects {
                    DispatchQueue.main.async {
                        completion(fetchedObjects, nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Télécharge les sons depuis l'API distante.
    /// - Parameters:
    ///   - soundsResponseHandler: Closure appelée à la fin du téléchargement
    ///   - progressHandler: Closure appelée pour chaque fichier téléchargé
    static func sounds(soundsResponseHandler: @escaping SoundsResponseHandler, progressHandler: @escaping SoundsProgressHandler) {
        let url = "\(SoundProvider.baseApiUrl)/sounds.json"
        
        AF.request(url, method: .get).responseDecodable(of: [[String: String]].self) { response in
            switch response.result {
            case .success(let json):
                DispatchQueue.global(qos: .background).async {
                    sounds(json: json, soundsResponseHandler: { (sounds, error) in
                        DispatchQueue.main.async {
                            soundsResponseHandler(sounds, error)
                        }
                    }, progressHandler: { (file, downloaded, count) in
                        DispatchQueue.main.async {
                            progressHandler(file, downloaded, count)
                        }
                    })
                }
                
            case .failure(let error):
                soundsResponseHandler(nil, error)
            }
        }
    }
    
    /// Traite le JSON et sauvegarde les sons.
    private static func sounds(json: [[String: String]], soundsResponseHandler: @escaping SoundsResponseHandler, progressHandler: @escaping SoundsProgressHandler) {
        guard let appDelegate = (UIApplication.shared.delegate as? AppDelegate) else {
            soundsResponseHandler([], nil)
            return
        }
        
        let context = appDelegate.persistentContainer.newBackgroundContext()
        // Active la fusion automatique des changements vers le viewContext
        appDelegate.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        
        switch saveSounds(json: json, context: context) {
        case .success(let sounds):
            // Sauvegarde IMMÉDIATEMENT après la création des objets
            appDelegate.saveContext(context)
            
            var filesToDownload = sounds.count
            
            if filesToDownload == 0 {
                soundsResponseHandler(sounds, nil)
                return
            }
            
            for sound in sounds {
                guard let file = sound.file else {
                    filesToDownload -= 1
                    if filesToDownload == 0 {
                        soundsResponseHandler(sounds, nil)
                    }
                    continue
                }
                
                guard let url = URL(string: "\(SoundProvider.baseApiUrl)/\(file)") else {
                    filesToDownload -= 1
                    if filesToDownload == 0 {
                        soundsResponseHandler(sounds, nil)
                    }
                    continue
                }
                
                // Utilise SoundCacheManager pour télécharger et mettre en cache
                SoundCacheManager.shared.fetchSound(from: url) { _ in
                    progressHandler(file, sounds.count - filesToDownload + 1, sounds.count)
                    filesToDownload -= 1
                    if filesToDownload == 0 {
                        soundsResponseHandler(sounds, nil)
                    }
                }
            }
        case .failure(let error):
            soundsResponseHandler(nil, error)
        }
    }
    
    /// Sauvegarde les sons dans Core Data.
    private static func saveSounds(json: [[String: String]], context: NSManagedObjectContext) -> Result<[SoundMO], Error> {
        
        var results : [SoundMO] = []
        
        let fetchRequest: NSFetchRequest<SoundMO> = SoundMO.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "file", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]

        let fetchResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try fetchResultController.performFetch()
            if let fetchedObjects = fetchResultController.fetchedObjects {
                var dictionnaire = fetchedObjects.toDictionary(with: { (sound) -> String in
                    return sound.file!
                })
                for obj in json {
                    guard let fileKey = obj["file"] else {
                        return Result.failure(JSONParsingError(reason: .invalidDictonnary))
                    }
                    
                    if let sound = dictionnaire[fileKey] {
                        sound.character = obj["character"] ?? ""
                        sound.characterClean = (sound.character ?? "").folding(options: .diacriticInsensitive, locale: .current)
                        sound.episode = obj["episode"] ?? ""
                        sound.episodeClean = (sound.episode ?? "").folding(options: .diacriticInsensitive, locale: .current)
                        sound.file = obj["file"] ?? ""
                        sound.title = obj["title"] ?? ""
                        sound.titleClean = (sound.title ?? "").folding(options: .diacriticInsensitive, locale: .current)
                        results.append(sound)
                        dictionnaire.removeValue(forKey: fileKey)
                    } else {
                        let sound = SoundMO.newInstance(
                            character: obj["character"] ?? "",
                            episode: obj["episode"] ?? "",
                            file: obj["file"] ?? "",
                            title: obj["title"] ?? "",
                            context: context
                        )
                        results.append(sound)
                    }
                }
                
                // Supprime les anciennes valeurs de sounds.json
                for (_, sound) in dictionnaire {
                    context.delete(sound)
                }
            }
        } catch {
            return Result.failure(error)
        }
        return Result.success(results)
    }
}

/// Erreur de parsing JSON.
struct JSONParsingError: Error {
    enum JSONParsingReason {
        case invalidDictonnary
        case invalidArray
    }
    let reason: JSONParsingReason
}

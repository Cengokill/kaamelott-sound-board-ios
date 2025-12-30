//
//  SoundTableViewController.swift
//  kaamelott
//
//  Created by Tony Ducrocq on 06/04/2017.
//  Copyright © 2017 hubmobile. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation

class SoundTableViewController: UITableViewController, NSFetchedResultsControllerDelegate, UISearchResultsUpdating {
    
    var player: AVAudioPlayer?
    var fetchResultController: NSFetchedResultsController<SoundMO>!
    var sounds:[SoundMO] = []
    var searchResults:[SoundMO] = []
    
    lazy var searchController: UISearchController = {
        return UISearchController(searchResultsController: nil)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Supprime le titre du bouton retour
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        // Active le dimensionnement automatique des cellules
        tableView.estimatedRowHeight = 80.0
        tableView.rowHeight = UITableView.automaticDimension
        
        // Récupère les données depuis le store
        fetchData {
            self.tableView.reloadData()
        }
        
        // S'inscrit pour recevoir les notifications
        NotificationCenter.default.addObserver(self, selector: #selector(fetchData), name: Notification.Name("SoundAdded"), object: nil)
        
        // Configure la barre de recherche
        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Rechercher des sons..."
        searchController.searchBar.tintColor = UIColor.white
        searchController.searchBar.barTintColor = UIColor.kaamelott
        definesPresentationContext = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    typealias fetchDataCompletionHandler = () -> Void
    
    /// Récupère les sons depuis Core Data et les stocke dans le tableau sounds.
    @objc func fetchData(completion: fetchDataCompletionHandler? = nil) {
        if let appDelegate = (UIApplication.shared.delegate as? AppDelegate) {
            let context = appDelegate.persistentContainer.viewContext
            SoundProvider.fetchData(sortKey: "titleClean", context: context, completion: { (sounds, error) in
                if let sounds = sounds {
                    self.sounds = sounds
                } else if let error = error {
                    print(error)
                }
                completion?()
            })
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.isActive {
            return searchResults.count
        } else {
            return sounds.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cellIdentifier = "Cell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! SoundTableViewCell
        
        // Détermine si on utilise les résultats de recherche ou le tableau original
        let sound = (searchController.isActive) ? searchResults[indexPath.row] : sounds[indexPath.row]
        
        // Configure la cellule
        cell.titleLabel.text = sound.title
        cell.characterLabel.text = sound.character
        cell.episodeLabel.text = sound.episode
        cell.indexLabel.text = "\(indexPath.row + 1)"
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sound = (searchController.isActive) ? searchResults[indexPath.row] : sounds[indexPath.row]
        
        guard let file = sound.file else { return }
        let urlString = "\(SoundProvider.baseApiUrl)/\(file)"
        guard let url = URL(string: urlString) else { return }
        
        // Télécharge et joue le son via Kingfisher pour le cache
        SoundCacheManager.shared.fetchSound(from: url) { [weak self] localURL in
            guard let localURL = localURL else { return }
            
            do {
                self?.player = try AVAudioPlayer(contentsOf: localURL)
                self?.player?.prepareToPlay()
                self?.player?.play()
            } catch {
                print(error.localizedDescription)
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if searchController.isActive {
            return false
        } else {
            return true
        }
    }
        
    // MARK: - Search Controller
    
    /// Filtre le contenu en fonction du texte de recherche.
    func filterContent(for searchText: String) {
        let foldedQuery = searchText.foldedForSearch()
        var results: [SoundMO] = []
        results.reserveCapacity(sounds.count)
        
        for sound in sounds {
            guard let character = sound.character, let title = sound.title, let episode = sound.episode else {
                continue
            }
            
            if character.containsFoldedQuery(foldedQuery) || title.containsFoldedQuery(foldedQuery) || episode.containsFoldedQuery(foldedQuery) {
                results.append(sound)
            }
        }
        
        searchResults = results
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text {
            // Si le texte est vide, affiche tous les résultats
            if searchText.isEmpty {
                searchResults = sounds
            } else {
                filterContent(for: searchText)
            }
            tableView.reloadData()
        }
    }
}

// MARK: - Sound Cache Manager

/// Gestionnaire de cache pour les fichiers audio, utilisant le système de fichiers.
class SoundCacheManager {
    static let shared = SoundCacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesPath.appendingPathComponent("SoundsCache")
        
        // Crée le répertoire de cache si nécessaire
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Récupère un fichier son depuis le cache ou le télécharge.
    /// - Parameters:
    ///   - url: URL distante du fichier audio
    ///   - completion: Closure appelée avec l'URL locale du fichier
    func fetchSound(from url: URL, completion: @escaping (URL?) -> Void) {
        let fileName = url.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(fileName)
        
        // Vérifie si le fichier est déjà en cache
        if fileManager.fileExists(atPath: localURL.path) {
            completion(localURL)
            return
        }
        
        // Télécharge le fichier
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let tempURL = tempURL, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            do {
                // Déplace le fichier temporaire vers le cache
                try self?.fileManager.moveItem(at: tempURL, to: localURL)
                DispatchQueue.main.async { completion(localURL) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
        task.resume()
    }
}

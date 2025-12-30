//
//  CharacterTableViewController.swift
//  kaamelott
//
//  Created by Tony Ducrocq on 06/04/2017.
//  Copyright © 2017 hubmobile. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation

class SectionTableViewController: UITableViewController, NSFetchedResultsControllerDelegate, UISearchResultsUpdating {
    
    var player: AVAudioPlayer?
    var fetchResultController: NSFetchedResultsController<SoundMO>!
    
    var sections : [String] = []
    var searchSections : [String] = []
    var displayedSections : [String] {
        get {
            if searchController.isActive {
                return searchSections
            } else {
                return sections
            }
        }
    }
    var sounds : [String : [SoundMO]] = [:]
    var searchSounds : [String : [SoundMO]] = [:]
    var displayedSounds : [String : [SoundMO]] {
        get {
            if searchController.isActive {
                return searchSounds
            } else {
                return sounds
            }
        }
    }
    
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
    
    typealias fetchDataCompletionHandler = () -> Void
    
    /// Récupère les données. Doit être surchargée par les sous-classes.
    @objc func fetchData(completion: fetchDataCompletionHandler? = nil) {
        preconditionFailure("must be override")
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return displayedSections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let key = displayedSections[section]
        if let values = displayedSounds[key] {
            return values.count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerCell = tableView.dequeueReusableCell(withIdentifier: "CharacterCell") as! SectionTableViewCell
        headerCell.backgroundColor = UIColor.kaamelott
        headerCell.characterLabel.text = displayedSections[section]
        headerCell.characterImageView.image = nil
        return headerCell
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 80.0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cellIdentifier = "Cell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! SoundTableViewCell
        
        let key = displayedSections[indexPath.section]
        guard let values = displayedSounds[key] else {
            return cell
        }
        let sound = values[indexPath.row]
        
        // Configure la cellule
        cell.titleLabel.text = sound.title
        cell.characterLabel.text = sound.character
        cell.episodeLabel.text = sound.episode
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let key = displayedSections[indexPath.section]
        guard let values = displayedSounds[key] else {
            return
        }
        let sound = values[indexPath.row]
        
        guard let file = sound.file else { return }
        let urlString = "\(SoundProvider.baseApiUrl)/\(file)"
        guard let url = URL(string: urlString) else { return }
        
        // Télécharge et joue le son via le cache manager
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
    
    // MARK: - Search Controller
    
    /// Filtre le contenu en fonction du texte de recherche.
    func filterContent(for searchText: String) {
        searchSounds = [:]
        searchSections = []
        for section in sections {
            if sounds[section] != nil {
                var values : [SoundMO] = []
                for sound in sounds[section]! {
                    if let character = sound.character, let title = sound.title, let episode = sound.episode {
                        if character.localizedCaseInsensitiveContains(searchText) || title.localizedCaseInsensitiveContains(searchText) || episode.localizedCaseInsensitiveContains(searchText) {
                            values.append(sound)
                        }
                    }
                }
                if !values.isEmpty {
                    searchSounds[section] = values
                    searchSections.append(section)
                }
            }
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text {
            // Si le texte est vide, réinitialise pour afficher tous les résultats
            if searchText.isEmpty {
                searchSounds = sounds
                searchSections = sections
            } else {
                filterContent(for: searchText)
            }
            tableView.reloadData()
        }
    }
}

// MARK: - CharacterTableViewController

/// Contrôleur affichant les sons groupés par personnage.
class CharacterTableViewController: SectionTableViewController {
    
    override func fetchData(completion: fetchDataCompletionHandler? = nil) {
        if let appDelegate = (UIApplication.shared.delegate as? AppDelegate) {
            let context = appDelegate.persistentContainer.viewContext
            SoundProvider.fetchData(sortKey: "titleClean", context: context, completion: { (sounds, error) in
                if let fetchedObjects = sounds {
                    self.sections = []
                    self.sounds = [:]
                    for object in fetchedObjects {
                        let key = object.characterClean!
                        if self.sounds[key] == nil {
                            self.sections.append(key)
                            self.sounds[key] = [object]
                        } else {
                            self.sounds[key]?.append(object)
                        }
                    }
                    self.sections.sort(by: { (s1, s2) -> Bool in
                        return s1.folding(options: .diacriticInsensitive, locale: .current) < s2.folding(options: .diacriticInsensitive, locale: .current)
                    })
                } else if let error = error {
                    print(error)
                }
                completion?()
            })
        }
    }
}

// MARK: - EpisodeTableViewController

/// Contrôleur affichant les sons groupés par épisode.
class EpisodeTableViewController: SectionTableViewController {
    
    override func fetchData(completion: fetchDataCompletionHandler? = nil) {
        if let appDelegate = (UIApplication.shared.delegate as? AppDelegate) {
            let context = appDelegate.persistentContainer.viewContext
            SoundProvider.fetchData(sortKey: "titleClean", context: context, completion: { (sounds, error) in
                if let fetchedObjects = sounds {
                    self.sections = []
                    self.sounds = [:]
                    for object in fetchedObjects {
                        let key = object.episode!
                        if self.sounds[key] == nil {
                            self.sections.append(key)
                            self.sounds[key] = [object]
                        } else {
                            self.sounds[key]?.append(object)
                        }
                    }
                    self.sections.sort(by: { (s1, s2) -> Bool in
                        return s1.folding(options: .diacriticInsensitive, locale: .current) < s2.folding(options: .diacriticInsensitive, locale: .current)
                    })
                } else if let error = error {
                    print(error)
                }
                completion?()
            })
        }
    }
}

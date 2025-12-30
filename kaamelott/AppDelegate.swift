//
//  AppDelegate.swift
//  kaamelott
//
//  Created by Tony Ducrocq on 06/04/2017.
//  Copyright © 2017 hubmobile. All rights reserved.
//

import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    /// Configure l'apparence globale de l'application au lancement.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configuration de l'apparence de la barre de navigation
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(netHex: 0x2EC0B4)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "AvenirNextCondensed-DemiBold", size: 24.0) ?? UIFont.systemFont(ofSize: 24.0)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor.white
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Appelé lorsque l'application passe de l'état actif à inactif.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Libère les ressources partagées, sauvegarde les données utilisateur.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Appelé lors de la transition du background vers l'état actif.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Redémarre les tâches qui ont été mises en pause.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Appelé lorsque l'application est sur le point de se terminer.
    }
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /// Le conteneur persistant pour l'application. Crée et retourne un conteneur
        /// après avoir chargé le store de l'application.
        let container = NSPersistentContainer(name: "Kaamelott")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    /// Sauvegarde le contexte Core Data si des modifications sont présentes.
    /// - Parameter context: Le contexte à sauvegarder. Utilise le viewContext par défaut.
    func saveContext (_ context : NSManagedObjectContext? = nil) {
        let mContext = context ?? persistentContainer.viewContext
        if mContext.hasChanges {
            do {
                try mContext.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

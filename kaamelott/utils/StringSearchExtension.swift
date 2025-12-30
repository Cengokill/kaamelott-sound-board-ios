//
//  StringSearchExtension.swift
//  kaamelott
//
//  Created by GPT-5.2 on 30/12/2025.
//

import Foundation

extension String {
    /// - Summary: Retourne une version normalisée de la chaîne pour la recherche (insensible aux accents et à la casse).
    func foldedForSearch(locale: Locale = .current) -> String {
        return folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: locale)
    }
    
    /// - Summary: Indique si la chaîne contient `foldedQuery` (déjà normalisée) en ignorant accents et casse.
    func containsFoldedQuery(_ foldedQuery: String, locale: Locale = .current) -> Bool {
        return foldedForSearch(locale: locale).contains(foldedQuery)
    }
}



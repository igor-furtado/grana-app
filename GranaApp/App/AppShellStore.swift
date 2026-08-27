import Foundation
import SwiftUI

@MainActor
@Observable
final class AppShellStore {
    private var mountedSections: Set<AppSection>
    private var branches: [AppSection: AppShellBranch]

    init(initialSection: AppSection = .dashboard) {
        self.mountedSections = [initialSection]
        self.branches = Dictionary(
            uniqueKeysWithValues: AppSection.allCases.map { section in
                (section, AppShellBranch(section: section))
            }
        )
    }

    func activate(_ section: AppSection) {
        mountedSections.insert(section)
    }

    func isMounted(_ section: AppSection) -> Bool {
        mountedSections.contains(section)
    }

    func branch(for section: AppSection) -> AppShellBranch {
        guard let branch = branches[section] else {
            preconditionFailure("Branch não configurada para seção \(section.rawValue)")
        }
        return branch
    }
}

@MainActor
@Observable
final class AppShellBranch {
    let section: AppSection
    var path = NavigationPath()

    init(section: AppSection) {
        self.section = section
    }
}

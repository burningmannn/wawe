import SwiftUI
#if canImport(UIKit)
import UIKit

// MARK: - Global UIAppearance configuration
// Light theme: pure white surfaces + crimson accent
// Dark theme: pure black surfaces + crimson accent

enum AppAppearance {

    // MARK: - Palette

    /// Pure white — nav/tab bar in light theme
    static let lightSurface = UIColor.white
    /// Pure black — nav/tab bar in dark theme
    static let darkSurface  = UIColor.black
    /// Deep purple accent — selected items in both themes
    static let darkAccent   = UIColor(red: 0.58, green: 0.28, blue: 0.88, alpha: 1)

    // MARK: - Apply

    static func apply(scheme: ColorScheme?) {
        // Resolve effective scheme: nil = follows system, but we style as light by default
        let isDark = scheme == .dark
        isDark ? applyDark() : applyLight()

        // Force already-rendered UIKit views (nav bar, tab bar) to re-read UIAppearance.
        // Without this, changing the theme requires navigating away and back.
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                window.subviews.forEach { $0.removeFromSuperview(); window.addSubview($0) }
            }
    }

    // MARK: - Light

    static func applyLight() {
        // ── Lists (UITableView backs SwiftUI List) ──────────────────────────
        // Warm cream background → white rows appear as floating cards
        // ── Navigation Bar ──────────────────────────────────────────────────
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = lightSurface
        nav.shadowColor = UIColor.black.withAlphaComponent(0.06)

        // Bold, slightly larger title feels more editorial
        nav.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        nav.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.black
        ]

        UINavigationBar.appearance().standardAppearance    = nav
        UINavigationBar.appearance().scrollEdgeAppearance  = nav
        UINavigationBar.appearance().compactAppearance     = nav

        // ── Tab Bar ─────────────────────────────────────────────────────────
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = lightSurface
        tab.shadowColor = UIColor.black.withAlphaComponent(0.08)

        // Item colors — unselected: dark gray; selected: crimson
        let normal   = UITabBarItemAppearance()
        normal.normal.iconColor   = UIColor.black.withAlphaComponent(0.35)
        normal.normal.titleTextAttributes   = [.foregroundColor: UIColor.black.withAlphaComponent(0.35)]
        normal.selected.iconColor = darkAccent
        normal.selected.titleTextAttributes = [.foregroundColor: darkAccent,
                                               .font: UIFont.systemFont(ofSize: 10, weight: .semibold)]
        tab.stackedLayoutAppearance   = normal
        tab.inlineLayoutAppearance    = normal
        tab.compactInlineLayoutAppearance = normal

        UITabBar.appearance().standardAppearance    = tab
        UITabBar.appearance().scrollEdgeAppearance  = tab

        // ── Segmented control ───────────────────────────────────────────────
        UISegmentedControl.appearance().selectedSegmentTintColor = .black
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
            for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.black.withAlphaComponent(0.7)],
            for: .normal)
    }

    // MARK: - Dark

    static func applyDark() {
        // Nav bar: pure black
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = darkSurface
        nav.shadowColor = .clear
        nav.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        nav.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        UINavigationBar.appearance().standardAppearance    = nav
        UINavigationBar.appearance().scrollEdgeAppearance  = nav
        UINavigationBar.appearance().compactAppearance     = nav

        // Tab bar: pure black + crimson for selected items
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = darkSurface
        tab.shadowColor = .clear

        let item = UITabBarItemAppearance()
        item.normal.iconColor   = UIColor.white.withAlphaComponent(0.4)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.4)]
        item.selected.iconColor = darkAccent
        item.selected.titleTextAttributes = [
            .foregroundColor: darkAccent,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        tab.stackedLayoutAppearance       = item
        tab.inlineLayoutAppearance        = item
        tab.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance    = tab
        UITabBar.appearance().scrollEdgeAppearance  = tab

        UISegmentedControl.appearance().selectedSegmentTintColor = nil
        UISegmentedControl.appearance().setTitleTextAttributes([:], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([:], for: .normal)
    }
}
#endif

// MARK: - SwiftUI colour tokens (use in views)

extension Color {
    /// Warm cream list/page background (light theme only)
    static let lightPageBg  = Color(red: 0.980, green: 0.973, blue: 0.953)
    /// Warm yellow card highlight – mirrors the reference image's accent cards
    static let lightCardAccent = Color(red: 0.973, green: 0.925, blue: 0.714)  // #F8EC
}

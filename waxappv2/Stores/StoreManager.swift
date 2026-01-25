//
//  StoreManager.swift
//  waxappv2
//
//  Created by Herman Henriksen on 10/01/2026.
//

import Foundation
import StoreKit
import SwiftUI
import Combine
import CloudKit

enum TrialStatus: Equatable {
    case active
    case warning(daysLeft: Int)
    case expired
}

enum TrialSourceStatus: Equatable {
    case cloudKit
    case localOnly
    case initializing
}

@MainActor
class StoreManager: ObservableObject {
    @Published var isPurchased: Bool = false
    @Published var products: [Product] = []

    /// Local cache of trial start date for offline enforcement
    @Published private(set) var cachedTrialStartDate: Date?
    
    /// Indicates where the trial date is sourced from
    @Published private(set) var trialSourceStatus: TrialSourceStatus = .initializing
    
    /// Cached trial status to prevent multiple updates per frame
    @Published private(set) var cachedTrialStatus: TrialStatus = .active
    
    /// Indicates if initial purchase status check is complete
    @Published private(set) var isInitialized: Bool = false

    private let productIds = ["com.waxappv2.lifetime"] // Replace with your actual Product ID

    // Local cache keys
    private let localCacheKey = "localTrialStartDateISO8601"
    private let lastCloudKitSyncKey = "lastCloudKitSync"
    private let hasCloudKitSyncedKey = "hasEverSyncedWithCloudKit"
    private let iso8601 = ISO8601DateFormatter()

    private let trialStore = CloudKitTrialStore()
    private var updateListenerTask: Task<Void, Error>? = nil

    // MARK: - Trial Date Management
    
    /// Returns the effective trial start date (CloudKit-synced or local cache)
    var trialStartDate: Date {
        // Use cached date if available (set from either local cache or CloudKit)
        if let cachedTrialStartDate {
            return cachedTrialStartDate
        }

        // Load from local cache (Keychain for security)
        if let cachedDate = loadLocalCache() {
            cachedTrialStartDate = cachedDate
            print("📅 Trial date source: Keychain cache")
            print("📅 Effective date: \(cachedDate)")
            return cachedDate
        }

        // First run - initialize with current date
        let now = Date()
        saveToLocalCache(now)
        cachedTrialStartDate = now
        print("📅 Trial date source: First run initialization")
        print("📅 Effective date: \(now)")
        return now
    }

    var daysSinceStart: Int {
        let calendar = Calendar.current
        let start = trialStartDate
        let now = Date()
        let components = calendar.dateComponents([.day], from: start, to: now)
        return components.day ?? 0
    }

    var trialStatus: TrialStatus {
        return cachedTrialStatus
    }
    
    /// Update the cached trial status based on current date
    /// Skips if app is purchased
    private func updateTrialStatus() {
        // Skip trial status updates if app is purchased
        if isPurchased {
            return
        }
        
        let days = daysSinceStart
        let newStatus: TrialStatus
        if days >= 14 {
            newStatus = .expired
        } else if days >= 10 {
            newStatus = .warning(daysLeft: 14 - days)
        } else {
            newStatus = .active
        }
        
        // Only update if status changed
        if cachedTrialStatus != newStatus {
            cachedTrialStatus = newStatus
            print("📊 Trial status updated: \(newStatus)")
        }
    }

    // MARK: - Initialization

    init() {
        print("\n🚀 StoreManager initializing...")
        
        // Listen for StoreKit transactions
        updateListenerTask = listenForTransactions()

        // Fetch products and check purchase status FIRST
        Task {
            await updatePurchasedStatus()
            await fetchProducts()
            
            // Mark as initialized after initial checks complete
            await MainActor.run {
                isInitialized = true
                
                if isPurchased {
                    print("✅ App is purchased - skipping trial functionality")
                } else {
                    print("ℹ️ Trial mode active - will check trial status")
                }
                
                print("✅ StoreManager fully initialized with purchase status")
            }
        }
        
        print("✅ StoreManager initialized\n")
    }
    
    /// Call this on every app launch to sync with CloudKit
    /// Only runs if app is not purchased
    func performLaunchSync() async {
        // Wait for initialization to complete first
        while !isInitialized {
            try? await Task.sleep(for: .milliseconds(50))
        }
        
        // Skip all trial functionality if app is purchased
        if isPurchased {
            print("✅ App is purchased - skipping CloudKit sync")
            return
        }
        
        print("\n🔄 Starting launch sync with CloudKit...")
        
        // Load initial cached date for trial users
        if cachedTrialStartDate == nil {
            cachedTrialStartDate = loadLocalCache()
            
            if let cached = cachedTrialStartDate {
                print("📦 Loaded from local cache: \(cached)")
            } else {
                print("📦 No local cache found - will initialize on first access")
            }
        }
        
        // Update trial status before sync
        updateTrialStatus()
        
        await syncWithCloudKit()
        print("🔄 Launch sync completed\n")
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Local Cache Management
    
    /// Load trial start date from local Keychain cache
    private func loadLocalCache() -> Date? {
        guard let dateString = try? KeychainService.getString(forKey: localCacheKey),
              let date = iso8601.date(from: dateString) else {
            return nil
        }
        return date
    }
    
    /// Save trial start date to local Keychain cache
    private func saveToLocalCache(_ date: Date) {
        let dateString = iso8601.string(from: date)
        try? KeychainService.setString(dateString, forKey: localCacheKey)
        
        // Also save last sync time
        let now = iso8601.string(from: Date())
        try? KeychainService.setString(now, forKey: lastCloudKitSyncKey)
    }
    
    /// Mark that we have successfully synced with CloudKit at least once
    private func markCloudKitSynced() {
        try? KeychainService.setString("true", forKey: hasCloudKitSyncedKey)
    }
    
    /// Check if we have ever synced with CloudKit
    private func hasEverSyncedWithCloudKit() -> Bool {
        return (try? KeychainService.getString(forKey: hasCloudKitSyncedKey)) == "true"
    }

    // MARK: - CloudKit Availability Check
    
    /// Check if CloudKit is available (user has iCloud account signed in)
    private func isCloudKitAvailable() async -> Bool {
        do {
            let status = try await CKContainer.default().accountStatus()
            return status == .available
        } catch {
            print("⚠️ Could not check iCloud account status: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - CloudKit Sync
    
    /// Sync with CloudKit - call on every app launch
    /// CloudKit is authoritative - if a record exists there, it always wins
    func syncWithCloudKit() async {
        print("\n☁️ === CloudKit Sync Starting ===")
        
        // Get local cached date (or create new one for first run)
        let localDate = loadLocalCache() ?? Date()
        print("📱 Local date: \(localDate)")
        
        // If no local cache existed, save the current date
        if loadLocalCache() == nil {
            print("💾 Saving initial local date to cache")
            saveToLocalCache(localDate)
            cachedTrialStartDate = localDate
        }
        
        // Check if CloudKit is available
        print("🔍 Checking iCloud availability...")
        let cloudKitAvailable = await isCloudKitAvailable()
        
        if !cloudKitAvailable {
            // No iCloud account - use local storage only
            trialSourceStatus = .localOnly
            print("❌ No iCloud account available")
            print("📦 Using local storage only")
            print("📅 Effective trial start date: \(localDate)")
            print("🔒 Source: LOCAL ONLY")
            print("☁️ === CloudKit Sync Complete ===\n")
            return
        }
        
        print("✅ iCloud account available")
        
        // CloudKit is available - fetch or create record
        do {
            print("☁️ Fetching from CloudKit...")
            let cloudKitDate = try await trialStore.upsertEarliestTrialStartDate(localDate)
            print("☁️ CloudKit date: \(cloudKitDate)")
            
            // CloudKit is authoritative - always use its date
            let effectiveDate = cloudKitDate
            
            // Determine what happened
            let source: String
            if effectiveDate < localDate {
                source = "CLOUDKIT (overwrote local)"
                print("⚠️ CloudKit date is earlier - overwriting local cache")
            } else if effectiveDate > localDate {
                source = "CLOUDKIT (created from local)"
                print("📤 Created new CloudKit record with local date")
            } else {
                source = "CLOUDKIT (synced)"
                print("✅ CloudKit and local dates match")
            }
            
            // Update local cache and memory with CloudKit's authoritative date
            saveToLocalCache(effectiveDate)
            cachedTrialStartDate = effectiveDate
            markCloudKitSynced()
            trialSourceStatus = .cloudKit
            
            // Update trial status after sync
            updateTrialStatus()
            
            print("📅 Effective trial start date: \(effectiveDate)")
            print("🔒 Source: \(source)")
            
        } catch {
            // CloudKit request failed (network issues, etc.)
            trialSourceStatus = hasEverSyncedWithCloudKit() ? .cloudKit : .localOnly
            print("❌ CloudKit sync failed: \(error.localizedDescription)")
            print("📦 Using local cache for offline enforcement")
            print("📅 Effective trial start date: \(localDate)")
            print("🔒 Source: LOCAL CACHE (offline)")
        }
        
        print("☁️ === CloudKit Sync Complete ===\n")
    }

    // MARK: - StoreKit Transaction Handling

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.updatePurchasedStatus()
                case .unverified:
                    print("❌ Transaction unverified")
                }
            }
        }
    }

    func fetchProducts() async {
        do {
            let products = try await Product.products(for: productIds)
            self.products = products
            print("✅ Loaded \(products.count) product(s)")
        } catch {
            print("❌ Failed to fetch products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await updatePurchasedStatus()
                print("✅ Purchase successful")
            case .unverified:
                print("❌ Purchase verification failed")
            }
        case .userCancelled:
            print("ℹ️ User cancelled purchase")
        case .pending:
            print("⏳ Purchase pending")
        @unknown default:
            break
        }
    }

    func updatePurchasedStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIds.contains(transaction.productID) {
                    isPurchased = true
                    print("✅ Valid purchase found")
                    return
                }
            }
        }
        isPurchased = false
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedStatus()
        print("🔄 Restore purchases completed")
    }
}

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
import Observation

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

@Observable class StoreManager {
    var isPurchased: Bool = false
    var products: [Product] = []
    var isPurchasing: Bool = false
    var productsError: String?

    /// Local cache of trial start date for offline enforcement
    private(set) var cachedTrialStartDate: Date?
    
    /// Indicates where the trial date is sourced from
    private(set) var trialSourceStatus: TrialSourceStatus = .initializing
    
    /// Cached trial status to prevent multiple updates per frame
    private(set) var cachedTrialStatus: TrialStatus = .active
    
    /// Indicates if initial purchase status check is complete
    private(set) var isInitialized: Bool = false

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
            // Don't update @Published property here - defer to async initialization
            print("📅 Trial date source: Keychain cache")
            print("📅 Effective date: \(cachedDate)")
            return cachedDate
        }

        // First run - return current date without updating @Published
        let now = Date()
        print("📅 Trial date source: First run initialization")
        print("📅 Effective date: \(now)")
        return now
    }
    
    /// Load and cache the trial start date (call this during async initialization)
    private func loadAndCacheTrialDate() {
        if cachedTrialStartDate != nil {
            return // Already loaded
        }
        
        // Load from local cache (Keychain for security)
        if let cachedDate = loadLocalCache() {
            cachedTrialStartDate = cachedDate
            print("📅 Trial date cached from Keychain: \(cachedDate)")
            return
        }

        // First run - initialize with current date
        let now = Date()
        saveToLocalCache(now)
        cachedTrialStartDate = now
        print("📅 Trial date initialized and cached: \(now)")
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
            await retryFetchProducts() // Use retry mechanism
            
            // Mark as initialized after initial checks complete
            await MainActor.run {
                // Load trial date into cache if not purchased
                if !isPurchased {
                    loadAndCacheTrialDate()
                }
                
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
        
        // Load trial date into cache if needed
        loadAndCacheTrialDate()
        
        if let cached = cachedTrialStartDate {
            print("📦 Loaded from local cache: \(cached)")
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
    /// Falls back to local cache if offline
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
        
        // IMPORTANT: Local cache is always saved first, so offline enforcement
        // works from first launch, even if CloudKit is never available
        
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
            print("🛒 Fetching products for IDs: \(productIds)")
            let products = try await Product.products(for: productIds)
            await MainActor.run {
                self.products = products
                self.productsError = nil
            }
            
            if products.isEmpty {
                let errorMsg = "No products found. Check: 1) Product ID matches App Store Connect 2) Paid Apps Agreement signed 3) Product is 'Ready to Submit'"
                print("⚠️ \(errorMsg)")
                await MainActor.run {
                    self.productsError = errorMsg
                }
            } else {
                print("✅ Loaded \(products.count) product(s)")
                for product in products {
                    print("   - \(product.id): \(product.displayName) (\(product.displayPrice))")
                }
            }
        } catch {
            let errorMsg = "Failed to load products: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            await MainActor.run {
                self.productsError = errorMsg
            }
        }
    }
    
    /// Retry fetching products with exponential backoff
    func retryFetchProducts(maxAttempts: Int = 3) async {
        for attempt in 1...maxAttempts {
            await fetchProducts()
            
            // If we successfully loaded products, stop retrying
            if !products.isEmpty {
                return
            }
            
            // Wait before retrying (exponential backoff)
            if attempt < maxAttempts {
                let delay = Double(attempt * attempt) // 1s, 4s, 9s
                print("⏳ Retrying in \(delay) seconds... (attempt \(attempt)/\(maxAttempts))")
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        
        print("❌ Failed to load products after \(maxAttempts) attempts")
    }

    func purchase(_ product: Product) async throws {
        // Prevent concurrent purchases
        guard !isPurchasing else {
            print("⚠️ Purchase already in progress")
            return
        }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
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

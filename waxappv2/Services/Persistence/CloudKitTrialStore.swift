//
//  CloudKitTrialStore.swift
//  waxappv2
//
//  Persists the trial start date in the user's iCloud Private Database.
//  This makes the trial follow the Apple ID across devices.
//

import Foundation
import CloudKit

@MainActor
final class CloudKitTrialStore {
    enum TrialStoreError: Error {
        case noRecord
        case invalidRecord
    }

    private let container: CKContainer
    private let database: CKDatabase

    private let recordType = "TrialState"
    private let recordName = "trialState" // single record per user
    private let fieldStartDate = "startDate"

    init(container: CKContainer = .default()) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    func fetchTrialStartDate() async throws -> Date {
        let recordID = CKRecord.ID(recordName: recordName)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            // If it doesn't exist yet, surface as noRecord so caller can create.
            throw TrialStoreError.noRecord
        }

        guard let date = record[fieldStartDate] as? Date else {
            throw TrialStoreError.invalidRecord
        }
        return date
    }

    /// Creates the trial record if missing. If the record already exists, it returns the existing date.
    func getOrCreateTrialStartDate(now: Date = Date()) async throws -> Date {
        do {
            return try await fetchTrialStartDate()
        } catch TrialStoreError.noRecord {
            let recordID = CKRecord.ID(recordName: recordName)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            record[fieldStartDate] = now as NSDate

            do {
                _ = try await database.save(record)
                return now
            } catch {
                // If we lost the race to another device, fetch again.
                return try await fetchTrialStartDate()
            }
        }
    }

    /// Fetches or creates trial start date in CloudKit.
    /// CloudKit is authoritative - if a record exists, it always wins.
    /// - Returns: The trial start date from CloudKit (existing or newly created).
    func upsertEarliestTrialStartDate(_ candidate: Date) async throws -> Date {
        let recordID = CKRecord.ID(recordName: recordName)
        
        do {
            // Fetch existing record from CloudKit
            let existingRecord = try await database.record(for: recordID)
            
            guard let cloudKitDate = existingRecord[fieldStartDate] as? Date else {
                throw TrialStoreError.invalidRecord
            }
            
            // CloudKit always wins - return its date
            print("📝 CloudKit record exists - using CloudKit date: \(cloudKitDate)")
            return cloudKitDate
            
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist - create it with local date
            print("📝 No CloudKit record found - creating new with: \(candidate)")
            let newRecord = CKRecord(recordType: recordType, recordID: recordID)
            newRecord[fieldStartDate] = candidate as NSDate
            _ = try await database.save(newRecord)
            return candidate
            
        } catch {
            // Some other error occurred
            throw error
        }
    }
}

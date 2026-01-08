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

    /// Ensures CloudKit contains the earliest (strictest) trial start date.
    /// - Returns: The effective start date stored in CloudKit after the operation.
    func upsertEarliestTrialStartDate(_ candidate: Date) async throws -> Date {
        do {
            let existing = try await fetchTrialStartDate()
            // Keep the earliest date.
            if existing <= candidate {
                return existing
            }

            // Candidate is earlier; overwrite.
            let recordID = CKRecord.ID(recordName: recordName)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            record[fieldStartDate] = candidate as NSDate
            _ = try await database.save(record)
            return candidate
        } catch TrialStoreError.noRecord {
            // No record yet: create with candidate.
            let recordID = CKRecord.ID(recordName: recordName)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            record[fieldStartDate] = candidate as NSDate
            _ = try await database.save(record)
            return candidate
        }
    }
}

//
//  PersistenceService.swift
//  waxappv2
//
//  Protocol and implementation for data persistence operations.
//

import Foundation

/// Protocol for managing data persistence operations.
/// Abstracts the underlying storage mechanism to enable testing and flexibility.
protocol PersistenceService {
  /// Saves data for a given key.
  /// - Parameters:
  ///   - data: The data to persist
  ///   - key: The key to associate with the data
  func save(_ data: Data, forKey key: String)

  /// Retrieves data for a given key.
  /// - Parameter key: The key associated with the data
  /// - Returns: The stored data, or nil if no data exists for the key
  func load(forKey key: String) -> Data?

  /// Removes data for a given key.
  /// - Parameter key: The key associated with the data to remove
  func remove(forKey key: String)
}

/// UserDefaults-based implementation of PersistenceService.
/// Provides standard persistent storage using the UserDefaults system.
final class UserDefaultsPersistenceService: PersistenceService {
  private let userDefaults: UserDefaults

  /// Initializes the service with a UserDefaults instance.
  /// - Parameter userDefaults: The UserDefaults instance to use (defaults to .standard)
  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func save(_ data: Data, forKey key: String) {
    userDefaults.set(data, forKey: key)
  }

  func load(forKey key: String) -> Data? {
    userDefaults.data(forKey: key)
  }

  func remove(forKey key: String) {
    userDefaults.removeObject(forKey: key)
  }
}

/// In-memory implementation of PersistenceService for testing.
/// Does not persist data between app launches.
final class InMemoryPersistenceService: PersistenceService {
  private var storage: [String: Data] = [:]

  func save(_ data: Data, forKey key: String) {
    storage[key] = data
  }

  func load(forKey key: String) -> Data? {
    storage[key]
  }

  func remove(forKey key: String) {
    storage.removeValue(forKey: key)
  }
}

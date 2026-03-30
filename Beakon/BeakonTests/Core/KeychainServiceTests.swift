//
//  KeychainServiceTests.swift
//  BeakonTests
//
//  Created by Ozer on 30.03.2026.
//

import Testing
import Foundation
@testable import Beakon

struct KeychainServiceTests {

    @Test func keychainErrorDescriptions() {
        #expect(KeychainError.duplicateItem.errorDescription != nil)
        #expect(KeychainError.itemNotFound.errorDescription != nil)
        #expect(KeychainError.invalidData.errorDescription != nil)
        #expect(KeychainError.unexpectedStatus(-25300).errorDescription?.contains("-25300") == true)
    }

    @Test func saveLoadDeleteRoundTrip() throws {
        let service = KeychainService()
        let testKey = "beakon-test-\(UUID().uuidString)"
        let testValue = "sk-ant-api03-test-key"

        // Clean up in case of leftover from a previous failed test
        try? service.delete(key: testKey)

        // Save
        try service.save(key: testKey, value: testValue)

        // Load
        let loaded = try service.load(key: testKey)
        #expect(loaded == testValue)

        // Update (save again with same key)
        let updatedValue = "sk-ant-api03-updated-key"
        try service.save(key: testKey, value: updatedValue)
        let loadedUpdated = try service.load(key: testKey)
        #expect(loadedUpdated == updatedValue)

        // Delete
        try service.delete(key: testKey)

        // Verify deleted
        #expect(throws: KeychainError.self) {
            try service.load(key: testKey)
        }
    }

    @Test func loadNonExistentKeyThrowsItemNotFound() {
        let service = KeychainService()
        #expect(throws: KeychainError.self) {
            try service.load(key: "beakon-nonexistent-\(UUID().uuidString)")
        }
    }
}

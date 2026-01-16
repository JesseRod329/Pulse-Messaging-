# Pulse Tests

This directory contains unit tests for the Pulse messaging app.

## Running Tests

### Using Xcode
1. Open `Pulse.xcodeproj` in Xcode
2. Press `Cmd + U` to run all tests
3. Select individual test files to run specific test suites

### Using Command Line
```bash
cd /Users/jesse/pulse/Pulse
xcodebuild test -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Test Coverage

### PulseIdentityTests.swift
Tests for encryption, decryption, and identity management:
- Identity creation and DID generation
- Encrypt/decrypt text, code snippets, and special characters
- Cross-identity messaging
- Base58 encoding/decoding
- Keychain storage operations
- Performance benchmarks

## Adding New Tests

1. Create a new test file in this directory
2. Inherit from `XCTestCase`
3. Add `@testable import Pulse` at the top
4. Write test methods starting with `test`
5. Use `XCTAssert` family of functions for assertions

## Test Data

Tests use in-memory data and don't persist to disk. No setup or teardown required for most tests.

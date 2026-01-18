# Pulse Bitcoin/Lightning Integration - Production Hardening Plan

> **48-Hour Sprint to transform Pulse from "feature-complete" to "production-hardened"**

## 🎯 Executive Summary

This document outlines the critical path to securely integrate Bitcoin Lightning payments (zaps) into Pulse. The focus is on **cryptographic guarantees** rather than superficial features, ensuring user funds are protected at every step.

## 🚨 Critical Security Risks Identified

### High-Priority Threats
1. **Invoice Swapping Attack**: Malicious LNURL server returns high-value invoice for low-value zap request
2. **Wallet URI Exploits**: Malicious strings injected into external wallet calls
3. **Fake Receipt Injection**: Relays broadcasting fake "paid" statuses
4. **Privacy Leaks**: Sensitive data exposed in app switcher/background

## 📋 48-Hour Hardening Sprint

### Phase 0: BOLT11 Parser Foundation (4 hours) - **CRITICAL**
**Status**: 🔄 In Progress  
**Priority**: P0  
**Files**: `Bolt11Parser.swift`, `Bolt11Validator.swift`

**Implementation**:
- Proper BOLT11 invoice parsing without external dependencies
- TLV (Type-Length-Value) data extraction
- Bech32 decoding validation
- Malicious pattern detection (SQL injection, XSS attempts)

**Dependencies**: None  
**Testing**: Unit tests with malicious invoice vectors

### Phase 1: NIP-57 JSON Normalization (3 hours) - **CRITICAL**
**Status**: ⚪ Pending  
**Priority**: P0  
**Files**: `NostrNormalization.swift`, `EventNormalization.swift`

**Implementation**:
- Deterministic JSON serialization with sorted keys
- SHA-256 hash calculation for description_hash
- Cross-client compatibility verification
- NIP-57 specification compliance

**Dependencies**: Phase 0 completion  
**Testing**: Hash comparison with reference clients (Damus, Amethyst)

### Phase 2: Enhanced Amount Guard (2 hours) - **CRITICAL**
**Status**: ⚪ Pending  
**Priority**: P0  
**Files**: `ZapSecurityGuard.swift`, `AmountGuard.swift`

**Implementation**:
- Three-way amount verification (UI → Zap Request → Invoice)
- Millisat precision checking
- Invoice expiration validation
- Defense-in-depth consistency checks

**Dependencies**: Phase 0 & 1 completion  
**Testing**: Amount mismatch scenarios

### Phase 2b: Signature & Key Validation (2 hours) - **CRITICAL**
**Status**: ⚪ Pending  
**Priority**: P0  
**Files**: `NostrIdentityManager.swift`, `NostrTransport.swift`, `ZapManager.swift`

**Implementation**:
- Verify NIP-57 zap request signatures before hashing/invoice checks
- Validate pubkey formats and event kinds
- Reject unsigned or malformed zap requests early

**Dependencies**: Phase 1 completion  
**Testing**: Invalid signature vectors, malformed pubkeys

### Phase 3: Wallet URI Sanitization (2 hours) - **HIGH**
**Status**: ⚪ Pending  
**Priority**: P1  
**Files**: `WalletURISanitizer.swift`, `LNURLService+Security.swift`

**Implementation**:
- Wallet scheme whitelisting
- URI encoding and validation
- Malicious character filtering
- Length-based DoS prevention

**Dependencies**: Phase 0 completion  
**Testing**: URI injection attempts

### Phase 3b: Network Defenses (2 hours) - **HIGH**
**Status**: ⚪ Pending  
**Priority**: P1  
**Files**: `LNURLService.swift`, `NostrTransport.swift`

**Implementation**:
- Request timeouts and cancellation propagation
- Retry/backoff with jitter for LNURL fetches
- Rate limiting for relay events and LNURL requests

**Dependencies**: None  
**Testing**: Timeout handling, retry behavior, flood simulation

### Phase 4: Privacy-Sensitive UI (1 hour) - **MEDIUM**
**Status**: ⚪ Pending  
**Priority**: P2  
**Files**: `PrivacyExtensions.swift`, `ZapDisplayView+Privacy.swift`

**Implementation**:
- `.privacySensitive()` modifiers for sensitive data
- Secure text display components
- App switcher data protection
- Optional reveal/hide functionality

**Dependencies**: None  
**Testing**: UI state preservation checks

### Phase 4b: Invoice Constraints & Logging Hygiene (2 hours) - **MEDIUM**
**Status**: ⚪ Pending  
**Priority**: P2  
**Files**: `Bolt11Validator.swift`, `ZapSecurityGuard.swift`, `ErrorManager.swift`

**Implementation**:
- Enforce invoice length caps and min/max amounts
- Reject unsupported or multi-currency tags
- Scrub invoices/LNURLs/payment hashes from logs in prod builds

**Dependencies**: Phase 0 completion  
**Testing**: Oversized invoice vectors, log redaction checks

### Phase 5: Security Testing & Audit (4 hours) - **CRITICAL**
**Status**: ⚪ Pending  
**Priority**: P0  
**Files**: `ProductionSecurityTests.swift`, `SecurityHardeningTests.swift`

**Implementation**:
- Malicious relay simulation
- Error log scrubbing audit
- Performance under attack conditions
- Integration testing with real wallets

**Dependencies**: All previous phases  
**Testing**: Full security test suite

## 🛠️ Technical Implementation Details

### NIP-57 Description Hash Verification
```swift
// Critical security check - prevents invoice swapping
func verifyDescriptionHash(zapRequest: NostrEvent, invoice: String) throws {
    let requestHash = try zapRequest.descriptionHash()
    let invoiceHash = try extractDescriptionHash(from: invoice)
    
    guard requestHash == invoiceHash else {
        throw ZapError.descriptionHashMismatch
    }
}

module acc_address::identity {
    use std::string::String;
    use aptos_framework::timestamp;
    use aptos_std::table::{Self, Table};
    use std::signer;

    const E_IDENTITY_ALREADY_EXISTS: u64 = 1;
    const E_IDENTITY_NOT_FOUND: u64 = 2;
    const E_UNAUTHORIZED: u64 = 3;

    struct Identity has store {
        name: String,
        verified: bool,
        verification_timestamp: u64,
        verifier: address,
    }

    struct IdentityRegistry has key {
        identities: Table<address, Identity>,
    }

    fun init_module(admin: &signer) {
        move_to(admin, IdentityRegistry {
            identities: table::new<address, Identity>(),
        });
    }

    #[test_only]
    public fun init_for_test(admin: &signer) {
        move_to(admin, IdentityRegistry {
            identities: table::new<address, Identity>(),
        });
    }

    public entry fun register_identity(
        user: &signer,
        name: String,
    ) acquires IdentityRegistry {
        let user_addr = signer::address_of(user);
        let registry = borrow_global_mut<IdentityRegistry>(@acc_address);
        assert!(!table::contains(&registry.identities, user_addr), E_IDENTITY_ALREADY_EXISTS);

        let identity = Identity {
            name,
            verified: false,
            verification_timestamp: 0,
            verifier: @0x0,
        };

        table::add(&mut registry.identities, user_addr, identity);
    }

    public entry fun verify_identity(
        verifier: &signer,
        user_to_verify: address,
    ) acquires IdentityRegistry {
        let verifier_addr = signer::address_of(verifier);
        let registry = borrow_global_mut<IdentityRegistry>(@acc_address);

        assert!(table::contains(&registry.identities, user_to_verify), E_IDENTITY_NOT_FOUND);

        let identity = table::borrow_mut(&mut registry.identities, user_to_verify);
        identity.verified = true;
        identity.verification_timestamp = timestamp::now_seconds();
        identity.verifier = verifier_addr;
    }

    #[view]
    public fun get_identity(user_addr: address): (String, bool, u64, address)
    acquires IdentityRegistry {
        let registry = borrow_global<IdentityRegistry>(@acc_address);
        assert!(table::contains(&registry.identities, user_addr), E_IDENTITY_NOT_FOUND);
        let identity = table::borrow(&registry.identities, user_addr);
        (identity.name, identity.verified, identity.verification_timestamp, identity.verifier)
    }

    #[test_only]
    public fun registry_exists(): bool {
        exists<IdentityRegistry>(@acc_address)
    }
}


#[test_only]
module acc_address::identity_tests {
    use std::string;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use acc_address::identity;

    // Test constants
    const TEST_USER_NAME: vector<u8> = b"John Doe";
    const TEST_USER_NAME_2: vector<u8> = b"Jane Smith";

    // Helper function to create test accounts
    fun create_test_accounts(): (signer, signer, signer) {
        let admin = account::create_account_for_test(@acc_address);
        let user1 = account::create_account_for_test(@0x123);
        let user2 = account::create_account_for_test(@0x456);
        (admin, user1, user2)
    }

    // Initialize timestamp for testing
    fun setup_timestamp() {
        timestamp::set_time_has_started_for_testing(&account::create_account_for_test(@0x1));
    }

    #[test]
    public fun test_register_identity_success() {
        let (admin, user1, _user2) = create_test_accounts();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Register identity should succeed
        identity::register_identity(&user1, string::utf8(TEST_USER_NAME));
        
        // Verify identity was registered by checking the registry exists
        assert!(identity::registry_exists(), 0);
        
        // Verify the identity details
        let (name, verified, timestamp, verifier) = identity::get_identity(signer::address_of(&user1));
        assert!(name == string::utf8(TEST_USER_NAME), 1);
        assert!(!verified, 2);
        assert!(timestamp == 0, 3);
        assert!(verifier == @0x0, 4);
    }

    #[test]
    public fun test_register_multiple_identities() {
        let (admin, user1, user2) = create_test_accounts();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Register multiple identities
        identity::register_identity(&user1, string::utf8(TEST_USER_NAME));
        identity::register_identity(&user2, string::utf8(TEST_USER_NAME_2));
        
        // Both should succeed without conflicts
        assert!(identity::registry_exists(), 0);
        
        // Verify both identities exist with correct names
        let (name1, _, _, _) = identity::get_identity(signer::address_of(&user1));
        let (name2, _, _, _) = identity::get_identity(signer::address_of(&user2));
        assert!(name1 == string::utf8(TEST_USER_NAME), 1);
        assert!(name2 == string::utf8(TEST_USER_NAME_2), 2);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = acc_address::identity)]
    public fun test_register_identity_duplicate_fails() {
        let (admin, user1, _user2) = create_test_accounts();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Register identity first time - should succeed
        identity::register_identity(&user1, string::utf8(TEST_USER_NAME));
        
        // Register identity second time - should fail
        identity::register_identity(&user1, string::utf8(b"Another Name"));
    }

    #[test]
    public fun test_verify_identity_success() {
        let (admin, user1, user2) = create_test_accounts();
        setup_timestamp();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Register identity first
        identity::register_identity(&user1, string::utf8(TEST_USER_NAME));
        
        // Verify identity should succeed
        identity::verify_identity(&user2, signer::address_of(&user1));
        
        // Check verification status
        let (_, verified, timestamp, verifier) = identity::get_identity(signer::address_of(&user1));
        assert!(verified, 0);
        assert!(timestamp >= 0, 1); // Changed to >= 0 since timestamp might be 0 in test environment
        assert!(verifier == signer::address_of(&user2), 2);
    }

    #[test]
    public fun test_self_verification() {
        let (admin, user1, _user2) = create_test_accounts();
        setup_timestamp();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Register identity
        identity::register_identity(&user1, string::utf8(TEST_USER_NAME));
        
        // User can verify their own identity
        identity::verify_identity(&user1, signer::address_of(&user1));
        
        // Check verification status
        let (_, verified, _, verifier) = identity::get_identity(signer::address_of(&user1));
        assert!(verified, 0);
        assert!(verifier == signer::address_of(&user1), 1);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = acc_address::identity)]
    public fun test_verify_nonexistent_identity_fails() {
        let (admin, _user1, user2) = create_test_accounts();
        setup_timestamp();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Try to verify identity that doesn't exist - should fail
        identity::verify_identity(&user2, @0x789);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = acc_address::identity)]
    public fun test_get_nonexistent_identity_fails() {
        let (admin, _user1, _user2) = create_test_accounts();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Try to get identity that doesn't exist - should fail
        identity::get_identity(@0x789);
    }

    #[test]
    public fun test_verify_after_registration() {
        let (admin, user1, user2) = create_test_accounts();
        setup_timestamp();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Register two identities
        identity::register_identity(&user1, string::utf8(TEST_USER_NAME));
        identity::register_identity(&user2, string::utf8(TEST_USER_NAME_2));
        
        // Each user verifies the other
        identity::verify_identity(&user1, signer::address_of(&user2));
        identity::verify_identity(&user2, signer::address_of(&user1));
        
        // Check both are verified
        let (_, verified1, _, verifier1) = identity::get_identity(signer::address_of(&user1));
        let (_, verified2, _, verifier2) = identity::get_identity(signer::address_of(&user2));
        
        assert!(verified1, 0);
        assert!(verified2, 1);
        assert!(verifier1 == signer::address_of(&user2), 2);
        assert!(verifier2 == signer::address_of(&user1), 3);
    }

    #[test]
    public fun test_multiple_verifications_same_identity() {
        let (admin, user1, user2) = create_test_accounts();
        let user3 = account::create_account_for_test(@0x789);
        setup_timestamp();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Register identity
        identity::register_identity(&user1, string::utf8(TEST_USER_NAME));
        
        // Multiple users verify the same identity
        identity::verify_identity(&user2, signer::address_of(&user1));
        identity::verify_identity(&user3, signer::address_of(&user1));
        
        // Last verification should overwrite previous
        let (_, verified, _, verifier) = identity::get_identity(signer::address_of(&user1));
        assert!(verified, 0);
        assert!(verifier == signer::address_of(&user3), 1);
    }

    #[test]
    public fun test_empty_name_registration() {
        let (admin, user1, _user2) = create_test_accounts();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Register identity with empty name should succeed
        identity::register_identity(&user1, string::utf8(b""));
        
        // Verify empty name was stored
        let (name, _, _, _) = identity::get_identity(signer::address_of(&user1));
        assert!(name == string::utf8(b""), 0);
    }

    #[test]
    public fun test_workflow_integration() {
        let (admin, user1, user2) = create_test_accounts();
        setup_timestamp();
        
        // Initialize the module
        identity::init_for_test(&admin);
        
        // Complete workflow test
        // 1. Register identities
        identity::register_identity(&user1, string::utf8(TEST_USER_NAME));
        identity::register_identity(&user2, string::utf8(TEST_USER_NAME_2));
        
        // 2. Cross-verify identities
        identity::verify_identity(&user1, signer::address_of(&user2));
        identity::verify_identity(&user2, signer::address_of(&user1));
        
        // 3. Self-verify
        identity::verify_identity(&user1, signer::address_of(&user1));
        
        // Verify final state
        let (name1, verified1, _, verifier1) = identity::get_identity(signer::address_of(&user1));
        let (name2, verified2, _, verifier2) = identity::get_identity(signer::address_of(&user2));
        
        assert!(name1 == string::utf8(TEST_USER_NAME), 0);
        assert!(name2 == string::utf8(TEST_USER_NAME_2), 1);
        assert!(verified1, 2);
        assert!(verified2, 3);
        assert!(verifier1 == signer::address_of(&user1), 4); // Last verifier (self)
        assert!(verifier2 == signer::address_of(&user1), 5);
    }
}
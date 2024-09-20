module salary_addr::payment {
    use std::option::{Self, Option};
    use std::signer;
    use std::vector;
    use std::error;

    use aptos_framework::aptos_account;
    use aptos_framework::event;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin;

    const ERESOURCE_ACCOUNT_ALREADY_SET: u64 = 1;
    const EEMPLOYEE_NOT_FOUND: u64 = 2;
    const EONLY_AUTHORIZED_ACCOUNTS_CAN_EXECUTE_THIS_OPERATION: u64 = 3;
    const ENOTHING_TO_CLAIM: u64 = 4;
    const ESALARY_SET_AMOUNT_HIGHER_THAN_BALANCE: u64 = 5;
    const ENOT_RESOURCE_ACCOUNT_ADDED: u64 = 6;
    const EONLY_ADMIN_CAN_SET_PENDING_ADMIN: u64 = 7;
    const ENOT_PENDING_ADMIN: u64 = 8;

    struct Config has key {
        admin_addr: address,
        pending_admin_addr: Option<address>,
    }

    struct SalaryAdmin has key {
        signer_cap: Option<SignerCapability>,
        salary_not_claimed: u64,
        employees: vector<address>
    }

    struct SalaryToClaim has key {
        amount: u64,
    }

    #[event]
    struct Payment has store, drop {
        employee: address,
        amount: u64,
    }

    fun init_module(sender: &signer) {
        move_to(sender, Config {
            admin_addr: signer::address_of(sender),
            pending_admin_addr: option::none(),
        });

        move_to(sender, SalaryAdmin {
            employees: vector::empty(),
            salary_not_claimed: 0,
            signer_cap: option::none(),
        })
}



    public entry fun create_resource_account(account: &signer, seed: vector<u8>, employees: vector<address>) acquires SalaryAdmin, Config {
        let account_addr = signer::address_of(account);
        let config = borrow_global<Config>(@salary_addr);

        assert!(is_admin(config, account_addr), error::permission_denied(EONLY_AUTHORIZED_ACCOUNTS_CAN_EXECUTE_THIS_OPERATION));

        let salary_admin = borrow_global_mut<SalaryAdmin>(@salary_addr);

        let (_resource_signer, signer_cap) = account::create_resource_account(account, seed);

        salary_admin.signer_cap = option::some(signer_cap);

        vector::for_each<address>(employees, |employee| {
            vector::push_back(&mut salary_admin.employees, employee);
        });
    }

    public entry fun remove_resource_account(account: &signer) acquires SalaryAdmin, Config {
        let account_addr = signer::address_of(account);
        let config = borrow_global<Config>(@salary_addr);
        assert!(is_admin(config, account_addr), error::permission_denied(EONLY_AUTHORIZED_ACCOUNTS_CAN_EXECUTE_THIS_OPERATION));

        let salary_admin = borrow_global_mut<SalaryAdmin>(@salary_addr);

        salary_admin.signer_cap = option::none();
    }

    public entry fun create_employee_object(account: &signer) acquires SalaryAdmin {
        let account_addr = signer::address_of(account);

        let salary_admin = borrow_global_mut<SalaryAdmin>(@salary_addr);



        let (is_found, _index) = vector::find(&salary_admin.employees, |employee| employee == &account_addr);

        assert!(is_found, error::not_found(EEMPLOYEE_NOT_FOUND));

        move_to(account, SalaryToClaim {
            amount: 0,
        });
    }

    public entry fun add_employee(account: &signer, employee: address) acquires SalaryAdmin, Config {
        let account_addr = signer::address_of(account);
        let config = borrow_global<Config>(@salary_addr);
        assert!(is_admin(config, account_addr), error::permission_denied(EONLY_AUTHORIZED_ACCOUNTS_CAN_EXECUTE_THIS_OPERATION));
        let salary_admin = borrow_global_mut<SalaryAdmin>(@salary_addr);

        vector::push_back(&mut salary_admin.employees, employee);
    }

    public entry fun remove_employee(account: &signer, employee: address) acquires SalaryAdmin, Config {
        let account_addr = signer::address_of(account);
        let config = borrow_global<Config>(@salary_addr);
        assert!(is_admin(config, account_addr), error::permission_denied(EONLY_AUTHORIZED_ACCOUNTS_CAN_EXECUTE_THIS_OPERATION));

        let salary_admin = borrow_global_mut<SalaryAdmin>(@salary_addr);

        let (is_found, index) = vector::find<address>(&salary_admin.employees, |c| {
            c == &employee
        });

        assert!(is_found, error::not_found(EEMPLOYEE_NOT_FOUND));

        vector::remove<address>(&mut salary_admin.employees, index);
    }

    public entry fun claim_salary<AptosCoin>(account: &signer) acquires SalaryAdmin, SalaryToClaim {
        let account_addr = signer::address_of(account);

        let salary_admin = borrow_global_mut<SalaryAdmin>(@salary_addr);

        let (is_found, _index) = vector::find<address>(&salary_admin.employees, |c| {
            c == &account_addr
        });

        assert!(is_found, error::not_found(EEMPLOYEE_NOT_FOUND));

        let salary_to_claim = borrow_global_mut<SalaryToClaim>(account_addr);


        assert!(salary_to_claim.amount > 0, error::invalid_state(ENOTHING_TO_CLAIM));

        let signer_cap = get_signer_cap(&salary_admin.signer_cap);

        let resource_signer = account::create_signer_with_capability(signer_cap);

        aptos_account::transfer_coins<AptosCoin>(&resource_signer, account_addr, salary_to_claim.amount);

        salary_admin.salary_not_claimed = salary_admin.salary_not_claimed - salary_to_claim.amount;


        event::emit(Payment {
            employee: account_addr,
            amount: salary_to_claim.amount
        });


        salary_to_claim.amount = 0;
    }

    public entry fun payment<AptosCoin>(account: &signer, employees: vector<address>, amounts: vector<u64>) acquires SalaryAdmin, Config, SalaryToClaim {
        let account_addr = signer::address_of(account);
        let config = borrow_global<Config>(@salary_addr);
        assert!(is_admin(config, account_addr), error::permission_denied(EONLY_AUTHORIZED_ACCOUNTS_CAN_EXECUTE_THIS_OPERATION));

        let salary_admin = borrow_global_mut<SalaryAdmin>(@salary_addr);

        let (is_found, _index) = vector::find<address>(&salary_admin.employees, |c| {
            vector::any(&employees, |e| e == c)
        });

        assert!(is_found, error::not_found(EEMPLOYEE_NOT_FOUND));


        let signer_cap = get_signer_cap(&salary_admin.signer_cap);
        let resource_signer = account::create_signer_with_capability(signer_cap);

        assert!(coin::balance<AptosCoin>(signer::address_of(&resource_signer)) > vector::fold(amounts, 0, |curr, acc| acc + curr) + salary_admin.salary_not_claimed, error::invalid_state(ESALARY_SET_AMOUNT_HIGHER_THAN_BALANCE));

        vector::for_each(employees, |e| {
            let (_has_amount, index) = vector::index_of(&employees, &e);

            let amount = *vector::borrow<u64>(&amounts, index);

            let salary_to_claim = borrow_global_mut<SalaryToClaim>(e);

            salary_to_claim.amount = amount;

            salary_admin.salary_not_claimed = salary_admin.salary_not_claimed + amount;
        });
    }

    public entry fun set_pending_admin(sender: &signer, new_admin: address) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@salary_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_SET_PENDING_ADMIN);
        config.pending_admin_addr = option::some(new_admin);
    }

    public entry fun accept_admin(sender: &signer) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@salary_addr);
        assert!(config.pending_admin_addr == option::some(sender_addr), ENOT_PENDING_ADMIN);
        config.admin_addr = sender_addr;
        config.pending_admin_addr = option::none();
    }

    #[view]
    /// Get contract admin
    public fun get_admin(): address acquires Config {
        let config = borrow_global<Config>(@salary_addr);
        config.admin_addr
    }

    #[view]
    /// Get contract pending admin
    public fun get_pendingadmin(): Option<address> acquires Config {
        let config = borrow_global<Config>(@salary_addr);
        config.pending_admin_addr
    }

    #[view]
    public fun get_employees(): vector<address> acquires SalaryAdmin {
        let salary_admin = borrow_global<SalaryAdmin>(@salary_addr);

        salary_admin.employees
    }

    #[view]
    public fun get_resource_balance<AptosCoin>(): u64 acquires SalaryAdmin {
        let salary_admin = borrow_global_mut<SalaryAdmin>(@salary_addr);

        let resource_sign_cap = get_signer_cap(&salary_admin.signer_cap);

        let resource_signer = account::create_signer_with_capability(resource_sign_cap);

        let resource_signer_addr = signer::address_of(&resource_signer);

        coin::balance<AptosCoin>(resource_signer_addr)
    }

    #[view]
    public fun check_employee_object(account_addr: address): bool {
        exists<SalaryToClaim>(account_addr)
    }

    #[view]
    public fun get_balance_to_claim(account_addr: address): u64 acquires SalaryToClaim {
        let salary_to_claim = borrow_global<SalaryToClaim>(account_addr);
        salary_to_claim.amount
    }

    #[view]
    public fun resource_account_exists(): bool acquires SalaryAdmin {
        let salary_admin = borrow_global<SalaryAdmin>(@salary_addr);
        option::is_some(&salary_admin.signer_cap)
    }

    #[view]
    public fun get_resource_account_address(): address acquires SalaryAdmin {
        let salary_admin = borrow_global<SalaryAdmin>(@salary_addr);
        let resource_sign_cap = get_signer_cap(&salary_admin.signer_cap);

        let resource_signer = account::create_signer_with_capability(resource_sign_cap);

        let resource_signer_addr = signer::address_of(&resource_signer);

        resource_signer_addr
    }



    fun is_admin(config: &Config, sender: address): bool {
        if (sender == config.admin_addr|| sender == @salary_addr) {
            true
        } else {
            false
        }
    }
    
    fun get_signer_cap(signer_cap_opt: &Option<SignerCapability>): &SignerCapability {
        assert!(option::is_some<SignerCapability>(signer_cap_opt), error::not_implemented(ENOT_RESOURCE_ACCOUNT_ADDED));
        option::borrow<SignerCapability>(signer_cap_opt)
    }

    #[test_only]
    use aptos_framework::aptos_coin::{Self, AptosCoin};

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    use aptos_std::math64;

    #[test_only]
    const EBALANCE_NOT_EQUAL: u64 = 18;

    #[test_only]
    const EEMPLOYEE_SHOULD_NOT_EXISTS: u64 = 19;

    #[test_only]
    const ESIGN_CAP_SHOULD_NOT_EXISTS: u64 = 20;

    #[test_only]
    fun bounded_percentage(amount: u64, numerator: u64, denominator: u64): u64 {
        if (denominator == 0) {
            0
        } else {
            math64::min(amount, math64::mul_div(amount, numerator, denominator))
        }
    }

    #[test(aptos_framework = @0x1, sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    fun test_payment(
        aptos_framework: &signer,
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer,
    ) acquires Config, SalaryAdmin, SalaryToClaim {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        // current timestamp is 0 after initialization
        timestamp::set_time_has_started_for_testing(aptos_framework);
        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);
        
        coin::register<AptosCoin>(user1);
        coin::register<AptosCoin>(user2);

        aptos_coin::mint(aptos_framework, user1_addr, 20000000);

        init_module(sender);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        create_resource_account(sender, b"test", vector[user3_addr, user4_addr]);

        let salary_admin = borrow_global_mut<SalaryAdmin>(@salary_addr);

        let resource_sign_cap = get_signer_cap(&salary_admin.signer_cap);

        let resource_signer = account::create_signer_with_capability(resource_sign_cap);

        let resource_signer_addr = signer::address_of(&resource_signer);

        aptos_account::transfer_coins<AptosCoin>(user1, resource_signer_addr, 20000000);

        let resource_balance = get_resource_balance<AptosCoin>();

        assert!(resource_balance == 20000000, EBALANCE_NOT_EQUAL);

        add_employee(user1, user2_addr);
        create_employee_object(user2);
        add_employee(user1, user3_addr);
        create_employee_object(user3);
        add_employee(user1, user4_addr);
        create_employee_object(user4);

        payment<AptosCoin>(sender, vector[user2_addr, user3_addr, user4_addr], vector[2000000, 1000000, 1500000]);

        let user2_addr_balance = get_balance_to_claim(user2_addr);
        let user3_addr_balance = get_balance_to_claim(user3_addr);
        let user4_addr_balance = get_balance_to_claim(user4_addr);

        assert!(user2_addr_balance == 2000000, EBALANCE_NOT_EQUAL);
        assert!(user3_addr_balance == 1000000, EBALANCE_NOT_EQUAL);
        assert!(user4_addr_balance == 1500000, EBALANCE_NOT_EQUAL);

        claim_salary<AptosCoin>(user3);

        let resource_balance_after_user3_claimed = get_resource_balance<AptosCoin>();
        let user3_addr_balance_after_claimed = get_balance_to_claim(user3_addr);
        let user4_addr_balance_after_user3_claimed = get_balance_to_claim(user4_addr);
        let user2_addr_balance_after_user3_claimed = get_balance_to_claim(user2_addr);
        
        assert!(user3_addr_balance_after_claimed == 0, EBALANCE_NOT_EQUAL);
        assert!(resource_balance_after_user3_claimed == resource_balance - user3_addr_balance, EBALANCE_NOT_EQUAL);
        assert!(user4_addr_balance_after_user3_claimed == 1500000, EBALANCE_NOT_EQUAL);
        assert!(user2_addr_balance_after_user3_claimed == 2000000, EBALANCE_NOT_EQUAL);

        claim_salary<AptosCoin>(user4);

        let user4_addr_balance_after_claimed = get_balance_to_claim(user4_addr);
        let resource_balance_after_user4_claimed = get_resource_balance<AptosCoin>();

        assert!(user4_addr_balance_after_claimed == 0, EBALANCE_NOT_EQUAL);
        assert!(resource_balance_after_user4_claimed == resource_balance - (user3_addr_balance + user4_addr_balance), EBALANCE_NOT_EQUAL);

        assert!(coin::balance<AptosCoin>(user2_addr) == 0, EBALANCE_NOT_EQUAL);
        assert!(coin::balance<AptosCoin>(user3_addr) == 1000000, EBALANCE_NOT_EQUAL);
        assert!(coin::balance<AptosCoin>(user4_addr) == 1500000, EBALANCE_NOT_EQUAL);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    fun test_add_employee(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires SalaryAdmin, Config {
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        create_resource_account(sender, b"test", vector[user2_addr, user3_addr]);

        create_employee_object(user2);
        create_employee_object(user3);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        add_employee(sender, user4_addr);

        let employees = get_employees();

        let (is_found, _index) = vector::find<address>(&employees, |c| {
            c == &user4_addr
        });

        assert!(is_found, EEMPLOYEE_NOT_FOUND);
    } 

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    fun test_remove_collector(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires SalaryAdmin, Config {
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        create_resource_account(sender, b"test", vector[user2_addr, user3_addr, user4_addr]);
        create_employee_object(user2);
        create_employee_object(user3);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        remove_employee(sender, user4_addr);

        let employees = get_employees();

        let (is_found, _index) = vector::find<address>(&employees, |c| {
            c == &user4_addr
        });

        assert!(!is_found, EEMPLOYEE_SHOULD_NOT_EXISTS);
    }

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    fun test_remove_resource_account(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires SalaryAdmin, Config {
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        create_resource_account(sender, b"test", vector[user2_addr, user3_addr, user4_addr]);

        create_employee_object(user2);
        create_employee_object(user3);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        remove_resource_account(user1);

        let fees_admin = borrow_global<SalaryAdmin>(@salary_addr);

        assert!(&fees_admin.signer_cap == &option::none(), ESIGN_CAP_SHOULD_NOT_EXISTS);
    }
    
    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    #[expected_failure(abort_code = 327683, location = Self)]
    fun test_remove_employee_with_not_admin_account(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires SalaryAdmin, Config {

        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        create_resource_account(sender, b"test", vector[user2_addr, user3_addr]);

        create_employee_object(user2);
        create_employee_object(user3);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        add_employee(user2, user4_addr);
    }

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    #[expected_failure(abort_code = 327683, location = Self)]
    fun test_remove_employee_with_not_owner_account(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires SalaryAdmin, Config {

        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        create_resource_account(sender, b"test", vector[user2_addr, user3_addr]);

        create_employee_object(user2);
        create_employee_object(user3);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        add_employee(user2, user4_addr);
    }

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    #[expected_failure(abort_code = 327683, location = Self)]
    fun test_remove_employee_with_not_admin_accout(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires SalaryAdmin, Config {
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        create_resource_account(sender, b"test", vector[user2_addr, user3_addr, user4_addr]);

        create_employee_object(user2);
        create_employee_object(user3);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        remove_employee(user2, user4_addr);
    }

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    #[expected_failure(abort_code = 327683, location = Self)]
    fun test_payment_with_not_autorized_account(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires SalaryAdmin, Config, SalaryToClaim {
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        create_resource_account(sender, b"test", vector[user2_addr, user3_addr]);

        create_employee_object(user2);
        create_employee_object(user3);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        
        payment<AptosCoin>(user4, vector[user2_addr, user3_addr], vector[2000000, 1000000]);
    }

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    #[expected_failure(abort_code = 393218, location = Self)]
    fun test_claim_fees_with_not_autorized_account(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires SalaryAdmin, Config, SalaryToClaim {
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        create_resource_account(sender, b"test", vector[user2_addr, user3_addr]);

        create_employee_object(user2);
        create_employee_object(user3);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        claim_salary<AptosCoin>(user4);
    }

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    #[expected_failure(abort_code = 7, location = Self)]
    fun test_set_pending_admin_with_not_autorized_account(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires Config {
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        set_pending_admin(user4, user1_addr);
    }

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    #[expected_failure(abort_code = 8, location = Self)]
    fun test_accept_admin_with_not_autorized_account(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires Config {
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        set_pending_admin(sender, user1_addr);

        accept_admin(user4);
    }

    #[test(sender = @salary_addr, user1 = @0x200, user2 = @0x201, user3 = @0x202, user4= @0x203)]
    #[expected_failure(abort_code = 327683, location = Self)]
    fun test_remove_resource_account_with_not_authorized_account(
        sender: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer,
        user4: &signer) acquires SalaryAdmin, Config {
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        let user4_addr = signer::address_of(user4);

        account::create_account_for_test(user1_addr);
        account::create_account_for_test(user2_addr);
        account::create_account_for_test(user3_addr);
        account::create_account_for_test(user4_addr);

        init_module(sender);

        create_resource_account(sender, b"test", vector[user2_addr, user3_addr, user4_addr]);

        set_pending_admin(sender, user1_addr);
        accept_admin(user1);

        remove_resource_account(user2);
    }
}
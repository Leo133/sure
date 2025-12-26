class PlaidItem::Syncer
  attr_reader :plaid_item

  def initialize(plaid_item)
    @plaid_item = plaid_item
  end

  def perform_sync(sync)
    # Phase 1: Import data from Plaid API
    sync.update!(status_text: "Importing accounts from Plaid...") if sync.respond_to?(:status_text)
    plaid_item.import_latest_plaid_data

    # Phase 2: Check account setup status and collect sync statistics
    sync.update!(status_text: "Checking account configuration...") if sync.respond_to?(:status_text)
    total_accounts = plaid_item.plaid_accounts.count
    linked_accounts = plaid_item.plaid_accounts.joins(:account).merge(Account.visible)
    unlinked_accounts = plaid_item.plaid_accounts.left_joins(:account).where(accounts: { id: nil })

    sync_stats = {
      total_accounts: total_accounts,
      linked_accounts: linked_accounts.count,
      unlinked_accounts: unlinked_accounts.count
    }

    if sync.respond_to?(:sync_stats)
      sync.update!(sync_stats: sync_stats)
    end

    # Phase 3: Process transactions for linked accounts
    sync.update!(status_text: "Processing transactions...") if sync.respond_to?(:status_text)
    plaid_item.process_accounts

    # Phase 4: Schedule balance calculations for linked accounts
    sync.update!(status_text: "Calculating balances...") if sync.respond_to?(:status_text)
    plaid_item.schedule_account_syncs(
      parent_sync: sync,
      window_start_date: sync.window_start_date,
      window_end_date: sync.window_end_date
    )
  end

  def perform_post_sync
    # no-op
  end
end

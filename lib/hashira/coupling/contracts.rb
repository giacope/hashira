# frozen_string_literal: true

module Hashira::Coupling::Contracts
  HOOKS = %w[
    initialize initialize_copy initialize_dup initialize_clone inherited included extended prepended
    method_added method_removed method_undefined singleton_method_added const_missing method_missing
    respond_to_missing? marshal_dump marshal_load _dump _load encode_with init_with to_json as_json
    to_param to_partial_path to_model to_key serializable_hash coerce call perform up down change
    table_name_prefix table_name_suffix model_name policy_class matches? should_generate_new_friendly_id?
    send_devise_notification send_reset_password_instructions_notification active_for_authentication?
    inactive_message password_required? email_required? after_confirmation timeout_in
    before_validation after_validation before_save around_save after_save before_create around_create after_create
    before_update around_update after_update before_destroy around_destroy after_destroy after_commit
    after_rollback after_initialize after_find after_touch
  ].to_set.freeze

  ENTRIES = %w[
    controllers helpers views channels mailboxes components policies graphql admin inputs validators jobs workers
    mailers
  ].freeze

  LEVELS = %w[ClassMethods InstanceMethods].freeze
end

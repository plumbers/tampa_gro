class CreateFcmMessages < ActiveRecord::Migration[5.1]
  def change

    create_table :fcm_tokens do |t|
      t.text       :key

      t.timestamp  :revoked_at
      t.timestamps

      t.references :user, foreign_key: true, index: true
      t.references :api_session, foreign_key: true, index: true
    end

    create_table :fcm_messages do |t|
      t.jsonb      :msg
      t.jsonb      :options
      t.jsonb      :origin
      t.jsonb      :target
      t.jsonb      :recipients
      t.jsonb      :errors_hash

      t.jsonb      :send_timestamps
      t.jsonb      :ack_timestamps

      t.datetime   :created_at
      t.datetime   :expired_at
      t.datetime   :ack_at

      t.references :business, foreign_key: true, index: true
      t.references :organization, foreign_key: true, index: true
    end

    add_reference   :fcm_messages, :author, references: :users, index: true
    add_foreign_key :fcm_messages, :users, column: :author_id

  end
end

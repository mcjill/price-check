class CreatePriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :price_histories do |t|
      t.references :product, null: false, foreign_key: true
      t.decimal :price, precision: 12, scale: 2, null: false
      t.string :currency, null: false
      t.datetime :scraped_at, null: false

      t.timestamps
    end

    add_index :price_histories, [:product_id, :scraped_at]
  end
end

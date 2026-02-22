class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :source, null: false
      t.text :url
      t.text :image_url
      t.string :currency, null: false

      t.timestamps
    end

    add_index :products, [:source, :url], unique: true
    add_index :products, [:source, :name]
  end
end

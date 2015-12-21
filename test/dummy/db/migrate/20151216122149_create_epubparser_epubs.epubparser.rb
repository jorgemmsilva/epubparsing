# This migration comes from epubparser (originally 20151216114015)
class CreateEpubparserEpubs < ActiveRecord::Migration
  def change
    create_table :epubparser_epubs do |t|
      t.text :book

      t.timestamps null: false
    end
  end
end

# This migration comes from epubparser (originally 20151216114426)
class AddAttachmentToEpub < ActiveRecord::Migration
  def change
  	add_attachment :epubparser_epubs, :epub
  end
end

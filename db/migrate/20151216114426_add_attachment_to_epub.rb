class AddAttachmentToEpub < ActiveRecord::Migration
  def change
  	add_attachment :epubparser_epubs, :epub
  end
end

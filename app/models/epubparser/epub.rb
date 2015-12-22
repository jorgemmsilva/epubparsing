module Epubparser
  class Epub < ActiveRecord::Base
    has_attached_file :epub, :path => ":rails_root/tmp/epubs/:id/:filename"
    validates_attachment :epub, content_type: { content_type: "application/epub+zip" }

    include Rails.application.routes.url_helpers


    def to_jq_upload
    {
      "name" => read_attribute(:epub_file_name),
      "size" => read_attribute(:epub_file_size),
      "url" => epub.url(:original),
      #"delete_url" => epub_path(self),
      "delete_type" => "DELETE"
    }
    end


    def get_metadata
      aux_book = read_attribute(:book)

    {
      "id" => id,
      #{}"book" => read_attribute(:book).id
      "identifier" => aux_book.id,
      "title" => aux_book.title,
      "creator" => aux_book.creator,
      "publisher" => aux_book.publisher,
      "description" => aux_book.description,
      "subject" => aux_book.subject,
      #"sections" => aux_book.sections,
      #"chapters" => aux_book.chapters,
      "url" => epub.url(:original),
      "file_name" => read_attribute(:epub_file_name),
      "file_size" => read_attribute(:epub_file_size)
      #"delete_url" => epub_path(self),
      #{}"delete_type" => "DELETE"
    }
    end


    serialize :book


  end
end

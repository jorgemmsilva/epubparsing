module Epubparser
  class Epub < ActiveRecord::Base
    has_attached_file :epub, :path => ":rails_root/tmp/epubs/:id/:filename"
    validates_attachment :epub, content_type: { content_type: ["application/epub+zip", "application/zip" ] }

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
      #'chapters' => aux_book.chapters,
      "url" => epub.url(:original),
      "file_name" => read_attribute(:epub_file_name),
      "file_size" => read_attribute(:epub_file_size)
      #"delete_url" => epub_path(self),
      #{}"delete_type" => "DELETE"
    }
    end


    def get_data
    
      bk = read_attribute(:book)
      sections = bk.sections
      chap_list = bk.chapters.values
      new_chapters = {}
      new_chapters['chapters'] = bk.chapters
      new_chapters["content"] = {}
      new_chapters["stylesheets"] = []
      new_heading_id = 1
      imgs = {} # img name => cloud url

      epub_path = File.dirname(sections.first)
      epub_files = Dir.glob("#{epub_path}/**/*")

      # find images and stylesheets present in the epub
      css_files = epub_files.map{|f| f if File.extname(f).include? ".css"}.compact  # css
      img_files = epub_files.map{|f| f if File.extname(f) =~ /.(png|gif|jpg|jpeg|svg)/}.compact# gif jpg jpeg png svg

      #upload image and css files to cloud server
      css_files.each do |f|
        new_chapters["stylesheets"] << upload_to_cloud(f)
      end

      uploaded_img_files = {}
      img_files.each do |f|
        uploaded_img_files[File.basename(f)] = upload_to_cloud(f)
      end

      #iterate throu all the html files contained in the epub
      sections.each do |s|

        path = File.dirname(s.to_s)
        file = File.open(s.to_s)
        path.slice! Rails.root.to_s

        filename = File.basename(file)

        text = file.read

        doc = Nokogiri::XML.parse(text)
        doc.remove_namespaces!
        subchaps = doc.xpath("//*[self::h1 or self::h2]")
        doc_images = doc.xpath("//*[self::img]")
        current_chap = ''

        #repath the images with the generated cloud url
        doc_images.each do |i|
          i["src"] = uploaded_img_files[File.basename(i["src"])]
        end

        #check for chapters inside this file
        chap_list.each do |c|
          if c["self"].include? filename  #find subchapters
            subchaps.each do |sc|
              heading_text = sc.text.strip.gsub(/\s+/, " ")
              if sc.name == 'h1' and new_chapters['chapters'].keys.map { |k| k.gsub(/\s+/, " ") }.include? heading_text #there are h1s which are not part of the folder structure!
                current_chap = heading_text
              else 
                if sc.name == 'h2'
                  new_chapters['chapters'][current_chap][heading_text] = "#{filename}#subchapter#{new_heading_id}"
                  sc.set_attribute("id","subchapter#{new_heading_id}")
                  new_heading_id+=1
                end
              end
            end
          end
        end

        new_chapters["content"][filename] = CGI.escapeHTML(doc.xpath("//body").first.to_s)

        file.close
      end 

      # sections.each do |s|
      #   filename = File.basename(s.to_s)

      #   html_content = new_chapters["content"][filename].gsub(/\n/,' ')
      #   html_content = html_content.gsub(/> </,'><')

      #   #---------
      #   #perceber quais os ficheiros que tem mais que um capitulo
      #   number_of_chaps_in_file = new_chapters['chapters'].values.map{|k| k['self']}.flatten.join('=').scan(/(?==#{filename})/).count
      #   if number_of_chaps_in_file > 1
      #     #caso existam mais que um capitulo por ficheiro, e preciso parti-lo

      #     doc = Nokogiri::XML.parse(html_content)
      #     chaps_to_split = [] #quais os capitulos a partir
      #     new_chapters['chapters'].keys.each do |c|
      #       if new_chapters['chapters'][c]['self'].include? filename
      #         chaps_to_split << c
      #       end
      #     end

      #     first = doc.children.first.children.first
      #     last =  doc.children.first.children.last

      #     index = 0
      #     chaps_to_split.each do |c|
      #       # 1 - partir do inicio do ficheiro até ao 2º capitulo da pagina
      #       if index == 0
      #         first = doc.children.first.children.first
      #         second_chap_id = new_chapters['chapters'][chaps_to_split.second]['self']
      #         second_chap_id = second_chap_id[second_chap_id.rindex('#')..second_chap_id.size]
      #         last = first
      #         while (last.next.css("#{second_chap_id}")).empty?
      #           last = last.next
      #         end
      #       else
      #         # 2 - partir de capitulo em capitulo ate ao fim do ficheiro
      #         first_chap_id = new_chapters['chapters'][chaps_to_split[index]]['self']
      #         first_chap_id = first_chap_id[first_chap_id.rindex('#')..first_chap_id.size]

      #         first = doc.children.first.children.first
      #         while (first.css("#{first_chap_id}")).empty?
      #           first = first.next
      #         end

      #         last =  doc.children.first.children.last

      #         if(c != chaps_to_split.last) #caso nao seja o ultimo
      #           second_chap_id = new_chapters['chapters'][chaps_to_split[index+1]]['self']
      #           second_chap_id = second_chap_id[second_chap_id.rindex('#')..second_chap_id.size]
      #           last = first
      #           while (last.next.css("#{second_chap_id}")).empty?
      #             last = last.next
      #           end
      #         end

      #       end

      #       #3 - colocar no "self" o html partido de cada um dos capitulos
      #       new_chapters['chapters'][c]['self'] = collect_between(first, last)
      #       index += 1

      #       if index == 3
      #         raise new_chapters['chapters'].inspect
      #       end

      #     end
      #   else 
      #     if number_of_chaps_in_file = 1
      #       #4 - colocar o html integral dos ficheiros que so tem 1 capitulo no "self"
      #       new_chapters['chapters'].keys.each do |c|
      #         if new_chapters['chapters'][c]['self'].include? filename
      #           new_chapters['chapters'][c]['self'] = html_content
      #         end
      #       end
      #     end
      #   end

      #     #5 - FALTA INSERIR OS FICHEIROS QUE NAO ESTAO NO 'chapters' o nome destes vai ser apenas o filename
      #   #---------
      # end

      return new_chapters.to_json
    end


    serialize :book

    private
       def upload_to_cloud(filepath)

        amazon = S3::Service.new(access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])
        bucket = amazon.buckets.find('stukproductionimages')
        download = open(filepath)

        #filename = "#{substep.recipe.slug}_substep_#{substep.id}_#{Time.now.to_i}"
        filename = File.basename(filepath)
        file = bucket.objects.build(filename)
        file.content = (File.read download)
        #file.content_type = substep.mime_type

        if file.save
           return file.url
        end
      end

      def collect_between(first, last)
        #raise "first = #{first.inspect} | last = #{last.inspect} "
        result = first.to_s
        while first != last #and (first.css("#{'#'+last.attr('id')}")).empty? do
          first = first.next
          result += first.to_s
        end
        result
      end

  end
end

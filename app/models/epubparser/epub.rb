module Epubparser
  class Epub < ActiveRecord::Base


    #has_attached_file :epub, :path => ":rails_root/tmp/epubs/:id/:filename"
    has_attached_file :epub, :path => "epubs/:id/:filename",
                    :storage => :s3,
                    :s3_credentials => Proc.new{|a| a.instance.s3_credentials }

    def s3_credentials
      {:bucket => "codeplaceepubsassets", :access_key_id => ENV['AWS_ACCESS_KEY_ID'], :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'], :s3_host_name => 's3-us-west-2.amazonaws.com', :secure => true}
    end


    validates_attachment :epub, content_type: { content_type: ["application/epub+zip", "application/zip" ] }

    include Rails.application.routes.url_helpers

    def get_metadata
      aux_book = read_attribute(:book)
    {
      "id" => id,
      "identifier" => aux_book.id,
      "title" => aux_book.title,
      "creator" => aux_book.creator,
      "publisher" => aux_book.publisher,
      "description" => aux_book.description,
      "subject" => aux_book.subject,
      "rights" => aux_book.rights,
      #'chapters' => aux_book.chapters,
      "url" => epub.url(:original),
      "file_name" => read_attribute(:epub_file_name),
      "file_size" => read_attribute(:epub_file_size)
    }
    end


    def get_data
    
      #EpubUtils.unzip(epub.path,location (tmpfoldeR) )
      bk = EpubUtils.parse(epub.url)
      #book_path =  "#{Rails.root}/tmp/file.epub"
      #bk = read_attribute(:book)
      sections = bk.sections
      chap_list = bk.chapters.values
      new_chapters = {}
      new_chapters['chapters'] = bk.chapters
      new_chapters["content"] = {}
      new_chapters["stylesheets"] = []
      new_heading_id = 1
      imgs = {} # img name => cloud url

      epub_path = File.dirname(sections.first)
      epub_files = Dir.glob("#{Rails.root}/tmp/tmp/**/*")

      # find images and stylesheets present in the epub
      css_files = epub_files.map{|f| f if File.extname(f).include? ".css"}.compact  # css
      img_files = epub_files.map{|f| f if File.extname(f) =~ /.(png|gif|jpg|jpeg|svg)/}.compact# gif jpg jpeg png svg


      #convert css files and upload them to cloud server
      css_files.each do |f|

        css_content = ""

        #add parent element to the stylesheet (sass), convert to regular css and rename the file
        File.open(f, "r") { |file|
          css_content =  file.read
          engine = Sass::Engine.new(".book-wrapper {#{css_content}}", :syntax => :scss)
          css_content = engine.render
        }

        File.open(f, "w+") { |file|
          file.write(css_content)
        }

        filename = File.basename(f)
        new_file = File.dirname(f) + "/" + id.to_s + "-" + filename
        File.rename(f,new_file) #rename the images to have the epub id
        new_chapters["stylesheets"] << upload_to_cloud(new_file,"text/css")

      end

      uploaded_img_files = {}
      

      #upload image files to cloud server
      img_files.each do |f|
        filename = File.basename(f)
        new_file = File.dirname(f) + "/" + id.to_s + "-" + filename
        File.rename(f,new_file) #rename the images to have the epub id
        uploaded_img_files[filename] = upload_to_cloud(new_file)
      end

      #iterate throu all the html files contained in the epub, substitute images and (sub)chapters to book structure
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

        new_chapters["content"][filename] = doc.xpath("//body").first.to_s#CGI.escapeHTML(doc.xpath("//body").first.to_s)

        file.close
      end 

      working_chap = nil
      output = new_chapters['chapters']
      
      chapters_in_file = new_chapters['chapters'].values.map{|k| k['self']}.flatten
      chapters_in_file =  chapters_in_file.map{ |c| c.include?('/') ? c[c.rindex('/')+1..c.size] : c}

      chapters_in_file_str = "=" + chapters_in_file.join('=')

      sections.each do |s|
        filename = File.basename(s.to_s)

        html_content = new_chapters["content"][filename].gsub(/\n/,' ')

        #perceber quais os ficheiros que tem mais que um capitulo
        number_of_chaps_in_file = chapters_in_file_str.scan(/(?==#{filename})/).count

        if number_of_chaps_in_file > 1
          #caso existam mais que um capitulo por ficheiro, e preciso parti-lo
          doc = Nokogiri::XML.parse(html_content)
          child_tree = getChildTree(doc)

          chaps_to_split = [] #quais os capitulos a partir

          new_chapters['chapters'].keys.each do |c|
            str = new_chapters['chapters'][c]['self']
            str =  str[str.rindex('/')+1..str.size] unless !str.include? '/'
            str =  str[0..str.rindex('#')-1] unless !str.include? '#'
            if str == filename
              chaps_to_split << c
            end
          end



          first = child_tree.children.first
          last =  child_tree.children.last

          index = 0
          chaps_to_split.each do |c|
            # 1 - partir do inicio do ficheiro até ao 2º capitulo da pagina
            if index == 0
              first = child_tree.children.first
              second_chap_id = new_chapters['chapters'][chaps_to_split.second]['self']
              second_chap_id = second_chap_id[second_chap_id.rindex('#')..second_chap_id.size]
              last = first

              while (last.next.css("#{second_chap_id}")).empty?
                last = last.next
              end
            else
              
              # 2 - partir de capitulo em capitulo ate ao fim do ficheiro
              first_chap_id = new_chapters['chapters'][chaps_to_split[index]]['self']
              first_chap_id = first_chap_id[first_chap_id.rindex('#')..first_chap_id.size]

              first = child_tree.children.first
              while (first.css("#{first_chap_id}")).empty?
                first = first.next
              end

              last =  child_tree.children.last

              if(c != chaps_to_split.last) #caso ainda nao seja o ultimo cap da pagina
                second_chap_id = new_chapters['chapters'][chaps_to_split[index+1]]['self']
                second_chap_id = second_chap_id[second_chap_id.rindex('#')..second_chap_id.size]

                last = first

                while (last.next.css("#{second_chap_id}")).empty?
                  last = last.next
                end
              end
            end

            #3 - colocar no "self" o html partido de cada um dos capitulos
            output[c]['self'] = CGI.escapeHTML(collect_between(first, last))
            index += 1
            working_chap = c
            
          end
        else 
          if number_of_chaps_in_file == 1
            #4 - colocar o html integral dos ficheiros que so tem 1 capitulo no "self"
            new_chapters['chapters'].keys.each do |c|
              str = new_chapters['chapters'][c]['self']
              str =  str[str.rindex('/')+1..str.size] unless !str.include? '/'
              str =  str[0..str.rindex('#')-1] unless !str.include? '#'
              if str == filename
                output[c]['self'] = CGI.escapeHTML(html_content)
                working_chap = c
              end
            end
          else #number_of_chapsin file == 0
              #5 - FALTA INSERIR OS FICHEIROS QUE NAO ESTAO EM 'chapters'
              if (working_chap.nil?) #fist pages of the book (probably cover,index,prefac,etc)
                if !output['first_pages'].nil?
                  output['first_pages']['self'] += CGI.escapeHTML(html_content)
                else
                  tmp = {}
                  tmp['first_pages'] = {'self' => CGI.escapeHTML(html_content)}
                  tmp.merge!(output)
                  output = tmp
                end
              else
                output[working_chap]['self'] += CGI.escapeHTML(html_content)
              end
          end
        end
      end

      to_return = {}
      to_return["book"] = output
      to_return["css"] =[]
      to_return["css"] = new_chapters["stylesheets"]
      return to_return.to_json
    end

    serialize :book

    private
       def upload_to_cloud(filepath,mimetype = nil)

        amazon = S3::Service.new(access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])
        bucket = amazon.buckets.find("codeplaceepubsassets")
        download = open(filepath)

        filename = File.basename(filepath)
        file = bucket.objects.build(filename)
        file.content = (File.read download)

        file.content_type = mimetype if mimetype

        if file.save
           return file.url.gsub("http","https")
        end
      end

      def getChildTree(doc)
        doc.children.each do |child|
          n_childs = child.children.size
          if(n_childs > 0)
            if(n_childs > 3)
              return doc.children
            end
            doc = getChildTree(doc.children)
          end
        end
        return doc
      end

      def collect_between(first, last)
        result = first.to_s
        while first != last 
          first = first.next
          result += first.to_s
        end
        result
      end

  end
end

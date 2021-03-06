require "epubparser/engine"
require 'open-uri'

module Epubparser

	class Book
		def initialize (id=nil,title=nil,creator=nil,publisher=nil,description=nil,subject=nil,date=nil,rights=nil)
			@id = id
			@title = title
			@creator = creator
			@publisher = publisher
			@description = description
			@subject = subject
			@date = date
			@rights = rights
			@sections = []
			@chapters = {}
		end

		def add_chapter (chapter_name,file)
			@chapters[chapter_name] = file
		end

		def add_section (section)
			@sections << section
		end

		def set_sections (sections)
			@sections = sections
		end

		def add_chapters (chapters)
			@chapters = @chapters.merge(chapters)
		end

		attr_accessor :id, :title, :creator, :publisher, :description, :subject, :date, :rights, :sections, :chapters
	end

	class EpubUtils

		#Extract all epub files from an archive to a destination folder
		#Status is returned true if successful, false otherwise

		def self.unzip_epubs(archive, destination_folder)
		  return false unless FileTest.exist?(archive)

		  system "mkdir #{destination_folder}"

		  file_array = Dir.glob("#{archive}/*.epub")
		  
		  file_array.each do |f|
		  		filename = File.basename(f, '.epub')
		  	 	system "unzip -o \"#{f}\" -d \"#{destination_folder}\""
		  end
		  return true
		end

		def self.parse_metadata (containerFile)
			#puts "--------------------BOOK METADATA-------------------------------"
			#open the .opf file and parse the metadata
			#puts containerFile
			opf = Nokogiri::XML.parse(File.open(containerFile))
			opf.remove_namespaces!

			uid = opf.xpath("//@unique-identifier").text
			#puts "unique-identifier attribute: " + uid

			id = opf.xpath("//package//metadata//*[@id=\"#{uid}\"]").text
			#puts "identifier (#{uid}) : " + id
			# ids.each do |id|
			# 	#puts "book identifier (#{uid}) : " + id.text
			# end

			title = opf.xpath("//package//metadata//title").text
			#puts "title: " + title

			creator = opf.xpath("//package//metadata//creator").text
			#puts "creator: " + creator

			subject = opf.xpath("//package//metadata//subject").text
			#puts "subject: " + subject

			publisher = opf.xpath("//package//metadata//publisher").text
			#puts "publisher: " + publisher

			date = opf.xpath("//package//metadata//date").text
			#puts "date: " + date

			rights = opf.xpath("//package//metadata//rights").text
			#puts "rights: " + rights

			description = opf.xpath("//package//metadata//description").text
			#puts "description: " + description

			book = Book.new(id,title,creator,publisher,description,subject,date,rights)

			#get book spine
			spine = opf.xpath("package/spine//itemref")
			spine_arr = spine.map{ |v| v.attributes['idref'].text}

			#parse book sections
			spine_arr.each do |file_id|
				section = opf.xpath("package/manifest//item[@id=\"#{file_id}\"]").first
				str = section.attributes['href'].text
				if !str.rindex('.').nil? and [".html",".xhtml"].include? str[str.rindex('.')..str.size]
						book.add_section(CGI::unescapeHTML(str))
				end
			end

			#parse book sections
			# sections = opf.xpath("package/manifest//item//@href")
			# sections.each do |p|
			# 	str = p.to_s
			# 	if !str.rindex('.').nil?
			# 		if [".html",".xhtml"].include? str[str.rindex('.')..str.size]
			# 			book.add_section(str)
			# 		end
			# 	end
			#end

			return book
		end

		#parses the table of contents of a single epub
		def self.parse_toc(toc_file,sections)

			chapters = {}
			
			if File.exist?(toc_file)
				##puts "toc.ncx @ :" + toc_file
				toc = Nokogiri::XML.parse(File.open(toc_file))
				toc.remove_namespaces!	
				navMap = toc.xpath("ncx//navMap")
				navPoints = navMap.xpath("navPoint")
				navPoints.each do |nav|

					##puts "#{nav.to_s} - #{nav.xpath("navLabel//text").to_s}  - #{nav.xpath("content//@src").to_s}\nYOOOOOOOOOOOOOO\n\n"

					chapter = CGI::unescapeHTML(nav.xpath("navLabel//text").text.gsub(/\s+/, " "))
					file = CGI::unescapeHTML(nav.xpath("content//@src").to_s.gsub(/\s+/, " "))

					chapters[chapter] = {}
					chapters[chapter]["self"] = file

					subchapters = nav.xpath("navPoint")
					subchapters.each do |sc|
						subchapter = CGI::unescapeHTML(sc.xpath("navLabel//text").text.gsub(/\s+/, " "))
						subfile = CGI::unescapeHTML(sc.xpath("content//@src").to_s.gsub(/\s+/, " "))
						chapters[chapter][subchapter] = subfile
					end

				end
			else
				sections.each do |s|
					if s.include? "/"
						str = s[s.rindex('/')+1..s.size]
						chapters[str] = {"self" => CGI::unescapeHTML(str)}
					else 
						chapters[s] = {"self" => CGI::unescapeHTML(s)}
					end
				end
			end

			return chapters
		end

		def self.rename_sections(folder,book)
			Dir.chdir(folder)
			file_array = Dir.glob("**/*").select { |f| [".xml", ".html", ".xhtml", ".ncx"].include?(File.extname(f))}
			
			section_number = 1;

			new_sections = []

			to_rename = {}

			book.sections.each do |filename|
				#change the sections filenames in the book object
				old_filename = filename
				if filename.include?('/')
					new_filename = filename[0..filename.rindex('/')] + section_number.to_s + filename[filename.rindex('.')..filename.size]
				else
					new_filename = section_number.to_s + filename[filename.rindex('.')..filename.size]
				end
				new_sections << folder + '/' + new_filename

				section_number += 1

				#change the sections references throu the epub files
				file_array.each do |file|
					text = File.read(file)

					#new_contents = text.gsub(/search_regexp/, "replacement string")
					new_contents = text.gsub(CGI.escape(old_filename), new_filename)
					
					#write changes to the file,
				 	File.open(file, "w") {|file| file.puts new_contents }
				end


				if old_filename.include? '#'
			 		old_filename = old_filename[0..old_filename.rindex('#')-1]
			 	end

			 	if new_filename.include? '#'
			 		new_filename = new_filename[0..new_filename.rindex('#')-1]
			 	end

			 	to_rename[File.basename(old_filename)] = File.basename(new_filename)
			 	##puts "to_rename #{old_filename}  ------   #{new_filename}"
			end


			#rename the filenames
			file_array.each do |file|
				filename = File.basename(file)
				if to_rename.keys.include? filename
		 			##puts "-----> renaming file: #{filename} into #{to_rename[filename]}"
		 			File.rename(file,File.dirname(file) + '/' + to_rename[filename])
		 		end

			end

			book.set_sections(new_sections)

			#Dir.chdir(@parent_folder)

			return book
		end

		#parses the a single epub
		def self.parse_epub(folder)


			Dir.chdir(folder)
			
			container = Nokogiri::XML.parse(File.open(folder + "/META-INF/container.xml"))
			
			#check for parsing erros
			if container.errors.size != 0 
				#puts "XML parsing errors: " 
				#puts container.errors
			end


			#find the root .opf file
			rootfile = CGI::unescapeHTML(container.xpath("//xmlns:rootfile//@full-path").text)
			rootfile = folder + "/" + rootfile.to_s
			return false unless FileTest.exist?(rootfile)
			#puts "rootfile found at: " + rootfile

			content_folder = File.dirname(rootfile)
			
			#parse book metadata
			book = parse_metadata(rootfile)
			
			#renames the epub chapters
			book = rename_sections(content_folder,book)
			
			#parse book table of contents
			book.add_chapters(parse_toc(content_folder + "/toc.ncx",book.sections))

			#puts "------------------------SECTIONS"
			#puts book.sections

			#puts "\n\n---------------------CHAPTERS"
			#puts book.chapters

			return book
		end

		def self.parse_epubs(folder)

			books = Array.new

			Dir.chdir(folder) #changes current directory to the tmp folder
			@parent_folder = Dir.pwd
			epubs_array = Dir.glob('*').select {|f| File.directory? f}
			
			#puts "--------------------"
			#puts "Number of extracted epubs:" + epubs_array.size.to_s
			#puts "--------------------"
			epubs_array.each do |f|
				books << parse_epub(f)
			end
			return books
		end

		#parses the metadata of a single epub
		def self.simple_parse_epub(folder)

			Dir.chdir(folder)
			
			container = Nokogiri::XML.parse(File.open(folder + "/META-INF/container.xml"))
			
			#check for parsing erros
			if container.errors.size != 0 
				puts "XML parsing errors: " 
				puts container.errors
			end


			#find the root .opf file
			rootfile = CGI::unescapeHTML(container.xpath("//xmlns:rootfile//@full-path").text)
			rootfile = folder + "/" + rootfile.to_s
			return false unless FileTest.exist?(rootfile)
			#puts "rootfile found at: " + rootfile

			content_folder = File.dirname(rootfile)
			
			#parse book metadata
			book = parse_metadata(rootfile)

			return book
		end



		def self.get_metadata (epub_path,epub_id)
			filepath = "#{Rails.root}/tmp/#{epub_id}"
			FileUtils.mkdir_p (filepath)
			filepath += "/#{epub_id}-epub.epub"

			# open(filepath, 'wb') do |file|
			# 	file << open("#{epub_path}").read
			# end

			IO.copy_stream(open(epub_path), filepath)

			epubFolder = File.dirname(filepath)
			tmp_folder = File.dirname(filepath) + '/tmp/'

			unzip_epubs(epubFolder,tmp_folder)
			book = simple_parse_epub(tmp_folder)
			return book
		end

		def self.parse (epub_path,epub_id)

			filepath = "#{Rails.root}/tmp/#{epub_id}"
			FileUtils.mkdir_p (filepath)
			filepath += "/#{epub_id}-epub.epub"

			# open(filepath, 'wb') do |file|
			# 	file << open("#{epub_path}").read
			# end

			IO.copy_stream(open(epub_path), filepath)

			epubFolder = File.dirname(filepath)
			tmp_folder = File.dirname(filepath) + '/tmp/'

			unzip_epubs(epubFolder,tmp_folder)
			book = parse_epub(tmp_folder)
			return book
		end

	end
end

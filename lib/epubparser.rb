require "epubparser/engine"

module Epubparser

	class Book
		def initialize (id=nil,title=nil,creator=nil,publisher=nil,description=nil,subject=nil,date=nil,rights=nil)
			@id = id
			@title = title
			@creator = creator
			@publisher = publisher
			@description = description
			@subject = subject
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
			puts "--------------------BOOK METADATA-------------------------------"
			#open the .opf file and parse the metadata
			puts containerFile
			opf = Nokogiri::XML.parse(File.open(containerFile))
			opf.remove_namespaces!

			uid = opf.xpath("//@unique-identifier").text
			puts "unique-identifier attribute: " + uid

			id = opf.xpath("//package//metadata//*[@id=\"#{uid}\"]").text
			puts "identifier (#{uid}) : " + id
			# ids.each do |id|
			# 	puts "book identifier (#{uid}) : " + id.text
			# end

			title = opf.xpath("//package//metadata//title").text
			puts "title: " + title

			creator = opf.xpath("//package//metadata//creator").text
			puts "creator: " + creator

			subject = opf.xpath("//package//metadata//subject").text
			puts "subject: " + subject

			publisher = opf.xpath("//package//metadata//publisher").text
			puts "publisher: " + publisher

			date = opf.xpath("//package//metadata//date").text
			puts "date: " + date

			rights = opf.xpath("//package//metadata//rights").text
			puts "rights: " + rights

			description = opf.xpath("//package//metadata//description").text
			puts "description: " + description

			book = Book.new(id,title,creator,publisher,description,subject,date,rights)

			#parse book sections
			sections = opf.xpath("//package//manifest//item//@href")
			sections.each do |p|
				if !p.text.match(/.html|.xhtml|.xml/).nil?
					book.add_section(p.text)
				end
			end

			return book
		end

		#parses the table of contents of a single epub
		def self.parse_toc(toc_file)

			chapters = {}

			#puts "toc.ncx @ :" + toc_file
			toc = Nokogiri::XML.parse(File.open(toc_file))
			toc.remove_namespaces!
			navPoints = toc.xpath("//ncx//navMap//navPoint")
			navPoints.each do |nav|
				chapter = nav.xpath(".//text").text.gsub(/\s+/, " ")
				file = nav.xpath(".//content//@src").text.gsub(/\s+/, " ")
				chapters[chapter] = {}
				chapters[chapter]["self"] = file
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
					new_contents = text.gsub(old_filename, new_filename)
					
					#write changes to the file,
				 	File.open(file, "w") {|file| file.puts new_contents }
				end


				if old_filename.include? '#'
			 		old_filename = old_filename[0..old_filename.rindex('#')-1]
			 	end

			 	if new_filename.include? '#'
			 		new_filename = new_filename[0..new_filename.rindex('#')-1]
			 	end

			 	to_rename[old_filename] = new_filename
			 	#puts "to_rename #{old_filename}  ------   #{new_filename}"
			end

			#rename the filenames
			file_array.each do |file|
				filename = File.basename(file)
				if to_rename.keys.include? filename
		 			#puts "-----> renaming file: #{filename} into #{to_rename[filename]}"
		 			File.rename(file,File.dirname(file) + '/' + to_rename[filename])
		 		end

			end

			book.set_sections(new_sections)

			#Dir.chdir(@parent_folder)

			return book
		 	
		end

		#parses the metadata of a single epub
		def self.parse_epub(folder)


			Dir.chdir(folder)
			
			container = Nokogiri::XML.parse(File.open(folder + "/META-INF/container.xml"))
			
			#check for parsing erros
			if container.errors.size != 0 
				puts "XML parsing errors: " 
				puts container.errors
			end


			#find the root .opf file
			rootfile = container.xpath("//xmlns:rootfile//@full-path")
			rootfile = folder + "/" + rootfile.to_s
			return false unless FileTest.exist?(rootfile)
			puts "rootfile found at: " + rootfile

			content_folder = File.dirname(rootfile)
			
			#parse book metadata
			book = parse_metadata(rootfile)
			
			#renames the epub chapters
			book = rename_sections(content_folder,book)
			
			#parse book table of contents
			book.add_chapters(parse_toc(content_folder + "/toc.ncx"))

			puts "------------------------SECTIONS"
			puts book.sections

			puts "\n\n---------------------CHAPTERS"
			puts book.chapters

			return book
		end

		def self.parse_epubs(folder)

			books = Array.new

			Dir.chdir(folder) #changes current directory to the tmp folder
			@parent_folder = Dir.pwd
			epubs_array = Dir.glob('*').select {|f| File.directory? f}
			
			puts "--------------------"
			puts "Number of extracted epubs:" + epubs_array.size.to_s
			puts "--------------------"
			epubs_array.each do |f|
				books << parse_epub(f)
			end
			return books
		end

		def self.parse (epub_path)

			epubFolder = File.dirname(epub_path)
			tmp_folder = File.dirname(epub_path) + '/tmp/'

			unzip_epubs(epubFolder,tmp_folder)
			book = parse_epub(tmp_folder)
			# puts "ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"
			# puts book.id
			# puts book.title
			# puts book.creator
			# puts book.publisher
			# puts book.description
			# puts book.subject
			# puts book.sections
			# puts book.chapters
			# puts "ΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩΩ"
			return book
		end


		# #console parameters
		# epubFolder = ARGV[0]	#epub files folder

		# #parameters
		# tmp_folder = 'tmp/'
		# #@final_folder = 'final/'


		# # yo = Book.new("123")
		# # puts yo.instance_variable_get("@title")

		# unzip_epubs(epubFolder,tmp_folder)
		# books = parse_epubs(tmp_folder)
	end
end

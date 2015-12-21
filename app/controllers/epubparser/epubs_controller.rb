require_dependency "epubparser/application_controller"

module Epubparser
  class EpubsController < ApplicationController
    before_action :set_epub, only: [:show, :edit, :update, :destroy]

    # GET /epubs
    def index
      @epubs = Epub.all
    end



    # GET /epubs/1
    def show

    	ActiveSupport.escape_html_entities_in_json = true 
    	#request for the epub data (chapters content)

		@epub = Epub.find(params[:id])
		bk = Book.new @epub.book
		sections = bk.id.sections
		chap_list = bk.id.chapters.values
		new_chapters = bk.id.chapters
		new_chapters["content"] = {}
		new_heading_id = 1
		stylesheets = {} # stylesheetId => cloud url
		imgs = {} # imgId => cloud url

		@debug = ''

		@content = {}

		epub_path = File.dirname(sections.first)
		epub_files = Dir.glob("#{epub_path}/**/*")

		# find images and stylesheets present in the epub
		css_files = epub_files.map{|f| f if File.extname(f).include? ".css"}.compact  # css
		img_files = epub_files.map{|f| f if File.extname(f) =~ /.(png|gif|jpg|jpeg|svg)/}.compact# gif jpg jpeg png svg
		
		#upload image and css files to cloud server
		uploaded_css_files = {}
		css_files.each do |f|
			uploaded_css_files[File.basename(f)] = upload_to_cloud(f)
		end

		uploaded_img_files = {}
		img_files.each do |f|
			uploaded_img_files[File.basename(f)] = upload_to_cloud(f)
		end


		#iterate throu all the html files contained in the epub
		sections.each do |s|

			path = File.dirname(s.to_s)
			file = File.open(s.to_s)
			path.slice! Rails.public_path.to_s

			filename = File.basename(file)

			text = file.read

			#√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√√ ON HOLD √√√√√√√√√√√√√√√√√√√√√√√√√√√√
			#rewrite all references to external files (css, imgs,html hrefs, etc)
			#text = text.gsub(/src=\"(?!http)(?!www)|href=\"(?!http)(?!www)/, "src=\"" => "src=\"#{path}/","href=\"" => "href=\"#{path}/")

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
						if sc.name == 'h1' and new_chapters.keys.map { |k| k.gsub(/\s+/, " ") }.include? heading_text #there are h1s which are not part of the folder structure!
							current_chap = heading_text
						else 
							if sc.name == 'h2'
								new_chapters[current_chap][heading_text] = "#{filename}#subchapter#{new_heading_id}"
								sc.set_attribute("id","subchapter#{new_heading_id}")
								new_heading_id+=1
							end
						end
					end
				end
			end

			new_chapters["content"][filename] = CGI.escapeHTML(doc.xpath("//body//*").to_s)

		end 

		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @new_chapters.to_json }
		end

    end

    # GET /epubs/new
    def new
      @epub = Epub.new
    end

    # GET /epubs/1/edit
    def edit
    end

    # POST /epubs
    def create

      @upload = Epub.new({epub: params[:epub].first})

      respond_to do |format|

        if @upload.save

			#epub parsed successfully
			@upload.book = EpubUtils.parse(Rails.public_path.to_s + @upload.epub.url.to_s)
			@upload.save


			#raise [@upload.get_metadata].to_json

			format.html {
				render :json => [@upload.get_metadata].to_json,
				:content_type => 'text/html',
				:layout => false
			}

			
			format.json { render json: {files: [@upload.get_metadata]}, status: :created}

			# format.html {
			# 	render :json => [@upload.to_jq_upload].to_json,
			# 	:content_type => 'text/html',
			# 	:layout => false
			# }

			# format.json { render json: {files: [@upload.to_jq_upload]}, status: :created}
        else
          format.html { render action: "new" }
          format.json { render json: @upload.errors, status: :unprocessable_entity }
        end
      end
      # @epub = Epub.new(epub_params)

      # if @epub.save
      #   redirect_to @epub, notice: 'Epub was successfully created.'
      # else
      #   render :new
      # end
    end

    # PATCH/PUT /epubs/1
    def update
      if @epub.update(epub_params)
        redirect_to @epub, notice: 'Epub was successfully updated.'
      else
        render :edit
      end
    end

    # DELETE /epubs/1
    def destroy
      @epub.destroy
      redirect_to epubs_url, notice: 'Epub was successfully destroyed.'
    end

    private
    # Use callbacks to share common setup or constraints between actions.
    def set_epub
      @epub = Epub.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def epub_params
      params.require(:epub).permit(:book)
    end


    def upload_to_cloud(filepath)
		#amazon = S3::Service.new(access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])
		#bucket = amazon.buckets.find('stukproductionimages')
		#url = substep.content
		#download = open(url)


		amazon = S3::Service.new(access_key_id: AWS_ACCESS_KEY_ID, secret_access_key: AWS_SECRET_ACCESS_KEY)
		bucket = amazon.buckets.find('stukproductionimages')
		download = open(filepath)

		#filename = "#{substep.recipe.slug}_substep_#{substep.id}_#{Time.now.to_i}"
		filename = File.basename(filepath)
		file = bucket.objects.build(filename)
		file.content = (File.read download)
		#file.content_type = substep.mime_type

		if file.save
		   @debug+= " url: #{file.url}  "
		end
    end

  end
end

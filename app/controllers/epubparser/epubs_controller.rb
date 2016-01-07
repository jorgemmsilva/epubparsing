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

      epub = Epub.find(params[:id])

      respond_to do |format|
      	format.html # show.html.erb
      	format.json { render json: epub.get_data}
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
          
          @upload.book = EpubUtils.parse(@upload.epub.url,@upload.id)

          @upload.save

          format.html {
          	render :json => [@upload.get_metadata].to_json,
          	:content_type => 'text/html',
          	:layout => false
          }

          format.json { render json: {files: [@upload.get_metadata]}, status: :created}

        else
          format.html { render action: "new" }
          format.json { render json: @upload.errors, status: :unprocessable_entity }
        end
      end

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

    end
end
